import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundTransferService {
  static const _channel = MethodChannel('offline_transfer/background');

  static Future<void> start() async {
    if (!kIsWeb && Platform.isAndroid) {
      await _channel.invokeMethod<void>('start');
    }
  }

  static Future<void> stop() async {
    if (!kIsWeb && Platform.isAndroid) {
      await _channel.invokeMethod<void>('stop');
    }
  }
}
