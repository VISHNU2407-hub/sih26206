import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/damage_assessment_model.dart';
import '../../models/disaster_event_model.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/damage_assessment_service.dart';
import '../../services/disaster_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import 'damage_assessment_detail_screen.dart';

/// SATS Disaster — Phase 5: authority damage assessment hub.
///
/// Lists all damage assessments for the authority's scope with severity
/// filters and provides the composer entry point. Realtime Firestore stream.
class DamageAssessmentScreen extends StatefulWidget {
  final UserModel user;

  const DamageAssessmentScreen({super.key, required this.user});

  @override
  State<DamageAssessmentScreen> createState() => _DamageAssessmentScreenState();
}

class _DamageAssessmentScreenState extends State<DamageAssessmentScreen> {
  final DamageAssessmentService _service = DamageAssessmentService();
  Stream<List<DamageAssessmentModel>> _stream = const Stream.empty();
  String _filter = 'all';

  static const List<(String, String)> _filters = [
    ('all', 'All'),
    ('serious', 'Critical/High'),
    ('medium', 'Medium'),
    ('low', 'Low'),
    ('recovered', 'Recovered'),
  ];

  List<DamageAssessmentModel> _applyFilter(
      List<DamageAssessmentModel> items) {
    switch (_filter) {
      case 'serious':
        return items
            .where((d) => !d.isResolved && (d.severity == 'critical' || d.severity == 'high'))
            .toList();
      case 'medium':
        return items.where((d) => d.severity == 'medium').toList();
      case 'low':
        return items.where((d) => d.severity == 'low').toList();
      case 'recovered':
        return items.where((d) => d.isResolved).toList();
      default:
        return items;
    }
  }

  @override
  void initState() {
    super.initState();
    // Bound once in initState (not inside build) so tapping a filter chip does
    // not tear down and re-issue the Firestore query on every rebuild.
    _stream = _buildStream();
  }

  Stream<List<DamageAssessmentModel>> _buildStream() {
    final isDistrictLevel = widget.user.district.isNotEmpty &&
        (widget.user.role == 'district_authority' ||
            widget.user.role == 'admin');

    return isDistrictLevel
        ? _service.getAssessmentsForDistrictStream(widget.user.district)
        : _service.getAssessmentsForMandalStream(widget.user.mandal);
  }

  /// Re-issues the Firestore subscription (used by the error-state retry).
  void _reload() {
    setState(() => _stream = _buildStream());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Damage Assessments',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DamageAssessmentComposerScreen(user: widget.user),
            ),
          );
          // List updates automatically via the realtime stream.
        },
        icon: const Icon(Icons.post_add),
        label: const Text('Record Damage'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filters ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (key, label) in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == key,
                          selectedColor:
                              AppColors.primary.withOpacity(0.25),
                          onSelected: (_) => setState(() => _filter = key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ── List ──
            Expanded(
              child: StreamBuilder<List<DamageAssessmentModel>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorState(
                      message:
                          'Damage records could not be loaded. Check your '
                          'connection and pull down to try again.',
                      onRetry: _reload,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LoadingState(
                        message: 'Loading damage records\u2026');
                  }

                  final items = DamageAssessmentService.sortForAuthorityList(
                    _applyFilter(snapshot.data!),
                  );

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fact_check_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'all'
                                ? 'No damage recorded yet'
                                : 'Nothing matches this filter',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Record damage with the button below',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _DamageCard(
                        item: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DamageAssessmentDetailScreen(
                                item: item,
                                currentUser: widget.user,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DamageCard extends StatelessWidget {
  final DamageAssessmentModel item;
  final VoidCallback onTap;

  const _DamageCard({required this.item, required this.onTap});

  Color get _severityColor {
    switch (item.severity) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _severityColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DamageAssessmentModel.severityLabel(item.severity),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DamageAssessmentModel.typeLabel(item.damageType),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isDemoData) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DEMO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.village}'
                    '${item.estimatedAffectedPeople > 0 ? ' • ~${item.estimatedAffectedPeople} people affected' : ''}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: _statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      DamageAssessmentModel.statusLabel(item.status),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (item.status) {
      case 'reported':
        return AppColors.warning;
      case 'verified':
        return AppColors.primary;
      case 'assessed':
        return AppColors.violet;
      case 'recovered':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Composer
// ─────────────────────────────────────────────────────────────────────────

/// Authority-only form to record post-disaster damage for a village.
class DamageAssessmentComposerScreen extends StatefulWidget {
  final UserModel user;

  const DamageAssessmentComposerScreen({super.key, required this.user});

  @override
  State<DamageAssessmentComposerScreen> createState() =>
      _DamageAssessmentComposerScreenState();
}

class _DamageAssessmentComposerScreenState
    extends State<DamageAssessmentComposerScreen> {
  final DamageAssessmentService _service = DamageAssessmentService();
  final DisasterService _disasterService = DisasterService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final _formKey = GlobalKey<FormState>();

  final _villageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _affectedController = TextEditingController();

  String _damageType = DamageAssessmentModel.typeHouse;
  String _severity = 'medium';
  String? _disasterId;
  double? _latitude;
  double? _longitude;
  bool _capturingLocation = false;
  File? _photo;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-seed the Village field from the user's profile. The controller owns
    // the text; passing both controller and initialValue would trip the
    // TextFormField assertion.
    _villageController.text = widget.user.village;
  }

  @override
  void dispose() {
    _villageController.dispose();
    _descriptionController.dispose();
    _affectedController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _capturingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location unavailable — check permissions')),
        );
      } else {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _cloudinaryService.pickImageFromCamera();
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (_) {
      try {
        final photo = await _cloudinaryService.pickImageFromGallery();
        if (photo != null && mounted) setState(() => _photo = photo);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not pick photo: $e')),
          );
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      String? photoUrl;
      if (_photo != null) {
        setState(() => _uploading = true);
        photoUrl = await _cloudinaryService.uploadImage(_photo!);
      }

      final now = DateTime.now();
      final assessment = DamageAssessmentModel(
        disasterId: _disasterId,
        reportedBy: widget.user.uid,
        reportedByName: widget.user.name,
        district: widget.user.district,
        mandal: widget.user.mandal,
        village: _villageController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        damageType: _damageType,
        severity: _severity,
        description: _descriptionController.text.trim(),
        estimatedAffectedPeople:
            int.tryParse(_affectedController.text.trim()) ?? 0,
        photoUrl: photoUrl,
        status: 'reported',
        updatedBy: widget.user.uid,
        createdAt: now,
        updatedAt: now,
      );

      await _service.createAssessment(assessment);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Damage assessment recorded'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not record damage: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Record Damage Assessment',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Linked disaster (optional)
              StreamBuilder<List<DisasterEventModel>>(
                stream: _disasterService.getActiveDisastersStream(),
                builder: (context, snapshot) {
                  final events =
                      (snapshot.data ?? const <DisasterEventModel>[])
                          .where((e) => e.isActive)
                          .toList();
                  return DropdownButtonFormField<String>(
                    value: _disasterId,
                    decoration: const InputDecoration(
                      labelText: 'Linked disaster (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('— Not linked —')),
                      for (final e in events)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(
                            '${DisasterEventModel.typeLabel(e.type)} — ${e.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _disasterId = v),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Village
              TextFormField(
                controller: _villageController,
                decoration: InputDecoration(
                  labelText: 'Village *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: widget.user.village.isNotEmpty
                      ? widget.user.village
                      : 'Village name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Village is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Damage type
              const Text('Damage Type',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in DamageAssessmentModel.damageTypes)
                    ChoiceChip(
                      label: Text(DamageAssessmentModel.typeLabel(t)),
                      selected: _damageType == t,
                      selectedColor:
                          AppColors.danger.withOpacity(0.2),
                      onSelected: (_) => setState(() => _damageType = t),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Severity
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final s in DamageAssessmentModel.severities)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                          DamageAssessmentModel.severityLabel(s)),
                    ),
                ],
                onChanged: (v) => setState(() => _severity = v!),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What was damaged, extent, access situation…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Affected people
              TextFormField(
                controller: _affectedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated people affected',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Location
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _latitude != null
                            ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                            : 'GPS location (optional)',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey[700]),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _capturingLocation ? null : _captureLocation,
                      icon: _capturingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 16),
                      label: const Text('Capture'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Photo
              Row(
                children: [
                  if (_photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_photo!,
                          width: 72, height: 72, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(Icons.add_a_photo,
                          color: Colors.grey.shade500),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Damage photo (optional) — uploaded to Cloudinary on submit',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _pickPhoto,
                    child: Text(_photo == null ? 'Add' : 'Change'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: _submitting || _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.post_add, size: 20),
                  label: Text(
                    _uploading ? 'Uploading photo…' : 'Record Damage',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
