import 'package:flutter/material.dart';

import '../../models/disaster_event_model.dart';
import '../../models/user_model.dart';
import '../../models/village_preparedness_model.dart';
import '../../services/disaster_service.dart';
import '../../theme/app_theme.dart';
import '../sos_screen.dart';
import 'disaster_alert_detail_screen.dart';
import 'evacuation_info_screen.dart';
import 'report_incident_screen.dart';
import 'shelters_screen.dart';
import 'help_screen.dart';

/// SATS Disaster — citizen disaster home.
///
/// Answers three questions in the first seconds of use:
///   1. Is there danger near me?        → safety status hero
///   2. What should I do?               → action line + evacuation emphasis
///   3. Where can I get help?           → SOS + quick actions
///
/// All data comes from the existing Phase 1 Firestore services — no changes
/// to services, models or SOS logic. Demo-seeded documents stay labeled.
class DisasterHomeScreen extends StatefulWidget {
  final UserModel user;

  const DisasterHomeScreen({super.key, required this.user});

  @override
  State<DisasterHomeScreen> createState() => _DisasterHomeScreenState();
}

class _DisasterHomeScreenState extends State<DisasterHomeScreen> {
  final DisasterService _service = DisasterService();

  UserModel get user => widget.user;

  /// Bound in [initState] rather than inside `build` so ordinary rebuilds do
  /// not tear down and re-issue the Firestore subscription.
  late Stream<DisasterEventModel?> _disasterStream;

  @override
  void initState() {
    super.initState();
    _disasterStream = _buildStream();
  }

  Stream<DisasterEventModel?> _buildStream() {
    return _service.getPrimaryDisasterForAreaStream(
      village: widget.user.village,
      mandal: widget.user.mandal,
      district: widget.user.district,
    );
  }

  void _reload() {
    setState(() => _disasterStream = _buildStream());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl,
        ),
        children: [
          // ── Compact header: greeting + location ──
          Text(
            _greeting(),
            style: AppText.headline,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  user.village.isNotEmpty
                      ? '${user.village} • ${user.mandal}'
                      : (user.mandal.isNotEmpty ? user.mandal : 'Andhra Pradesh'),
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── 1. Safety status hero (danger near me?) ──
          StreamBuilder<DisasterEventModel?>(
            stream: _disasterStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _HeroPlaceholder();
              }
              // Safety-critical: a failed/denied query is NOT an all-clear.
              // Never render "no danger near you" for data we could not read.
              if (snapshot.hasError) {
                return _StatusUnavailableCard(
                  onRetry: _reload,
                  onPreparednessTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvacuationInfoScreen(user: user),
                      ),
                    );
                  },
                );
              }
              final disaster = snapshot.data;
              if (disaster == null) {
                return _AllClearCard(
                  village: user.village,
                  mandal: user.mandal,
                  onPreparednessTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvacuationInfoScreen(user: user),
                      ),
                    );
                  },
                );
              }
              return _SafetyStatusHero(disaster: disaster, user: user);
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── 2. Emergency SOS — prominent, hold-to-confirm ──
          _SosSection(user: user),

          const SizedBox(height: AppSpacing.xl),

          // ── 3. Quick actions (help, shelter, report) ──
          const SectionHeader('What do you need?'),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.night_shelter_rounded,
                  color: AppColors.primary,
                  label: 'Shelters',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SheltersScreen(user: user),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _QuickTile(
                  icon: Icons.directions_run_rounded,
                  color: AppColors.warning,
                  label: 'Evacuation',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EvacuationInfoScreen(user: user),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.report_rounded,
                  color: AppColors.danger,
                  label: 'Report Incident',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportIncidentScreen(user: user),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _QuickTile(
                  icon: Icons.support_agent_rounded,
                  color: AppColors.success,
                  label: 'Get Help',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HelpScreen(user: user),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── 4. Village preparedness ──
          _VillageStatusCard(
            village: user.village,
            onSeeEvacuation: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EvacuationInfoScreen(user: user),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  1. Safety status hero
// ─────────────────────────────────────────────────────────────────────────

class _SafetyStatusHero extends StatelessWidget {
  final DisasterEventModel disaster;
  final UserModel user;

  const _SafetyStatusHero({required this.disaster, required this.user});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(disaster.severity);
    final evacuation = disaster.evacuationRequired;

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
        boxShadow: appCardShadow(opacity: 0.04),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity line
            Row(
              children: [
                StatusChip(
                  '${DisasterEventModel.severityLabel(disaster.severity)} ALERT',
                  color,
                  filled: true,
                ),
                const Spacer(),
                if (disaster.isDemoData) const DemoTag(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Headline — human language, not field names
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon(disaster.type), color: color, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${DisasterEventModel.typeLabel(disaster.type)} alert near you',
                    style: AppText.headline.copyWith(color: color),
                  ),
                ),
              ],
            ),

            // One-line summary
            if (disaster.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                disaster.summary,
                style: AppText.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Affected area — plain words
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _affectedAreaText(),
                    style: AppText.caption,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // What should I do — evacuation guidance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: evacuation
                    ? AppColors.danger.withAlpha(20)
                    : AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                children: [
                  Icon(
                    evacuation
                        ? Icons.directions_run_rounded
                        : Icons.shield_rounded,
                    size: 17,
                    color: evacuation ? AppColors.danger : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      evacuation
                          ? 'Evacuation required — go to your nearest shelter'
                          : 'No evacuation needed — stay alert for updates',
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            evacuation ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Action
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DisasterAlertDetailScreen(
                        user: user,
                        disaster: disaster,
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('View Safety Instructions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _affectedAreaText() {
    final parts = <String>[];
    if (disaster.affectedVillages.isNotEmpty) {
      parts.addAll(disaster.affectedVillages.take(3));
    } else if (disaster.affectedMandals.isNotEmpty) {
      parts.addAll(disaster.affectedMandals.take(3));
    } else if (disaster.affectedDistricts.isNotEmpty) {
      parts.addAll(disaster.affectedDistricts.take(3));
    }
    if (parts.isEmpty) return 'Your area';
    final text = parts.join(' • ');
    if (parts.length < (disaster.affectedVillages.isNotEmpty
            ? disaster.affectedVillages.length
            : (disaster.affectedMandals.isNotEmpty
                ? disaster.affectedMandals.length
                : disaster.affectedDistricts.length))) {
      return '$text and more areas';
    }
    return text;
  }

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

/// All-clear hero — calm green, still gives the user something to do.
class _AllClearCard extends StatelessWidget {
  final String village;
  final String mandal;
  final VoidCallback onPreparednessTap;

  const _AllClearCard({
    required this.village,
    required this.mandal,
    required this.onPreparednessTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.success.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\u2019re safe',
                  style: AppText.headline.copyWith(
                    fontSize: 18,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No disaster warnings for '
                  '${village.isNotEmpty ? village : 'your area'} right now.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPreparednessTap,
            child: const Text('Prepare'),
          ),
        ],
      ),
    );
  }
}

/// Neutral "we could not read the alert feed" hero.
///
/// Deliberately NOT the green all-clear card: an unreadable feed must never
/// be presented to a citizen as "you are safe". It stays actionable so the
/// user can retry or fall back to the evacuation/preparedness guidance.
class _StatusUnavailableCard extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onPreparednessTap;

  const _StatusUnavailableCard({
    required this.onRetry,
    required this.onPreparednessTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.warning.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: AppColors.warning, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert status unavailable',
                      style: AppText.headline.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We could not load warnings for your area. Check your '
                      'connection, or call 112 if you need help now.',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onPreparednessTap,
                  child: const Text('What to do'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  2. SOS section
// ─────────────────────────────────────────────────────────────────────────

class _SosSection extends StatelessWidget {
  final UserModel user;

  const _SosSection({required this.user});

  Future<void> _openSos(BuildContext context) async {
    // Opens the existing SOS experience; autoActivate lets the home-screen
    // hold complete flow straight into the (unchanged) activation logic.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SOSScreen(user: user, autoActivate: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.danger, AppColors.dangerDeep],
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withAlpha(60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'EMERGENCY SOS',
            style: AppText.headline.copyWith(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          EmergencySosButton(
            size: 150,
            onSOSActivated: () => _openSos(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: Colors.white70, size: 15),
              const SizedBox(width: 6),
              Text(
                'Press & hold for 2 seconds',
                style: AppText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Alerts your emergency contacts with your live location',
            style: AppText.metadata.copyWith(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  3. Quick action tile
// ─────────────────────────────────────────────────────────────────────────

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.outline),
            boxShadow: appCardShadow(),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(icon, color: color, size: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppText.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  4. Village preparedness
// ─────────────────────────────────────────────────────────────────────────

class _VillageStatusCard extends StatelessWidget {
  final String village;
  final VoidCallback onSeeEvacuation;

  const _VillageStatusCard({
    required this.village,
    required this.onSeeEvacuation,
  });

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();
    return StreamBuilder<List<VillagePreparednessModel>>(
      stream: service.getPreparednessForVillageStream(village),
      builder: (context, snapshot) {
        final record = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? snapshot.data!.first
            : null;

        return AppCard(
          child: record == null
              ? _noDataContent()
              : _content(record),
        );
      },
    );
  }

  Widget _noDataContent() {
    return Row(
      children: [
        const IconBadge(Icons.family_restroom_rounded, AppColors.primary,
            size: 42, soft: true),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Village Preparedness', style: AppText.cardTitle),
              const SizedBox(height: 3),
              Text(
                'Your local authority will publish preparedness and safety '
                'information here.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(VillagePreparednessModel record) {
    final riskColor = severityColor(
      switch (record.riskLevel) {
        'severe' => 'critical',
        'high' => 'high',
        'moderate' => 'medium',
        _ => 'low',
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Village Preparedness', style: AppText.cardTitle),
            ),
            if (record.isDemoData) const DemoTag(),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Risk + shelters + vulnerable chips
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusChip(
              'Risk: ${VillagePreparednessModel.riskLabel(record.riskLevel)}',
              riskColor,
            ),
            StatusChip(
              '${record.sheltersCount} shelter${record.sheltersCount == 1 ? '' : 's'}',
              AppColors.primary,
            ),
            if (record.vulnerableCount > 0)
              StatusChip(
                '${record.vulnerableCount} need extra help',
                AppColors.violet,
              ),
          ],
        ),

        // Hazards
        if (record.hazards.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Known hazards: '
            '${record.hazards.map((h) => h[0].toUpperCase() + h.substring(1)).join(", ")}',
            style: AppText.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // Preparedness progress
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preparedness ${(record.checklistProgress * 100).toStringAsFixed(0)}%',
                    style: AppText.metadata.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  CapacityBar(value: record.checklistProgress),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            OutlinedButton(
              onPressed: onSeeEvacuation,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12.5),
              ),
              child: const Text('Evacuation'),
            ),
          ],
        ),
      ],
    );
  }
}
