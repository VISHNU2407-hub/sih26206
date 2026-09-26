import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class DeviceSettingsService {
  static const MethodChannel _channel = MethodChannel(
    'village_verse/device_settings',
  );

  static Future<bool> isOverlayGranted() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await ph.Permission.systemAlertWindow.status;
    return status.isGranted;
  }

  static Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await ph.Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  static Future<bool> isNotificationGranted() async {
    final status = await ph.Permission.notification.status;
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await ph.Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }

  static Future<void> openAutoStartSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod('openAutoStartSettings');
  }
}
