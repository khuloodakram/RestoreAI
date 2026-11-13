package com.restoreai.restoreai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native entry point for offline image inference.
 *
 * This implementation is intentionally a safe stub: no model weights or
 * inference runtime are bundled yet, so processing must not be reported
 * as successful. Replace with verified JNI/ncnn integration only after
 * shipping licensed models and validating real image output.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "restoreai/offline_inference"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(false)
                "process" -> result.error(
                    "ENGINE_NOT_INSTALLED",
                    "The offline AI model and native inference runtime are not installed.",
                    null
                )
                else -> result.notImplemented()
            }
        }
    }
}
