import 'package:flutter/material.dart';

import '../../models/damage_assessment_model.dart';
import '../../models/resource_model.dart';
import '../../models/shelter_model.dart';
import '../../models/user_model.dart';
import '../../services/damage_assessment_service.dart';
import '../../services/recovery_status_helper.dart';
import '../../services/resource_service.dart';
import '../../services/shelter_service.dart';
import '../../theme/app_theme.dart';

/// SATS Disaster — citizen recovery & relief view.
///
/// Public, read-only information about the village's recovery status,
/// shelter availability and relief availability. Shows NO reporter
/// personal details and NO authority-only figures. Answers in plain
/// language: "Is my village recovering? What's available?"
class CitizenRecoveryScreen extends StatelessWidget {
  final UserModel user;

  const CitizenRecoveryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final damageService = DamageAssessmentService();
    final resourceService = ResourceService();
    final shelterService = ShelterService();

    return Scaffold(
      appBar: AppBar(title: const Text('Village Recovery')),
      body: SafeArea(
        child: StreamBuilder<List<DamageAssessmentModel>>(
          stream: user.village.isNotEmpty
              ? damageService.getAssessmentsForVillageStream(user.village)
              : damageService.getAssessmentsForMandalStream(user.mandal),
          builder: (context, damageSnapshot) {
            return StreamBuilder<List<ResourceModel>>(
              stream: user.village.isNotEmpty
                  ? resourceService.getResourcesForVillageStream(user.village)
                  : resourceService.getResourcesForMandalStream(user.mandal),
              builder: (context, resourceSnapshot) {
                return StreamBuilder<List<ShelterModel>>(
                  stream: shelterService.getAllSheltersStream(),
                  builder: (context, shelterSnapshot) {
                    if (damageSnapshot.hasError ||
                        resourceSnapshot.hasError ||
                        shelterSnapshot.hasError) {
                      return const ErrorState();
                    }

                    final damage = damageSnapshot.data ??
                        const <DamageAssessmentModel>[];
                    final resources =
                        resourceSnapshot.data ?? const <ResourceModel>[];
                    final allShelters =
                        shelterSnapshot.data ?? const <ShelterModel>[];
                    final villageShelters = user.village.isNotEmpty
                        ? allShelters
                            .where((s) => s.village == user.village)
                            .toList()
                        : allShelters;

                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      children: [
                        _RecoveryStatusCard(
                          village: user.village.isNotEmpty
                              ? user.village
                              : user.mandal,
                          damage: damage,
                          resources: resources,
                          shelters: villageShelters,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Shelter status ──
                        const SectionHeader('Shelter Status'),
                        if (villageShelters.isEmpty)
                          _EmptyNote(
                            'No shelters registered for this area yet. '
                            'Your authority will publish them here.',
                          )
                        else
                          ...villageShelters.map(
                            (s) => _ShelterRow(shelter: s),
                          ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Relief availability ──
                        const SectionHeader('What\u2019s Available'),
                        if (resources.isEmpty)
                          _EmptyNote(
                            'No relief information published for this area '
                            'yet. Distributions will appear here once '
                            'announced.',
                          )
                        else
                          ...resources.map(
                            (r) => _ReliefRow(resource: r),
                          ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Recovery progress (public damage items only) ──
                        const SectionHeader('Recovery Work'),
                        if (damage.isEmpty)
                          _EmptyNote(
                            'No recovery work recorded for this area yet. '
                            'Repairs appear here as authorities complete '
                            'assessments.',
                          )
                        else
                          ...damage.map(
                            (d) => _RecoveryItemRow(item: d),
                          ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Guidance ──
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  IconBadge(Icons.tips_and_updates_rounded,
                                      AppColors.primary,
                                      size: 38),
                                  SizedBox(width: AppSpacing.md),
                                  Text('What you can do',
                                      style: AppText.cardTitle),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                '• Follow village authority announcements for '
                                'relief distribution times and places.\n'
                                '• Report new damage to your village authority '
                                'so it can be assessed and repaired.\n'
                                '• Water and food distributions are announced '
                                'at the shelter / panchayat notice board.\n'
                                '• In an emergency call 112.',
                                style: AppText.body,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Widgets
// ─────────────────────────────────────────────────────────────────────────

class _RecoveryStatusCard extends StatelessWidget {
  final String village;
  final List<DamageAssessmentModel> damage;
  final List<ResourceModel> resources;
  final List<ShelterModel> shelters;

  const _RecoveryStatusCard({
    required this.village,
    required this.damage,
    required this.resources,
    required this.shelters,
  });

  @override
  Widget build(BuildContext context) {
    final status = RecoveryStatusHelper.deriveForVillage(
      incidents: const [],
      damage: damage,
      resources: resources,
      shelters: shelters,
    );

    final color = switch (status) {
      RecoveryStatusHelper.statusRestored => AppColors.success,
      RecoveryStatusHelper.statusRecovery => AppColors.primary,
      _ => AppColors.warning,
    };

    // Human headline per status.
    final headline = switch (status) {
      RecoveryStatusHelper.statusRestored =>
        '$village has recovered',
      RecoveryStatusHelper.statusRecovery =>
        '$village is recovering',
      _ => '$village is recovering from impact',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: color.withAlpha(110), width: 1.5),
        boxShadow: appCardShadow(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restart_alt_rounded, color: color, size: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  headline,
                  style: AppText.headline.copyWith(color: color, fontSize: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Based on recorded damage and relief information',
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          CapacityBar(value: RecoveryStatusHelper.progress(status), height: 9),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 20, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppText.caption)),
        ],
      ),
    );
  }
}

/// Public shelter occupancy row (no caretaker contact details).
class _ShelterRow extends StatelessWidget {
  final ShelterModel shelter;

  const _ShelterRow({required this.shelter});

  @override
  Widget build(BuildContext context) {
    final full = !shelter.hasSpace;
    final color = shelter.status == 'closed'
        ? AppColors.neutral
        : full
            ? AppColors.danger
            : AppColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            IconBadge(Icons.night_shelter_rounded, color, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shelter.name,
                    style: AppText.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${shelter.occupancy} of ${shelter.capacity} spaces used'
                    '${shelter.availableSpace > 0 ? ' • ${shelter.availableSpace} free' : ''}',
                    style: AppText.metadata,
                  ),
                ],
              ),
            ),
            StatusChip(
              ShelterModel.statusLabel(shelter.status),
              color,
            ),
          ],
        ),
      ),
    );
  }
}

/// Public relief availability row (needs + what is on the ground).
class _ReliefRow extends StatelessWidget {
  final ResourceModel resource;

  const _ReliefRow({required this.resource});

  @override
  Widget build(BuildContext context) {
    final covered = resource.isCovered;
    final color = resource.isExhausted
        ? AppColors.danger
        : covered
            ? AppColors.success
            : AppColors.warning;

    final statusLabel = resource.isExhausted
        ? 'Out of stock'
        : covered
            ? 'Sufficient'
            : 'Running low';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            IconBadge(
              resource.isExhausted
                  ? Icons.report_problem_rounded
                  : covered
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_bottom_rounded,
              color,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ResourceModel.resourceLabel(resource.resourceType),
                    style: AppText.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resource.requiredQuantity > 0
                        ? '${resource.quantity} of ${resource.requiredQuantity} '
                            '${resource.unit} at the distribution point'
                        : '${resource.quantity} ${resource.unit} available',
                    style: AppText.metadata,
                  ),
                ],
              ),
            ),
            StatusChip(statusLabel, color),
          ],
        ),
      ),
    );
  }
}

/// Public recovery progress row — administrative state of recorded damage.
/// Deliberately omits reporter identity and GPS coordinates.
class _RecoveryItemRow extends StatelessWidget {
  final DamageAssessmentModel item;

  const _RecoveryItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final done = item.isResolved;
    final color = done ? AppColors.success : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Row(
          children: [
            IconBadge(
              done ? Icons.task_alt_rounded : Icons.construction_rounded,
              color,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DamageAssessmentModel.typeLabel(item.damageType)} — ${item.village}',
                    style: AppText.cardTitle.copyWith(fontSize: 14),
                  ),
                  if (item.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.metadata,
                      ),
                    ),
                ],
              ),
            ),
            StatusChip(
              DamageAssessmentModel.statusLabel(item.status),
              color,
            ),
          ],
        ),
      ),
    );
  }
}
