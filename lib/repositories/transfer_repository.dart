import 'dart:developer' as developer;

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../models/transfer_item.dart';
import '../models/transfer_chunk.dart';

/// Repository for all transfer history and state persistence.
/// This is the source of truth for resume functionality.
class TransferRepository {
  TransferRepository._();
  static final TransferRepository instance = TransferRepository._();

  late Box<TransferItem> _box;
  final _uuid = const Uuid();

  Future<void> init() async {
    _box = Hive.box<TransferItem>(AppConstants.transferBox);
  }

  // ── CRUD ───────────────────────────────────────────────────────────────

  Future<TransferItem> findOrCreateOutgoing({
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required String sourcePath,
    String? peerDeviceId,
    String? peerDeviceName,
  }) async {
    for (final item in getAllTransfers()) {
      if (item.isSender &&
          !item.isComplete &&
          item.fileName == fileName &&
          item.fileSize == fileSize &&
          item.sourcePath == sourcePath &&
          item.peerDeviceId == peerDeviceId &&
          item.totalChunks == totalChunks) {
        return item;
      }
    }
    return createTransfer(
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: totalChunks,
      isSender: true,
      sourcePath: sourcePath,
      peerDeviceId: peerDeviceId,
      peerDeviceName: peerDeviceName,
    );
  }

  Future<TransferItem> upsertIncoming({
    required TransferInitPayload init,
    String? peerDeviceId,
    String? peerDeviceName,
  }) async {
    final existing = _box.get(init.transferId);
    if (existing != null) {
      if (existing.isSender ||
          existing.fileName != init.fileName ||
          existing.fileSize != init.fileSize ||
          existing.totalChunks != init.totalChunks) {
        throw StateError('Transfer identity mismatch');
      }
      return existing;
    }
    final item = TransferItem(
      transferId: init.transferId,
      fileName: init.fileName,
      fileSize: init.fileSize,
      totalChunks: init.totalChunks,
      isSender: false,
      peerDeviceId: peerDeviceId,
      peerDeviceName: peerDeviceName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _box.put(item.transferId, item);
    return item;
  }

  Future<TransferItem> createTransfer({
    required String fileName,
    required int fileSize,
    required int totalChunks,
    required bool isSender,
    String? sourcePath,
    String? sourceHash,
    String? peerDeviceId,
    String? peerDeviceName,
    String? mimeType,
  }) async {
    final item = TransferItem(
      transferId: _uuid.v4(),
      fileName: fileName,
      fileSize: fileSize,
      sourceHash: sourceHash,
      sourcePath: sourcePath,
      totalChunks: totalChunks,
      isSender: isSender,
      peerDeviceId: peerDeviceId,
      peerDeviceName: peerDeviceName,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _box.put(item.transferId, item);
    _log('[REPO] Created transfer: ${item.transferId} (${item.fileName})');
    return item;
  }

  Future<void> updateProgress({
    required String transferId,
    required int bytesTransferred,
    required int lastConfirmedChunk,
    TransferStatus? status,
    String? destinationPath,
  }) async {
    final item = _box.get(transferId);
    if (item == null) return;

    item.bytesTransferred = bytesTransferred;
    item.lastConfirmedChunk = lastConfirmedChunk;
    item.updatedAt = DateTime.now();
    if (status != null) item.status = status;
    if (destinationPath != null) item.destinationPath = destinationPath;

    await item.save();
  }

  Future<void> updateStatus(String transferId, TransferStatus status) async {
    final item = _box.get(transferId);
    if (item == null) return;
    item.status = status;
    item.updatedAt = DateTime.now();
    await item.save();
  }

  Future<void> updateHash(String transferId, String hash) async {
    final item = _box.get(transferId);
    if (item == null) return;
    item.sourceHash = hash;
    await item.save();
  }

  TransferItem? getTransfer(String transferId) => _box.get(transferId);

  List<TransferItem> getAllTransfers() {
    return _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<TransferItem> getResumableTransfers() {
    return _box.values.where((t) => t.isResumable).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> deleteTransfer(String transferId) async {
    await _box.delete(transferId);
  }

  Future<void> clearCompleted() async {
    final keys = _box.values
        .where(
          (t) =>
              t.status == TransferStatus.completed ||
              t.status == TransferStatus.cancelled,
        )
        .map((t) => t.transferId)
        .toList();
    await _box.deleteAll(keys);
  }

  void _log(String msg) => developer.log(msg, name: 'TransferRepository');
}
