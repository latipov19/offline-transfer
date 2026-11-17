import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../models/transfer_chunk.dart';
import '../models/transfer_item.dart';
import '../repositories/transfer_repository.dart';
import '../services/nearby_service.dart';
import '../services/transfer_service.dart';
import '../services/background_transfer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/transfer_panels.dart';

class TransferScreen extends StatefulWidget {
  final bool isReceiver;
  final Uint8List sessionKey;
  final String peerName;
  final String? peerDeviceId;
  final List<PlatformFile>? selectedFiles;
  final List<int>? initialPayload;

  const TransferScreen({
    super.key,
    required this.isReceiver,
    required this.sessionKey,
    required this.peerName,
    this.peerDeviceId,
    this.selectedFiles,
    this.initialPayload,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // Transfer state
  TransferProgress? _progress;
  bool _isPaused = false;
  bool _isConnectionLost = false;
  String? _completedFilePath;
  String _currentFileName = '';

  // File queue (sender)
  int _currentFileIndex = 0;
  final List<PlatformFile> _queue = [];

  // Payload routing
  final _receiverPayloadController = StreamController<Uint8List>();
  StreamIterator<Uint8List>? _receiverIterator;
  Future<void> _persistence = Future<void>.value();

  // Streams
  StreamSubscription? _progressSub;
  StreamSubscription? _disconnectionSub;
  StreamSubscription? _payloadSub;

  @override
  void initState() {
    super.initState();
    _startSession();

    _disconnectionSub = NearbyService.instance.disconnectionStream.listen((_) {
      TransferService.instance.cancel();
      BackgroundTransferService.stop();
      if (!_receiverPayloadController.isClosed) {
        _receiverPayloadController.close();
      }
      if (mounted) {
        setState(() => _isConnectionLost = true);
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _disconnectionSub?.cancel();
    _payloadSub?.cancel();
    _receiverIterator?.cancel();
    _receiverPayloadController.close();
    TransferService.instance.cancel();
    NearbyService.instance.stopAll();
    BackgroundTransferService.stop();
    super.dispose();
  }

  // ── SENDER ─────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    try {
      await BackgroundTransferService.start();
      if (!mounted) {
        await BackgroundTransferService.stop();
        return;
      }
      if (widget.isReceiver) {
        await _startReceiving();
      } else {
        _queue.addAll(widget.selectedFiles ?? []);
        await _startSending();
      }
    } catch (e) {
      _log('Transfer session failed: $e');
      if (mounted) setState(() => _isConnectionLost = true);
    } finally {
      await BackgroundTransferService.stop();
    }
  }

  Future<void> _persistProgress(TransferProgress progress) async {
    await TransferRepository.instance.updateProgress(
      transferId: progress.transferId,
      bytesTransferred: progress.bytesTransferred,
      lastConfirmedChunk: progress.currentChunk,
      status: _mapStatus(progress.status),
      destinationPath: progress.destinationPath,
    );
  }

  void _showProgress(TransferProgress progress) {
    _persistence = _persistence.then((_) => _persistProgress(progress));
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _isPaused = progress.status == TransferProgressStatus.paused;
      if (progress.status == TransferProgressStatus.completed) {
        _completedFilePath = progress.destinationPath;
      }
      if (progress.status == TransferProgressStatus.failed ||
          progress.status == TransferProgressStatus.cancelled) {
        _isConnectionLost = true;
      }
    });
  }

  Future<void> _startSending() async {
    _progressSub = TransferService.instance.progressStream.listen(
      _showProgress,
    );
    while (mounted && _currentFileIndex < _queue.length) {
      final file = _queue[_currentFileIndex];
      TransferItem? transfer;
      try {
        if (file.path == null) {
          throw StateError('Selected file has no local path');
        }
        transfer = await TransferRepository.instance.findOrCreateOutgoing(
          fileName: file.name,
          fileSize: file.size,
          sourcePath: file.path!,
          peerDeviceId: widget.peerDeviceId,
          peerDeviceName: widget.peerName,
          totalChunks: TransferChunk.calculateTotalChunks(file.size),
        );
        if (!mounted) return;
        setState(() {
          _currentFileName = file.name;
          _progress = null;
          _isPaused = false;
        });
        await TransferService.instance.sendFile(
          transferItem: transfer,
          sessionKey: widget.sessionKey,
        );
        await _persistence;
        if (!mounted || _progress?.status != TransferProgressStatus.completed) {
          return;
        }
        _currentFileIndex++;
      } catch (e) {
        if (transfer != null) {
          await _persistence;
          await TransferRepository.instance.updateStatus(
            transfer.transferId,
            TransferStatus.failed,
          );
        }
        _log('Send failed: $e');
        if (mounted) setState(() => _isConnectionLost = true);
        return;
      }
    }
  }

  Future<void> _startReceiving() async {
    _receiverIterator = StreamIterator(_receiverPayloadController.stream);
    _payloadSub = NearbyService.instance.payloadStream.listen(
      (payload) {
        if (!_receiverPayloadController.isClosed) {
          _receiverPayloadController.add(payload);
        }
      },
      onError: (Object error) {
        if (!_receiverPayloadController.isClosed) {
          _receiverPayloadController.addError(error);
        }
      },
    );
    if (widget.initialPayload != null) {
      _receiverPayloadController.add(
        Uint8List.fromList(widget.initialPayload!),
      );
    }
    try {
      // Keep one subscription across file boundaries so no packets are dropped.
      while (mounted && await _receiverIterator!.moveNext()) {
        final bytes = _receiverIterator!.current;
        if (bytes.isEmpty || bytes[0] != MessageType.transferInit.index) {
          continue;
        }
        final message = ProtocolMessage.fromAuthenticatedBytes(
          bytes,
          widget.sessionKey,
        );
        final init = TransferInitPayload.fromJson(message.payload);
        await TransferRepository.instance.upsertIncoming(
          init: init,
          peerDeviceId: widget.peerDeviceId,
          peerDeviceName: widget.peerName,
        );
        if (!mounted) return;
        setState(() {
          _currentFileName = init.fileName;
          _progress = null;
          _completedFilePath = null;
          _isPaused = false;
        });
        final result = await TransferService.instance.receiveFile(
          initPayload: init,
          payloadStream: const Stream<Uint8List>.empty(),
          payloadIterator: _receiverIterator,
          sessionKey: widget.sessionKey,
          onProgress: _showProgress,
        );
        await _persistence;
        if (result == null) return;
      }
    } catch (e) {
      _log('Receive failed: $e');
      if (mounted) setState(() => _isConnectionLost = true);
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[TransferScreen] $message');
  }

  // ── Controls ───────────────────────────────────────────────────────────

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      TransferService.instance.pause();
    } else {
      TransferService.instance.resume();
    }
  }

  void _cancel() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Transfer?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'The partial file will be kept for resuming later.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Going',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              TransferService.instance.cancel();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() => _isConnectionLost = false);
    // Attempt reconnect - navigate back to home
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  TransferStatus _mapStatus(TransferProgressStatus s) {
    switch (s) {
      case TransferProgressStatus.connecting:
        return TransferStatus.connecting;
      case TransferProgressStatus.transferring:
        return TransferStatus.transferring;
      case TransferProgressStatus.paused:
        return TransferStatus.paused;
      case TransferProgressStatus.verifying:
        return TransferStatus.verifying;
      case TransferProgressStatus.completed:
        return TransferStatus.completed;
      case TransferProgressStatus.failed:
        return TransferStatus.failed;
      case TransferProgressStatus.cancelled:
        return TransferStatus.cancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnectionLost) return _buildConnectionLost();
    if (_completedFilePath != null ||
        _progress?.status == TransferProgressStatus.completed) {
      return _buildCompleted();
    }
    return _buildTransferring();
  }

  Widget _buildTransferring() {
    final progress = _progress;
    return Scaffold(
      backgroundColor: AppTheme.color(context, AppTheme.background),
      appBar: AppBar(
        title: Text(widget.isReceiver ? 'Receiving file' : 'Sending file'),
        leading: IconButton(
          tooltip: 'Cancel transfer',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _cancel,
        ),
      ),
      body: SafeArea(
        child: TransferPanel(
          fileName: _currentFileName,
          bytesLabel: progress == null
              ? 'Preparing...'
              : '${formatBytes(progress.bytesTransferred)} / ${formatBytes(progress.totalBytes)}',
          speed: progress?.speedLabel ?? '--',
          eta: progress?.etaLabel ?? '--',
          peer: '${widget.isReceiver ? 'From' : 'To'} ${widget.peerName}',
          status: progress?.status == TransferProgressStatus.verifying
              ? 'Verifying file'
              : 'Transferring',
          fraction: progress?.progressFraction ?? 0,
          paused: _isPaused,
          queueLabel: !widget.isReceiver && _queue.length > 1
              ? 'File ${_currentFileIndex + 1} of ${_queue.length}'
              : null,
          onPause: _togglePause,
          onCancel: _cancel,
        ),
      ),
    );
  }

  Widget _buildConnectionLost() => Scaffold(
    backgroundColor: AppTheme.color(context, AppTheme.background),
    body: SafeArea(
      child: TransferResultPanel(
        completed: false,
        fileName: _currentFileName,
        fraction: _progress?.progressFraction,
        savedLabel: _progress == null
            ? null
            : '${formatBytes(_progress!.bytesTransferred)} transferred',
        onRetry: _retry,
        onHome: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    ),
  );

  Widget _buildCompleted() => Scaffold(
    backgroundColor: AppTheme.color(context, AppTheme.background),
    body: SafeArea(
      child: TransferResultPanel(
        completed: true,
        fileName: _currentFileName,
        onOpen: _completedFilePath == null
            ? null
            : () => OpenFile.open(_completedFilePath!),
        onHome: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
    ),
  );
}
