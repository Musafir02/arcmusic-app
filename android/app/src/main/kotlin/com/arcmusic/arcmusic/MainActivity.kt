package com.arcmusic.arcmusic

import android.os.Build
import android.os.Build.VERSION
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.arcmusic.arcmusic/abi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSupportedAbis") {
                val abis = if (VERSION.SDK_INT >= 21) {
                    Build.SUPPORTED_ABIS.toList()
                } else {
                    listOf(Build.CPU_ABI)
                }
                val primary = abis.firstOrNull() ?: "arm64-v8a"
                result.success(primary)
            } else {
                result.notImplemented()
            }
        }
    }
}
