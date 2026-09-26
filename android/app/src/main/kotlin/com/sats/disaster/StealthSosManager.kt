package com.sats.disaster

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.auth.ktx.auth
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Handles the complete Stealth SOS emergency escalation from native Android code.
 *
 * This manager is invoked by [PowerButtonSosService] when 4 rapid power-button
 * presses are detected. It operates entirely outside the Flutter engine lifecycle,
 * making it reliable in all scenarios: reboot, swipe-from-recents, background,
 * locked screen, etc.
 *
 * Flow:
 * 1. Get authenticated user from FirebaseAuth (persisted cross-reboot)
 * 2. Read user profile + guardian contacts from Firestore
 * 3. Get current device location (fresh GPS fix)
 * 4. Create emergency document in Firestore
 * 5. Send emergency SMS to each guardian
 */
object StealthSosManager {

    private const val TAG = "StealthSosManager"

    // Periodic location tracking state
    private var trackedEmergencyId: String? = null
    private var trackedUserId: String? = null
    @Volatile
    private var isTracking = false
    private var trackingContext: Context? = null
    private val trackingThread = HandlerThread("location-tracker")
    private var trackingHandler: Handler? = null

    /** Interval between periodic location updates in milliseconds. */
    private const val LOCATION_UPDATE_INTERVAL_MS = 30_000L

    private val locationUpdateRunnable = object : Runnable {
        override fun run() {
            val ctx = trackingContext ?: return
            val emergencyId = trackedEmergencyId ?: return
            val userId = trackedUserId ?: return
            val handler = trackingHandler ?: return

            // Fetch one fresh GPS point
            val location = requestFreshLocation(ctx)

            // Guard: tracking may have been stopped while we waited for GPS
            if (!isTracking) return

            if (location != null) {
                Log.i(TAG, "Periodic location update: ${location.latitude}, ${location.longitude}")
                updateEmergencyLocation(emergencyId, userId, location)
            } else {
                Log.w(TAG, "Periodic location fetch returned null -- skipping update")
            }

            // Reschedule after 30s if still tracking
            if (isTracking) {
                handler.postDelayed(this, LOCATION_UPDATE_INTERVAL_MS)
            }
        }
    }

    /**
     * Triggers the full stealth SOS workflow on a background thread.
     * After the emergency is created, periodic location tracking begins automatically.
     * Safe to call from any thread (including BroadcastReceiver's main thread).
     */
    fun triggerStealthSos(context: Context) {
        Log.i(TAG, "=== STEALTH SOS TRIGGERED ===")

        // All Firestore/location/SMS work must happen off the main thread
        // to avoid ANR, since these are blocking I/O calls.
        Thread {
            try {
                executeSos(context)
            } catch (e: Exception) {
                Log.e(TAG, "Stealth SOS failed with exception: ${e.message}", e)
            }
        }.apply {
            name = "stealth-sos-worker"
            start()
        }
    }

    /**
     * Starts periodic background location tracking for the active emergency.
     * Called automatically after [triggerStealthSos] creates the emergency,
     * but exposed publicly so [PowerButtonSosService] can restart tracking
     * if the service is re-created.
     */
    fun startPeriodicLocationUpdates(
        context: Context,
        emergencyId: String,
        userId: String
    ) {
        if (isTracking) {
            Log.d(TAG, "Location tracking already active for emergency: $emergencyId")
            return
        }

        Log.i(TAG, "Starting periodic location tracking for emergency: $emergencyId")
        isTracking = true
        trackedEmergencyId = emergencyId
        trackedUserId = userId
        trackingContext = context.applicationContext

        if (!trackingThread.isAlive) {
            trackingThread.start()
        }
        trackingHandler = Handler(trackingThread.looper)
        trackingHandler?.post(locationUpdateRunnable)
    }

    /**
     * Stops periodic location tracking. Called from
     * [PowerButtonSosService.onDestroy] when the service is shut down.
     */
    fun stopPeriodicLocationUpdates() {
        if (!isTracking) return
        Log.i(TAG, "Stopping periodic location tracking")
        isTracking = false
        trackingHandler?.removeCallbacks(locationUpdateRunnable)
        trackingHandler = null
        trackedEmergencyId = null
        trackedUserId = null
        trackingContext = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            trackingThread.quitSafely()
        } else {
            trackingThread.quit()
        }
    }

    /**
     * Updates the Firestore emergency document with a fresh location.
     * Runs on the background [trackingThread].
     */
    private fun updateEmergencyLocation(
        emergencyId: String,
        userId: String,
        location: android.location.Location
    ) {
        val latitude = location.latitude
        val longitude = location.longitude
        val locationLink = "https://maps.google.com/?q=$latitude,$longitude"

        try {
            val db = Firebase.firestore
            db.collection("emergencies").document(emergencyId)
                .update(
                    "latitude", latitude,
                    "longitude", longitude,
                    "locationLink", locationLink,
                    "lastLocationUpdate", FieldValue.serverTimestamp()
                )
                .awaitWithTimeout("location update", 10_000)

            // Also update user's current location for later retrieval
            db.collection("users").document(userId)
                .update(
                    "latitude", latitude,
                    "longitude", longitude
                )
                .awaitWithTimeout("user location update", 10_000)

            Log.d(TAG, "Location updated in Firestore: $latitude, $longitude")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update location in Firestore: ${e.message}")
        }
    }

    // -------------------------------------------------------------------------
    // Core execution (runs on background thread)
    // -------------------------------------------------------------------------

    private fun executeSos(context: Context) {
        // ---- Step 1: Authenticated user ------------------------------------
        Log.d(TAG, "Step 1: Checking FirebaseAuth...")
        val auth = Firebase.auth
        val firebaseUser = auth.currentUser
        if (firebaseUser == null) {
            Log.e(TAG, "FAILED: No authenticated user. User must log in at least once.")
            return
        }
        val userId = firebaseUser.uid
        Log.d(TAG, "Authenticated user: $userId")

        // ---- Step 2: User profile + guardians from Firestore ---------------
        Log.d(TAG, "Step 2: Reading user profile from Firestore...")
        val db = Firebase.firestore

        val userDoc = db.collection("users").document(userId).get()
            .awaitWithTimeout("user profile", 10_000)

        if (userDoc == null || !userDoc.exists()) {
            Log.e(TAG, "FAILED: User document not found in Firestore")
            return
        }

        val userName = userDoc.getString("name") ?: "Unknown"
        val userPhone = userDoc.getString("phone") ?: ""
        Log.d(TAG, "User: $userName, phone: $userPhone")

        // ---- Step 3: Guardians ---------------------------------------------
        Log.d(TAG, "Step 3: Reading guardians from Firestore...")
        val guardiansSnapshot = db.collection("users").document(userId)
            .collection("guardians")
            .get()
            .awaitWithTimeout("guardians", 10_000)

        val guardians = guardiansSnapshot?.documents.orEmpty()
        if (guardians.isEmpty()) {
            Log.e(TAG, "FAILED: No guardians configured")
            return
        }

        val guardianPhones = guardians.mapNotNull { doc -> doc.getString("phone") }
        val guardianNames = guardians.mapNotNull { doc -> doc.getString("name") }
        Log.d(TAG, "Guardians: ${guardianNames.joinToString()}")

        // ---- Step 4: Current location (fresh GPS fix) ----------------------
        Log.d(TAG, "Step 4: Requesting GPS location (3-tier, up to ~40s)...")
        val location = requestFreshLocation(context)
        val latitude = location?.latitude
        val longitude = location?.longitude
        val locationLink = if (location != null) {
            "https://maps.google.com/?q=${location.latitude},${location.longitude}"
        } else {
            Log.w(TAG, "No GPS location available -- storing null coordinates")
            null
        }
        Log.d(TAG, "Location: ${latitude?.toString() ?: "null"}, " +
                "${longitude?.toString() ?: "null"} " +
                "(${if (location == null) "UNAVAILABLE" else "GPS_FRESH"})")

        // ---- Step 5: Create emergency in Firestore -------------------------
        Log.d(TAG, "Step 5: Creating emergency document in Firestore...")
        val guardianPhonesNormalized = guardianPhones.map { phone ->
            phone.replace(Regex("[^0-9+]"), "")
        }

        val emergencyData = hashMapOf<String, Any?>(
            "userId" to userId,
            "userName" to userName,
            "userPhone" to userPhone,
            "latitude" to latitude,
            "longitude" to longitude,
            "locationLink" to locationLink,
            "timestamp" to FieldValue.serverTimestamp(),
            "status" to "active",
            "guardiansNotified" to true,
            "guardianCount" to guardianPhones.size,
            "lastLocationUpdate" to FieldValue.serverTimestamp(),
            "triggerMode" to "stealth_power_button",
            "guardianPhonesNormalized" to guardianPhonesNormalized,
            "guardianAlertMode" to "firestore_realtime",
            "guardianAlertCreatedAt" to FieldValue.serverTimestamp()
        )

        val emergencyRef = db.collection("emergencies").add(emergencyData)
            .awaitWithTimeout("emergency creation", 15_000)

        if (emergencyRef == null) {
            Log.e(TAG, "FAILED: Could not create emergency document in Firestore")
            return
        }

        val emergencyId = emergencyRef.id
        Log.i(TAG, "Emergency created: $emergencyId")

        // ---- Step 6: Send SMS to each guardian -----------------------------
        Log.d(TAG, "Step 6: Sending SMS to ${guardianPhones.size} guardian(s)...")

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "SEND_SMS permission not granted -- SMS will NOT be sent")
        } else {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val message = buildSmsMessage(userName, userPhone, locationLink)
            Log.d(TAG, "SMS body: $message")

            for (phone in guardianPhones) {
                try {
                    val trimmedPhone = phone.trim()
                    if (trimmedPhone.isEmpty()) continue

                    val parts = smsManager.divideMessage(message)
                    smsManager.sendMultipartTextMessage(
                        trimmedPhone, null, parts, null, null
                    )
                    Log.i(TAG, "SMS sent to guardian: $trimmedPhone")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send SMS to '$phone': ${e.message}")
                }
            }
        }

        // ---- Step 7: Start periodic location tracking ----------------------
        Log.i(TAG, "Step 7: Starting background location tracking...")
        startPeriodicLocationUpdates(context, emergencyId, userId)

        // ---- Done ----------------------------------------------------------
        Log.i(TAG, "=== STEALTH SOS COMPLETED SUCCESSFULLY ===")
        Log.i(TAG, "Emergency ID: $emergencyId")
        Log.i(TAG, "Guardians notified: ${guardianPhones.size}")
    }

    // -------------------------------------------------------------------------
    // Fresh location acquisition (FusedLocationProvider)
    // -------------------------------------------------------------------------

    /**
     * Requests a fresh GPS location fix with a **3-tier fallback strategy**:
     *
     * **Tier 1 — getCurrentLocation (10s):** returns the best available location
     *   quickly (cached or a recent fix). This is the same API used previously,
     *   but with a 10-second timeout instead of 15, since we now have fallbacks.
     *
     * **Tier 2 — getLastLocation (5s):** returns the most recent known location
     *   from any provider. Frequently succeeds when the device has had a GPS
     *   fix in the recent past (e.g., the user was using maps before the SOS).
     *
     * **Tier 3 — requestLocationUpdates (25s):** actively asks the GPS chip to
     *   acquire a fresh fix using [LocationRequest] with
     *   [Priority.PRIORITY_HIGH_ACCURACY] and
     *   [LocationRequest.Builder.setWaitForAccurateLocation].
     *   This is the most reliable method for forcing a cold-start GPS acquisition.
     *   Uses a [CountDownLatch] + [LocationCallback] to block the background
     *   thread until a fix is obtained or the timeout expires.
     *
     * Total wall-clock timeout: ~40 seconds.
     *
     * If all tiers fail, returns `null` and the SOS proceeds without coordinates
     * (the Dart [SOSService.restoreActiveEmergency] updates them later).
     */
    private fun requestFreshLocation(context: Context): Location? {
        val fineLocationGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocationGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineLocationGranted && !coarseLocationGranted) {
            Log.e(TAG, "Fresh location FAILED: neither FINE nor COARSE location permission granted")
            return null
        }

        val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)

        // -----------------------------------------------------------------
        // Tier 1: Fast current location (10s)
        // -----------------------------------------------------------------
        Log.d(TAG, "Tier 1: getCurrentLocation (10s)...")
        try {
            val task = fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY, null
            )
            val location = Tasks.await(task, 10, TimeUnit.SECONDS)
            if (location != null) {
                Log.i(TAG, "Tier 1 success: ${location.latitude},${location.longitude} " +
                        "(acc: ${location.accuracy}m)")
                return location
            }
            Log.w(TAG, "Tier 1: getCurrentLocation returned null")
        } catch (e: Exception) {
            Log.w(TAG, "Tier 1 failed: ${e.message}")
        }

        // -----------------------------------------------------------------
        // Tier 2: Last known location (5s)
        // -----------------------------------------------------------------
        Log.d(TAG, "Tier 2: getLastLocation (5s)...")
        try {
            val task = fusedLocationClient.lastLocation
            val location = Tasks.await(task, 5, TimeUnit.SECONDS)
            if (location != null) {
                Log.i(TAG, "Tier 2 success: ${location.latitude},${location.longitude} " +
                        "(acc: ${location.accuracy}m)")
                return location
            }
            Log.w(TAG, "Tier 2: getLastLocation returned null")
        } catch (e: Exception) {
            Log.w(TAG, "Tier 2 failed: ${e.message}")
        }

        // -----------------------------------------------------------------
        // Tier 3: Active GPS fix via requestLocationUpdates (25s)
        // -----------------------------------------------------------------
        Log.d(TAG, "Tier 3: requestLocationUpdates active GPS wait (25s)...")
        try {
            val latch = CountDownLatch(1)
            var gpsLocation: Location? = null

            val locationRequest = LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY, 1000L
            )
                .setWaitForAccurateLocation(true)
                .setMinUpdateIntervalMillis(500L)
                .build()

            val callback = object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    val loc = result.lastLocation
                    if (loc != null && gpsLocation == null) {
                        gpsLocation = loc
                        latch.countDown()
                    }
                }
            }

            fusedLocationClient.requestLocationUpdates(
                locationRequest, callback, Looper.getMainLooper()
            )

            val acquired = latch.await(25, TimeUnit.SECONDS)
            fusedLocationClient.removeLocationUpdates(callback)

            if (acquired && gpsLocation != null) {
                Log.i(TAG, "Tier 3 success: ${gpsLocation?.latitude},${gpsLocation?.longitude} " +
                        "(acc: ${gpsLocation?.accuracy}m)")
                return gpsLocation
            }
            Log.w(TAG, "Tier 3: GPS fix not acquired within 25s")
        } catch (e: Exception) {
            Log.w(TAG, "Tier 3 failed: ${e.message}")
        }

        Log.e(TAG, "All 3 location tiers exhausted — no location available")
        return null
    }

    // -------------------------------------------------------------------------
    // SMS message formatting
    // -------------------------------------------------------------------------

    /**
     * Builds the emergency SMS.
     *
     * When [locationLink] is null (GPS fix unavailable), the SMS omits the
     * "Live Location" line entirely so guardians are not shown a broken
     * "https://maps.google.com/?q=0.0,0.0" link.
     *
     * Must match the format in [SMSService._formatEmergencyMessage] when
     * location IS available.
     */
    private fun buildSmsMessage(
        userName: String,
        userPhone: String,
        locationLink: String?
    ): String {
        val locationLine = if (locationLink != null) {
            "\n\nLive Location: $locationLink"
        } else {
            ""
        }

        return """EMERGENCY ALERT

$userName may be in danger.$locationLine

Phone: $userPhone

Please respond immediately."""
    }

    // -------------------------------------------------------------------------
    // Firestore Task --> blocking await with timeout
    // -------------------------------------------------------------------------

    /**
     * Awaits a Firestore [com.google.android.gms.tasks.Task] with a
     * timeout in milliseconds. Returns `null` on timeout or failure.
     *
     * IMPORTANT: Must only be called from a background thread.
     */
    private fun <T> com.google.android.gms.tasks.Task<T>.awaitWithTimeout(
        description: String,
        timeoutMillis: Long
    ): T? {
        return try {
            com.google.android.gms.tasks.Tasks.await(this, timeoutMillis, java.util.concurrent.TimeUnit.MILLISECONDS)
        } catch (e: java.util.concurrent.TimeoutException) {
            Log.e(TAG, "Timeout waiting for $description")
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error waiting for $description: ${e.message}")
            null
        }
    }
}
