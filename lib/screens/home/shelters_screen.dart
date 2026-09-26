import 'package:flutter/material.dart';

import '../../models/shelter_model.dart';
import '../../models/user_model.dart';
import '../../services/disaster_service.dart';
import '../../services/maps_directions.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo_match.dart';

/// SATS Disaster — shelters for the citizen's area.
///
/// Strict 3-level geographic matching is unchanged: a shelter is visible
/// ONLY if village AND mandal AND district all match the user's profile.
/// Availability = stored Firestore data (capacity − occupancy).
class SheltersScreen extends StatelessWidget {
  final UserModel user;

  const SheltersScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final service = DisasterService();
    final hasVillage = user.village.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Shelters')),
      body: SafeArea(
        child: StreamBuilder<List<ShelterModel>>(
          stream: hasVillage
              ? service.getSheltersForVillageStream(user.village)
              : service.getSheltersForMandalStream(user.mandal),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LoadingState(message: 'Finding shelters near you…');
            }
            if (snapshot.hasError) {
              return const ErrorState(
                message: 'Something went wrong while loading shelters. '
                    'Please try again.',
              );
            }

            // Strict 3-level geographic matching (unchanged).
            final shelters = (snapshot.data ?? const <ShelterModel>[])
                .where((s) => GeoMatch.matches3Level(
                      itemVillage: s.village,
                      itemMandal: s.mandal,
                      itemDistrict: s.district,
                      userVillage: user.village,
                      userMandal: user.mandal,
                      userDistrict: user.district,
                    ))
                .toList();
            if (shelters.isEmpty) {
              return EmptyState(
                icon: Icons.night_shelter_rounded,
                title: 'No shelters registered yet',
                message: hasVillage
                    ? 'Your authority hasn\u2019t registered shelters for '
                        '${user.village} yet. They publish shelters here '
                        'before any evacuation.'
                    : 'Complete your profile with your village to see '
                        'shelters near you.',
              );
            }

            // Open shelters with space first, then partial, then full/closed.
            final sorted = [...shelters]..sort((a, b) {
                int rank(ShelterModel s) {
                  if (s.status == 'closed') return 3;
                  if (!s.hasSpace) return 2;
                  if (s.occupancyPercent != null &&
                      s.occupancyPercent! >= 80) {
                    return 1;
                  }
                  return 0;
                }
                final byRank = rank(a).compareTo(rank(b));
                if (byRank != 0) return byRank;
                return b.availableSpace.compareTo(a.availableSpace);
              });

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: sorted.length,
                itemBuilder: (context, index) =>
                    _ShelterCard(shelter: sorted[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Shelter card
// ─────────────────────────────────────────────────────────────────────────

class _ShelterCard extends StatelessWidget {
  final ShelterModel shelter;

  const _ShelterCard({required this.shelter});

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(shelter);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ShelterDetailScreen(shelter: shelter),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  Icons.home_work_rounded,
                  status.color,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shelter.name,
                        style: AppText.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shelter.locationDisplay,
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Show the geographic area only when a specific
                      // address already occupies the first line.
                      if (shelter.locationText != null &&
                          shelter.locationText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${shelter.village} • ${shelter.mandal}',
                          style: AppText.metadata,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status.label, status.color, filled: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Capacity
            CapacityBar(
              value: shelter.capacity > 0
                  ? shelter.occupancy / shelter.capacity
                  : 0,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    shelter.availableSpace > 0
                        ? '${shelter.availableSpace} spaces available'
                        : (shelter.status == 'closed'
                            ? 'Currently closed'
                            : 'No space available'),
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: status.color,
                    ),
                  ),
                ),
                if (shelter.isDemoData) const DemoTag(),
              ],
            ),

            // Facilities
            if (shelter.amenities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 2),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 6,
                children: shelter.amenities
                    .take(4)
                    .map(
                      (a) => StatusChip(a, AppColors.primary,
                          icon: Icons.check_rounded),
                    )
                    .toList(),
              ),
            ],

            // Compact directions shortcut — the full action lives on the
            // detail screen. Hidden entirely when no coordinates exist.
            if (shelter.hasLocation) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openDirections(context),
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text(
                    'Get Directions',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    final ok = await MapsDirections.openDirections(
      latitude: shelter.latitude,
      longitude: shelter.longitude,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open Google Maps. Please try again or use the '
              'shelter address.'),
        ),
      );
    }
  }

  _StatusInfo _statusInfo(ShelterModel shelter) {
    if (shelter.status == 'closed') {
      return const _StatusInfo('CLOSED', AppColors.neutral);
    }
    if (!shelter.hasSpace) {
      return const _StatusInfo('FULL', AppColors.danger);
    }
    final pct = shelter.occupancyPercent ?? 0;
    if (pct >= 80) {
      return const _StatusInfo('LIMITED', AppColors.amber);
    }
    return const _StatusInfo('OPEN', AppColors.success);
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}

// ─────────────────────────────────────────────────────────────────────────
//  Shelter detail
// ─────────────────────────────────────────────────────────────────────────

class _ShelterDetailScreen extends StatelessWidget {
  final ShelterModel shelter;

  const _ShelterDetailScreen({required this.shelter});

  /// Opens Google Maps turn-by-turn directions to the shelter coordinates
  /// via the shared helper. Missing coordinates and launch failures both
  /// surface as calm, human-readable messages.
  Future<void> _openDirections(BuildContext context) async {
    if (!shelter.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Directions aren\u2019t available for this shelter yet. '
              'Use the address shown above.'),
        ),
      );
      return;
    }
    final ok = await MapsDirections.openDirections(
      latitude: shelter.latitude,
      longitude: shelter.longitude,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open Google Maps. Please try again or use the '
              'shelter address.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = shelterStatusColor(
      shelter.status,
      hasSpace: shelter.hasSpace,
      occupancyPercent: shelter.occupancyPercent,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Shelter Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // Header
            Row(
              children: [
                IconBadge(Icons.home_work_rounded, statusColor, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shelter.name, style: AppText.headline),
                      const SizedBox(height: 3),
                      if (shelter.locationText != null &&
                          shelter.locationText!.trim().isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shelter.locationText!,
                                style: AppText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        '${shelter.village}, ${shelter.mandal}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (shelter.isDemoData) ...[
              const SizedBox(height: AppSpacing.sm),
              const Align(
                alignment: Alignment.centerLeft,
                child: DemoTag(),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Occupancy summary
            AppCard(
              borderColor: statusColor.withAlpha(90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shelter.availableSpace > 0
                              ? '${shelter.availableSpace} spaces available'
                              : (shelter.status == 'closed'
                                  ? 'Currently closed'
                                  : 'No space available'),
                          style: AppText.cardTitle
                              .copyWith(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CapacityBar(
                    value: shelter.capacity > 0
                        ? shelter.occupancy / shelter.capacity
                        : 0,
                    height: 9,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _figure('${shelter.capacity}', 'Capacity'),
                      _figure('${shelter.occupancy}', 'Occupied'),
                      _figure(
                        '${shelter.availableSpace}',
                        'Available',
                        highlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Facilities
            if (shelter.amenities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Facilities'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: shelter.amenities
                    .map(
                      (a) => StatusChip(a, AppColors.primary,
                          icon: Icons.check_rounded),
                    )
                    .toList(),
              ),
            ],

            // Supplies
            if (shelter.supplies.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Supplies'),
              AppCard(
                child: Text(
                  shelter.supplies.join(' • '),
                  style: AppText.body
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],

            // Contact
            if (shelter.contactPhone.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Contact'),
              AppCard(
                child: Row(
                  children: [
                    const IconBadge(Icons.call_rounded, AppColors.success,
                        size: 40),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shelter helpline',
                              style: AppText.caption),
                          const SizedBox(height: 2),
                          Text(
                            shelter.contactPhone,
                            style: AppText.cardTitle.copyWith(
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    shelter.hasLocation ? () => _openDirections(context) : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      shelter.hasLocation ? AppColors.primary : null,
                ),
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Get Directions'),
              ),
            ),
            if (!shelter.hasLocation) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Directions aren\u2019t available for this shelter yet.',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _figure(String value, String label, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.success : AppColors.textPrimary,
            ),
          ),
          Text(label, style: AppText.metadata),
        ],
      ),
    );
  }
}
