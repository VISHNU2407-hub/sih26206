import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/hospital_model.dart';
import '../../models/user_model.dart';
import '../../services/hospital_service.dart';
import '../../services/location_service.dart';
import '../../services/maps_directions.dart';
import '../../theme/app_theme.dart';

/// SATS Disaster — Public Hospitals directory (migrated from the original
/// SATS app, restyled with the current design system).
///
/// Hospitals are a directory service, NOT disaster-targeted records, so no
/// GeoMatch is applied — the full public dataset is searchable, optionally
/// narrowed by district. Distances appear only when a location fix exists.
class HospitalsScreen extends StatefulWidget {
  final UserModel? user;

  const HospitalsScreen({super.key, this.user});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  // ── Data ──
  List<Hospital> _hospitals = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _locationHint;

  // ── Filters ──
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDistrict = ''; // '' = all districts

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hospitals = await HospitalService.loadAllHospitals();

      if (!mounted) return;

      if (hospitals.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'The hospital directory isn\u2019t available right now. '
              'Please try again later.';
        });
        return;
      }

      setState(() {
        _hospitals = hospitals;
        _isLoading = false;
      });

      // Best-effort distance sort — never blocks the directory from
      // showing. A permission/location failure simply keeps alphabetical
      // order with a gentle hint.
      await _trySortByDistance();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'The hospital directory isn\u2019t available right now. '
            'Please try again later.';
      });
    }
  }

  /// Attempts a GPS fix and re-sorts the (cached) hospital list nearest
  /// first. Silent on failure — distance is a convenience, not a gate.
  Future<void> _trySortByDistance() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        setState(() {
          _locationHint =
              'Enable location to see the nearest hospitals first.';
        });
        return;
      }
      final sorted = await HospitalService.getNearestHospitals(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _hospitals = sorted;
        _locationHint = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationHint = 'Enable location to see the nearest hospitals first.';
      });
    }
  }

  // ── Derived list ──

  List<Hospital> get _filteredHospitals {
    var list = HospitalService.filterByDistrict(_hospitals, _selectedDistrict);
    list = HospitalService.searchHospitals(list, _searchQuery);
    return list;
  }

  List<String> get _districtOptions => HospitalService.districtsIn(_hospitals);

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onDistrictChanged(String district) {
    setState(() => _selectedDistrict = district);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public Hospitals')),
      body: SafeArea(
        child: _isLoading
            ? const LoadingState(message: 'Loading hospitals…')
            : _errorMessage != null
                ? ErrorState(
                    message: _errorMessage!,
                    onRetry: _loadHospitals,
                  )
                : _buildDirectory(),
      ),
    );
  }

  Widget _buildDirectory() {
    return Column(
      children: [
        // ── Search + district filter (fixed at top) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name, district or address…',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _buildDistrictFilter(),
            ],
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildDistrictFilter() {
    final districts = _districtOptions;
    if (districts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: districts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final district = isAll ? '' : districts[index - 1];
          final label =
              isAll ? 'All districts' : HospitalService.formatDistrictName(district);
          final selected = _selectedDistrict == district;

          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => _onDistrictChanged(district),
            labelStyle: AppText.caption.copyWith(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceMuted,
            side: BorderSide.none,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    final results = _filteredHospitals;

    if (results.isEmpty) {
      final searching = _searchQuery.trim().isNotEmpty || _selectedDistrict.isNotEmpty;
      return EmptyState(
        icon: searching ? Icons.search_off_rounded : Icons.local_hospital_outlined,
        title: searching ? 'No hospitals found' : 'No hospitals listed yet',
        message: searching
            ? 'Try a different name, district or spelling.'
            : 'The public hospital directory is empty right now. '
                'Please try again later.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      itemCount: results.length + 1, // +1 for the header/hint row
      itemBuilder: (context, index) {
        if (index == 0) return _buildResultsHeader(results.length);
        return _HospitalCard(hospital: results[index - 1]);
      },
    );
  }

  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count hospital${count == 1 ? '' : 's'}',
            style: AppText.metadata,
          ),
          if (_locationHint != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.location_off_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_locationHint!, style: AppText.metadata),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Hospital card
// ─────────────────────────────────────────────────────────────────────────

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;

  const _HospitalCard({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final districtLabel = HospitalService.formatDistrictName(hospital.district);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _HospitalDetailScreen(hospital: hospital),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  Icons.local_hospital_rounded,
                  AppColors.primary,
                  size: 44,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospital.name,
                        style: AppText.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hospital.address.trim().isNotEmpty
                            ? '${hospital.address} • $districtLabel'
                            : districtLabel,
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hospital.distanceKm > 0) ...[
                  const SizedBox(width: 8),
                  StatusChip(
                    HospitalService.formatDistance(hospital.distanceKm),
                    AppColors.success,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                // Call Hospital — only tappable with a valid number.
                Expanded(
                  child: TextButton.icon(
                    onPressed:
                        hospital.hasPhone ? () => _callHospital(context) : null,
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call Hospital',
                        style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
                // Get Directions — only shown when coordinates exist.
                if (hospital.hasValidCoordinates)
                  TextButton.icon(
                    onPressed: () => _openDirections(context),
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text('Get Directions',
                        style: TextStyle(fontSize: 12.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dialer launch via tel: — the same mechanism the Help screen uses.
  /// A missing number never reaches here; a launch failure surfaces as a
  /// calm, human-readable message.
  Future<void> _callHospital(BuildContext context) async {
    final phone = hospital.phone.trim();
    if (phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        _showFailure(context, 'Could not start the call. Please try again.');
      }
    } catch (_) {
      if (context.mounted) {
        _showFailure(context, 'Could not start the call. Please try again.');
      }
    }
  }

  /// Directions via the shared Google Maps helper (no API key needed).
  Future<void> _openDirections(BuildContext context) async {
    final ok = await MapsDirections.openDirections(
      latitude: hospital.latitude,
      longitude: hospital.longitude,
    );
    if (!ok && context.mounted) {
      _showFailure(
        context,
        'Could not open Google Maps. Please try again.',
      );
    }
  }

  void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Hospital detail
// ─────────────────────────────────────────────────────────────────────────

class _HospitalDetailScreen extends StatelessWidget {
  final Hospital hospital;

  const _HospitalDetailScreen({required this.hospital});

  @override
  Widget build(BuildContext context) {
    final districtLabel = HospitalService.formatDistrictName(hospital.district);
    final address = hospital.address.trim();
    final hasAddress = address.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Hospital Details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // Header
            Row(
              children: [
                const IconBadge(
                  Icons.local_hospital_rounded,
                  AppColors.primary,
                  size: 52,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hospital.name, style: AppText.headline),
                      const SizedBox(height: 3),
                      Text(districtLabel, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Location
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(Icons.place_rounded, AppColors.info,
                          size: 40, soft: true),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Location', style: AppText.caption),
                            const SizedBox(height: 2),
                            Text(
                              hasAddress ? address : 'Address not available',
                              style: AppText.cardTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: hasAddress
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hospital.distanceKm > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    InfoRow(
                      'Distance',
                      '${HospitalService.formatDistance(hospital.distanceKm)} away',
                      icon: Icons.near_me_rounded,
                    ),
                  ],
                ],
              ),
            ),

            // Contact
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Contact'),
            AppCard(
              child: hospital.hasPhone
                  ? Row(
                      children: [
                        const IconBadge(Icons.call_rounded, AppColors.success,
                            size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hospital phone', style: AppText.caption),
                              const SizedBox(height: 2),
                              Text(
                                hospital.phone.trim(),
                                style: AppText.cardTitle.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const IconBadge(
                            Icons.phone_disabled_rounded, AppColors.neutral,
                            size: 40, soft: true),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'No phone number is listed for this hospital.',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
            ),

            // Actions
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: hospital.hasPhone
                    ? () => _callHospital(context)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      hospital.hasPhone ? AppColors.success : null,
                ),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Hospital'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: hospital.hasValidCoordinates
                    ? () => _openDirections(context)
                    : null,
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Get Directions'),
              ),
            ),
            if (!hospital.hasValidCoordinates) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Directions aren\u2019t available for this hospital yet.',
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

  Future<void> _callHospital(BuildContext context) async {
    final phone = hospital.phone.trim();
    if (phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        _showFailure(context);
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  Future<void> _openDirections(BuildContext context) async {
    final ok = await MapsDirections.openDirections(
      latitude: hospital.latitude,
      longitude: hospital.longitude,
    );
    if (!ok && context.mounted) {
      _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Couldn\u2019t complete this action. Please check your apps and '
            'try again.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }
}
