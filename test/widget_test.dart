import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:offline_transfer/core/constants/app_constants.dart';
import 'package:offline_transfer/models/pairing_info.dart';
import 'package:offline_transfer/models/transfer_chunk.dart';
import 'package:offline_transfer/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    final enc = EncryptionService.instance;

    test('generateKey produces 32 bytes', () {
      final key = enc.generateKey();
      expect(key.length, equals(32));
    });

    test('generateIV produces 12 bytes', () {
      final iv = enc.generateIV();
      expect(iv.length, equals(12));
    });

    test('encrypt → decrypt roundtrip', () {
      final key = enc.generateKey();
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final chunk = enc.encrypt(plaintext, key);
      final decrypted = enc.decrypt(chunk, key);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt with wrong key throws EncryptionException', () {
      final key1 = enc.generateKey();
      final key2 = enc.generateKey();
      final plaintext = Uint8List.fromList([10, 20, 30]);
      final chunk = enc.encrypt(plaintext, key1);
      expect(() => enc.decrypt(chunk, key2), throwsA(isA<EncryptionException>()));
    });

    test('serialize and deserialize chunk', () {
      final key = enc.generateKey();
      final plaintext = Uint8List.fromList(List.generate(100, (i) => i));
      final chunk = enc.encrypt(plaintext, key);
      final serialized = enc.serializeChunk(chunk);
      final deserialized = enc.deserializeChunk(serialized);
      final decrypted = enc.decrypt(deserialized, key);
      expect(decrypted, equals(plaintext));
    });

    test('computeHash is deterministic', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final h1 = enc.computeHash(data);
      final h2 = enc.computeHash(data);
      expect(h1, equals(h2));
    });

    test('verifyHash returns true for matching hash', () {
      final data = Uint8List.fromList([255, 128, 64]);
      final hash = enc.computeHash(data);
      expect(enc.verifyHash(data, hash), isTrue);
    });

    test('verifyHash returns false for corrupted data', () {
      final data = Uint8List.fromList([255, 128, 64]);
      final hash = enc.computeHash(data);
      final corrupted = Uint8List.fromList([255, 0, 64]); // byte changed
      expect(enc.verifyHash(corrupted, hash), isFalse);
    });

    test('encodeKey and decodeKey roundtrip', () {
      final key = enc.generateKey();
      final encoded = enc.encodeKey(key);
      final decoded = enc.decodeKey(encoded);
      expect(decoded, equals(key));
    });
  });

  group('PairingInfo', () {
    test('toQrString and fromQrString roundtrip', () {
      final pairing = PairingInfo.generate(
        sessionId: 'test-session-123',
        deviceId: 'device-abc',
        deviceName: 'Test Phone',
      );
      final qr = pairing.toQrString();
      expect(qr.startsWith(AppConstants.qrPrefix), isTrue);

      final parsed = PairingInfo.fromQrString(qr);
      expect(parsed.sessionId, equals(pairing.sessionId));
      expect(parsed.deviceId, equals(pairing.deviceId));
      expect(parsed.deviceName, equals(pairing.deviceName));
      expect(parsed.protocolVersion, equals(pairing.protocolVersion));
      expect(parsed.sessionKey, equals(pairing.sessionKey));
    });

    test('fromQrString throws on invalid prefix', () {
      expect(
        () => PairingInfo.fromQrString('INVALID:data'),
        throwsA(isA<FormatException>()),
      );
    });

    test('isValid returns true for fresh QR', () {
      final p = PairingInfo.generate(
        sessionId: 'sid',
        deviceId: 'did',
        deviceName: 'name',
      );
      expect(p.isValid, isTrue);
    });

    test('keyBytes matches decoded sessionKey', () {
      final p = PairingInfo.generate(
        sessionId: 'sid',
        deviceId: 'did',
        deviceName: 'Phone',
      );
      expect(p.keyBytes, equals(base64Url.decode(p.sessionKey)));
    });

    test('keyBytes length is 32', () {
      final p = PairingInfo.generate(
        sessionId: 'sid',
        deviceId: 'did',
        deviceName: 'Phone',
      );
      expect(p.keyBytes.length, equals(32));
    });
  });

  group('TransferChunk', () {
    test('calculateTotalChunks for exact multiple', () {
      final size = AppConstants.chunkSize * 5;
      expect(TransferChunk.calculateTotalChunks(size), equals(5));
    });

    test('calculateTotalChunks rounds up', () {
      final size = AppConstants.chunkSize * 3 + 1;
      expect(TransferChunk.calculateTotalChunks(size), equals(4));
    });

    test('calculateTotalChunks for empty file', () {
      expect(TransferChunk.calculateTotalChunks(0), equals(1));
    });

    test('calculateTotalChunks for single byte', () {
      expect(TransferChunk.calculateTotalChunks(1), equals(1));
    });

    test('toJson and fromJson roundtrip', () {
      const chunk = TransferChunk(
        transferId: 'tid-1',
        chunkIndex: 5,
        totalChunks: 10,
        offset: 5 * 256 * 1024,
        length: 256 * 1024,
        fileSize: 10 * 256 * 1024,
        fileName: 'test.mp4',
      );
      final json = chunk.toJson();
      final parsed = TransferChunk.fromJson(json);
      expect(parsed.transferId, equals(chunk.transferId));
      expect(parsed.chunkIndex, equals(chunk.chunkIndex));
      expect(parsed.totalChunks, equals(chunk.totalChunks));
      expect(parsed.offset, equals(chunk.offset));
    });
  });

  group('ProtocolMessage', () {
    test('serialize and deserialize', () {
      final msg = ProtocolMessage(
        type: MessageType.transferInit,
        payload: {'key': 'value', 'num': 42},
      );
      final bytes = msg.toBytes();
      final parsed = ProtocolMessage.fromBytes(bytes);
      expect(parsed.type, equals(MessageType.transferInit));
      expect(parsed.payload['key'], equals('value'));
      expect(parsed.payload['num'], equals(42));
    });

    test('throws on empty bytes', () {
      expect(
        () => ProtocolMessage.fromBytes(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('all message types serialize correctly', () {
      for (final type in MessageType.values) {
        final msg = ProtocolMessage(type: type, payload: {'t': type.index});
        final bytes = msg.toBytes();
        final parsed = ProtocolMessage.fromBytes(bytes);
        expect(parsed.type, equals(type));
      }
    });
  });

  group('Filename sanitization (via TransferService logic)', () {
    String sanitize(String name) {
      String safe = name
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
          .replaceAll('..', '_')
          .trim();
      if (safe.isEmpty) safe = 'received_file';
      if (safe.length > 200) safe = safe.substring(0, 200);
      return safe;
    }

    test('removes path traversal', () {
      expect(sanitize('../../malicious.txt'), isNot(contains('..')));
    });

    test('removes slashes', () {
      expect(sanitize('/etc/passwd'), isNot(contains('/')));
    });

    test('removes dangerous chars', () {
      expect(sanitize('file*name?.txt'), isNot(contains('*')));
      expect(sanitize('file*name?.txt'), isNot(contains('?')));
    });

    test('empty name returns default', () {
      expect(sanitize(''), equals('received_file'));
    });

    test('normal name unchanged', () {
      expect(sanitize('video.mp4'), equals('video.mp4'));
    });

    test('long name truncated to 200', () {
      final long = 'a' * 250;
      expect(sanitize(long).length, equals(200));
    });
  });
}
