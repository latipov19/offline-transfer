package com.offlinetransfer.offline_transfer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "offline_transfer/background")
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, TransferForegroundService::class.java)
                try {
                    when (call.method) {
                        "start" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(null)
                        }
                        "stop" -> { stopService(intent); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("BACKGROUND_TRANSFER", error.message, null)
                }
            }
    }
}
