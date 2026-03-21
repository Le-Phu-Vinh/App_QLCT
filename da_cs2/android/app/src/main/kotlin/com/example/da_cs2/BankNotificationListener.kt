package com.example.da_cs2

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class BankNotificationListener : NotificationListenerService() {
  override fun onNotificationPosted(sbn: StatusBarNotification) {
    try {
      val n = sbn.notification ?: return
      val extras = n.extras ?: return

      val title = extras.getCharSequence("android.title")?.toString() ?: ""
      val text = extras.getCharSequence("android.text")?.toString() ?: ""
      val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

      val intent = Intent(ACTION_BANK_NOTIFICATION)
      intent.setPackage(packageName)
      intent.putExtra("package", sbn.packageName ?: "")
      intent.putExtra("title", title)
      intent.putExtra("text", text)
      intent.putExtra("bigText", bigText)
      intent.putExtra("postTime", sbn.postTime)
      sendBroadcast(intent)
    } catch (_: Throwable) {
      // ignore
    }
  }

  companion object {
    const val ACTION_BANK_NOTIFICATION = "com.example.da_cs2.BANK_NOTIFICATION"
  }
}

