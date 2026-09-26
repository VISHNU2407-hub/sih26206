import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/damage_assessment_model.dart';
import '../../models/disaster_event_model.dart';
import '../../models/incident_model.dart';
import '../../models/resource_model.dart';
import '../../models/shelter_model.dart';
import '../../models/user_model.dart';
import '../../models/village_preparedness_model.dart';
import '../../services/dashboard_metrics.dart';
import '../../services/damage_assessment_service.dart';
import '../../services/disaster_service.dart';
import '../../services/incident_service.dart';
import '../../services/recovery_status_helper.dart';
import '../../services/resource_service.dart';
import '../../services/shelter_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/roles.dart';
import '../../widgets/profile_image_widget.dart';
import '../profile/profile_screen.dart';
import 'authority_alerts_screen.dart';
import 'authority_incident_feed_screen.dart';
import 'authority_resources_screen.dart';
import 'authority_shelters_screen.dart';
import 'damage_assessment_screen.dart';

/// SATS Disaster — Authority Disaster Command Dashboard.
///
/// Answers "what needs my attention right now?" at the top, then gives
/// live counters, command actions, recovery and village status. All data
/// flows from realtime Firestore streams — no polling, no hardcoded demo
/// records.
class DisasterDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const DisasterDashboardScreen({super.key, required this.currentUser});

  @override
  State<DisasterDashboardScreen> createState() =>
      _DisasterDashboardScreenState();
}

class _DisasterDashboardScreenState extends State<DisasterDashboardScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
  }

  Future<void> _openProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: _user!),
      ),
    );
    if (result == true && mounted) {
      // Reload user data after profile edit.
      final fresh = await Navigator.push<UserModel>(
        context,
        MaterialPageRoute(
          builder: (_) => _ReloadUser(uid: _user!.uid),
        ),
      );
      if (fresh != null && mounted) {
        setState(() => _user = fresh);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _user!;
    final incidentService = IncidentService();
    final disasterService = DisasterService();
    final shelterService = ShelterService();
    final isDistrictLevel = AppRoles.isDistrictLevel(currentUser.role);

    // Scope: village authority → own mandal feed (village filter applied in
    // the feed screen); district authority → whole district.
    final incidentsStream = isDistrictLevel
        ? incidentService.getIncidentsForDistrictStream(
            currentUser.district.isNotEmpty
                ? currentUser.district
                : currentUser.mandal,
          )
        : incidentService.getIncidentsForMandalStream(currentUser.mandal);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Disaster Command'),
            Text(
              isDistrictLevel
                  ? (currentUser.district.isNotEmpty
                      ? '${currentUser.district} District'
                      : 'District level')
                  : (currentUser.village.isNotEmpty
                      ? '${currentUser.village}, ${currentUser.mandal}'
                      : currentUser.mandal),
              style: AppText.metadata.copyWith(height: 1.1),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ProfileImageWidget(
                imageUrl: currentUser.photoUrl,
                name: currentUser.name,
                size: 34,
                showBorder: true,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl,
          ),
          children: [
            // ── A. Active disaster summary ──
            StreamBuilder<List<DisasterEventModel>>(
              stream: disasterService.getActiveDisastersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const _SummaryError();
                final events = snapshot.data ?? const <DisasterEventModel>[];
                final primary = DashboardMetrics.primaryDisaster(
                  events,
                  village: currentUser.village,
                  mandal: currentUser.mandal,
                  district: currentUser.district,
                );
                return _DisasterSummaryCard(
                  disaster: primary,
                  allEvents: events,
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── B. Live counters + attention strip ──
            StreamBuilder<List<DisasterIncidentModel>>(
              stream: incidentsStream,
              builder: (context, incidentsSnapshot) {
                if (incidentsSnapshot.hasError) {
                  return const _SummaryError();
                }
                return StreamBuilder<List<ShelterModel>>(
                  stream: isDistrictLevel
                      ? shelterService.getAllSheltersStream()
                      : shelterService.getSheltersForMandalStream(
                          currentUser.mandal),
                  builder: (context, sheltersSnapshot) {
                    if (sheltersSnapshot.hasError) {
                      return const _SummaryError();
                    }
                    final incidents = incidentsSnapshot.data ??
                        const <DisasterIncidentModel>[];
                    final shelters =
                        sheltersSnapshot.data ?? const <ShelterModel>[];

                    final activeIncidents =
                        DashboardMetrics.activeIncidents(incidents);
                    final criticalIncidents =
                        DashboardMetrics.criticalIncidents(incidents);
                    final peopleAwaitingRescue =
                        DashboardMetrics.peopleAwaitingRescue(incidents);
                    final limitedShelters = DashboardMetrics
                        .sheltersWithLimitedCapacity(shelters);
                    final availableSpaces =
                        DashboardMetrics.availableShelterSpaces(shelters);
                    final peopleAffected =
                        DashboardMetrics.peopleAffected(incidents);

                    return Column(
                      children: [
                        // Attention strip — "what needs me right now?"
                        _AttentionStrip(
                          criticalIncidents: criticalIncidents,
                          peopleAwaitingRescue: peopleAwaitingRescue,
                          onOpenFeed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AuthorityIncidentFeedScreen(
                                  currentUser: currentUser,
                                ),
                              ),
                            );
                          },
                        ),

                        // ── Stat grid ──
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            _StatCard(
                              value: activeIncidents,
                              label: 'Active Incidents',
                              icon: Icons.report_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _StatCard(
                              value: criticalIncidents,
                              label: 'Critical',
                              icon: Icons.priority_high_rounded,
                              color: AppColors.danger,
                              pulse: criticalIncidents > 0,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            _StatCard(
                              value: peopleAwaitingRescue,
                              label: 'Awaiting Rescue',
                              icon: Icons.support_rounded,
                              color: AppColors.warning,
                              pulse: peopleAwaitingRescue > 0,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _StatCard(
                              value: peopleAffected,
                              label: 'People Affected',
                              icon: Icons.groups_rounded,
                              color: AppColors.violet,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            _StatCard(
                              value: limitedShelters,
                              label: 'Shelters Limited/Full',
                              icon: Icons.night_shelter_rounded,
                              color: AppColors.amber,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _StatCard(
                              value: availableSpaces,
                              label: 'Shelter Spaces Open',
                              icon: Icons.airline_seat_recline_normal_rounded,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Command actions ──
            const SectionHeader('Command Actions'),
            _CommandActions(
              currentUser: currentUser,
              isDistrictLevel: isDistrictLevel,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Recovery & relief ──
            _RecoverySection(
              currentUser: currentUser,
              isDistrictLevel: isDistrictLevel,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Village status ──
            _VillageStatusSection(
              currentUser: currentUser,
              isDistrictLevel: isDistrictLevel,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Attention strip
// ─────────────────────────────────────────────────────────────────────────

class _AttentionStrip extends StatelessWidget {
  final int criticalIncidents;
  final int peopleAwaitingRescue;
  final VoidCallback onOpenFeed;

  const _AttentionStrip({
    required this.criticalIncidents,
    required this.peopleAwaitingRescue,
    required this.onOpenFeed,
  });

  @override
  Widget build(BuildContext context) {
    final needs = <String>[
      if (criticalIncidents > 0)
        '$criticalIncidents critical incident${criticalIncidents == 1 ? '' : 's'}',
      if (peopleAwaitingRescue > 0)
        '$peopleAwaitingRescue awaiting rescue',
    ];

    final urgent = needs.isNotEmpty;

    return InkWell(
      onTap: onOpenFeed,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: urgent ? AppColors.danger : AppColors.success,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: (urgent ? AppColors.danger : AppColors.success)
                  .withAlpha(56),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              urgent ? Icons.notification_important_rounded : Icons.task_alt_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgent ? 'Needs your attention' : 'All clear',
                    style: AppText.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    urgent
                        ? '${needs.join(' • ')} — open the incident feed'
                        : 'No critical incidents or rescues pending',
                    style: AppText.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textTertiary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Live data is temporarily unavailable. Pull to refresh or '
              'check back shortly.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Active disaster summary
// ─────────────────────────────────────────────────────────────────────────

class _DisasterSummaryCard extends StatelessWidget {
  final DisasterEventModel? disaster;
  final List<DisasterEventModel> allEvents;

  const _DisasterSummaryCard({
    required this.disaster,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context) {
    if (disaster == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(13),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.success.withAlpha(90)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active disaster',
                    style:
                        AppText.cardTitle.copyWith(color: AppColors.success),
                  ),
                  Text(
                    allEvents.isEmpty
                        ? 'Issue an alert when a warning is received.'
                        : '${allEvents.length} past event${allEvents.length == 1 ? '' : 's'} in history.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final d = disaster!;
    final color = severityColor(d.severity);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
        boxShadow: appCardShadow(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                '${DisasterEventModel.typeLabel(d.type)} — '
                '${DisasterEventModel.severityLabel(d.severity)}',
                color,
                filled: true,
              ),
              const Spacer(),
              StatusChip(
                DisasterEventModel.statusLabel(d.status),
                disasterStatusColor(d.status),
              ),
              if (d.isDemoData) ...[
                const SizedBox(width: 6),
                const DemoTag(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(d.title, style: AppText.cardTitle.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(
                d.evacuationRequired ? 'Evacuation required' : 'No evacuation',
                d.evacuationRequired ? AppColors.danger : AppColors.success,
                icon: d.evacuationRequired
                    ? Icons.directions_run_rounded
                    : Icons.shield_rounded,
              ),
              StatusChip(
                '${d.affectedVillages.length} village${d.affectedVillages.length == 1 ? '' : 's'} affected',
                AppColors.primary,
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Stat cards
// ─────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final bool pulse;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: pulse ? color.withAlpha(140) : AppColors.outline,
            width: pulse ? 1.5 : 1,
          ),
          boxShadow: appCardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: value > 0 ? color : AppColors.textTertiary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    style: AppText.metadata.copyWith(height: 1.15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Command actions
// ─────────────────────────────────────────────────────────────────────────

class _CommandActions extends StatelessWidget {
  final UserModel currentUser;
  final bool isDistrictLevel;

  const _CommandActions({
    required this.currentUser,
    required this.isDistrictLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CommandTile(
          icon: Icons.feed_rounded,
          color: AppColors.danger,
          title: 'Incident Feed & Triage',
          subtitle: 'Verify, prioritize and dispatch citizen reports',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthorityIncidentFeedScreen(
                  currentUser: currentUser,
                ),
              ),
            );
          },
        ),
        _CommandTile(
          icon: Icons.night_shelter_rounded,
          color: AppColors.primary,
          title: 'Shelter Management',
          subtitle: 'Capacity, occupancy and status updates',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthoritySheltersScreen(user: currentUser),
              ),
            );
          },
        ),
        _CommandTile(
          icon: Icons.campaign_rounded,
          color: AppColors.warning,
          title: 'Disaster Alerts',
          subtitle: 'Active alerts and the alert composer',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthorityAlertsScreen(user: currentUser),
              ),
            );
          },
        ),
        _CommandTile(
          icon: Icons.home_repair_service_rounded,
          color: AppColors.violet,
          title: 'Damage Assessments',
          subtitle: 'Record and track post-disaster damage',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DamageAssessmentScreen(user: currentUser),
              ),
            );
          },
        ),
        _CommandTile(
          icon: Icons.inventory_2_rounded,
          color: AppColors.success,
          title: 'Relief Resources',
          subtitle: 'Requirements, stock and allocation tracking',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuthorityResourcesScreen(user: currentUser),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CommandTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            IconBadge(icon, color, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.metadata),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Village status section
// ─────────────────────────────────────────────────────────────────────────

class _VillageStatusSection extends StatelessWidget {
  final UserModel currentUser;
  final bool isDistrictLevel;

  const _VillageStatusSection({
    required this.currentUser,
    required this.isDistrictLevel,
  });

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Village Preparedness'),
        if (isDistrictLevel)
          FutureBuilder<List<VillagePreparednessModel>>(
            future: service.getPreparednessForMandal(
              currentUser.mandal.isNotEmpty
                  ? currentUser.mandal
                  : currentUser.district,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const AppCard(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return _noPreparednessData();
              }
              return Column(
                children: records
                    .map((r) => _VillageStatusRow(record: r))
                    .toList(),
              );
            },
          )
        else
          StreamBuilder<List<VillagePreparednessModel>>(
            stream:
                service.getPreparednessForVillageStream(currentUser.village),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _noPreparednessData();
              final records = snapshot.data ?? const [];
              if (records.isEmpty) {
                return _noPreparednessData();
              }
              return _VillageStatusRow(record: records.first);
            },
          ),
      ],
    );
  }

  Widget _noPreparednessData() {
    return AppCard(
      child: Row(
        children: [
          const IconBadge(Icons.checklist_rounded, AppColors.textTertiary,
              size: 40, soft: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'No preparedness plans published for this area yet. '
              'Published plans will appear here.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  D2. Recovery & relief section
// ─────────────────────────────────────────────────────────────────────────

/// Compact per-village recovery overview: incidents, damage, affected
/// people, shelter occupancy, resource shortages and a derived recovery
/// status. Data comes from realtime streams — nothing hardcoded.
class _RecoverySection extends StatelessWidget {
  final UserModel currentUser;
  final bool isDistrictLevel;

  const _RecoverySection({
    required this.currentUser,
    required this.isDistrictLevel,
  });

  @override
  Widget build(BuildContext context) {
    final damageService = DamageAssessmentService();
    final resourceService = ResourceService();
    final incidentService = IncidentService();
    final shelterService = ShelterService();

    final damageStream = isDistrictLevel
        ? damageService.getAssessmentsForDistrictStream(
            currentUser.district.isNotEmpty
                ? currentUser.district
                : currentUser.mandal)
        : damageService.getAssessmentsForMandalStream(currentUser.mandal);
    final resourceStream = isDistrictLevel
        ? resourceService.getResourcesForDistrictStream(
            currentUser.district.isNotEmpty
                ? currentUser.district
                : currentUser.mandal)
        : resourceService.getResourcesForMandalStream(currentUser.mandal);
    final incidentStream = isDistrictLevel
        ? incidentService.getIncidentsForDistrictStream(
            currentUser.district.isNotEmpty
                ? currentUser.district
                : currentUser.mandal)
        : incidentService.getIncidentsForMandalStream(currentUser.mandal);
    final shelterStream = isDistrictLevel
        ? shelterService.getAllSheltersStream()
        : shelterService.getSheltersForMandalStream(currentUser.mandal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Recovery & Relief'),
        StreamBuilder<List<DamageAssessmentModel>>(
          stream: damageStream,
          builder: (context, damageSnapshot) {
            return StreamBuilder<List<ResourceModel>>(
              stream: resourceStream,
              builder: (context, resourceSnapshot) {
                return StreamBuilder<List<DisasterIncidentModel>>(
                  stream: incidentStream,
                  builder: (context, incidentSnapshot) {
                    return StreamBuilder<List<ShelterModel>>(
                      stream: shelterStream,
                      builder: (context, shelterSnapshot) {
                        final damage = damageSnapshot.data ??
                            const <DamageAssessmentModel>[];
                        final resources = resourceSnapshot.data ??
                            const <ResourceModel>[];
                        final incidents = incidentSnapshot.data ??
                            const <DisasterIncidentModel>[];
                        final shelters =
                            shelterSnapshot.data ?? const <ShelterModel>[];

                        if (damage.isEmpty &&
                            resources.isEmpty &&
                            incidents.isEmpty) {
                          return AppCard(
                            child: Row(
                              children: [
                                const IconBadge(
                                    Icons.restore_rounded,
                                    AppColors.textTertiary,
                                    size: 40,
                                    soft: true),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'No damage or relief records yet. Record '
                                    'damage and resource needs after the '
                                    'response phase.',
                                    style: AppText.caption,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Group by village.
                        final villages = <String>{
                          ...damage.map((d) => d.village),
                          ...resources.map((r) => r.village),
                          ...incidents.map((i) => i.village),
                        }.toList()
                          ..sort();

                        return Column(
                          children: villages.map((village) {
                            final vDamage = damage
                                .where((d) => d.village == village)
                                .toList();
                            final vResources = resources
                                .where((r) => r.village == village)
                                .toList();
                            final vIncidents = incidents
                                .where((i) => i.village == village)
                                .toList();
                            final vShelters = shelters
                                .where((s) => s.village == village)
                                .toList();

                            final status =
                                RecoveryStatusHelper.deriveForVillage(
                              incidents: vIncidents,
                              damage: vDamage,
                              resources: vResources,
                              shelters: vShelters,
                            );

                            return _VillageRecoveryCard(
                              village: village,
                              status: status,
                              openIncidents: vIncidents
                                  .where((i) => i.needsResponse)
                                  .length,
                              unresolvedDamage: vDamage
                                  .where((d) => !d.isResolved)
                                  .length,
                              peopleAffected: vDamage.fold(
                                  0,
                                  (sum, d) =>
                                      sum + d.estimatedAffectedPeople),
                              shelterOccupancy: vShelters.fold(
                                  0, (sum, s) => sum + s.occupancy),
                              shelterCapacity: vShelters.fold(
                                  0, (sum, s) => sum + s.capacity),
                              resourcesNeeded: vResources
                                  .where((r) =>
                                      r.shortfall > 0 && !r.isExhausted)
                                  .length,
                              resourcesAllocated: vResources
                                  .where((r) => r.allocatedQuantity > 0)
                                  .length,
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _VillageRecoveryCard extends StatelessWidget {
  final String village;
  final String status;
  final int openIncidents;
  final int unresolvedDamage;
  final int peopleAffected;
  final int shelterOccupancy;
  final int shelterCapacity;
  final int resourcesNeeded;
  final int resourcesAllocated;

  const _VillageRecoveryCard({
    required this.village,
    required this.status,
    required this.openIncidents,
    required this.unresolvedDamage,
    required this.peopleAffected,
    required this.shelterOccupancy,
    required this.shelterCapacity,
    required this.resourcesNeeded,
    required this.resourcesAllocated,
  });

  Color get _statusColor {
    switch (status) {
      case RecoveryStatusHelper.statusRestored:
        return AppColors.success;
      case RecoveryStatusHelper.statusRecovery:
        return AppColors.primary;
      case RecoveryStatusHelper.statusAffected:
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: _statusColor.withAlpha(90),
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(village,
                    style: AppText.cardTitle.copyWith(fontSize: 14.5)),
              ),
              StatusChip(
                RecoveryStatusHelper.label(status),
                _statusColor,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CapacityBar(value: RecoveryStatusHelper.progress(status)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (openIncidents > 0)
                StatusChip('$openIncidents open incidents',
                    openIncidents > 0 ? AppColors.warning : AppColors.success),
              if (unresolvedDamage > 0)
                StatusChip('$unresolvedDamage damage items',
                    AppColors.amber),
              StatusChip(
                shelterCapacity > 0
                    ? 'Shelter $shelterOccupancy/$shelterCapacity'
                    : 'No shelter data',
                AppColors.primary,
              ),
              if (resourcesNeeded > 0)
                StatusChip('$resourcesNeeded resources short',
                    AppColors.warning),
              if (resourcesAllocated > 0)
                StatusChip('$resourcesAllocated allocated',
                    AppColors.success),
              if (peopleAffected > 0)
                StatusChip('~$peopleAffected affected', AppColors.violet),
            ],
          ),
        ],
      ),
    );
  }
}

class _VillageStatusRow extends StatelessWidget {
  final VillagePreparednessModel record;

  const _VillageStatusRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final riskColor = severityColor(
      switch (record.riskLevel) {
        'severe' => 'critical',
        'high' => 'high',
        'moderate' => 'medium',
        _ => 'low',
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(record.village,
                      style: AppText.cardTitle.copyWith(fontSize: 14.5)),
                ),
                StatusChip(
                  VillagePreparednessModel.riskLabel(record.riskLevel),
                  riskColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: CapacityBar(value: record.checklistProgress),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${(record.checklistProgress * 100).toStringAsFixed(0)}% prepared',
                  style: AppText.metadata
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Hazards: ${record.hazards.isEmpty ? 'none recorded' : record.hazards.join(", ")}'
              '  •  ${record.vulnerableCount} vulnerable  •  ${record.sheltersCount} shelters',
              style: AppText.metadata,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Helper: reload user after profile edit
// ─────────────────────────────────────────────────────────────────────────

/// Transient widget that fetches the latest [UserModel] from Firestore
/// and pops it back to the caller. Used to refresh the dashboard header
/// after a profile edit without adding a stream listener.
class _ReloadUser extends FutureBuilder<UserModel?> {
  _ReloadUser({required String uid})
      : super(
          future: _fetch(uid),
          builder: (context, snapshot) {
            // Pop as soon as the future completes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.pop(context, snapshot.data);
              }
            });
            return const SizedBox.shrink();
          },
        );

  static Future<UserModel?> _fetch(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          uid,
        );
      }
    } catch (_) {}
    return null;
  }
}
