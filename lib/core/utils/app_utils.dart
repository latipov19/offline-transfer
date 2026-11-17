/// Utility helpers for Offline Transfer.
library;

import 'dart:math';

/// Returns human-readable file size string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Sanitize a filename from remote source to prevent path traversal.
String sanitizeFileName(String name) {
  String safe = name
      .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
      .replaceAll('..', '_')
      .trim();
  if (safe.isEmpty) safe = 'received_file';
  if (safe.length > 200) safe = safe.substring(0, 200);
  return safe;
}

/// Returns a formatted ETA string from remaining bytes and speed (bytes/sec).
String formatEta(int remainingBytes, double speedBps) {
  if (speedBps <= 0) return '--:--';
  final seconds = remainingBytes / speedBps;
  if (seconds.isInfinite || seconds.isNaN) return '--:--';
  if (seconds > 3600) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    return '${h}h ${m}m';
  }
  if (seconds > 60) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    return '${m}m ${s}s';
  }
  return '${seconds.floor()}s';
}

/// Random integer between min (inclusive) and max (exclusive).
int randomInt(int min, int max) => min + Random().nextInt(max - min);
