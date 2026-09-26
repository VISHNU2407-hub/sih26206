import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/guardian_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/disaster_event_model.dart';
import 'call_service.dart';
import 'disaster_service.dart';
import 'firestore_service.dart';
import 'sms_service.dart';
import 'live_location_service.dart';
import 'guardian_alert_service.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class SOSService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final DisasterService _disasterService = DisasterService();
  final SMSService _smsService = SMSService();
  final LiveLocationService _locationService = LiveLocationService();
  final CallService _callService = CallService();

  String? _currentEmergencyId;
  bool _isEmergencyActive = false;
  StreamSubscription? _locationSubscription;
  int _guardianCallToken = 0;

  /// Restore any active SOS emergency for the current user.
  Future<SOSActiveEmergency?> restoreActiveEmergency() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _currentEmergencyId = null;
        _isEmergencyActive = false;
        return null;
      }

      final activeEmergency = await _firestore
          .collection('emergencies')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeEmergency.docs.isEmpty) {
        _currentEmergencyId = null;
        _isEmergencyActive = false;
        return null;
      }

      final doc = activeEmergency.docs.first;
      _currentEmergencyId = doc.id;
      _isEmergencyActive = true;

      await _startLocationTracking(doc.id, currentUser.uid);

      return SOSActiveEmergency(emergencyId: doc.id, data: doc.data());
    } catch (e) {
      print('Error restoring active SOS: $e');
      return null;
    }
  }

  /// Activate SOS emergency
  Future<SOSActivationResult> activateSOS({
    bool silent = false,
    bool playGuardianEmergencyCall = true,
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return SOSActivationResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Get user data
      final UserModel? user = await _firestoreService.getUser(currentUser.uid);
      if (user == null) {
        return SOSActivationResult(
          success: false,
          error: 'User data not found',
        );
      }

      // Get guardians
      final List<GuardianModel> guardians = await _firestoreService
          .getGuardians(currentUser.uid);
      if (guardians.isEmpty) {
        return SOSActivationResult(
          success: false,
          error: 'No guardians configured',
        );
      }

      // Get current location
      final location = await _locationService.getCurrentLocation(
        allowPermissionRequest: !silent,
        allowOpenSettings: !silent,
      );
      if (location == null) {
        return SOSActivationResult(
          success: false,
          error: 'Unable to get location',
        );
      }

      // Generate Google Maps link
      final locationLink = _locationService.generateGoogleMapsLink(
        location.latitude,
        location.longitude,
      );

      // Create emergency session in Firebase
      final emergencyId = await _createEmergencySession(
        userId: currentUser.uid,
        userName: user.name,
        userPhone: user.phone,
        guardians: guardians,
        latitude: location.latitude,
        longitude: location.longitude,
        locationLink: locationLink,
        guardianCount: guardians.length,
        silent: silent,
        user: user,
      );

      if (emergencyId == null) {
        return SOSActivationResult(
          success: false,
          error: 'Failed to create emergency session',
        );
      }

      _currentEmergencyId = emergencyId;
      _isEmergencyActive = true;

      // Create Firestore notification documents for guardians' Notification Center
      await _createSOSNotifications(
        userName: user.name,
        emergencyId: emergencyId,
        guardians: guardians,
      );

      // Send SMS to all guardians
      final phoneNumbers = guardians.map((g) => g.phone).toList();
      final smsResults = await _smsService.sendEmergencySMSToMultiple(
        phoneNumbers: phoneNumbers,
        userName: user.name,
        userPhone: user.phone,
        locationLink: locationLink,
      );

      // Count successful SMS sends
      final successfulSms = smsResults.values
          .where((success) => success)
          .length;

      // Start location tracking
      await _startLocationTracking(emergencyId, currentUser.uid);

      if (playGuardianEmergencyCall) {
        _startGuardianEmergencyCall(guardians);
      }

      return SOSActivationResult(
        success: true,
        emergencyId: emergencyId,
        location: location,
        locationLink: locationLink,
        guardiansNotified: successfulSms,
        totalGuardians: guardians.length,
      );
    } catch (e) {
      print('Error activating SOS: $e');
      return SOSActivationResult(success: false, error: e.toString());
    }
  }

  /// Creates Firestore notification documents for each guardian
  /// when an SOS alert is activated.
  Future<void> _createSOSNotifications({
    required String userName,
    required String emergencyId,
    required List<GuardianModel> guardians,
  }) async {
    if (guardians.isEmpty) return;

    // Normalize guardian phone numbers for lookup
    final normalizedPhones = guardians
        .map((g) => GuardianAlertService.normalizePhone(g.phone))
        .where((p) => p.isNotEmpty)
        .toList();

    if (normalizedPhones.isEmpty) return;

    try {
      // Query users by normalized phone numbers to find guardian user IDs
      final usersSnapshot = await _firestore
          .collection('users')
          .where('phoneNormalized', whereIn: normalizedPhones)
          .get();

      if (usersSnapshot.docs.isEmpty) return;

      for (final userDoc in usersSnapshot.docs) {
        final guardianUserId = userDoc.id;
        final notification = NotificationModel(
          id: '', // Firestore .add() will assign the document ID
          title: 'SOS Activated',
          body: '$userName triggered an emergency SOS alert.',
          type: 'sos',
          createdAt: DateTime.now(),
          isRead: false,
          targetMandal: '',
          targetUserId: guardianUserId,
          relatedDocumentId: emergencyId,
        );
        await _firestoreService.createNotification(notification);
      }
    } catch (e) {
      // Log but do not fail SOS activation if notification creation fails
      print('Error creating SOS notifications: $e');
    }
  }

  void _startGuardianEmergencyCall(List<GuardianModel> guardians) {
    final token = ++_guardianCallToken;
    unawaited(_callFirstGuardianWithEmergencyVoice(guardians, token));
  }

  Future<void> _callFirstGuardianWithEmergencyVoice(
    List<GuardianModel> guardians,
    int token,
  ) async {
    String? firstGuardianPhone;
    for (final guardian in guardians) {
      final phone = guardian.phone.trim();
      if (phone.isNotEmpty) {
        firstGuardianPhone = phone;
        break;
      }
    }

    if (firstGuardianPhone == null) {
      return;
    }

    try {
      final started = await _callService.callPhoneNumber(firstGuardianPhone);
      if (!started) {
        print('Unable to initiate guardian 1 call');
        return;
      }

      if (!_shouldKeepGuardianCallActive(token)) {
        return;
      }

      await _callService.startEmergencyVoicePlayback();
      await _monitorGuardianCallUntilDisconnected(token);
    } catch (e) {
      print('Error initiating guardian 1 call: $e');
      await _callService.stopEmergencyVoicePlayback();
    }
  }

  Future<void> _monitorGuardianCallUntilDisconnected(int token) async {
    var hasSeenActiveCall = false;
    var idleChecksBeforeActive = 0;

    while (_shouldKeepGuardianCallActive(token)) {
      final callState = await _callService.getCallState();
      if (callState.isActive) {
        hasSeenActiveCall = true;
      } else if (callState == CallState.idle && hasSeenActiveCall) {
        break;
      } else if (callState == CallState.idle) {
        idleChecksBeforeActive++;
        if (idleChecksBeforeActive >= 5) {
          break;
        }
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    await _callService.stopEmergencyVoicePlayback();
  }

  bool _shouldKeepGuardianCallActive(int token) {
    return _isEmergencyActive && token == _guardianCallToken;
  }

  void _stopGuardianEmergencyCall() {
    _guardianCallToken++;
    unawaited(_callService.stopEmergencyVoicePlayback());
  }

  /// Deactivate SOS emergency
  Future<bool> deactivateSOS() async {
    try {
      if (_currentEmergencyId == null) {
        return false;
      }

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final emergencyId = _currentEmergencyId!;
      final UserModel? user = await _firestoreService.getUser(currentUser.uid);
      final List<GuardianModel> guardians = await _firestoreService
          .getGuardians(currentUser.uid);

      _locationService.stopLocationTracking();
      _locationSubscription?.cancel();
      _locationSubscription = null;
      _stopGuardianEmergencyCall();

      final deactivationClaim = await _claimSOSDeactivation(emergencyId);
      if (!deactivationClaim.claimed) {
        _currentEmergencyId = null;
        _isEmergencyActive = false;
        return false;
      }

      final userName = user?.name.isNotEmpty == true
          ? user!.name
          : deactivationClaim.userName;
      final phoneNumbers = guardians.map((g) => g.phone).toList();

      await _smsService.sendEmergencyEndedSMSToMultiple(
        phoneNumbers: phoneNumbers,
        userName: userName,
      );

      _currentEmergencyId = null;
      _isEmergencyActive = false;

      return true;
    } catch (e) {
      print('Error deactivating SOS: $e');
      return false;
    }
  }

  Future<_SOSDeactivationClaim> _claimSOSDeactivation(
    String emergencyId,
  ) async {
    final emergencyRef = _firestore.collection('emergencies').doc(emergencyId);

    return _firestore.runTransaction((transaction) async {
      final emergencyDoc = await transaction.get(emergencyRef);
      if (!emergencyDoc.exists) {
        return const _SOSDeactivationClaim(claimed: false, userName: '');
      }

      final data = emergencyDoc.data() ?? <String, dynamic>{};
      final status = data['status'] as String?;
      final endedSmsSent = data['endedSmsSent'] == true;

      if (status != 'active' || endedSmsSent) {
        return _SOSDeactivationClaim(
          claimed: false,
          userName: data['userName'] as String? ?? '',
        );
      }

      transaction.update(emergencyRef, {
        'status': 'inactive',
        'deactivatedAt': FieldValue.serverTimestamp(),
        'endedSmsSent': true,
        'endedSmsSentAt': FieldValue.serverTimestamp(),
      });

      return _SOSDeactivationClaim(
        claimed: true,
        userName: data['userName'] as String? ?? '',
      );
    });
  }

  /// Create emergency session in Firebase
  Future<String?> _createEmergencySession({
    required String userId,
    required String userName,
    required String userPhone,
    required List<GuardianModel> guardians,
    required double latitude,
    required double longitude,
    required String locationLink,
    required int guardianCount,
    required bool silent,
    required UserModel user,
  }) async {
    try {
      // Disaster context: attach the deterministic primary disaster for the
      // user's area (null when none — SOS stays purely personal then).
      final activeDisaster = await _disasterService
          .getDisastersForAreaStream(
        village: user.village,
        mandal: user.mandal,
        district: user.district,
      )
          .first
          .then((events) => DisasterService.pickActiveDisaster(
                events,
                village: user.village,
                mandal: user.mandal,
                district: user.district,
              ));

      final docRef = await _firestore.collection('emergencies').add({
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'latitude': latitude,
        'longitude': longitude,
        'locationLink': locationLink,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'guardiansNotified': true,
        'guardianCount': guardianCount,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'triggerMode': silent ? 'stealth_power_button' : 'manual_button',
        // SATS Disaster context (additive; SOS still works without it).
        'village': user.village,
        'mandal': user.mandal,
        'district': user.district,
        'disasterId': activeDisaster?.id,
        if (activeDisaster != null)
          'disasterContext':
              '${DisasterEventModel.typeLabel(activeDisaster.type)} '
                  '(${DisasterEventModel.severityLabel(activeDisaster.severity)})',
        ...GuardianAlertService.instance.buildEmergencyTargetFields(guardians),
      });

      return docRef.id;
    } catch (e) {
      print('Error creating emergency session: $e');
      return null;
    }
  }

  /// Start location tracking for emergency
  Future<void> _startLocationTracking(String emergencyId, String userId) async {
    try {
      _locationService.stopLocationTracking();
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      final started = await _locationService.startLocationTracking(
        interval: const Duration(seconds: 5),
      );

      if (started) {
        _locationSubscription = _locationService.locationStream.listen((
          position,
        ) async {
          await _updateEmergencyLocation(
            emergencyId: emergencyId,
            userId: userId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
      }
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  /// Update emergency location in Firebase
  Future<void> _updateEmergencyLocation({
    required String emergencyId,
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final locationLink = _locationService.generateGoogleMapsLink(
        latitude,
        longitude,
      );

      await _firestore.collection('emergencies').doc(emergencyId).update({
        'latitude': latitude,
        'longitude': longitude,
        'locationLink': locationLink,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      // Also update user's current location
      await _firestoreService.updateUserLocation(userId, latitude, longitude);
    } catch (e) {
      print('Error updating emergency location: $e');
    }
  }

  /// Check if emergency is currently active
  bool get isEmergencyActive => _isEmergencyActive;

  /// Get current emergency ID
  String? get currentEmergencyId => _currentEmergencyId;

  /// Dispose resources
  void dispose() {
    _stopGuardianEmergencyCall();
    _locationSubscription?.cancel();
    _locationService.dispose();
  }
}

/// Active SOS emergency restored from Firestore
class SOSActiveEmergency {
  final String emergencyId;
  final Map<String, dynamic> data;

  SOSActiveEmergency({required this.emergencyId, required this.data});
}

class _SOSDeactivationClaim {
  final bool claimed;
  final String userName;

  const _SOSDeactivationClaim({required this.claimed, required this.userName});
}

/// Result of SOS activation
class SOSActivationResult {
  final bool success;
  final String? error;
  final String? emergencyId;
  final dynamic location;
  final String? locationLink;
  final int? guardiansNotified;
  final int? totalGuardians;

  SOSActivationResult({
    required this.success,
    this.error,
    this.emergencyId,
    this.location,
    this.locationLink,
    this.guardiansNotified,
    this.totalGuardians,
  });
}
