package com.sats.disaster

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives system broadcasts after device boot and app update to
 * automatically restart [PowerButtonSosService] so the stealth SOS
 * power-button trigger is active without requiring the user to
 * manually open the app.
 *
 * Broadcasts handled:
 * - [Intent.ACTION_BOOT_COMPLETED]        — Device fully booted and user unlocked
 * - [Intent.ACTION_LOCKED_BOOT_COMPLETED] — Device booted but user locked (API 27+ only, API < 31)
 * - [Intent.ACTION_MY_PACKAGE_REPLACED]   — App was updated via Play Store / sideload
 *
 * Android 12+ foreground-service restriction note:
 * Both BOOT_COMPLETED and MY_PACKAGE_REPLACED are explicitly exempt from
 * the background-start restrictions that apply to most other broadcasts.
 * Starting a foreground service from LOCKED_BOOT_COMPLETED is NOT exempt
 * on API 31+, so the service is only started from that broadcast on API < 31.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                startPowerButtonService(context)
            }

            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // On API 31+ the system restricts foreground-service starts
                // from LOCKED_BOOT_COMPLETED. BOOT_COMPLETED will fire later
                // once the user unlocks, so we rely on that path instead.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    startPowerButtonService(context)
                }
            }

            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // App was updated. Restart the service to pick up any new code paths.
                // This broadcast is also exempt from background FGS restrictions.
                startPowerButtonService(context)
            }
        }
    }

    private fun startPowerButtonService(context: Context) {
        val intent = Intent(context, PowerButtonSosService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
}
