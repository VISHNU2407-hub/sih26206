import 'package:flutter/material.dart';

import '../../models/disaster_event_model.dart';
import '../../models/shelter_model.dart';
import '../../models/user_model.dart';
import '../../models/village_preparedness_model.dart';
import '../../services/disaster_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import 'shelters_screen.dart';

/// SATS Disaster — full disaster alert detail.
///
/// Structured so a citizen instantly gets:
///   WHAT happened?      → type + title + summary
///   HOW serious?        → severity badge + status
///   WHERE does it affect me? → affected area chips
///   WHAT should I do?   → evacuation emphasis + safety instructions
///
/// Data source and services unchanged.
class DisasterAlertDetailScreen extends StatelessWidget {
  final UserModel user;

  /// Pre-loaded disaster (from the home banner). When null, the screen
  /// resolves the primary active disaster for the user's area itself.
  final DisasterEventModel? disaster;

  const DisasterAlertDetailScreen({
    super.key,
    required this.user,
    this.disaster,
  });

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();

    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Alert')),
      body: disaster != null
          ? _AlertDetailBody(user: user, disaster: disaster!)
          : StreamBuilder<DisasterEventModel?>(
              stream: service.getPrimaryDisasterForAreaStream(
                village: user.village,
                mandal: user.mandal,
                district: user.district,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const LoadingState(message: 'Checking your area…');
                }
                if (snapshot.hasError) {
                  return const ErrorState();
                }
                final event = snapshot.data;
                if (event == null) {
                  return EmptyState(
                    icon: Icons.verified_rounded,
                    iconColor: AppColors.success,
                    title: 'No alerts for your area',
                    message:
                        'There is currently no disaster warning affecting '
                        '${user.village.isNotEmpty ? user.village : 'your village'}. '
                        'New warnings will appear here immediately.',
                  );
                }
                return _AlertDetailBody(user: user, disaster: event);
              },
            ),
    );
  }
}

class _AlertDetailBody extends StatelessWidget {
  final UserModel user;
  final DisasterEventModel disaster;

  const _AlertDetailBody({required this.user, required this.disaster});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(disaster.severity);
    final evacuation = disaster.evacuationRequired;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl,
        ),
        children: [
          // ── WHAT + HOW SERIOUS: severity header ──
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: color.withAlpha(13),
              borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              border: Border.all(color: color.withAlpha(120), width: 1.5),
              boxShadow: appCardShadow(opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      '${DisasterEventModel.severityLabel(disaster.severity)} ALERT',
                      color,
                      filled: true,
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      DisasterEventModel.statusLabel(disaster.status),
                      disasterStatusColor(disaster.status),
                    ),
                    const Spacer(),
                    if (disaster.isDemoData) const DemoTag(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_typeIcon(disaster.type), color: color, size: 28),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${DisasterEventModel.typeLabel(disaster.type)} alert',
                        style: AppText.headline.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                if (disaster.title.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(disaster.title, style: AppText.cardTitle),
                ],
                if (disaster.summary.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    disaster.summary,
                    style: AppText.body,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Issued ${_formatDateTime(disaster.startedAt ?? disaster.createdAt)}'
                  '  •  Updated ${_formatDateTime(disaster.updatedAt)}',
                  style: AppText.metadata,
                ),
              ],
            ),
          ),

          // ── WHAT TO DO: evacuation emphasis (first action block) ──
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: evacuation
                  ? AppColors.danger.withAlpha(16)
                  : AppColors.success.withAlpha(16),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: evacuation
                    ? AppColors.danger.withAlpha(110)
                    : AppColors.success.withAlpha(110),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      evacuation
                          ? Icons.directions_run_rounded
                          : Icons.shield_rounded,
                      color: evacuation ? AppColors.danger : AppColors.success,
                      size: 26,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        evacuation
                            ? 'Evacuation required'
                            : 'No evacuation needed',
                        style: AppText.cardTitle.copyWith(
                          fontSize: 16,
                          color:
                              evacuation ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  evacuation
                      ? 'Move to your nearest shelter as advised by local '
                          'authorities. Take essential items and help people '
                          'who need support.'
                      : 'Stay alert for further advisories. Keep your phone '
                          'reachable and follow any instructions below.',
                  style: AppText.body,
                ),
                if (evacuation) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SheltersScreen(user: user),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.night_shelter_rounded,
                              size: 18),
                          label: const Text('Find Shelter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── WHERE: affected area ──
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Affected Area'),
          _areaCard(),

          // ── WHAT TO DO: instructions ──
          if (disaster.instructions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Safety Instructions'),
            AppCard(
              child: Column(
                children: disaster.instructions
                    .split('\n')
                    .where((line) => line.trim().isNotEmpty)
                    .map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 17, color: AppColors.success),
                              const SizedBox(width: AppSpacing.sm + 2),
                              Expanded(
                                child: Text(
                                  line.trim(),
                                  style: AppText.body.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],

          // ── Shelter guidance ──
          const SizedBox(height: AppSpacing.xl),
          _ShelterGuidance(user: user),

          // ── Emergency contacts ──
          const SizedBox(height: AppSpacing.xl),
          _EmergencyContacts(village: user.village),
        ],
      ),
    );
  }

  Widget _areaCard() {
    final rows = <(String, List<String>)>[
      if (disaster.affectedVillages.isNotEmpty)
        ('Villages', disaster.affectedVillages),
      if (disaster.affectedMandals.isNotEmpty)
        ('Mandals', disaster.affectedMandals),
      if (disaster.affectedDistricts.isNotEmpty)
        ('Districts', disaster.affectedDistricts),
    ];

    if (rows.isEmpty) {
      return AppCard(
        child: Text(
          'Your area is within the alert scope — follow the instructions above.',
          style: AppText.caption,
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm + 2),
                SizedBox(
                  width: 72,
                  child: Text(
                    rows[i].$1,
                    style: AppText.caption,
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2.join(' • '),
                    style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) => AppHelpers.formatDateTime(dt);

  IconData _typeIcon(String type) {
    switch (type) {
      case 'flood':
        return Icons.water_rounded;
      case 'cyclone':
        return Icons.cyclone_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'earthquake':
        return Icons.vibration_rounded;
      case 'landslide':
        return Icons.landscape_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Shelter guidance (nearest shelter for the user's village)
// ─────────────────────────────────────────────────────────────────────────

class _ShelterGuidance extends StatelessWidget {
  final UserModel user;

  const _ShelterGuidance({required this.user});

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();
    return StreamBuilder<List<ShelterModel>>(
      stream: service.getSheltersForVillageStream(user.village),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final shelters = snapshot.data ?? const <ShelterModel>[];
        final withSpace =
            shelters.where((s) => s.availableSpace > 0).toList()
              ..sort(
                (a, b) => b.availableSpace.compareTo(a.availableSpace),
              );
        final primary = withSpace.isNotEmpty
            ? withSpace.first
            : shelters.isNotEmpty
                ? shelters.first
                : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Where to Go'),
            if (primary == null)
              AppCard(
                child: Text(
                  user.village.isEmpty
                      ? 'Complete your profile with your village to see '
                          'nearby shelters.'
                      : 'No shelters registered for ${user.village} yet. '
                          'Your authority will publish them before an evacuation.',
                  style: AppText.caption,
                ),
              )
            else ...[
              AppCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SheltersScreen(user: user),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const IconBadge(Icons.home_work_rounded, AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(primary.name, style: AppText.cardTitle),
                          const SizedBox(height: 3),
                          Text(
                            primary.availableSpace > 0
                                ? '${primary.village} • ${primary.availableSpace} spaces available'
                                : '${primary.village} • currently full',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SheltersScreen(user: user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.night_shelter_rounded, size: 18),
                  label: const Text('View All Shelters'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Emergency contacts from the preparedness record
// ─────────────────────────────────────────────────────────────────────────

class _EmergencyContacts extends StatelessWidget {
  final String village;

  const _EmergencyContacts({required this.village});

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();
    return StreamBuilder<List<VillagePreparednessModel>>(
      stream: service.getPreparednessForVillageStream(village),
      builder: (context, snapshot) {
        final record = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? snapshot.data!.first
            : null;
        final contacts =
            record?.emergencyContacts ?? const <Map<String, dynamic>>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Emergency Contacts'),
            if (contacts.isEmpty)
              AppCard(
                child: Text(
                  'Village emergency contacts have not been published yet. '
                  'In an emergency call 112 (national emergency number).',
                  style: AppText.caption,
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
                child: Column(
                  children: [
                    for (var i = 0; i < contacts.length; i++) ...[
                      if (i > 0) const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.contact_phone_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(
                              child: Text(
                                '${contacts[i]['name'] ?? 'Contact'}',
                                style: AppText.body
                                    .copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              '${contacts[i]['phone'] ?? '—'}',
                              style: AppText.cardTitle
                                  .copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
