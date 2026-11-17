// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info_model.dart';

class DeviceInfoModelAdapter extends TypeAdapter<DeviceInfoModel> {
  @override
  final int typeId = 2;

  @override
  DeviceInfoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeviceInfoModel(
      deviceId: fields[0] as String,
      deviceName: fields[1] as String,
      model: fields[2] as String?,
      androidVersion: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DeviceInfoModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.deviceId)
      ..writeByte(1)
      ..write(obj.deviceName)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.androidVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
