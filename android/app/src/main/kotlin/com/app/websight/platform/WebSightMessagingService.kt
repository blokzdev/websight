package com.app.websight.platform

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.app.websight.MainActivity
import com.app.websight.R
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Default FCM receiver. The service is declared in the manifest but only does
 * meaningful work when the integrator's `webview_config.yaml` enables
 * `notifications.fcm_enabled` AND the app has a valid `google-services.json`.
 *
 * Behavior:
 *   - Foreground messages: posted as a system notification on the
 *     `websight_default_channel`. The Dart side ALSO receives them via
 *     `firebase_messaging`'s onMessage stream and may forward to JS via
 *     `WebSightBridge.onPush` — duplicates are deliberately avoided by checking
 *     a `silent` data flag.
 *   - Notification taps: launch [MainActivity] with a `route` extra so the
 *     Dart router can navigate to the deep-linked screen.
 */
class WebSightMessagingService : FirebaseMessagingService() {

    companion object {
        const val CHANNEL_ID = "websight_default_channel"
        const val EXTRA_ROUTE = "ws_route"
    }

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // The Dart side reads the current token directly via
        // FirebaseMessaging.instance.getToken(). No-op here.
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Allow the server to suppress system notifications by sending data-only
        // payloads tagged `silent=true`; the Dart layer will forward them to JS.
        val isSilent = message.data["silent"] == "true"
        if (isSilent) return

        val title = message.notification?.title ?: message.data["title"] ?: getString(R.string.app_name)
        val body = message.notification?.body ?: message.data["body"] ?: ""
        val route = message.data["route"]

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (!route.isNullOrEmpty()) putExtra(EXTRA_ROUTE, route)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(message.messageId?.hashCode() ?: System.currentTimeMillis().toInt(), notification)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "General",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Default WebSight push notifications"
        }
        nm.createNotificationChannel(channel)
    }
}
