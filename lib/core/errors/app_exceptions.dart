/// Core error types for Offline Transfer.
library;

class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;
  const AppException(this.message, {this.code, this.cause});
  @override
  String toString() => 'AppException[$code]: $message';
}

class TransferException extends AppException {
  const TransferException(super.message, {super.code, super.cause});
  static const String codeChunkFailed = 'CHUNK_FAILED';
  static const String codeHashMismatch = 'HASH_MISMATCH';
  static const String codeTimeout = 'TIMEOUT';
  static const String codeCancelled = 'CANCELLED';
  static const String codeFileNotFound = 'FILE_NOT_FOUND';
  static const String codeCorrupted = 'CORRUPTED';
}

class ConnectionException extends AppException {
  const ConnectionException(super.message, {super.code, super.cause});
  static const String codePermissionDenied = 'PERMISSION_DENIED';
  static const String codeDisconnected = 'DISCONNECTED';
  static const String codeTimeout = 'TIMEOUT';
}

class EncryptionException extends AppException {
  const EncryptionException(super.message, {super.code, super.cause});
  static const String codeDecryptFailed = 'DECRYPT_FAILED';
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.cause});
  static const String codePermissionDenied = 'STORAGE_PERMISSION_DENIED';
  static const String codeWriteFailed = 'WRITE_FAILED';
}

class PairingException extends AppException {
  const PairingException(super.message, {super.code, super.cause});
  static const String codeExpired = 'QR_EXPIRED';
  static const String codeInvalidFormat = 'INVALID_FORMAT';
}
