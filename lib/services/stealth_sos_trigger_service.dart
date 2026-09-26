import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages the native power-button watcher lifecycle.
///
/// The actual SOS emergency escalation is now handled entirely
/// on the native Android side by [StealthSosManager] (Kotlin)
/// for maximum reliability — it works after reboot, swipe-from-recents,
/// locked screen, and when the Flutter engine is not running.
///
/// This Dart class is responsible for:
///   1. Telling the native side to *start* listening for power-button presses
///      (called on app launch, or whenever the user enables stealth SOS).
///   2. Telling the native side to *stop* listening (called on app exit
///      or when the user disables stealth SOS).
///
/// The Flutter UI detects an active emergency via [SOSService.restoreActiveEmergency]
/// and [GuardianAlertService], which both listen to Firestore directly.
class StealthSOSTriggerService {
  StealthSOSTriggerService._();

  static final StealthSOSTriggerService instance = StealthSOSTriggerService._();

  static const MethodChannel _channel = MethodChannel(
    'village_verse/stealth_sos_trigger',
  );

  bool _isInitialized = false;

  /// Initialize the service — tells the native side to start watching
  /// for power-button presses.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    try {
      await _channel.invokeMethod('startPowerButtonWatcher');
      debugPrint('Stealth SOS watcher started successfully');
    } catch (e) {
      debugPrint('Error starting stealth SOS watcher: $e');
    }
  }

  /// Release resources. Currently no-op — the native service lifecycle
  /// is managed independently.
  Future<void> dispose() async {
    // Native service handles its own lifecycle.
  }
}
