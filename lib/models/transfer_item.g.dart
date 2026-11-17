// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransferItemAdapter extends TypeAdapter<TransferItem> {
  @override
  final int typeId = 1;

  @override
  TransferItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransferItem(
      transferId: fields[0] as String,
      fileName: fields[1] as String,
      fileSize: fields[2] as int,
      sourceHash: fields[3] as String?,
      sourcePath: fields[4] as String?,
      destinationPath: fields[5] as String?,
      bytesTransferred: fields[6] as int,
      lastConfirmedChunk: fields[7] as int,
      totalChunks: fields[8] as int,
      status: fields[9] as TransferStatus,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      peerDeviceId: fields[12] as String?,
      peerDeviceName: fields[13] as String?,
      isSender: fields[14] as bool,
      mimeType: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TransferItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.transferId)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.fileSize)
      ..writeByte(3)
      ..write(obj.sourceHash)
      ..writeByte(4)
      ..write(obj.sourcePath)
      ..writeByte(5)
      ..write(obj.destinationPath)
      ..writeByte(6)
      ..write(obj.bytesTransferred)
      ..writeByte(7)
      ..write(obj.lastConfirmedChunk)
      ..writeByte(8)
      ..write(obj.totalChunks)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.peerDeviceId)
      ..writeByte(13)
      ..write(obj.peerDeviceName)
      ..writeByte(14)
      ..write(obj.isSender)
      ..writeByte(15)
      ..write(obj.mimeType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransferStatusAdapter extends TypeAdapter<TransferStatus> {
  @override
  final int typeId = 0;

  @override
  TransferStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransferStatus.pending;
      case 1:
        return TransferStatus.connecting;
      case 2:
        return TransferStatus.transferring;
      case 3:
        return TransferStatus.paused;
      case 4:
        return TransferStatus.completed;
      case 5:
        return TransferStatus.failed;
      case 6:
        return TransferStatus.cancelled;
      case 7:
        return TransferStatus.verifying;
      default:
        return TransferStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, TransferStatus obj) {
    switch (obj) {
      case TransferStatus.pending:
        writer.writeByte(0);
        break;
      case TransferStatus.connecting:
        writer.writeByte(1);
        break;
      case TransferStatus.transferring:
        writer.writeByte(2);
        break;
      case TransferStatus.paused:
        writer.writeByte(3);
        break;
      case TransferStatus.completed:
        writer.writeByte(4);
        break;
      case TransferStatus.failed:
        writer.writeByte(5);
        break;
      case TransferStatus.cancelled:
        writer.writeByte(6);
        break;
      case TransferStatus.verifying:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
