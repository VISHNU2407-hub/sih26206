import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class SMSService {
  static const MethodChannel _channel = MethodChannel('village_verse/sms');

  bool _isInitialized = false;

  /// Initialize the SMS service
  Future<void> initialize() async {
    if (!_isInitialized) {
      // Check permission
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        await requestPermission();
      }
      _isInitialized = true;
    }
  }

  /// Check if SMS permission is granted
  Future<bool> checkPermission() async {
    final status = await ph.Permission.sms.status;
    return status.isGranted;
  }

  /// Request SMS permission
  Future<bool> requestPermission() async {
    final status = await ph.Permission.sms.request();
    return status.isGranted;
  }

  /// Send emergency SMS to a single guardian
  Future<bool> sendEmergencySMS({
    required String phoneNumber,
    required String userName,
    required String userPhone,
    required String locationLink,
  }) async {
    try {
      // Initialize if needed
      await initialize();

      // Check permission first
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          return false;
        }
      }

      // Format the SMS message
      final message = _formatEmergencyMessage(
        userName: userName,
        userPhone: userPhone,
        locationLink: locationLink,
      );

      return _sendSMS(phoneNumber: phoneNumber, message: message);
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Send emergency SMS to multiple guardians
  Future<Map<String, bool>> sendEmergencySMSToMultiple({
    required List<String> phoneNumbers,
    required String userName,
    required String userPhone,
    required String locationLink,
  }) async {
    final results = <String, bool>{};

    for (final phone in phoneNumbers) {
      final success = await sendEmergencySMS(
        phoneNumber: phone,
        userName: userName,
        userPhone: userPhone,
        locationLink: locationLink,
      );
      results[phone] = success;

      // Small delay between SMS to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return results;
  }

  /// Send emergency ended SMS to a single guardian
  Future<bool> sendEmergencyEndedSMS({
    required String phoneNumber,
    required String userName,
  }) async {
    try {
      await initialize();

      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          return false;
        }
      }

      final message = _formatEmergencyEndedMessage(userName: userName);

      return _sendSMS(phoneNumber: phoneNumber, message: message);
    } catch (e) {
      print('Error sending emergency ended SMS: $e');
      return false;
    }
  }

  /// Send emergency ended SMS to multiple guardians
  Future<Map<String, bool>> sendEmergencyEndedSMSToMultiple({
    required List<String> phoneNumbers,
    required String userName,
  }) async {
    final results = <String, bool>{};
    final uniquePhoneNumbers = <String>{};

    for (final phone in phoneNumbers) {
      final trimmedPhone = phone.trim();
      if (trimmedPhone.isEmpty || !uniquePhoneNumbers.add(trimmedPhone)) {
        continue;
      }

      final success = await sendEmergencyEndedSMS(
        phoneNumber: trimmedPhone,
        userName: userName,
      );
      results[trimmedPhone] = success;

      await Future.delayed(const Duration(milliseconds: 500));
    }

    return results;
  }

  /// Format the emergency SMS message
  String _formatEmergencyMessage({
    required String userName,
    required String userPhone,
    required String locationLink,
  }) {
    return '''EMERGENCY ALERT

$userName may be in danger.

Live Location: $locationLink

Phone: $userPhone

Please respond immediately.''';
  }

  /// Format the emergency ended SMS message
  String _formatEmergencyEndedMessage({required String userName}) {
    return '$userName is safe now. Emergency has ended.';
  }

  /// Send a test SMS (for development/testing)
  Future<bool> sendTestSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      await initialize();

      final hasPermission = await checkPermission();
      if (!hasPermission) {
        final granted = await requestPermission();
        if (!granted) {
          return false;
        }
      }

      return _sendSMS(phoneNumber: phoneNumber, message: message);
    } catch (e) {
      print('Error sending test SMS: $e');
      return false;
    }
  }

  Future<bool> _sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    final result = await _channel.invokeMethod<bool>(
      'sendSms',
      <String, String>{
        'phoneNumber': phoneNumber,
        'message': message,
      },
    );

    return result ?? false;
  }
}
