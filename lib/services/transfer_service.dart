import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../models/transfer_chunk.dart';
import '../models/transfer_item.dart';
import 'encryption_service.dart';
import 'nearby_service.dart';

/// Bounded streaming: success means the peer verified the saved file.
class TransferService {
  TransferService._()
    : _sendPayload = NearbyService.instance.sendPayload,
      _controlStream = NearbyService.instance.payloadStream,
      _receiveDirectory = _defaultReceiveDirectory,
      responseTimeout = const Duration(seconds: 30),
      verificationTimeout = const Duration(minutes: 10);

  TransferService.forTesting({
    required this._sendPayload,
    required this._controlStream,
    required this._receiveDirectory,
    this.responseTimeout = const Duration(seconds: 30),
    this.verificationTimeout = const Duration(minutes: 10),
  });

  static final TransferService instance = TransferService._();
  final Future<void> Function(Uint8List) _sendPayload;
  final Stream<Uint8List> _controlStream;
  final Future<Directory> Function() _receiveDirectory;
  final Duration responseTimeout;
  final Duration verificationTimeout;
  final _crypto = EncryptionService.instance;
  final _progressController = StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progressStream => _progressController.stream;
  bool _isCancelled = false;
  bool _isPaused = false;
  bool _remotePaused = false;
  bool _busy = false;
  String? _activeId;
  Uint8List? _key;
  Object? _remoteError;
  int _lastAckedChunk = -1;
  int get lastAckedChunk => _lastAckedChunk;
  Completer<void>? _wake;
  Completer<void> _cancelSignal = Completer<void>();

  Future<void> _send(MessageType type, Map<String, dynamic> payload) =>
      _sendPayload(
        ProtocolMessage(type: type, payload: payload).authenticatedBytes(_key!),
      );

  void _begin(String id, Uint8List key) {
    if (_busy) throw StateError('Another transfer is active');
    _busy = true;
    _activeId = id;
    _key = key;
    _isCancelled = false;
    _isPaused = false;
    _remotePaused = false;
    _remoteError = null;
    _lastAckedChunk = -1;
    _cancelSignal = Completer<void>();
  }

  void _check() {
    if (_isCancelled) throw const TransferCancelled();
    if (_remoteError != null) throw StateError('Peer: $_remoteError');
  }

  void _notify() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  Future<bool> _moveNext(StreamIterator<Uint8List> iterator) {
    _check();
    // A fresh signal avoids retaining one cancellation listener per file chunk.
    _cancelSignal = Completer<void>();
    return Future.any<bool>([
      iterator.moveNext(),
      _cancelSignal.future.then<bool>((_) => throw const TransferCancelled()),
    ]);
  }

  Future<void> _waitUntil(bool Function() ready, Duration timeout) async {
    var deadline = DateTime.now().add(timeout);
    while (!ready()) {
      _check();
      if (_isPaused || _remotePaused) {
        deadline = DateTime.now().add(timeout);
      } else if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Peer response timed out', timeout);
      }
      _wake = Completer<void>();
      await _wake!.future.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () {},
      );
    }
    _check();
  }

  Future<void> sendFile({
    required TransferItem transferItem,
    required Uint8List sessionKey,
    int startFromChunk = 0,
  }) async {
    _begin(transferItem.transferId, sessionKey);
    RandomAccessFile? raf;
    StreamSubscription<Uint8List>? controls;
    var bytesSent = 0;
    var chunkIndex = 0;
    int? receiverStart;
    var verified = false;
    final id = transferItem.transferId;
    final size = transferItem.fileSize;
    final total = TransferChunk.calculateTotalChunks(size);
    void emit(
      TransferProgressStatus status, {
      double speed = 0,
      String? error,
    }) {
      _progressController.add(
        TransferProgress(
          transferId: id,
          bytesTransferred: bytesSent,
          totalBytes: size,
          currentChunk: _lastAckedChunk,
          totalChunks: total,
          speedBps: speed,
          status:
              status == TransferProgressStatus.transferring &&
                  (_isPaused || _remotePaused)
              ? TransferProgressStatus.paused
              : status,
          errorMessage: error,
        ),
      );
    }

    try {
      if (transferItem.sourcePath == null) {
        throw StateError('No local source file');
      }
      final file = File(transferItem.sourcePath!);
      if (await file.length() != size) {
        throw StateError('Source file size changed');
      }
      controls = _controlStream.listen(
        (bytes) {
          try {
            final msg = ProtocolMessage.fromAuthenticatedBytes(
              bytes,
              sessionKey,
            );
            if (msg.payload['tid'] != id) return;
            switch (msg.type) {
              case MessageType.transferResume:
                receiverStart ??= msg.payload['sfc'] as int;
                break;
              case MessageType.chunkAck:
                final ack = msg.payload['lac'] as int;
                if (ack >= 0 && ack < total && ack < chunkIndex) {
                  onAckReceived(ack);
                }
                break;
              case MessageType.hashVerify:
                verified = msg.payload['ok'] == true;
                if (!verified) _remoteError = 'File verification failed';
                break;
              case MessageType.pause:
                _remotePaused = true;
                emit(TransferProgressStatus.paused);
                break;
              case MessageType.resume:
                _remotePaused = false;
                emit(
                  _isPaused
                      ? TransferProgressStatus.paused
                      : TransferProgressStatus.transferring,
                );
                break;
              case MessageType.cancel:
                _isCancelled = true;
                break;
              case MessageType.error:
                _remoteError = msg.payload['message'] ?? 'Transfer failed';
                break;
              default:
                break;
            }
            _notify();
          } on FormatException {
            // Ignore unauthenticated traffic and stale protocol versions.
          } catch (e) {
            _remoteError = e;
            _notify();
          }
        },
        onError: (Object e) {
          _remoteError = e;
          _notify();
        },
      );
      emit(TransferProgressStatus.connecting);
      await _send(
        MessageType.transferInit,
        TransferInitPayload(
          transferId: id,
          fileName: transferItem.fileName,
          fileSize: size,
          totalChunks: total,
          fileHash: '',
          startFromChunk: startFromChunk,
          mimeType: transferItem.mimeType,
        ).toJson(),
      );
      await _waitUntil(() => receiverStart != null, responseTimeout);
      chunkIndex = receiverStart!;
      if (chunkIndex < 0 || chunkIndex > total) {
        throw StateError('Invalid resume offset');
      }
      _lastAckedChunk = chunkIndex - 1;
      bytesSent = min(size, chunkIndex * AppConstants.chunkSize);
      raf = await file.open();
      // Hash the prefix too so a changed source cannot validate a stale resume.
      final digests = <Digest>[];
      final hashSink = sha256.startChunkedConversion(
        ChunkedConversionSink.withCallback(digests.addAll),
      );
      var prefix = bytesSent;
      while (prefix > 0) {
        _check();
        final data = await raf.read(min(prefix, 256 * 1024));
        if (data.isEmpty) throw StateError('Source file truncated');
        hashSink.add(data);
        prefix -= data.length;
      }
      var measuredBytes = bytesSent;
      var measuredAt = DateTime.now();
      var lastEmit = measuredAt;
      var speed = 0.0;
      while (chunkIndex < total) {
        _check();
        await _waitUntil(() => !_isPaused && !_remotePaused, responseTimeout);
        await _waitUntil(
          () => chunkIndex - _lastAckedChunk <= AppConstants.maxInFlightChunks,
          responseTimeout,
        );
        final length = min(AppConstants.chunkSize, size - bytesSent);
        final raw = await raf.read(length);
        if (raw.length != length) {
          throw StateError('Source file changed during transfer');
        }
        hashSink.add(raw);
        final encrypted = _crypto.serializeChunk(
          _crypto.encrypt(raw, sessionKey),
        );
        final header = utf8.encode(
          jsonEncode(
            TransferChunk(
              transferId: id,
              chunkIndex: chunkIndex,
              totalChunks: total,
              offset: bytesSent,
              length: length,
              fileSize: size,
              fileName: transferItem.fileName,
            ).toJson(),
          ),
        );
        final packet = Uint8List(5 + header.length + encrypted.length);
        if (packet.length > 32 * 1024) {
          throw StateError('Chunk metadata exceeds the Nearby payload limit');
        }
        packet[0] = MessageType.chunk.index;
        ByteData.sublistView(packet).setUint32(1, header.length);
        packet.setRange(5, 5 + header.length, header);
        packet.setRange(5 + header.length, packet.length, encrypted);
        chunkIndex++;
        await _sendWithRetry(packet);
        bytesSent += length;
        final now = DateTime.now();
        final elapsed = now.difference(measuredAt).inMilliseconds;
        if (elapsed >= 500) {
          speed = (bytesSent - measuredBytes) * 1000 / elapsed;
          measuredAt = now;
          measuredBytes = bytesSent;
        }
        if (now.difference(lastEmit).inMilliseconds >=
            AppConstants.progressIntervalMs) {
          emit(TransferProgressStatus.transferring, speed: speed);
          lastEmit = now;
        }
      }
      await _waitUntil(() => _lastAckedChunk == total - 1, responseTimeout);
      hashSink.close();
      emit(TransferProgressStatus.verifying);
      await _send(MessageType.complete, {
        'tid': id,
        'fh': digests.single.toString(),
      });
      await _waitUntil(() => verified, verificationTimeout);
      emit(TransferProgressStatus.completed);
    } on TransferCancelled {
      emit(TransferProgressStatus.cancelled);
    } catch (e) {
      emit(TransferProgressStatus.failed, error: e.toString());
      await _bestEffortSend(MessageType.error, {
        'tid': id,
        'message': e.toString(),
      });
      rethrow;
    } finally {
      await controls?.cancel();
      await raf?.close();
      _busy = false;
      _activeId = null;
    }
  }

  Future<void> _sendWithRetry(Uint8List packet) async {
    for (var attempt = 0; ; attempt++) {
      _check();
      try {
        await _sendPayload(packet);
        return;
      } catch (_) {
        if (attempt + 1 >= AppConstants.maxRetryCount) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
  }

  Future<String?> receiveFile({
    required TransferInitPayload initPayload,
    required Stream<Uint8List> payloadStream,
    required Uint8List sessionKey,
    required void Function(TransferProgress) onProgress,
    int resumeFromChunk = 0,
    StreamIterator<Uint8List>? payloadIterator,
  }) async {
    final init = initPayload;
    _begin(init.transferId, sessionKey);
    final iterator = payloadIterator ?? StreamIterator(payloadStream);
    RandomAccessFile? raf;
    var received = 0;
    var nextChunk = 0;
    String? partPath;
    var lastEmit = DateTime.now();
    var measuredAt = lastEmit;
    var measuredBytes = 0;
    var speed = 0.0;
    void emit(
      TransferProgressStatus status, {
      String? error,
      String? destination,
    }) {
      onProgress(
        TransferProgress(
          transferId: init.transferId,
          bytesTransferred: received,
          totalBytes: init.fileSize,
          currentChunk: nextChunk - 1,
          totalChunks: init.totalChunks,
          speedBps: speed,
          status:
              status == TransferProgressStatus.transferring &&
                  (_isPaused || _remotePaused)
              ? TransferProgressStatus.paused
              : status,
          errorMessage: error,
          destinationPath: destination,
        ),
      );
    }

    try {
      if (!RegExp(r'^[a-zA-Z0-9-]{1,64}$').hasMatch(init.transferId) ||
          init.fileSize < 0 ||
          init.totalChunks !=
              TransferChunk.calculateTotalChunks(init.fileSize)) {
        throw const FormatException('Invalid transfer metadata');
      }
      final dir = await _receiveDirectory();
      await dir.create(recursive: true);
      final name = sanitizeFileName(init.fileName);
      partPath = p.join(dir.path, '${init.transferId}.part');
      final checkpoint = File('$partPath.json');
      final part = File(partPath);
      // Resume only from a durable contiguous checkpoint, never file length alone.
      if (await part.exists() && await checkpoint.exists()) {
        try {
          final saved = jsonDecode(
            await checkpoint.readAsString(),
          ) as Map<String, dynamic>;
          if (saved['size'] == init.fileSize &&
              saved['name'] == init.fileName) {
            final count = saved['next'] as int;
            final length = min(init.fileSize, count * AppConstants.chunkSize);
            if (count >= 0 &&
                count <= init.totalChunks &&
                await part.length() >= length) {
              nextChunk = count;
              received = length;
            }
          }
        } catch (_) {
          /* Restart after an interrupted checkpoint write. */
        }
      }
      raf = await part.open(mode: FileMode.append);
      await raf.truncate(received);
      await raf.setPosition(received);
      measuredBytes = received;
      Future<void> saveCheckpoint() async {
        await raf!.flush();
        await checkpoint.writeAsString(
          jsonEncode({
            'size': init.fileSize,
            'name': init.fileName,
            'next': nextChunk,
          }),
          flush: true,
        );
      }

      await _send(MessageType.transferResume, {
        'tid': init.transferId,
        'sfc': nextChunk,
      });
      emit(TransferProgressStatus.transferring);
      while (await _moveNext(iterator)) {
        _check();
        final bytes = iterator.current;
        if (bytes.isEmpty) continue;
        if (bytes[0] == MessageType.chunk.index) {
          if (bytes.length < 5) throw const FormatException('Truncated chunk');
          final headerLength = ByteData.sublistView(bytes).getUint32(1);
          if (headerLength > 4096 || 5 + headerLength >= bytes.length) {
            throw const FormatException('Invalid chunk header');
          }
          final meta = TransferChunk.fromJson(
            jsonDecode(utf8.decode(bytes.sublist(5, 5 + headerLength)))
                as Map<String, dynamic>,
          );
          if (meta.transferId != init.transferId) continue;
          if (meta.chunkIndex < nextChunk) continue;
          if (meta.chunkIndex != nextChunk ||
              meta.offset != received ||
              meta.totalChunks != init.totalChunks ||
              meta.fileSize != init.fileSize ||
              meta.length !=
                  min(AppConstants.chunkSize, init.fileSize - received)) {
            throw const FormatException('Unexpected chunk sequence or size');
          }
          final decrypted = _crypto.decrypt(
            _crypto.deserializeChunk(bytes.sublist(5 + headerLength)),
            sessionKey,
          );
          if (decrypted.length != meta.length) {
            throw const FormatException('Chunk length mismatch');
          }
          await raf!.writeFrom(decrypted);
          received += decrypted.length;
          nextChunk++;
          if (nextChunk % AppConstants.ackWindowSize == 0 ||
              nextChunk == init.totalChunks) {
            await saveCheckpoint();
            await _send(
              MessageType.chunkAck,
              ChunkAckPayload(
                transferId: init.transferId,
                lastAckedChunk: nextChunk - 1,
                bytesReceived: received,
              ).toJson(),
            );
          }
          final now = DateTime.now();
          final elapsed = now.difference(measuredAt).inMilliseconds;
          if (elapsed >= 500) {
            speed = (received - measuredBytes) * 1000 / elapsed;
            measuredAt = now;
            measuredBytes = received;
          }
          if (now.difference(lastEmit).inMilliseconds >=
              AppConstants.progressIntervalMs) {
            emit(TransferProgressStatus.transferring);
            lastEmit = now;
          }
        } else {
          final msg = ProtocolMessage.fromAuthenticatedBytes(bytes, sessionKey);
          if (msg.payload['tid'] != init.transferId) continue;
          if (msg.type == MessageType.cancel) throw const TransferCancelled();
          if (msg.type == MessageType.error) {
            throw StateError('${msg.payload['message']}');
          }
          if (msg.type == MessageType.pause || msg.type == MessageType.resume) {
            _remotePaused = msg.type == MessageType.pause;
            emit(
              _remotePaused
                  ? TransferProgressStatus.paused
                  : TransferProgressStatus.transferring,
            );
          }
          if (msg.type != MessageType.complete) continue;
          if (received != init.fileSize || nextChunk != init.totalChunks) {
            throw StateError('Incomplete file');
          }
          await raf!.flush();
          await raf.close();
          raf = null;
          emit(TransferProgressStatus.verifying);
          final hash = await computeFileHash(part.path);
          _check();
          if (hash != msg.payload['fh']) {
            await checkpoint.delete();
            throw StateError('File integrity check failed');
          }
          var finalPath = p.join(dir.path, name);
          var suffix = 1;
          while (await File(finalPath).exists()) {
            finalPath = p.join(
              dir.path,
              '${p.basenameWithoutExtension(name)} (${suffix++})${p.extension(name)}',
            );
          }
          await part.rename(finalPath);
          if (await checkpoint.exists()) await checkpoint.delete();
          await _send(MessageType.hashVerify, {
            'tid': init.transferId,
            'ok': true,
          });
          emit(TransferProgressStatus.completed, destination: finalPath);
          return finalPath;
        }
      }
      throw StateError('Connection closed before transfer completed');
    } on TransferCancelled {
      emit(TransferProgressStatus.cancelled, destination: partPath);
    } catch (e) {
      emit(
        TransferProgressStatus.failed,
        error: e.toString(),
        destination: partPath,
      );
      await _bestEffortSend(MessageType.error, {
        'tid': init.transferId,
        'message': e.toString(),
      });
    } finally {
      await raf?.close();
      if (payloadIterator == null) await iterator.cancel();
      _busy = false;
      _activeId = null;
    }
    return null;
  }

  Future<void> _bestEffortSend(
    MessageType type,
    Map<String, dynamic> data,
  ) async {
    try {
      await _send(type, data);
    } catch (_) {}
  }

  void pause() {
    _isPaused = true;
    if (_busy) {
      unawaited(_bestEffortSend(MessageType.pause, {'tid': _activeId}));
    }
    _notify();
  }

  void resume() {
    _isPaused = false;
    if (_busy) {
      unawaited(_bestEffortSend(MessageType.resume, {'tid': _activeId}));
    }
    _notify();
  }

  void cancel() {
    _isCancelled = true;
    _isPaused = false;
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
    if (_busy) {
      unawaited(_bestEffortSend(MessageType.cancel, {'tid': _activeId}));
    }
    _notify();
  }

  void onAckReceived(int index) {
    _lastAckedChunk = max(index, _lastAckedChunk);
    _notify();
  }

  static Future<String> computeFileHash(String path) => Isolate.run(() async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  });
  static String sanitizeFileName(String name) {
    var safe = name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '_')
        .replaceAll('..', '_')
        .trim();
    if (safe.isEmpty || safe == '.') safe = 'received_file';
    return safe.length > 160 ? safe.substring(0, 160) : safe;
  }

  static Future<Directory> _defaultReceiveDirectory() async {
    if (Platform.isAndroid) {
      try {
        final dir = Directory(
          '/storage/emulated/0/Download/${AppConstants.receivedFolder}',
        );
        await dir.create(recursive: true);
        final probe = File(p.join(dir.path, '.write_probe'));
        await probe.writeAsString('ok');
        await probe.delete();
        return dir;
      } catch (_) {}
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return Directory(p.join(external.path, AppConstants.receivedFolder));
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, AppConstants.receivedFolder));
  }
}

class TransferCancelled implements Exception {
  const TransferCancelled();
}

enum TransferProgressStatus {
  connecting,
  transferring,
  paused,
  verifying,
  completed,
  failed,
  cancelled,
}

class TransferProgress {
  final String transferId;
  final int bytesTransferred;
  final int totalBytes;
  final int currentChunk;
  final int totalChunks;
  final double speedBps;
  final TransferProgressStatus status;
  final String? errorMessage;
  final String? destinationPath;
  const TransferProgress({
    required this.transferId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.currentChunk,
    required this.totalChunks,
    required this.speedBps,
    required this.status,
    this.errorMessage,
    this.destinationPath,
  });
  double get progressFraction => totalBytes > 0
      ? (bytesTransferred / totalBytes).clamp(0.0, 1.0)
      : (status == TransferProgressStatus.completed ? 1.0 : 0.0);
  double get progressPercent => progressFraction * 100;
  double? get eta =>
      speedBps < 1024 ? null : max(0, totalBytes - bytesTransferred) / speedBps;
  String get speedLabel {
    if (speedBps < 1024) return '${speedBps.toStringAsFixed(0)} B/s';
    if (speedBps < 1024 * 1024) {
      return '${(speedBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get etaLabel {
    final seconds = eta?.ceil();
    if (seconds == null) return '--';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }
}
