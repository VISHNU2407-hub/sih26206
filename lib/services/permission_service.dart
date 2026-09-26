import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  /// Request SMS permission
  static Future<bool> requestSMSPermission() async {
    final status = await ph.Permission.sms.request();
    return status.isGranted;
  }

  /// Request Phone permission
  static Future<bool> requestPhonePermission() async {
    final status = await ph.Permission.phone.request();
    return status.isGranted;
  }

  /// Request Location permission
  static Future<bool> requestLocationPermission() async {
    final status = await ph.Permission.location.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      return false;
    }
    return false;
  }

  /// Request Contacts permission
  static Future<bool> requestContactsPermission() async {
    final status = await ph.Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if SMS permission is granted
  static Future<bool> isSMSPermissionGranted() async {
    final status = await ph.Permission.sms.status;
    return status.isGranted;
  }

  /// Check if Phone permission is granted
  static Future<bool> isPhonePermissionGranted() async {
    final status = await ph.Permission.phone.status;
    return status.isGranted;
  }

  /// Check if Location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await ph.Permission.location.status;
    return status.isGranted;
  }

  /// Check if Contacts permission is granted
  static Future<bool> isContactsPermissionGranted() async {
    final status = await ph.Permission.contacts.status;
    return status.isGranted;
  }

  /// Request all required permissions at once
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    results['sms'] = await requestSMSPermission();
    results['phone'] = await requestPhonePermission();
    results['location'] = await requestLocationPermission();

    return results;
  }

  /// Check all permissions status
  static Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};

    results['sms'] = await isSMSPermissionGranted();
    results['phone'] = await isPhonePermissionGranted();
    results['location'] = await isLocationPermissionGranted();

    return results;
  }

  /// Open app settings for permission
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  /// Show permission rationale dialog
  static Future<bool> showPermissionRationale(
    BuildContext context,
    String permissionType,
    String rationale,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Permission Required'),
            content: Text(rationale),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Grant Permission'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
