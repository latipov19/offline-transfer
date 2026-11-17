class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Offline Transfer';
  static const String appVersion = '1.0.0';
  static const int protocolVersion = 2;

  // Hive boxes
  static const String transferBox = 'transfers';
  static const String settingsBox = 'settings';

  // Settings keys
  static const String keyDeviceName = 'device_name';
  static const String keyThemeMode = 'theme_mode';

  // Transfer
  // Reserve room for metadata, IV and tag within Nearby's 32 KB payload limit.
  static const int chunkSize = 28 * 1024;
  static const int maxRetryCount = 5;
  static const int connectionTimeoutMs = 30000;
  static const int ackWindowSize = 64;
  static const int maxInFlightChunks = ackWindowSize * 2;
  static const int progressIntervalMs = 250;

  // Nearby
  static const String serviceId = 'com.offlinetransfer.nearby';

  // File storage
  static const String receivedFolder = 'OfflineTransfer';

  // QR
  static const String qrPrefix = 'OT:';

  // Security
  static const int ivLength = 12; // AES-GCM IV bytes
  static const int keyLength = 32; // AES-256 key bytes
  static const int tagLength = 128; // GCM tag bits
}
