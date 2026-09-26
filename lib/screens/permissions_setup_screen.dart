import 'dart:io';

import 'package:flutter/material.dart';

import '../services/device_settings_service.dart';
import '../services/permission_service.dart';
import '../services/permissions_setup_service.dart';

class PermissionsSetupScreen extends StatefulWidget {
  final bool canSkip;
  final VoidCallback? onCompleted;

  const PermissionsSetupScreen({super.key, this.canSkip = false, this.onCompleted});

  @override
  State<PermissionsSetupScreen> createState() => _PermissionsSetupScreenState();
}

class _PermissionsSetupScreenState extends State<PermissionsSetupScreen> {
  bool _locationGranted = false;
  bool _smsGranted = false;
  bool _contactsGranted = false;
  bool _phoneGranted = false;
  bool _notificationGranted = false;
  bool _overlayGranted = !Platform.isAndroid;
  bool _batteryOptimizationHandled = !Platform.isAndroid;
  bool _autoStartHandled = !Platform.isAndroid;
  bool _loading = true;

  bool get _criticalReady =>
      _smsGranted && _locationGranted && _phoneGranted && _overlayGranted;

  int get _completedCount {
    final values = [
      _locationGranted,
      _smsGranted,
      _contactsGranted,
      _phoneGranted,
      _notificationGranted,
      _overlayGranted,
      _batteryOptimizationHandled,
      _autoStartHandled,
    ];
    return values.where((done) => done).length;
  }

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loading = true);
    final permissions = await PermissionService.checkAllPermissions();
    final contacts = await PermissionService.isContactsPermissionGranted();
    final notification = await DeviceSettingsService.isNotificationGranted();
    final overlay = await DeviceSettingsService.isOverlayGranted();
    final batteryIgnore =
        await DeviceSettingsService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _smsGranted = permissions['sms'] ?? false;
      _phoneGranted = permissions['phone'] ?? false;
      _locationGranted = permissions['location'] ?? false;
      _contactsGranted = contacts;
      _notificationGranted = notification;
      _overlayGranted = overlay;
      _batteryOptimizationHandled = batteryIgnore;
      _loading = false;
    });
  }

  Future<void> _completeAndContinue() async {
    await PermissionsSetupService.markCompleted();
    if (!mounted) return;
    if (widget.onCompleted != null) {
      widget.onCompleted!.call();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _completedCount / 8;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safety Permissions Setup',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Grant required permissions to keep SOS and stealth safety triggers reliable.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: Colors.red.shade100,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed $_completedCount of 8',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshStatuses,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            _permissionCard(
                              icon: Icons.location_on_rounded,
                              title: 'Location',
                              reason:
                                  'Needed to send your live location during SOS emergencies.',
                              granted: _locationGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await PermissionService.requestLocationPermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.sms_rounded,
                              title: 'SMS',
                              reason:
                                  'Needed to send emergency messages to your guardians.',
                              granted: _smsGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await PermissionService.requestSMSPermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.contact_phone_rounded,
                              title: 'Contacts',
                              reason:
                                  'Lets you pick guardian numbers quickly from your contacts.',
                              granted: _contactsGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await PermissionService.requestContactsPermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.phone_in_talk_rounded,
                              title: 'Phone Call',
                              reason:
                                  'Allows emergency call initiation and call-state checks.',
                              granted: _phoneGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await PermissionService.requestPhonePermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.notifications_active_rounded,
                              title: 'Notifications',
                              reason:
                                  'Needed for safety service visibility and alert prompts.',
                              granted: _notificationGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await DeviceSettingsService
                                    .requestNotificationPermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.layers_rounded,
                              title: 'Display Over Other Apps',
                              reason:
                                  'Required so emergency alerts can appear over lock/home screens.',
                              granted: _overlayGranted,
                              actionLabel: 'Enable',
                              onTap: () async {
                                await DeviceSettingsService
                                    .requestOverlayPermission();
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.battery_saver_rounded,
                              title: 'Battery Optimization',
                              reason:
                                  'Disable optimization to reduce background service interruptions.',
                              granted: _batteryOptimizationHandled,
                              actionLabel: 'Open Settings',
                              hint:
                                  'On many Android devices: set app battery to Unrestricted / No restrictions.',
                              onTap: () async {
                                await DeviceSettingsService
                                    .openBatteryOptimizationSettings();
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                await _refreshStatuses();
                              },
                            ),
                            _permissionCard(
                              icon: Icons.power_settings_new_rounded,
                              title: 'Auto-start (Xiaomi / Poco / Redmi)',
                              reason:
                                  'Enable auto-start so stealth SOS watcher can restart after reboot.',
                              granted: _autoStartHandled,
                              actionLabel: 'Open Auto-start',
                              hint:
                                  'MIUI/HyperOS path usually: Settings > Apps > Permissions > Auto start.',
                              onTap: () async {
                                await DeviceSettingsService.openAutoStartSettings();
                                if (!mounted) return;
                                setState(() {
                                  _autoStartHandled = true;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: const Text(
                                'Critical requirements to continue: SMS, Location, Phone Call, and Overlay.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFB71C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _criticalReady ? _completeAndContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Continue to App'),
                    ),
                    if (widget.canSkip)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String reason,
    required bool granted,
    required String actionLabel,
    required Future<void> Function() onTap,
    String? hint,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: granted
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: granted ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: granted
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: granted ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    granted ? 'Granted' : 'Not Granted',
                    style: TextStyle(
                      color: granted ? Colors.green.shade700 : Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(reason, style: TextStyle(color: Colors.grey.shade700, height: 1.3)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.settings),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
