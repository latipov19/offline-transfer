import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles all runtime permission requests.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final _deviceInfoPlugin = DeviceInfoPlugin();
  int? _cachedSdkInt;

  /// Request all permissions needed for Nearby Connections.
  Future<PermissionResult> requestNearbyPermissions({
    bool needsCamera = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return PermissionResult.granted;
    }

    final androidVersion = await _getAndroidSdkInt();
    _log('[PERMISSIONS] Android SDK: $androidVersion');

    final List<Permission> required = [if (needsCamera) Permission.camera];

    if (androidVersion >= 33) {
      // Android 13+
      required.addAll([
        Permission.nearbyWifiDevices,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ]);
    } else if (androidVersion >= 31) {
      // Android 12
      required.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ]);
    } else {
      // Android 10-11
      required.addAll([Permission.bluetooth, Permission.locationWhenInUse]);
    }

    final statuses = await required.request();

    final denied = statuses.entries
        .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();

    if (denied.isEmpty) {
      _log('[PERMISSIONS] All permissions granted');
      return PermissionResult.granted;
    }

    final permanentlyDenied = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .toList();

    if (permanentlyDenied.isNotEmpty) {
      _log(
        '[PERMISSIONS] Permanently denied: ${permanentlyDenied.map((e) => e.key).join(', ')}',
      );
      return PermissionResult.permanentlyDenied;
    }

    _log('[PERMISSIONS] Denied: ${denied.join(', ')}');
    return PermissionResult.denied;
  }

  /// Request only camera permission (for QR scanning).
  Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<int> _getAndroidSdkInt() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        _cachedSdkInt = info.version.sdkInt;
        return _cachedSdkInt!;
      }
    } catch (e) {
      _log('[PERMISSIONS] Could not get SDK int: $e');
    }
    _cachedSdkInt = 21;
    return _cachedSdkInt!;
  }

  void _log(String message) {
    developer.log(message, name: 'PermissionService');
  }
}

enum PermissionResult { granted, denied, permanentlyDenied }
