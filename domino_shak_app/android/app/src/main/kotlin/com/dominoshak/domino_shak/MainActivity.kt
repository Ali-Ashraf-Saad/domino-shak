package com.dominoshak.domino_shak

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.dominoshak.domino_shak/native"
    private val deepLinkChannelName = "com.dominoshak.domino_shak/deeplink"
    private val deepLinkEventsName = "com.dominoshak.domino_shak/deeplink_events"

    private var pendingLink: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Capture before super.onCreate: Flutter configures the engine (and the
        // Dart side calls getInitialLink) inside that call.
        rememberLink(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        rememberLink(intent)
    }

    private fun rememberLink(intent: Intent) {
        val link = intent.data?.toString()?.takeIf { it.isNotBlank() } ?: return
        val sink = eventSink
        if (sink == null) {
            pendingLink = link
        } else {
            sink.success(link)
        }
    }

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingLink)
                    pendingLink = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkEventsName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // Do not flush pendingLink here: it belongs to getInitialLink().
                // Emitting before Dart subscribes to the stream would lose it.
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
}
