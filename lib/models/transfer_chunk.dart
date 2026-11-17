import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/constants/app_constants.dart';

/// Represents a single file chunk being transferred.
class TransferChunk {
  final String transferId;
  final int chunkIndex;
  final int totalChunks;
  final int offset;
  final int length;
  final int fileSize;
  final String fileName;

  const TransferChunk({
    required this.transferId,
    required this.chunkIndex,
    required this.totalChunks,
    required this.offset,
    required this.length,
    required this.fileSize,
    required this.fileName,
  });

  Map<String, dynamic> toJson() => {
    'tid': transferId,
    'ci': chunkIndex,
    'tc': totalChunks,
    'off': offset,
    'len': length,
    'fs': fileSize,
    'fn': fileName,
  };

  factory TransferChunk.fromJson(Map<String, dynamic> json) => TransferChunk(
    transferId: json['tid'] as String,
    chunkIndex: json['ci'] as int,
    totalChunks: json['tc'] as int,
    offset: json['off'] as int,
    length: json['len'] as int,
    fileSize: json['fs'] as int,
    fileName: json['fn'] as String,
  );

  /// Calculate total chunks for a file of given [fileSize].
  static int calculateTotalChunks(int fileSize) {
    if (fileSize == 0) return 1;
    return ((fileSize - 1) ~/ AppConstants.chunkSize) + 1;
  }
}

/// Protocol message types for the internal transfer protocol.
enum MessageType {
  hello, // Initial handshake
  transferInit, // Start new transfer
  transferResume, // Resume existing transfer
  chunk, // File data chunk
  chunkAck, // Acknowledge chunk(s)
  pause, // Pause transfer
  resume, // Resume transfer
  complete, // Transfer finished
  error, // Error occurred
  cancel, // Cancel transfer
  hashVerify, // File hash verification
}

/// Wrapper for all protocol messages.
class ProtocolMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  const ProtocolMessage({required this.type, required this.payload});

  /// Serialize to bytes for Nearby transmission.
  /// Format: [1 byte type][JSON payload]
  Uint8List toBytes() {
    final typeIndex = MessageType.values.indexOf(type);
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final result = Uint8List(1 + jsonBytes.length);
    result[0] = typeIndex;
    result.setRange(1, result.length, jsonBytes);
    return result;
  }

  Uint8List authenticatedBytes(Uint8List key) {
    final body = toBytes();
    final tag = Hmac(sha256, key).convert(body).bytes;
    return Uint8List.fromList([...body, ...tag]);
  }

  factory ProtocolMessage.fromAuthenticatedBytes(
    Uint8List bytes,
    Uint8List key,
  ) {
    if (bytes.length < 34) {
      throw const FormatException('Missing authentication');
    }
    final body = bytes.sublist(0, bytes.length - 32);
    final tag = Hmac(sha256, key).convert(body).bytes;
    var difference = 0;
    for (var i = 0; i < 32; i++) {
      difference |= tag[i] ^ bytes[body.length + i];
    }
    if (difference != 0) throw const FormatException('Invalid authentication');
    return ProtocolMessage.fromBytes(body);
  }

  /// Deserialize from bytes.
  factory ProtocolMessage.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw FormatException('Empty protocol message');
    final typeIndex = bytes[0];
    if (typeIndex >= MessageType.values.length) {
      throw FormatException('Unknown message type: $typeIndex');
    }
    final type = MessageType.values[typeIndex];
    final jsonStr = utf8.decode(bytes.sublist(1));
    final payload = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ProtocolMessage(type: type, payload: payload);
  }
}

/// ChunkAck message payload.
class ChunkAckPayload {
  final String transferId;
  final int lastAckedChunk;
  final int bytesReceived;

  const ChunkAckPayload({
    required this.transferId,
    required this.lastAckedChunk,
    required this.bytesReceived,
  });

  Map<String, dynamic> toJson() => {
    'tid': transferId,
    'lac': lastAckedChunk,
    'br': bytesReceived,
  };

  factory ChunkAckPayload.fromJson(Map<String, dynamic> json) =>
      ChunkAckPayload(
        transferId: json['tid'] as String,
        lastAckedChunk: json['lac'] as int,
        bytesReceived: json['br'] as int,
      );
}

/// TransferInit payload — sent before chunks start.
class TransferInitPayload {
  final String transferId;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final String fileHash;
  final int startFromChunk;
  final String? mimeType;

  const TransferInitPayload({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.fileHash,
    this.startFromChunk = 0,
    this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'tid': transferId,
    'fn': fileName,
    'fs': fileSize,
    'tc': totalChunks,
    'fh': fileHash,
    'sfc': startFromChunk,
    'mt': mimeType,
  };

  factory TransferInitPayload.fromJson(Map<String, dynamic> json) =>
      TransferInitPayload(
        transferId: json['tid'] as String,
        fileName: json['fn'] as String,
        fileSize: json['fs'] as int,
        totalChunks: json['tc'] as int,
        fileHash: json['fh'] as String,
        startFromChunk: json['sfc'] as int? ?? 0,
        mimeType: json['mt'] as String?,
      );
}
