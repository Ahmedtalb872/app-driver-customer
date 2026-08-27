package com.alhudhud.captain

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps the app process alive while a trip is active, with the persistent,
 * low-priority notification Android requires for any foreground service -
 * without this, the OS can (and does, per a real user report) kill the
 * process while the app is backgrounded mid-trip, silently breaking trip
 * tracking/realtime updates until the customer manually reopens the app.
 * Started/stopped from Dart via MethodChannel - see
 * lib/core/services/trip_foreground_service.dart, the only caller
 * (through MainActivity).
 */
class TripForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "trip_tracking_channel"
        private const val NOTIFICATION_ID = 4821
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "تتبع المشوار",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("جارٍ تتبع مشوارك")
            .setContentText("الهدهد يعمل في الخلفية لإبقائك على اطلاع بمشوارك.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
