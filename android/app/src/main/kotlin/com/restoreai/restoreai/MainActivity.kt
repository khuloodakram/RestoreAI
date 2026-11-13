package com.restoreai.restoreai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import java.io.File
import java.io.FileOutputStream
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
                "enhanceBasic" -> {
                    val input = call.argument<String>("inputPath")
                    val output = call.argument<String>("outputPath")
                    if (input.isNullOrBlank() || output.isNullOrBlank() || input == output) {
                        result.error("BAD_PATH", "Distinct input and output paths required", null)
                    } else {
                        Thread {
                            try {
                                val saved = enhanceBasic(input, output)
                                runOnUiThread { result.success(saved) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("BASIC_FAILED", e.message, null) }
                            }
                        }.start()
                    }
                }
                "process" -> result.error(
                    "ENGINE_NOT_INSTALLED",
                    "The offline AI model and native inference runtime are not installed.",
                    null
                )
                else -> result.notImplemented()
            }
        }
    }
    /**
     * Local non-AI brightness/contrast adjustment for a functional offline
     * preview. Not super-resolution, scratch removal or neural restoration.
     */
    private fun enhanceBasic(inputPath: String, outputPath: String): String {
        val source = File(inputPath).canonicalFile
        val target = File(outputPath).canonicalFile
        require(source.isFile && source != target) { "Invalid image paths" }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Unsupported image" }
        val maxPixels = 12_000_000L
        var sample = 1
        while ((bounds.outWidth.toLong() / sample) *
            (bounds.outHeight.toLong() / sample) > maxPixels) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val decoded = BitmapFactory.decodeFile(source.path, options)
            ?: throw IllegalArgumentException("Could not decode image")
        try {
            val width = decoded.width
            val height = decoded.height
            val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                val row = IntArray(width)
                for (y in 0 until height) {
                    decoded.getPixels(row, 0, width, 0, y, width, 1)
                    for (x in row.indices) {
                        val pixel = row[x]
                        fun adjust(value: Int): Int =
                            ((value - 128) * 1.07 + 133).toInt().coerceIn(0, 255)
                        row[x] = Color.argb(
                            Color.alpha(pixel),
                            adjust(Color.red(pixel)),
                            adjust(Color.green(pixel)),
                            adjust(Color.blue(pixel))
                        )
                    }
                    output.setPixels(row, 0, width, 0, y, width, 1)
                }
                target.parentFile?.mkdirs()
                FileOutputStream(target).use { stream ->
                    check(output.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                        "Could not encode PNG"
                    }
                }
                return target.path
            } finally {
                output.recycle()
            }
        } finally {
            decoded.recycle()
        }
    }
}
