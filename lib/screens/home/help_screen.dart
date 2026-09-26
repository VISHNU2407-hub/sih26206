import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../services/disaster_service.dart';
import '../../theme/app_theme.dart';
import '../sos_screen.dart';
import 'blood_bank_screen.dart';
import 'complaint_screen.dart';
import 'hospitals_screen.dart';
import 'citizen_recovery_screen.dart';
import 'missing_person_alerts_screen.dart';
import 'shelters_screen.dart';

/// SATS Disaster — citizen Help hub.
///
/// Every assistance entry point in one calm, scannable place:
/// SOS, shelters, recovery, missing persons, blood banks and helplines.
class HelpScreen extends StatelessWidget {
  final UserModel user;

  const HelpScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl,
          ),
          children: [
            // ── SOS (existing infrastructure) ──
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.danger, AppColors.dangerDeep],
                ),
                borderRadius: BorderRadius.circular(AppRadius.cardLarge),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withAlpha(50),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.cardLarge),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SOSScreen(user: user)),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.emergency,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency SOS',
                                style: AppText.cardTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Alert your contacts with your live location',
                                style: AppText.caption
                                    .copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Main assistance ──
            const SectionHeader('Find help near you'),
            _HelpAction(
              icon: Icons.night_shelter_rounded,
              color: AppColors.primary,
              title: 'Shelters',
              subtitle: 'Open shelters, capacity and facilities',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SheltersScreen(user: user),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            _HelpAction(
              icon: Icons.restart_alt_rounded,
              color: AppColors.success,
              title: 'Village Recovery',
              subtitle: 'Water, relief and shelter availability in your area',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CitizenRecoveryScreen(user: user),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            _HelpAction(
              icon: Icons.person_search_rounded,
              color: AppColors.warning,
              title: 'Missing Person Alerts',
              subtitle: 'Report or look for missing people',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MissingPersonAlertsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            _HelpAction(
              icon: Icons.bloodtype_rounded,
              color: const Color(0xFFB71C1C),
              title: 'Blood Bank Directory',
              subtitle: 'Find blood banks and emergency donors',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BloodBankScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            _HelpAction(
              icon: Icons.local_hospital_rounded,
              color: AppColors.info,
              title: 'Public Hospitals',
              subtitle: 'Find, call and navigate to public hospitals',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HospitalsScreen(user: user),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Emergency contacts (village) ──
            _EmergencyContactsCard(village: user.village),

            const SizedBox(height: AppSpacing.xl),

            // ── National helplines (static, public numbers) ──
            const SectionHeader('Emergency Numbers'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Column(
                children: [
                  _helpline(context, '112', 'National emergency'),
                  _divider(),
                  _helpline(context, '108', 'Ambulance'),
                  _divider(),
                  _helpline(context, '100', 'Police'),
                  _divider(),
                  _helpline(context, '101', 'Fire'),
                  _divider(),
                  _helpline(context, '1077', 'Disaster management'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Legacy civic complaints (non-emergency) — kept reachable ──
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ComplaintScreen()),
                  );
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Civic complaint (non-emergency)'),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(indent: 56);

  Widget _helpline(BuildContext context, String number, String label) {
    return InkWell(
      onTap: () => _call(context, number),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppText.body)),
            const Icon(Icons.call_rounded,
                size: 18, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start the call to $number'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
}

class _HelpAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          IconBadge(icon, color, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _EmergencyContactsCard extends StatelessWidget {
  final String village;

  const _EmergencyContactsCard({required this.village});

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Your Village Contacts'),
        StreamBuilder<List<dynamic>>(
          stream: service
              .getPreparednessForVillageStream(village)
              .map((records) => (records.isNotEmpty
                  ? records.first.emergencyContacts
                  : const <Map<String, dynamic>>[]) as List<dynamic>),
          builder: (context, snapshot) {
            final contacts = snapshot.data ?? const <dynamic>[];
            if (contacts.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const IconBadge(Icons.contact_phone_rounded,
                        AppColors.textTertiary,
                        size: 42, soft: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Your village hasn\u2019t published emergency contacts '
                        'yet. In an emergency, call 112.',
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
              );
            }
            return AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
              child: Column(
                children: [
                  for (var i = 0; i < contacts.length; i++) ...[
                    if (i > 0) const Divider(),
                    _contactRow(context, contacts[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _contactRow(BuildContext context, dynamic c) {
    final name = '${c['name'] ?? 'Contact'}';
    final phone = '${c['phone'] ?? ''}';
    return InkWell(
      onTap: phone.isEmpty ? null : () => _callNumber(context, phone),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const Icon(Icons.contact_phone_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: AppText.body)),
            Text(
              phone.isEmpty ? '—' : phone,
              style: AppText.cardTitle.copyWith(color: AppColors.primary),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.call_rounded, size: 16, color: AppColors.success),
          ],
        ),
      ),
    );
  }

  Future<void> _callNumber(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not start the call'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
}
