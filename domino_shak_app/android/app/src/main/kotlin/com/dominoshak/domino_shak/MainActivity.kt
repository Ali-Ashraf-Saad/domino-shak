package com.dominoshak.domino_shak

import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.dominoshak.domino_shak/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "toast" -> {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) {
                        result.error("bad_args", "Toast text is empty", null)
                    } else {
                        Toast.makeText(applicationContext, text, Toast.LENGTH_SHORT).show()
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
