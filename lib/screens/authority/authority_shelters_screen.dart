import 'package:flutter/material.dart';

import '../../models/shelter_model.dart';
import '../../models/user_model.dart';
import '../../services/live_location_service.dart';
import '../../services/shelter_service.dart';
import '../../theme/app_theme.dart';

/// SATS Disaster — authority shelter management.
///
/// Authorities inspect shelters in their scope and update the management
/// fields: capacity, occupancy and status (plus amenities/supplies/contact).
/// Validation prevents occupancy > capacity before any write is attempted.
///
/// Citizen shelter views use the same Firestore documents via realtime
/// streams, so updates are reflected there immediately — no polling.
class AuthoritySheltersScreen extends StatefulWidget {
  final UserModel user;

  const AuthoritySheltersScreen({super.key, required this.user});

  @override
  State<AuthoritySheltersScreen> createState() =>
      _AuthoritySheltersScreenState();
}

class _AuthoritySheltersScreenState extends State<AuthoritySheltersScreen> {
  final ShelterService _shelterService = ShelterService();

  @override
  Widget build(BuildContext context) {
    final isDistrictLevel = widget.user.role == 'district_authority' ||
        widget.user.role == 'admin';

    final sheltersStream = isDistrictLevel
        ? _shelterService.getAllSheltersStream()
        : _shelterService.getSheltersForMandalStream(widget.user.mandal);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shelter Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreator(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create Shelter',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ShelterModel>>(
          stream: sheltersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ErrorState(
                message: 'Something went wrong while loading shelters. '
                    'Please try again.',
              );
            }
            if (!snapshot.hasData) {
              return const LoadingState(message: 'Loading shelters…');
            }

            final shelters = snapshot.data!;
            if (shelters.isEmpty) {
              return EmptyState(
                icon: Icons.night_shelter_outlined,
                title: 'No shelters in your scope yet',
                message: 'Register shelters before an evacuation so citizens '
                    'can find them. Shelters appear in the citizen app '
                    'instantly after you create one.',
                action: ElevatedButton.icon(
                  onPressed: () => _openCreator(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create Shelter'),
                ),
              );
            }

            // Summary strip: open / limited+full / closed.
            final open = shelters.where((s) => s.status == 'active').length;
            final constrained =
                shelters.where((s) => s.status == 'full').length;
            final closed = shelters.where((s) => s.status == 'closed').length;
            final spaces = shelters.fold<int>(
                0, (sum, s) => sum + (s.availableSpace > 0 ? s.availableSpace : 0));

            return Column(
              children: [
                // Scope summary
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: appCardShadow(),
                  ),
                  child: Row(
                    children: [
                      _summaryFigure('$open', 'Open', AppColors.success),
                      _summaryDivider(),
                      _summaryFigure(
                          '$constrained', 'Full', AppColors.danger),
                      _summaryDivider(),
                      _summaryFigure('$closed', 'Closed', AppColors.neutral),
                      _summaryDivider(),
                      _summaryFigure(
                          '$spaces', 'Spaces free', AppColors.primary),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: shelters.length,
                    itemBuilder: (context, index) => _ShelterManagementCard(
                      shelter: shelters[index],
                      openFullEdit: (cardContext) =>
                          _openForm(shelters[index]),
                      onDelete: (cardContext) =>
                          _confirmDelete(shelters[index]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _summaryFigure(
      String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          Text(label, style: AppText.metadata),
        ],
      ),
    );
  }

  static Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 26,
      color: AppColors.outline,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  void _openCreator() {
    _openForm();
  }

  void _openForm([ShelterModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShelterFormSheet(user: widget.user, existing: existing),
    );
  }

  /// Destructive-action confirmation. Deletion only happens after an
  /// explicit second tap inside this dialog.
  Future<void> _confirmDelete(ShelterModel shelter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        ),
        title: const Text('Delete shelter?'),
        content: Text(
          '"${shelter.name}" will be removed from the active shelter '
          'list. Citizens will no longer see this shelter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Shelter'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _shelterService.deleteShelter(shelter.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${shelter.name} deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Shelter delete failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Couldn\u2019t delete this shelter. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

class _ShelterManagementCard extends StatelessWidget {
  final ShelterModel shelter;

  /// Opens the shared full form pre-filled for editing. Injected by the
  /// parent screen which owns the sheet + service wiring.
  final void Function(BuildContext context) openFullEdit;

  /// Opens the delete confirmation. Injected by the parent screen.
  final void Function(BuildContext context) onDelete;

  const _ShelterManagementCard({
    required this.shelter,
    required this.openFullEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(shelter.status);
    final percent = shelter.occupancyPercent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          // Tapping the card opens the same full edit form.
          onTap: () => openFullEdit(context),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.outline),
              boxShadow: appCardShadow(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBadge(
                        Icons.home_work_rounded,
                        statusColor,
                        size: 40,
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
                            Text(
                              '${shelter.village} • ${shelter.mandal}',
                              style: AppText.metadata,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        ShelterModel.statusLabel(shelter.status),
                        statusColor,
                        filled: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Occupancy bar
                  if (percent != null) ...[
                    CapacityBar(
                      value: percent / 100,
                      height: 8,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${shelter.occupancy} / ${shelter.capacity}'
                          '  •  ${shelter.availableSpace} available',
                          style: AppText.cardTitle.copyWith(fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Full-form edit (all fields, location included).
                      TextButton.icon(
                        onPressed: () => openFullEdit(context),
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.primary),
                        label: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                      // Destructive — always behind a confirmation dialog.
                      TextButton.icon(
                        onPressed: () => onDelete(context),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.danger),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'full':
        return AppColors.danger;
      case 'closed':
        return AppColors.neutral;
      default:
        return AppColors.neutral;
    }
  }
}
// ─────────────────────────────────────────────────────────────────────────
//  Shelter create / edit form
//
//  One form, two modes: [existing] == null → create, otherwise edit with
//  every field pre-filled. Keeps a single source of truth for shelter
//  validation and the location capture UX.
// ─────────────────────────────────────────────────────────────────────────

class _ShelterFormSheet extends StatefulWidget {
  final UserModel user;

  /// Non-null → edit mode for this shelter; null → create mode.
  final ShelterModel? existing;

  const _ShelterFormSheet({required this.user, this.existing});

  @override
  State<_ShelterFormSheet> createState() => _ShelterFormSheetState();
}

class _ShelterFormSheetState extends State<_ShelterFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _villageController;
  late final TextEditingController _mandalController;
  late final TextEditingController _districtController;
  late final TextEditingController _locationTextController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _capacityController;
  late final TextEditingController _occupancyController;
  late final TextEditingController _contactController;
  late final TextEditingController _amenitiesController;
  late final TextEditingController _suppliesController;
  late String _status;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  final LiveLocationService _locationService = LiveLocationService();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _villageController = TextEditingController(
        text: existing?.village ?? widget.user.village);
    _mandalController =
        TextEditingController(text: existing?.mandal ?? widget.user.mandal);
    _districtController = TextEditingController(
        text: existing?.district ?? widget.user.district);
    _locationTextController =
        TextEditingController(text: existing?.locationText ?? '');
    _latitudeController = TextEditingController(
        text: existing?.latitude?.toStringAsFixed(6) ?? '');
    _longitudeController = TextEditingController(
        text: existing?.longitude?.toStringAsFixed(6) ?? '');
    _capacityController =
        TextEditingController(text: existing == null ? '' : '${existing.capacity}');
    _occupancyController =
        TextEditingController(text: existing == null ? '0' : '${existing.occupancy}');
    _contactController =
        TextEditingController(text: existing?.contactPhone ?? '');
    _amenitiesController = TextEditingController(
        text: existing?.amenities.join(', ') ?? '');
    _suppliesController =
        TextEditingController(text: existing?.supplies.join(', ') ?? '');
    _status = existing?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villageController.dispose();
    _mandalController.dispose();
    _districtController.dispose();
    _locationTextController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _capacityController.dispose();
    _occupancyController.dispose();
    _contactController.dispose();
    _amenitiesController.dispose();
    _suppliesController.dispose();
    super.dispose();
  }

  List<String> _splitList(String text) {
    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Fills the coordinate fields from the device GPS. Reuses the existing
  /// [LiveLocationService] — no new location infrastructure. Coordinates
  /// are optional; failure is a calm inline message, never a blocker.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await _locationService.getCurrentLocation(
        allowPermissionRequest: true,
        allowOpenSettings: false,
      );
      if (!mounted) return;
      if (position == null) {
        setState(() {
          _locating = false;
          _error = 'Could not get your location. You can type the '
              'coordinates manually instead.';
        });
        return;
      }
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = 'Could not get your location. You can type the '
            'coordinates manually instead.';
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final village = _villageController.text.trim();
    final mandal = _mandalController.text.trim();
    final district = _districtController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim());
    final occupancy = int.tryParse(_occupancyController.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Shelter name is required');
      return;
    }
    if (village.isEmpty) {
      setState(() => _error = 'Village is required');
      return;
    }
    if (mandal.isEmpty) {
      setState(() => _error = 'Mandal is required');
      return;
    }

    final capError = ShelterService.validateCapacity(
      capacity: capacity,
      occupancy: occupancy,
    );
    if (capError != null) {
      setState(() => _error = capError);
      return;
    }

    // Location block: text is required, coordinates optional but must be
    // valid pairs in range when provided. Same rules for create and edit.
    final locationText = _locationTextController.text.trim();
    if (locationText.isEmpty) {
      setState(() => _error = 'Location / address is required');
      return;
    }
    final latitude = double.tryParse(
        _latitudeController.text.trim().replaceAll(',', '.'));
    final longitude = double.tryParse(
        _longitudeController.text.trim().replaceAll(',', '.'));
    final locError = ShelterService.validateShelterUpdate(
      name: name,
      village: village,
      mandal: mandal,
      capacity: capacity,
      occupancy: occupancy,
      locationText: locationText,
      latitude: latitude,
      longitude: longitude,
    );
    if (locError != null) {
      setState(() => _error = locError);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      if (_isEdit) {
        await ShelterService().updateShelter(
          shelterId: widget.existing!.id,
          name: name,
          village: village,
          mandal: mandal,
          district: district,
          capacity: capacity!,
          occupancy: occupancy!,
          status: _status,
          locationText: locationText,
          latitude: latitude,
          longitude: longitude,
          amenities: _splitList(_amenitiesController.text),
          supplies: _splitList(_suppliesController.text),
          contactPhone: _contactController.text.trim(),
        );
      } else {
        await ShelterService().createShelter(
          name: name,
          village: village,
          mandal: mandal,
          district: district,
          capacity: capacity!,
          occupancy: occupancy!,
          status: _status,
          locationText: locationText,
          latitude: latitude,
          longitude: longitude,
          amenities: _splitList(_amenitiesController.text),
          supplies: _splitList(_suppliesController.text),
          contactPhone: _contactController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? '$name updated'
              : '$name created'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Shelter save failed: $e');
      if (!mounted) return;
      setState(() {
        _error = _isEdit
            ? 'Could not save the changes. Check your connection and try again.'
            : 'Could not create the shelter. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit Shelter' : 'Create Shelter',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Shelter name *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _villageController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Village *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mandalController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Mandal *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _districtController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'District',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── Shelter Location ──
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text(
                  'Shelter Location',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationTextController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location / Address *',
                hintText: 'e.g. Government High School, Mukkamala',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g. 16.8161',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g. 82.1221',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Optional coordinates helper — authorities can skip GPS and
            // type values, or tap to capture where they are standing.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 17),
                label: Text(
                  _locating ? 'Finding your location…' : 'Use Current Location',
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Status selector
            const Text(
              'Status',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'active',
                    label: Text('Active'),
                    icon: Icon(Icons.check_circle_outline, size: 16)),
                ButtonSegment(
                    value: 'full',
                    label: Text('Full'),
                    icon: Icon(Icons.warning_amber_outlined, size: 16)),
                ButtonSegment(
                    value: 'closed',
                    label: Text('Closed'),
                    icon: Icon(Icons.block, size: 16)),
              ],
              selected: {_status},
              onSelectionChanged: (selection) =>
                  setState(() => _status = selection.first),
            ),
            const SizedBox(height: 16),
            // Capacity + occupancy
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _occupancyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Occupancy',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amenitiesController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Amenities (comma-separated)',
                hintText: 'e.g. Drinking water, First aid, Generator',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _suppliesController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Supplies (comma-separated)',
                hintText: 'e.g. Blankets, Rice bags, Ors tablets',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isEdit ? Icons.save_outlined : Icons.add, size: 18),
                label: Text(_isEdit ? 'Save Changes' : 'Create Shelter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
