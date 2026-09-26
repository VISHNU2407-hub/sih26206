package com.sats.disaster

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat

class PowerButtonSosService : Service() {
    private val pressTimestamps = ArrayDeque<Long>()
    private var lastEventAt = 0L
    private var lastTriggerAt = 0L
    private var isReceiverRegistered = false

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF || intent.action == Intent.ACTION_SCREEN_ON) {
                handlePowerButtonEvent()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NotificationIds.powerButtonSos, buildNotification())
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        registerScreenReceiver()
        return START_STICKY
    }

    override fun onDestroy() {
        Log.i(TAG, "Service shutting down -- stopping location tracking")
        StealthSosManager.stopPeriodicLocationUpdates()

        if (isReceiverRegistered) {
            unregisterReceiver(screenReceiver)
            isReceiverRegistered = false
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun registerScreenReceiver() {
        if (isReceiverRegistered) {
            return
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        registerReceiver(screenReceiver, filter)
        isReceiverRegistered = true
    }

    private fun handlePowerButtonEvent() {
        val now = SystemClock.elapsedRealtime()

        if (now - lastTriggerAt < triggerCooldownMillis) {
            return
        }

        if (lastEventAt != 0L) {
            val delta = now - lastEventAt
            if (delta < minPressGapMillis) {
                return
            }
            if (delta > maxPressGapMillis) {
                pressTimestamps.clear()
            }
        }

        lastEventAt = now
        pressTimestamps.addLast(now)

        while (pressTimestamps.isNotEmpty() && now - pressTimestamps.first() > triggerWindowMillis) {
            pressTimestamps.removeFirst()
        }

        if (pressTimestamps.size >= requiredPresses) {
            pressTimestamps.clear()
            lastTriggerAt = now
            vibrateBriefly()
            Log.i(TAG, "Power button trigger threshold reached — invoking StealthSosManager")
            StealthSosManager.triggerStealthSos(this)
        }
    }

    private fun vibrateBriefly() {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(80, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(80)
        }
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Safety trigger",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("SATS Protection")
            .setContentText("Safety monitoring active")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    private object NotificationIds {
        const val powerButtonSos = 4102
    }

    companion object {
        private const val notificationChannelId = "stealth_sos_trigger"
        private const val requiredPresses = 4
        private const val triggerWindowMillis = 3500L
        private const val minPressGapMillis = 120L
        private const val maxPressGapMillis = 1600L
        private const val triggerCooldownMillis = 30000L
        private const val TAG = "PowerButtonSosService"
    }
}
