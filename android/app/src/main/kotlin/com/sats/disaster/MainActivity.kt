package com.sats.disaster

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.provider.ContactsContract
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import java.util.Locale
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val smsChannel = "village_verse/sms"
    private val callChannel = "village_verse/call"
    private val contactPickerChannel = "village_verse/contact_picker"
    private val stealthSosTriggerChannel = "village_verse/stealth_sos_trigger"
    private val deviceSettingsChannel = "village_verse/device_settings"
    private val pickPhoneContactRequestCode = 4101
    private var pendingContactPickerResult: MethodChannel.Result? = null
    private val emergencyVoiceHandler = Handler(Looper.getMainLooper())
    private val emergencyVoiceMessage = "This is an emergency. I need help. Please check my SMS for my live location."
    private var emergencyTextToSpeech: TextToSpeech? = null
    private var isEmergencyVoicePlaying = false
    private val emergencyVoiceRunnable = object : Runnable {
        override fun run() {
            if (!isEmergencyVoicePlaying) {
                return
            }

            val textToSpeech = emergencyTextToSpeech
            if (textToSpeech == null) {
                emergencyVoiceHandler.postDelayed(this, 1000)
                return
            }

            val params = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "sos_emergency_voice")
            }
            textToSpeech.speak(
                emergencyVoiceMessage,
                TextToSpeech.QUEUE_FLUSH,
                params,
                "sos_emergency_voice"
            )
            emergencyVoiceHandler.postDelayed(this, 5500)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Stealth SOS trigger Channel — used by [StealthSOSTriggerService] to
        // start / stop the native power-button watcher foreground service.
        // The actual SOS escalation happens entirely on the native side
        // via [StealthSosManager], which works without a Flutter engine.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, stealthSosTriggerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startPowerButtonWatcher" -> {
                        val intent = Intent(this, PowerButtonSosService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopPowerButtonWatcher" -> {
                        stopService(Intent(this, PowerButtonSosService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("invalid_arguments", "Phone number and message are required.", null)
                        return@setMethodCallHandler
                    }

                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("permission_denied", "SEND_SMS permission has not been granted.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                        result.success(true)
                    } catch (exception: Exception) {
                        result.error("send_failed", exception.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contactPickerChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPhoneContact" -> {
                    if (pendingContactPickerResult != null) {
                        result.error("picker_active", "Contact picker is already open.", null)
                        return@setMethodCallHandler
                    }

                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("permission_denied", "READ_CONTACTS permission has not been granted.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        pendingContactPickerResult = result
                        val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                        startActivityForResult(intent, pickPhoneContactRequestCode)
                    } catch (exception: ActivityNotFoundException) {
                        pendingContactPickerResult = null
                        result.error("picker_unavailable", exception.message, null)
                    } catch (exception: Exception) {
                        pendingContactPickerResult = null
                        result.error("picker_failed", exception.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "callPhoneNumber" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")

                    if (phoneNumber.isNullOrBlank()) {
                        result.error("invalid_arguments", "Phone number is required.", null)
                        return@setMethodCallHandler
                    }

                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
                        result.error("permission_denied", "CALL_PHONE permission has not been granted.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val intent = Intent(Intent.ACTION_CALL).apply {
                            data = Uri.fromParts("tel", phoneNumber, null)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (exception: ActivityNotFoundException) {
                        result.error("call_failed", exception.message, null)
                    } catch (exception: SecurityException) {
                        result.error("permission_denied", exception.message, null)
                    } catch (exception: Exception) {
                        result.error("call_failed", exception.message, null)
                    }
                }
                "getCallState" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                        result.success("unknown")
                        return@setMethodCallHandler
                    }

                    try {
                        val telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                        @Suppress("DEPRECATION")
                        val callState = telephonyManager.callState
                        val state = when (callState) {
                            TelephonyManager.CALL_STATE_IDLE -> "idle"
                            TelephonyManager.CALL_STATE_RINGING -> "ringing"
                            TelephonyManager.CALL_STATE_OFFHOOK -> "offHook"
                            else -> "unknown"
                        }
                        result.success(state)
                    } catch (exception: Exception) {
                        result.success("unknown")
                    }
                }
                "startEmergencyVoicePlayback" -> {
                    startEmergencyVoicePlayback()
                    result.success(true)
                }
                "stopEmergencyVoicePlayback" -> {
                    stopEmergencyVoicePlayback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceSettingsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                "openAutoStartSettings" -> {
                    openAutoStartSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickPhoneContactRequestCode) {
            val result = pendingContactPickerResult
            pendingContactPickerResult = null

            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }

            if (resultCode != RESULT_OK || data?.data == null) {
                result.success(null)
                return
            }

            try {
                val contactUri = data.data
                val projection = arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                )
                contentResolver.query(contactUri!!, projection, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        val phoneIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                        val name = if (nameIndex >= 0) cursor.getString(nameIndex).orEmpty() else ""
                        val phone = if (phoneIndex >= 0) cursor.getString(phoneIndex).orEmpty() else ""
                        result.success(mapOf("name" to name, "phone" to phone))
                    } else {
                        result.success(null)
                    }
                } ?: result.success(null)
            } catch (exception: SecurityException) {
                result.error("permission_denied", exception.message, null)
            } catch (exception: Exception) {
                result.error("contact_read_failed", exception.message, null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun startEmergencyVoicePlayback() {
        if (isEmergencyVoicePlaying) {
            return
        }

        isEmergencyVoicePlaying = true
        if (emergencyTextToSpeech == null) {
            emergencyTextToSpeech = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    emergencyTextToSpeech?.language = Locale.ENGLISH
                    if (isEmergencyVoicePlaying) {
                        emergencyVoiceHandler.post(emergencyVoiceRunnable)
                    }
                } else {
                    isEmergencyVoicePlaying = false
                }
            }
        } else {
            emergencyVoiceHandler.post(emergencyVoiceRunnable)
        }
    }

    private fun stopEmergencyVoicePlayback() {
        isEmergencyVoicePlaying = false
        emergencyVoiceHandler.removeCallbacks(emergencyVoiceRunnable)
        emergencyTextToSpeech?.stop()
    }

    override fun onDestroy() {
        stopEmergencyVoicePlayback()
        emergencyTextToSpeech?.shutdown()
        emergencyTextToSpeech = null
        // StealthSosManager lifecycle is independent of the Activity.
        // No cleanup needed here.
        super.onDestroy()
    }

    private fun openBatteryOptimizationSettings() {
        val intents = listOf(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            },
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return
            } catch (_: Exception) {
            }
        }
    }

    private fun openAutoStartSettings() {
        val intents = listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.appmanager.ApplicationsDetailsActivity"
                )
                putExtra("package_name", packageName)
            },
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                return
            } catch (_: Exception) {
            }
        }
    }

    // Companion object has been removed.
    // The legacy [triggerStealthSosFromPowerButton] relied on a static
    // MethodChannel that was null whenever the Activity was destroyed
    // or never created (reboot). All SOS escalation is now handled by
    // the native [StealthSosManager], which operates independently of
    // the Flutter engine lifecycle.
}
