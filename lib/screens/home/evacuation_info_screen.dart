import 'package:flutter/material.dart';

import '../../models/disaster_event_model.dart';
import '../../models/user_model.dart';
import '../../models/village_preparedness_model.dart';
import '../../services/disaster_service.dart';
import '../../theme/app_theme.dart';
import 'shelters_screen.dart';

/// SATS Disaster — evacuation information for the citizen's village.
///
/// Combines the active disaster (evacuation requirement) with the village
/// preparedness record (routes). If no route information exists, the screen
/// clearly says so instead of inventing one.
class EvacuationInfoScreen extends StatelessWidget {
  final UserModel user;

  const EvacuationInfoScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();

    return Scaffold(
      appBar: AppBar(title: const Text('Evacuation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // ── Evacuation requirement (from active disaster) ──
            StreamBuilder<DisasterEventModel?>(
              stream: service.getPrimaryDisasterForAreaStream(
                village: user.village,
                mandal: user.mandal,
                district: user.district,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const AppCard(
                    child: Text(
                      'Live disaster information is temporarily unavailable. '
                      'Check back shortly.',
                      style: AppText.caption,
                    ),
                  );
                }
                final disaster = snapshot.data;
                final required = disaster?.evacuationRequired ?? false;

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: required
                        ? AppColors.danger.withAlpha(16)
                        : AppColors.success.withAlpha(16),
                    borderRadius: BorderRadius.circular(AppRadius.cardLarge),
                    border: Border.all(
                      color: required
                          ? AppColors.danger.withAlpha(120)
                          : AppColors.success.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            required
                                ? Icons.directions_run_rounded
                                : Icons.shield_rounded,
                            color: required
                                ? AppColors.danger
                                : AppColors.success,
                            size: 30,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              required
                                  ? 'Evacuation required'
                                  : 'No evacuation ordered',
                              style: AppText.headline.copyWith(
                                fontSize: 19,
                                color: required
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            ),
                          ),
                          if (disaster?.isDemoData == true) const DemoTag(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        disaster == null
                            ? 'There is no active disaster for '
                                '${user.village.isNotEmpty ? user.village : 'your village'}. '
                                'Review your routes below so you\u2019re ready '
                                'if that changes.'
                            : (required
                                ? 'Authorities have ordered evacuation for '
                                    '${disaster.affectedVillages.isNotEmpty ? disaster.affectedVillages.join(", ") : 'the affected area'}. '
                                    'Move to your nearest shelter.'
                                : disaster.instructions.isNotEmpty
                                    ? disaster.instructions
                                    : 'No evacuation ordered for the current '
                                        '${DisasterEventModel.typeLabel(disaster.type)} warning.'),
                        style: AppText.body,
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Routes (from preparedness) ──
            const SectionHeader('Evacuation Routes'),
            StreamBuilder<List<VillagePreparednessModel>>(
              stream: service.getPreparednessForVillageStream(user.village),
              builder: (context, snapshot) {
                final record =
                    (snapshot.data != null && snapshot.data!.isNotEmpty)
                        ? snapshot.data!.first
                        : null;
                final routes = record?.evacuationRoutes ?? const [];

                if (routes.isEmpty) {
                  return AppCard(
                    child: Row(
                      children: [
                        const IconBadge(Icons.route_rounded,
                            AppColors.textTertiary,
                            size: 40, soft: true),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'No evacuation routes published for '
                            '${user.village.isNotEmpty ? user.village : 'your village'} '
                            'yet. Contact your village office for the current '
                            'evacuation plan.',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: routes
                      .map((route) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const IconBadge(Icons.route_rounded,
                                      AppColors.primary,
                                      size: 40),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      route,
                                      style: AppText.body.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Nearest shelter ──
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SheltersScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(Icons.night_shelter_rounded),
                label: const Text('View Nearest Shelters'),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Emergency contacts ──
            const SectionHeader('Emergency Contacts'),
            StreamBuilder<List<VillagePreparednessModel>>(
              stream: service.getPreparednessForVillageStream(user.village),
              builder: (context, snapshot) {
                final record =
                    (snapshot.data != null && snapshot.data!.isNotEmpty)
                        ? snapshot.data!.first
                        : null;
                final contacts =
                    record?.emergencyContacts ?? const <Map<String, dynamic>>[];

                if (contacts.isEmpty) {
                  return AppCard(
                    child: Text(
                      'Village contacts not published yet. In an emergency '
                      'call 112.',
                      style: AppText.caption,
                    ),
                  );
                }

                return AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
                  child: Column(
                    children: contacts
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.contact_phone_rounded,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.sm + 2),
                                  Expanded(
                                    child: Text(
                                      '${c['name'] ?? 'Contact'}',
                                      style: AppText.body
                                          .copyWith(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    '${c['phone'] ?? '—'}',
                                    style: AppText.cardTitle
                                        .copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
