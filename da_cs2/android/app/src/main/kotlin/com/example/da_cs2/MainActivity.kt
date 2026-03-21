package com.example.da_cs2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
  private val channelName = "bank_notifications"
  private var eventSink: EventChannel.EventSink? = null

  private val receiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      if (intent == null) return
      if (intent.action != BankNotificationListener.ACTION_BANK_NOTIFICATION) return

      val payload: MutableMap<String, Any?> = HashMap()
      payload["package"] = intent.getStringExtra("package") ?: ""
      payload["title"] = intent.getStringExtra("title") ?: ""
      payload["text"] = intent.getStringExtra("text") ?: ""
      payload["bigText"] = intent.getStringExtra("bigText") ?: ""
      payload["postTime"] = intent.getLongExtra("postTime", 0L)

      eventSink?.success(payload)
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    EventChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          eventSink = events
        }

        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      }
    )
  }

  override fun onStart() {
    super.onStart()
    val filter = IntentFilter(BankNotificationListener.ACTION_BANK_NOTIFICATION)
    if (Build.VERSION.SDK_INT >= 33) {
      registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      @Suppress("UnspecifiedRegisterReceiverFlag")
      registerReceiver(receiver, filter)
    }
  }

  override fun onStop() {
    try {
      unregisterReceiver(receiver)
    } catch (_: Throwable) {
      // ignore
    }
    super.onStop()
  }
}
