import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';

/// Manages local device identity and settings.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late Box<String> _settingsBox;
  final _uuid = const Uuid();
  final _deviceInfo = DeviceInfoPlugin();

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  Future<void> init() async {
    _settingsBox = Hive.box<String>(AppConstants.settingsBox);
  }

  // ── Device identity ────────────────────────────────────────────────────

  /// Get or create a stable local device ID.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? stored = _settingsBox.get('device_id');
    if (stored == null) {
      stored = _uuid.v4();
      await _settingsBox.put('device_id', stored);
    }
    _cachedDeviceId = stored;
    return stored;
  }

  /// Get the display name for this device.
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;

    // Check saved name first
    final saved = _settingsBox.get(AppConstants.keyDeviceName);
    if (saved != null && saved.isNotEmpty) {
      _cachedDeviceName = saved;
      return saved;
    }

    // Auto-detect
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final name = '${info.brand} ${info.model}'.trim();
        _cachedDeviceName = name.isNotEmpty ? name : 'Android Device';
      } else if (kIsWeb) {
        _cachedDeviceName = 'Web Browser';
      } else {
        _cachedDeviceName = 'Unknown Device';
      }
    } catch (e) {
      developer.log('DeviceInfo error: $e', name: 'StorageService');
      _cachedDeviceName = kIsWeb ? 'Web Browser' : 'Android Device';
    }

    return _cachedDeviceName!;
  }

  Future<void> setDeviceName(String name) async {
    _cachedDeviceName = name;
    await _settingsBox.put(AppConstants.keyDeviceName, name);
  }

  // ── Settings ───────────────────────────────────────────────────────────

  String? getSetting(String key) => _settingsBox.get(key);

  Future<void> putSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }
}
