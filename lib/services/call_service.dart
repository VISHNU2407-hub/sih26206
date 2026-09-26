import 'package:flutter/services.dart';

import 'permission_service.dart';

class CallService {
  static const MethodChannel _channel = MethodChannel('village_verse/call');

  Future<bool> callPhoneNumber(String phoneNumber) async {
    final trimmedPhoneNumber = phoneNumber.trim();
    if (trimmedPhoneNumber.isEmpty) {
      return false;
    }

    final hasPhonePermission = await PermissionService.requestPhonePermission();
    if (!hasPhonePermission) {
      return false;
    }

    try {
      final didStartCall = await _channel.invokeMethod<bool>(
        'callPhoneNumber',
        {'phoneNumber': trimmedPhoneNumber},
      );
      return didStartCall ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<CallState> getCallState() async {
    try {
      final state = await _channel.invokeMethod<String>('getCallState');
      return CallState.fromPlatformValue(state);
    } on PlatformException {
      return CallState.unknown;
    }
  }

  Future<bool> startEmergencyVoicePlayback() async {
    try {
      final started = await _channel.invokeMethod<bool>(
        'startEmergencyVoicePlayback',
      );
      return started ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stopEmergencyVoicePlayback() async {
    try {
      await _channel.invokeMethod<void>('stopEmergencyVoicePlayback');
    } on PlatformException {
      return;
    }
  }
}

enum CallState {
  idle,
  ringing,
  offHook,
  unknown;

  bool get isActive => this == CallState.ringing || this == CallState.offHook;

  static CallState fromPlatformValue(String? value) {
    switch (value) {
      case 'idle':
        return CallState.idle;
      case 'ringing':
        return CallState.ringing;
      case 'offHook':
        return CallState.offHook;
      default:
        return CallState.unknown;
    }
  }
}
