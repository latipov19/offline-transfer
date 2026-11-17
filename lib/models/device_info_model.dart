import 'package:hive/hive.dart';

part 'device_info_model.g.dart';

@HiveType(typeId: 2)
class DeviceInfoModel extends HiveObject {
  @HiveField(0)
  late String deviceId;

  @HiveField(1)
  late String deviceName;

  @HiveField(2)
  late String? model;

  @HiveField(3)
  late String? androidVersion;

  DeviceInfoModel({
    required this.deviceId,
    required this.deviceName,
    this.model,
    this.androidVersion,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'model': model,
        'androidVersion': androidVersion,
      };

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) =>
      DeviceInfoModel(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        model: json['model'] as String?,
        androidVersion: json['androidVersion'] as String?,
      );
}
