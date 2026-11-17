import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_transfer/core/constants/app_constants.dart';
import 'package:offline_transfer/models/transfer_chunk.dart';
import 'package:offline_transfer/models/transfer_item.dart';
import 'package:offline_transfer/services/encryption_service.dart';
import 'package:offline_transfer/services/transfer_service.dart';

class TestLink {
  final Directory directory;
  final key = EncryptionService.instance.generateKey();
  final data = StreamController<Uint8List>();
  final controls = StreamController<Uint8List>.broadcast();
  late final StreamIterator<Uint8List> iterator = StreamIterator(data.stream);
  late final TransferService sender;
  late final TransferService receiver;
  final sentProgress = <TransferProgress>[];
  final receivedProgress = <TransferProgress>[];
  final starts = <int>[];
  final files = <String>[];
  int? failAt;
  int? corruptAt;
  int? dropAt;
  bool dropVerification = false;
  bool duplicate = false;
  bool dropAcks = false;
  int sentChunks = 0;
  void Function(int)? onChunk;
  int outstanding = 0;
  int peakOutstanding = 0;
  int maxPacket = 0;
  StreamSubscription<TransferProgress>? subscription;
  Future<void>? serving;

  TestLink(this.directory) {
    sender = TransferService.forTesting(
      controlStream: controls.stream,
      receiveDirectory: () async => directory,
      responseTimeout: const Duration(seconds: 2),
      verificationTimeout: const Duration(milliseconds: 500),
      sendPayload: (bytes) async {
        if (bytes.length > maxPacket) maxPacket = bytes.length;
        if (bytes[0] == MessageType.chunk.index) {
          final length = ByteData.sublistView(bytes).getUint32(1);
          final header = jsonDecode(
            utf8.decode(bytes.sublist(5, 5 + length)),
          ) as Map<String, dynamic>;
          final index = header['ci'] as int;
          sentChunks++;
          onChunk?.call(index);
          if (failAt != null && index >= failAt!) {
            throw StateError('Simulated disconnect');
          }
          outstanding++;
          if (outstanding > peakOutstanding) peakOutstanding = outstanding;
          if (index == dropAt) return;
          if (index == corruptAt) {
            bytes = Uint8List.fromList(bytes);
            bytes[bytes.length - 1] ^= 1;
          }
          data.add(bytes);
          if (duplicate) data.add(bytes);
        } else {
          data.add(bytes);
        }
      },
    );
    receiver = TransferService.forTesting(
      controlStream: const Stream<Uint8List>.empty(),
      receiveDirectory: () async => directory,
      sendPayload: (bytes) async {
        final msg = ProtocolMessage.fromAuthenticatedBytes(bytes, key);
        if (msg.type == MessageType.transferResume) {
          starts.add(msg.payload['sfc'] as int);
          outstanding = 0;
        }
        if (msg.type == MessageType.chunkAck) {
          outstanding = 0;
          if (dropAcks) return;
        }
        if (msg.type == MessageType.hashVerify && dropVerification) return;
        controls.add(bytes);
      },
    );
    subscription = sender.progressStream.listen(sentProgress.add);
    serving = _serve();
  }

  Future<void> _serve() async {
    while (await iterator.moveNext()) {
      final bytes = iterator.current;
      if (bytes[0] != MessageType.transferInit.index) continue;
      final init = TransferInitPayload.fromJson(
        ProtocolMessage.fromAuthenticatedBytes(bytes, key).payload,
      );
      final path = await receiver.receiveFile(
        initPayload: init,
        payloadStream: const Stream<Uint8List>.empty(),
        payloadIterator: iterator,
        sessionKey: key,
        onProgress: receivedProgress.add,
      );
      if (path != null) files.add(path);
    }
  }

  Future<void> close() async {
    receiver.cancel();
    await iterator.cancel();
    await data.close();
    await serving;
    await subscription?.cancel();
    await controls.close();
  }
}

void main() {
  late Directory temporary;
  late TestLink link;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('offline_transfer_test_');
    link = TestLink(Directory('${temporary.path}/received'));
  });
  tearDown(() async {
    await link.close();
    await temporary.delete(recursive: true);
  });
  Future<TransferItem> source(
    String id,
    int size, {
    String name = 'sample.bin',
  }) async {
    final file = File('${temporary.path}/$id');
    final bytes = Uint8List.fromList(
      List.generate(size, (i) => (i * 13 + 7) % 256),
    );
    await file.writeAsBytes(bytes);
    return TransferItem(
      transferId: id,
      fileName: name,
      fileSize: size,
      sourcePath: file.path,
      totalChunks: TransferChunk.calculateTotalChunks(size),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isSender: true,
    );
  }

  test(
    'streams a multi-window file with exact bytes and bounded packets',
    () async {
      final item = await source('large', 5 * 1024 * 1024 + 17);
      await link.sender.sendFile(transferItem: item, sessionKey: link.key);
      await Future<void>.delayed(Duration.zero);
      expect(link.sentProgress.last.status, TransferProgressStatus.completed);
      expect(
        await File(link.files.single).readAsBytes(),
        await File(item.sourcePath!).readAsBytes(),
      );
      expect(link.maxPacket, lessThanOrEqualTo(32 * 1024));
      expect(
        link.peakOutstanding,
        lessThanOrEqualTo(AppConstants.maxInFlightChunks),
      );
      expect(link.sentProgress.length, lessThan(item.totalChunks));
    },
  );

  test(
    'receives consecutive files, empty files, and preserves existing names',
    () async {
      for (var i = 0; i < 3; i++) {
        final item = await source(
          'file-$i',
          i == 0 ? 0 : 1000 + i,
          name: 'same.bin',
        );
        await link.sender.sendFile(transferItem: item, sessionKey: link.key);
        link.receiver.cancel();
      }
      await Future<void>.delayed(Duration.zero);
      expect(link.files.length, 3);
      expect(link.files.toSet().length, 3);
      expect(await File(link.files.first).length(), 0);
      expect(link.starts, [0, 0, 0]);
    },
  );

  test('resumes a failed transfer from its durable checkpoint', () async {
    final item = await source(
      'resume',
      AppConstants.chunkSize * AppConstants.ackWindowSize * 3 + 7,
    );
    link.failAt = AppConstants.ackWindowSize + 15;
    await expectLater(
      link.sender.sendFile(transferItem: item, sessionKey: link.key),
      throwsStateError,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    link.failAt = null;
    await link.sender.sendFile(transferItem: item, sessionKey: link.key);
    await Future<void>.delayed(Duration.zero);
    expect(link.starts, [0, AppConstants.ackWindowSize]);
    expect(
      await File(link.files.single).readAsBytes(),
      await File(item.sourcePath!).readAsBytes(),
    );
  });

  test('rejects corrupted ciphertext without reporting success', () async {
    final item = await source('corrupt', AppConstants.chunkSize * 5);
    link.corruptAt = 2;
    await expectLater(
      link.sender.sendFile(transferItem: item, sessionKey: link.key),
      throwsStateError,
    );
    expect(link.files, isEmpty);
    expect(
      link.sentProgress.any(
        (p) => p.status == TransferProgressStatus.completed,
      ),
      isFalse,
    );
  });

  test('rejects a missing chunk instead of acknowledging a hole', () async {
    final item = await source('missing', AppConstants.chunkSize * 5);
    link.dropAt = 2;
    await expectLater(
      link.sender.sendFile(transferItem: item, sessionKey: link.key),
      throwsStateError,
    );
    expect(link.files, isEmpty);
  });

  test('does not report completion without peer verification', () async {
    final item = await source('unconfirmed', 1000);
    link.dropVerification = true;
    await expectLater(
      link.sender.sendFile(transferItem: item, sessionKey: link.key),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      link.sentProgress.any(
        (p) => p.status == TransferProgressStatus.completed,
      ),
      isFalse,
    );
  });

  test('ignores duplicate chunks without duplicating bytes', () async {
    final item = await source('duplicate', AppConstants.chunkSize * 3 + 11);
    link.duplicate = true;
    await link.sender.sendFile(transferItem: item, sessionKey: link.key);
    await Future<void>.delayed(Duration.zero);
    expect(
      await File(link.files.single).readAsBytes(),
      await File(item.sourcePath!).readAsBytes(),
    );
  });

  test('rejects modified and wrong-key control messages', () {
    final message = ProtocolMessage(
      type: MessageType.complete,
      payload: {'tid': 'test'},
    );
    final bytes = message.authenticatedBytes(link.key);
    expect(
      ProtocolMessage.fromAuthenticatedBytes(bytes, link.key).type,
      MessageType.complete,
    );
    bytes[3] ^= 1;
    expect(
      () => ProtocolMessage.fromAuthenticatedBytes(bytes, link.key),
      throwsFormatException,
    );
    expect(
      () => ProtocolMessage.fromAuthenticatedBytes(
        message.authenticatedBytes(link.key),
        EncryptionService.instance.generateKey(),
      ),
      throwsFormatException,
    );
  });

  test('receiver pause stops the sender until resume', () async {
    final item = await source('pause', AppConstants.chunkSize * 10);
    Future<void>? pauseCheck;
    link.onChunk = (index) {
      if (index != 2) return;
      link.receiver.pause();
      pauseCheck = Future<void>(() async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          final count = link.sentChunks;
          await Future<void>.delayed(const Duration(milliseconds: 80));
          expect(link.sentChunks, count);
        } finally {
          link.receiver.resume();
        }
      });
    };
    await link.sender.sendFile(transferItem: item, sessionKey: link.key);
    await pauseCheck;
    expect(
      link.sentProgress.any((p) => p.status == TransferProgressStatus.paused),
      isTrue,
    );
    expect(link.files.length, 1);
  });

  test('missing ACK times out rather than reporting success', () async {
    final item = await source('ack-timeout', AppConstants.chunkSize * 2);
    link.dropAcks = true;
    await expectLater(
      link.sender.sendFile(transferItem: item, sessionKey: link.key),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      link.sentProgress.any(
        (p) => p.status == TransferProgressStatus.completed,
      ),
      isFalse,
    );
    expect(link.files, isEmpty);
  });

  test('local cancel releases a receiver waiting for data', () async {
    final input = StreamController<Uint8List>();
    final progress = <TransferProgress>[];
    final receiving = link.receiver.receiveFile(
      initPayload: const TransferInitPayload(
        transferId: 'idle',
        fileName: 'idle.bin',
        fileSize: 100,
        totalChunks: 1,
        fileHash: '',
      ),
      payloadStream: input.stream,
      sessionKey: link.key,
      onProgress: progress.add,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    link.receiver.cancel();
    expect(await receiving.timeout(const Duration(seconds: 1)), isNull);
    expect(progress.last.status, TransferProgressStatus.cancelled);
    await input.close();
  });

  test('uses the production filename sanitizer for traversal and control characters', () {
    expect(
      TransferService.sanitizeFileName('../../bad\u0000.txt'),
      isNot(anyOf(contains('/'), contains('..'), contains('\u0000'))),
    );
    expect(TransferService.sanitizeFileName('.'), 'received_file');
  });
}
