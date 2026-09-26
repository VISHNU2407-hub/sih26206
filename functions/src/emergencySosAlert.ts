import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
//  EMERGENCY SOS ALERT – FCM Push to Guardians
// ─────────────────────────────────────────────────────────────────────────────
//
//  Trigger:  onCreate of a document in the `emergencies` collection
//  Purpose:  When a user triggers SOS, immediately send a high-priority
//            FCM push notification to all their guardians so that the
//            guardian devices show an alert even when the app is killed
//            or in the background.
//
//  The existing GuardianAlertService (Flutter) + Firestore listener
//  already handles the real-time detection when the app is in the
//  foreground. This Cloud Function adds FCM delivery so that the
//  notification arrives *reliably* regardless of app state.
//
//  Architecture:
//    1. Read the emergency document (victim name, phone, location,
//       guardianPhonesNormalized)
//    2. Query the `users` collection to find all users whose
//       phoneNormalized matches one of the guardian phone numbers
//    3. Get each guardian user's FCM token
//    4. Send a high-priority FCM notification + data message to
//       each token
//
//  FCM Message Payload:
//    - notification: System-tray title & body (shown automatically)
//    - data:         Custom fields parsed by the app to launch the
//                    EmergencyAlertActivity with victim info
// ─────────────────────────────────────────────────────────────────────────────

export const sendEmergencySosPushToGuardians = functions.firestore
  .document('emergencies/{emergencyId}')
  .onCreate(async (snap, context) => {
    const emergency = snap.data();
    const emergencyId = context.params.emergencyId;

    // ── 1. Extract guardian phone numbers ──
    const guardianPhones: string[] = emergency.guardianPhonesNormalized ?? [];
    if (guardianPhones.length === 0) {
      functions.logger.info(
        `Emergency ${emergencyId}: No guardians to notify (guardianPhonesNormalized is empty).`
      );
      return null;
    }

    const victimName = emergency.userName ?? 'Someone';
    const victimPhone = emergency.userPhone ?? '';
    const locationLink = emergency.locationLink ?? '';
    const latitude = emergency.latitude?.toString() ?? '';
    const longitude = emergency.longitude?.toString() ?? '';
    const victimUserId = emergency.userId ?? '';

    // Parse the timestamp – it's a Firestore Timestamp or server sentinel
    let startedAtMillis: number;
    const ts = emergency.timestamp;
    if (ts && typeof ts.toMillis === 'function') {
      startedAtMillis = ts.toMillis();
    } else {
      startedAtMillis = Date.now();
    }

    functions.logger.info(
      `Emergency ${emergencyId}: Notifying ${guardianPhones.length} guardian(s) about ${victimName}`
    );

    // ── 2. Look up guardian user accounts by phone number ──
    //
    // guardianPhonesNormalized contains the *normalized* phone numbers
    // of the guardians (digits only, or with +). The users collection
    // stores phoneNormalized alongside each user document.
    //
    // We query the users collection for documents that have one of
    // these phone numbers. This requires a composite index, or we
    // query one-by-one in batches.
    //
    // For up to 3 guardians (the app's max), we query individually.

    const tokens: string[] = [];

    for (const phone of guardianPhones) {
      try {
        const snapshot = await db
          .collection('users')
          .where('phoneNormalized', '==', phone)
          .get();

        if (snapshot.empty) {
          functions.logger.warn(
            `Emergency ${emergencyId}: No user found for guardian phone ${phone}`
          );
          continue;
        }

        // Take the first match; a phone number should be unique per user
        const guardianUser = snapshot.docs[0].data();
        const fcmToken = guardianUser.fcmToken as string | undefined;

        if (fcmToken && fcmToken.length > 0) {
          tokens.push(fcmToken);
        } else {
          functions.logger.warn(
            `Emergency ${emergencyId}: Guardian with phone ${phone} has no FCM token`
          );
        }
      } catch (err) {
        functions.logger.error(
          `Emergency ${emergencyId}: Error querying guardian ${phone}:`,
          err
        );
      }
    }

    if (tokens.length === 0) {
      functions.logger.warn(
        `Emergency ${emergencyId}: No FCM tokens found for any guardian.`
      );
      return null;
    }

    functions.logger.info(
      `Emergency ${emergencyId}: Sending FCM to ${tokens.length} device(s)`
    );

    // ── 3. Send FCM push notification to each token ──
    //
    // We send a notification + data message so that:
    //   - The system tray shows the alert immediately (notification payload)
    //   - The app receives full emergency details to launch the
    //     EmergencyAlertActivity (data payload)

    const payload: admin.messaging.Message = {
      notification: {
        title: '\uD83D\uDEA8 EMERGENCY SOS ALERT',
        body: `${victimName} has triggered an SOS alert and may be in danger.\nImmediate attention required.`,
      },
      data: {
        type: 'sos_alert',
        emergencyId: emergencyId,
        victimName: victimName,
        victimPhone: victimPhone,
        victimUserId: victimUserId,
        locationLink: locationLink,
        latitude: latitude,
        longitude: longitude,
        startedAtMillis: String(startedAtMillis),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'sos_emergency_alert',
          priority: 'max',
          visibility: 'public',
          color: '#FF0000',
          sound: 'default',
          defaultSound: true,
          defaultVibrateTimings: true,
          notificationCount: 1,
          // Use the alarm category so the system treats it
          // as a high-importance event
          eventTime: startedAtMillis,
          ticker: `SOS Alert: ${victimName} needs help`,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: '\uD83D\uDEA8 EMERGENCY SOS ALERT',
              body: `${victimName} has triggered an SOS alert and may be in danger.\nImmediate attention required.`,
            },
            sound: 'default',
            badge: 1,
            'content-available': 1,
            'mutable-content': 1,
            category: 'sos_alert',
            'thread-id': emergencyId,
          },
        },
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
      },
      webpush: {
        notification: {
          title: '\uD83D\uDEA8 EMERGENCY SOS ALERT',
          body: `${victimName} has triggered an SOS alert and may be in danger.\nImmediate attention required.`,
          icon: '/favicon.ico',
          badge: '/badge.png',
          tag: emergencyId,
          renotify: true,
          requireInteraction: true,
          vibrate: [200, 100, 200, 100, 400],
        },
        fcmOptions: {
          link: 'https://village-assistance-app.web.app/sos',
        },
      },
    };

    // Send individually so one failure doesn't prevent sending to others
    const results = await Promise.allSettled(
      tokens.map((token) =>
        admin.messaging().send({
          ...payload,
          token,
        })
      )
    );

    // ── 4. Report results ──
    let successCount = 0;
    let failureCount = 0;

    for (const result of results) {
      if (result.status === 'fulfilled') {
        successCount++;
      } else {
        failureCount++;
        functions.logger.error(
          `Emergency ${emergencyId}: FCM send failed: ${result.reason}`
        );
      }
    }

    functions.logger.info(
      `Emergency ${emergencyId}: FCM results – ${successCount} sent, ${failureCount} failed`
    );

    // Update the emergency document with FCM delivery status
    try {
      await db.collection('emergencies').doc(emergencyId).update({
        fcmPushSent: true,
        fcmPushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmPushSuccessCount: successCount,
        fcmPushFailureCount: failureCount,
      });
    } catch (err) {
      functions.logger.error(
        `Emergency ${emergencyId}: Failed to update FCM status: ${err}`
      );
    }

    return null;
  });
