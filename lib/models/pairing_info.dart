import 'dart:convert';
import 'dart:typed_data';

import '../core/constants/app_constants.dart';
import '../services/encryption_service.dart';

/// Pairing information exchanged via QR code.
/// Contains session metadata + ephemeral session key.
class PairingInfo {
  /// Unique session ID (UUID v4)
  final String sessionId;

  /// Sender's device ID
  final String deviceId;

  /// Human-readable sender name
  final String deviceName;

  /// Protocol version for forward compatibility
  final int protocolVersion;

  /// AES-256 session key (base64 encoded for QR)
  /// This is an ephemeral key generated per-session.
  final String sessionKey;

  /// Timestamp (to detect stale QR codes)
  final int timestamp;

  const PairingInfo({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.protocolVersion,
    required this.sessionKey,
    required this.timestamp,
  });

  /// Generate a new pairing info with a fresh session key.
  factory PairingInfo.generate({
    required String sessionId,
    required String deviceId,
    required String deviceName,
  }) {
    final keyBytes = EncryptionService.instance.generateKey();
    return PairingInfo(
      sessionId: sessionId,
      deviceId: deviceId,
      deviceName: deviceName,
      protocolVersion: AppConstants.protocolVersion,
      sessionKey: base64Url.encode(keyBytes),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get the raw key bytes from the base64 encoded session key.
  Uint8List get keyBytes => base64Url.decode(sessionKey);

  /// Check if this QR code is still valid (within 5 minutes).
  bool get isValid {
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - timestamp;
    return age >= -30000 &&
        age < 5 * 60 * 1000 &&
        protocolVersion == AppConstants.protocolVersion &&
        keyBytes.length == 32;
  }

  // ── Serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    's': sessionId,
    'd': deviceId,
    'n': deviceName,
    'p': protocolVersion,
    'k': sessionKey,
    't': timestamp,
  };

  factory PairingInfo.fromJson(Map<String, dynamic> json) => PairingInfo(
    sessionId: json['s'] as String,
    deviceId: json['d'] as String,
    deviceName: json['n'] as String,
    protocolVersion: json['p'] as int,
    sessionKey: json['k'] as String,
    timestamp: json['t'] as int,
  );

  /// Encode to compact QR string: "OT:{base64json}"
  String toQrString() {
    final json = jsonEncode(toJson());
    return '${AppConstants.qrPrefix}${base64Url.encode(utf8.encode(json))}';
  }

  /// Parse from QR string.
  factory PairingInfo.fromQrString(String qrString) {
    if (!qrString.startsWith(AppConstants.qrPrefix)) {
      throw FormatException('Not a valid Offline Transfer QR code');
    }
    final encoded = qrString.substring(AppConstants.qrPrefix.length);
    final json = utf8.decode(base64Url.decode(encoded));
    return PairingInfo.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
