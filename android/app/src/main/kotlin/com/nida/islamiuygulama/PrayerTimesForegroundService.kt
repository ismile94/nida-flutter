package com.nida.islamiuygulama

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Foreground service that shows a persistent notification with live countdown to next prayer.
 * Keeps updating every second even when the app is closed.
 */
class PrayerTimesForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val dataJson = intent?.getStringExtra(EXTRA_DATA) ?: return START_NOT_STICKY
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            prefs.edit().putString(KEY_DATA, dataJson).apply()
        } catch (_: Exception) { }
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification(dataJson))
        scheduleNextUpdate(dataJson)
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Times",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Continuous prayer times countdown"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun scheduleNextUpdate(dataJson: String) {
        updateRunnable?.let { handler.removeCallbacks(it) }
        updateRunnable = object : Runnable {
            override fun run() {
                val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                val json = prefs.getString(KEY_DATA, null) ?: dataJson
                val notification = buildNotification(json)
                val nm = getSystemService(NotificationManager::class.java)
                nm.notify(NOTIFICATION_ID, notification)
                handler.postDelayed(this, UPDATE_INTERVAL_MS)
            }
        }
        handler.postDelayed(updateRunnable!!, UPDATE_INTERVAL_MS)
    }

    private fun buildNotification(dataJson: String): android.app.Notification {
        val (title, body) = buildContent(dataJson)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName)?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) } ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun buildContent(dataJson: String): Pair<String, String> {
        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        val minute = now.get(Calendar.MINUTE)
        val second = now.get(Calendar.SECOND)
        val nowSecs = hour * 3600 + minute * 60 + second

        try {
            val json = JSONObject(dataJson)
            val location = json.optString("location", "").ifEmpty { "Prayer Times" }
            val prayers = listOf(
                "fajr" to json.optString("fajr", "00:00"),
                "dhuhr" to json.optString("dhuhr", "00:00"),
                "asr" to json.optString("asr", "00:00"),
                "maghrib" to json.optString("maghrib", "00:00"),
                "isha" to json.optString("isha", "00:00")
            )
            var nextKey = ""
            var nextTime = ""
            var remainingSecs = 0
            for ((key, timeStr) in prayers) {
                val parts = timeStr.split(":")
                if (parts.size < 2) continue
                val pH = parts[0].toIntOrNull() ?: 0
                val pM = parts[1].toIntOrNull() ?: 0
                val prayerSecs = pH * 3600 + pM * 60
                if (prayerSecs > nowSecs) {
                    nextKey = key
                    nextTime = timeStr
                    remainingSecs = prayerSecs - nowSecs
                    break
                }
            }
            if (nextKey.isEmpty()) {
                val fajrStr = json.optString("fajr", "05:00")
                val fParts = fajrStr.split(":")
                val fH = if (fParts.isNotEmpty()) fParts[0].toIntOrNull() ?: 5 else 5
                val fM = if (fParts.size > 1) fParts[1].toIntOrNull() ?: 0 else 0
                nextKey = "fajr"
                nextTime = fajrStr
                remainingSecs = (fH + 24) * 3600 + fM * 60 - nowSecs
            }
            val appTitle = json.optString("appTitle", "Nida Adhan")
            val title = "$appTitle • (${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')})"
            val prayerLabel = nextKey.replaceFirstChar { it.uppercase(Locale.ROOT) }
            val remaining = formatRemaining(remainingSecs)
            val body = "$location. $prayerLabel $nextTime. ($remaining)"
            return title to body
        } catch (_: Exception) {
            val title = "Nida Adhan • (${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')})"
            return title to "Waiting for prayer times..."
        }
    }

    private fun formatRemaining(totalSeconds: Int): String {
        if (totalSeconds <= 0) return "0:00"
        val h = totalSeconds / 3600
        val m = (totalSeconds % 3600) / 60
        val s = totalSeconds % 60
        return when {
            h > 0 -> "%d:%02d:%02d".format(h, m, s)
            m > 0 -> "%d:%02d".format(m, s)
            else -> "0:%02d".format(s)
        }
    }

    override fun onDestroy() {
        updateRunnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "prayer_times_persistent"
        private const val NOTIFICATION_ID = 1001
        private const val PREFS_NAME = "nida_persistent_notification"
        private const val KEY_DATA = "data"
        private const val UPDATE_INTERVAL_MS = 5000L // 5s to reduce NotificationManager log spam
        const val ACTION_STOP = "com.nida.islamiuygulama.STOP_PERSISTENT"
        const val EXTRA_DATA = "data"
    }
}
