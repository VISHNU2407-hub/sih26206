import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/guardian_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/permission_service.dart';
import '../../services/sos_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/guardian_card.dart';
import 'emergency_history_screen.dart';
import 'profile/guardian_setup_screen.dart';

/// SATS Disaster — Emergency SOS.
///
/// Pure UI around the unchanged [SOSService] logic: hold-to-activate with
/// 2-second confirmation, guardian notifications, SMS, live location and
/// call-out all behave exactly as before.
class SOSScreen extends StatefulWidget {
  final UserModel user;

  /// When true (SOS triggered from the home-screen hold), activation begins
  /// as soon as this screen opens — the hold already confirmed intent.
  final bool autoActivate;

  const SOSScreen({
    super.key,
    required this.user,
    this.autoActivate = false,
  });

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final SOSService _sosService = SOSService();

  List<GuardianModel> _guardians = [];
  bool _isLoading = true;
  bool _smsGranted = false;
  bool _phoneGranted = false;
  bool _locationGranted = false;
  bool _isActivatingSOS = false;
  bool _isSOSActive = false;
  bool _autoHandled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.autoActivate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_autoHandled && mounted) {
          _autoHandled = true;
          _handleSOSActivated();
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadGuardians(),
        _checkPermissions(),
        _restoreActiveSOSState(),
      ]);
    } catch (e) {
      debugPrint('Error loading SOS data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreActiveSOSState() async {
    final activeEmergency = await _sosService.restoreActiveEmergency();
    if (mounted) {
      setState(() {
        _isSOSActive = activeEmergency != null;
      });
    }
  }

  Future<void> _loadGuardians() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      final guardians = await _firestoreService.getGuardians(currentUser.uid);
      if (mounted) {
        setState(() {
          _guardians = guardians;
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = await PermissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _smsGranted = permissions['sms'] ?? false;
        _phoneGranted = permissions['phone'] ?? false;
        _locationGranted = permissions['location'] ?? false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final results = await PermissionService.requestAllPermissions();
    if (mounted) {
      setState(() {
        _smsGranted = results['sms'] ?? false;
        _phoneGranted = results['phone'] ?? false;
        _locationGranted = results['location'] ?? false;
      });

      if (!(results['sms'] ?? false) ||
          !(results['phone'] ?? false) ||
          !(results['location'] ?? false)) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'SMS, Phone, and Location permissions are required for the SOS feature to work properly. Please grant all permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sosService.dispose();
    super.dispose();
  }

  Future<void> _handleSOSActivated() async {
    if (_isActivatingSOS || _isSOSActive) {
      return;
    }

    setState(() {
      _isActivatingSOS = true;
    });

    try {
      final result = await _sosService.activateSOS();

      if (mounted) {
        if (result.success) {
          setState(() {
            _isSOSActive = true;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 72),
                  const SizedBox(height: 16),
                  const Text(
                    'Help is on the way',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${result.guardiansNotified ?? 0} of '
                    '${result.totalGuardians ?? 0} emergency contacts '
                    'have been alerted with your location.',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          _showActivationProblem(result.error);
        }
      }
    } catch (e) {
      debugPrint('SOS activation error: $e');
      if (mounted) {
        _showActivationProblem(null);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingSOS = false;
        });
      }
    }
  }

  /// Human-friendly failure message. Technical causes are logged, never shown.
  void _showActivationProblem(String? technicalError) {
    debugPrint('SOS activation failed: $technicalError');

    String title = 'SOS couldn\u2019t be activated';
    String message =
        'Something went wrong while sending your emergency alert. '
        'Check your connection and try again.';

    if (technicalError != null) {
      if (technicalError.contains('guardian')) {
        title = 'No emergency contacts yet';
        message =
            'Add at least one emergency contact so we know who to alert '
            'when you need help.';
      } else if (technicalError.contains('location')) {
        title = 'Location unavailable';
        message =
            'We couldn\u2019t get your current location. Turn on location '
            'services and try again — your contacts need your location '
            'to find you.';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.warning, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppText.cardTitle)),
          ],
        ),
        content: Text(message, style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToGuardianSetup();
            },
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStopSOS() async {
    if (!_isSOSActive || _isActivatingSOS) {
      return;
    }

    setState(() {
      _isActivatingSOS = true;
    });

    try {
      final stopped = await _sosService.deactivateSOS();

      if (!mounted) {
        return;
      }

      if (stopped) {
        setState(() {
          _isSOSActive = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('SOS Stopped'),
            content: const Text('Emergency location sharing has been stopped.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to Stop SOS'),
            content: const Text(
                'No active SOS session was found to stop.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping SOS: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text(
                'Something went wrong while stopping the SOS. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingSOS = false;
        });
      }
    }
  }

  void _navigateToGuardianSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuardianSetupScreen()),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        actions: [
          IconButton(
            tooltip: 'Emergency History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingState(message: 'Preparing emergency tools…')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── What this does — one calm line ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(14),
                        borderRadius:
                            BorderRadius.circular(AppRadius.control),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 17, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'For personal emergencies — instantly alerts '
                              'your contacts with your live location.',
                              style: AppText.caption
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Hold-to-activate button (unchanged 2s behavior) ──
                    Center(
                      child: Opacity(
                        opacity: _isActivatingSOS ? 0.6 : 1,
                        child: EmergencySosButton(
                          size: 210,
                          onSOSActivated: _handleSOSActivated,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _isSOSActive
                          ? 'SOS is active'
                          : _isActivatingSOS
                              ? 'Activating…'
                              : 'Press & hold for 2 seconds',
                      textAlign: TextAlign.center,
                      style: AppText.cardTitle.copyWith(
                        color: _isSOSActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isSOSActive
                          ? 'Your emergency contacts can see your live location'
                          : 'Holding confirms it\u2019s not an accidental touch',
                      textAlign: TextAlign.center,
                      style: AppText.metadata,
                    ),

                    // ── Active state: Stop SOS ──
                    if (_isSOSActive) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _isActivatingSOS ? null : _handleStopSOS,
                        icon: const Icon(Icons.stop_circle_rounded),
                        label: const Text('Stop SOS'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // ── Readiness (compact — replaces the long checklist) ──
                    _ReadinessCard(
                      guardiansReady: _guardians.isNotEmpty,
                      guardianCount: _guardians.length,
                      permissionsReady:
                          _smsGranted && _phoneGranted && _locationGranted,
                      smsGranted: _smsGranted,
                      phoneGranted: _phoneGranted,
                      locationGranted: _locationGranted,
                      onFixTap: _guardians.isEmpty
                          ? _navigateToGuardianSetup
                          : _requestPermissions,
                      fixLabel: _guardians.isEmpty
                          ? 'Add Emergency Contact'
                          : 'Grant Permissions',
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Emergency contacts ──
                    SectionHeader(
                      'Your Emergency Contacts',
                      actionLabel: _guardians.isEmpty ? null : 'Manage',
                      onAction:
                          _guardians.isEmpty ? null : _navigateToGuardianSetup,
                    ),
                    if (_guardians.isEmpty)
                      _buildEmptyGuardiansState()
                    else
                      ..._guardians.map(
                        (guardian) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GuardianCard(
                            guardian: guardian,
                            onEdit: _navigateToGuardianSetup,
                          ),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyGuardiansState() {
    return AppCard(
      child: Column(
        children: [
          const IconBadge(Icons.contact_phone_rounded, AppColors.warning,
              size: 56, soft: true),
          const SizedBox(height: AppSpacing.md),
          Text('No emergency contacts yet', style: AppText.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Add people who should be alerted when you trigger SOS — '
            'family, neighbours or friends nearby.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _navigateToGuardianSetup,
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Add Emergency Contact'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Readiness card — compact green/amber summary
// ─────────────────────────────────────────────────────────────────────────

class _ReadinessCard extends StatelessWidget {
  final bool guardiansReady;
  final int guardianCount;
  final bool permissionsReady;
  final bool smsGranted;
  final bool phoneGranted;
  final bool locationGranted;
  final VoidCallback onFixTap;
  final String fixLabel;

  const _ReadinessCard({
    required this.guardiansReady,
    required this.guardianCount,
    required this.permissionsReady,
    required this.smsGranted,
    required this.phoneGranted,
    required this.locationGranted,
    required this.onFixTap,
    required this.fixLabel,
  });

  bool get _allReady => guardiansReady && permissionsReady;

  @override
  Widget build(BuildContext context) {
    final accent =
        _allReady ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withAlpha(12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _allReady
                    ? Icons.verified_user_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                _allReady
                    ? 'SOS is ready to use'
                    : 'SOS needs one more thing',
                style:
                    AppText.cardTitle.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _row(
            Icons.contact_phone_rounded,
            'Emergency contacts',
            guardiansReady ? '$guardianCount ready' : 'None added',
            guardiansReady,
          ),
          const SizedBox(height: 8),
          _row(
            Icons.sms_rounded,
            'SMS permission',
            smsGranted ? 'Granted' : 'Missing',
            smsGranted,
          ),
          const SizedBox(height: 8),
          _row(
            Icons.phone_rounded,
            'Phone permission',
            phoneGranted ? 'Granted' : 'Missing',
            phoneGranted,
          ),
          const SizedBox(height: 8),
          _row(
            Icons.location_on_rounded,
            'Location permission',
            locationGranted ? 'Granted' : 'Missing',
            locationGranted,
          ),
          if (!_allReady) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFixTap,
                icon: const Icon(Icons.build_circle_outlined, size: 18),
                label: Text(fixLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, bool ok) {
    final color = ok ? AppColors.success : AppColors.warning;
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppText.caption)),
        StatusChip(value, color),
      ],
    );
  }
}
