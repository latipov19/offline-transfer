import 'package:hive/hive.dart';

part 'transfer_item.g.dart';

@HiveType(typeId: 0)
enum TransferStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  connecting,

  @HiveField(2)
  transferring,

  @HiveField(3)
  paused,

  @HiveField(4)
  completed,

  @HiveField(5)
  failed,

  @HiveField(6)
  cancelled,

  @HiveField(7)
  verifying,
}

extension TransferStatusX on TransferStatus {
  String get statusLabel {
    switch (this) {
      case TransferStatus.pending:
        return 'Waiting';
      case TransferStatus.connecting:
        return 'Connecting';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.verifying:
        return 'Verifying';
    }
  }
}

@HiveType(typeId: 1)
class TransferItem extends HiveObject {
  @HiveField(0)
  late String transferId;

  @HiveField(1)
  late String fileName;

  @HiveField(2)
  late int fileSize;

  @HiveField(3)
  late String? sourceHash;

  @HiveField(4)
  late String? sourcePath;

  @HiveField(5)
  late String? destinationPath;

  @HiveField(6)
  late int bytesTransferred;

  @HiveField(7)
  late int lastConfirmedChunk;

  @HiveField(8)
  late int totalChunks;

  @HiveField(9)
  late TransferStatus status;

  @HiveField(10)
  late DateTime createdAt;

  @HiveField(11)
  late DateTime updatedAt;

  @HiveField(12)
  late String? peerDeviceId;

  @HiveField(13)
  late String? peerDeviceName;

  @HiveField(14)
  late bool isSender;

  @HiveField(15)
  late String? mimeType;

  TransferItem({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    this.sourceHash,
    this.sourcePath,
    this.destinationPath,
    this.bytesTransferred = 0,
    this.lastConfirmedChunk = -1,
    required this.totalChunks,
    this.status = TransferStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.peerDeviceId,
    this.peerDeviceName,
    required this.isSender,
    this.mimeType,
  });

  double get progress => fileSize > 0 ? bytesTransferred / fileSize : 0.0;

  bool get isResumable =>
      status != TransferStatus.completed && bytesTransferred > 0;

  bool get isComplete => status == TransferStatus.completed;

  String get statusLabel => status.statusLabel;

  TransferItem copyWith({
    String? transferId,
    String? fileName,
    int? fileSize,
    String? sourceHash,
    String? sourcePath,
    String? destinationPath,
    int? bytesTransferred,
    int? lastConfirmedChunk,
    int? totalChunks,
    TransferStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? peerDeviceId,
    String? peerDeviceName,
    bool? isSender,
    String? mimeType,
  }) {
    return TransferItem(
      transferId: transferId ?? this.transferId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      sourceHash: sourceHash ?? this.sourceHash,
      sourcePath: sourcePath ?? this.sourcePath,
      destinationPath: destinationPath ?? this.destinationPath,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      lastConfirmedChunk: lastConfirmedChunk ?? this.lastConfirmedChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      peerDeviceName: peerDeviceName ?? this.peerDeviceName,
      isSender: isSender ?? this.isSender,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}
