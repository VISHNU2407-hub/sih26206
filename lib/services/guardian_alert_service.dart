import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/guardian_model.dart';

/// Manages guardian-specific emergency detection.
///
/// Previously this service listened for active emergencies in Firestore
/// and launched [EmergencyAlertActivity] (full-screen red alert with
/// siren). That disruptive behavior has been removed.
///
/// The service now only writes the current user's normalized phone number
/// to their Firestore document on startup, which is needed by the
/// [StealthSosManager] and SOS Cloud Function for guardian-to-user
/// lookups. All other notification channels (SMS, FCM push, phone
/// calls, live location, Notification Center) remain intact.
class GuardianAlertService {
  GuardianAlertService._();

  static final GuardianAlertService instance = GuardianAlertService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;

  Future<void> initialize() async {
    _authSubscription ??= _auth.authStateChanges().listen(
      (user) => unawaited(_ensurePhoneNormalized(user)),
    );
    await _ensurePhoneNormalized(_auth.currentUser);
  }

  /// Ensures the current user's Firestore document contains a
  /// normalized phone number so that the SOS Cloud Function and
  /// [StealthSosManager] can look up guardian device tokens.
  Future<void> _ensurePhoneNormalized(User? user) async {
    if (user == null) return;

    try {
      final phone = await _currentUserPhone(user);
      final phoneNormalized = normalizePhone(phone);
      if (phoneNormalized.isEmpty) return;

      await _firestore.collection('users').doc(user.uid).set({
        'phoneNormalized': phoneNormalized,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error writing normalized phone: $e');
    }
  }

  Future<String> _currentUserPhone(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    return (data?['phone'] as String?) ?? user.phoneNumber ?? '';
  }

  Map<String, dynamic> buildEmergencyTargetFields(
    List<GuardianModel> guardians,
  ) {
    final guardianPhonesNormalized = guardians
        .map((guardian) => normalizePhone(guardian.phone))
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .toList();

    return {
      'guardianPhonesNormalized': guardianPhonesNormalized,
      'guardianAlertMode': 'firestore_realtime',
      'guardianAlertCreatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
