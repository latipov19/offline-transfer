import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../core/constants/app_constants.dart';

/// Handles all AES-256-GCM encryption and decryption.
/// Keys are ephemeral per-session, never hardcoded, never logged.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  final Random _secureRandom = Random.secure();

  // ── Key generation ───────────────────────────────────────────────────

  /// Generate a cryptographically secure 256-bit (32-byte) AES key.
  Uint8List generateKey() {
    final key = Uint8List(AppConstants.keyLength);
    for (int i = 0; i < key.length; i++) {
      key[i] = _secureRandom.nextInt(256);
    }
    return key;
  }

  /// Generate a cryptographically secure 96-bit (12-byte) IV for GCM.
  Uint8List generateIV() {
    final iv = Uint8List(AppConstants.ivLength);
    for (int i = 0; i < iv.length; i++) {
      iv[i] = _secureRandom.nextInt(256);
    }
    return iv;
  }

  // ── Encryption ───────────────────────────────────────────────────────

  /// Encrypt [plaintext] with AES-256-GCM.
  /// Returns: [IV (12 bytes)] + [ciphertext + GCM tag]
  EncryptedChunk encrypt(Uint8List plaintext, Uint8List keyBytes) {
    final iv = generateIV();
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: enc.IV(iv));
    return EncryptedChunk(iv: iv, ciphertext: encrypted.bytes);
  }

  /// Decrypt an [EncryptedChunk] with AES-256-GCM.
  /// Throws [EncryptionException] on authentication failure.
  Uint8List decrypt(EncryptedChunk chunk, Uint8List keyBytes) {
    try {
      final key = enc.Key(keyBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encrypted = enc.Encrypted(chunk.ciphertext);
      final decrypted = encrypter.decryptBytes(encrypted, iv: enc.IV(chunk.iv));
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw EncryptionException(
        'GCM authentication failed: integrity check failed',
      );
    }
  }

  // ── Serialization ────────────────────────────────────────────────────

  /// Serialize [EncryptedChunk] to bytes: [IV 12B][ciphertext]
  Uint8List serializeChunk(EncryptedChunk chunk) {
    final result = Uint8List(AppConstants.ivLength + chunk.ciphertext.length);
    result.setRange(0, AppConstants.ivLength, chunk.iv);
    result.setRange(AppConstants.ivLength, result.length, chunk.ciphertext);
    return result;
  }

  /// Deserialize bytes back to [EncryptedChunk].
  EncryptedChunk deserializeChunk(Uint8List data) {
    if (data.length <= AppConstants.ivLength) {
      throw EncryptionException('Invalid encrypted chunk: too short');
    }
    final iv = data.sublist(0, AppConstants.ivLength);
    final ciphertext = data.sublist(AppConstants.ivLength);
    return EncryptedChunk(iv: iv, ciphertext: ciphertext);
  }

  // ── Hash / Integrity ─────────────────────────────────────────────────

  /// Compute SHA-256 hash of [data]. Returns hex string.
  String computeHash(Uint8List data) {
    return sha256.convert(data).toString();
  }

  /// Verify that [data] matches the expected [expectedHash].
  bool verifyHash(Uint8List data, String expectedHash) {
    return computeHash(data) == expectedHash;
  }

  // ── Key encoding ─────────────────────────────────────────────────────

  /// Encode key to base64 for QR transmission.
  String encodeKey(Uint8List keyBytes) => base64Url.encode(keyBytes);

  /// Decode key from base64.
  Uint8List decodeKey(String encoded) => base64Url.decode(encoded);
}

// ── Supporting types ──────────────────────────────────────────────────────────

class EncryptedChunk {
  final Uint8List iv;
  final Uint8List ciphertext;

  const EncryptedChunk({required this.iv, required this.ciphertext});
}

class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
