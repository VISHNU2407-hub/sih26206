import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/disaster_event_model.dart';
import '../../models/incident_model.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/disaster_service.dart';
import '../../services/incident_draft_service.dart';
import '../../services/incident_service.dart';
import '../../services/live_location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import 'my_incidents_screen.dart';

/// SATS Disaster — citizen disaster incident report.
///
/// Feels like: "I need help → tell the app what happened → send location →
/// done." Essentials (type, severity, description, location) come first;
/// everything optional lives under "Add details". Draft autosave, photo
/// upload and submission logic are unchanged.
class ReportIncidentScreen extends StatefulWidget {
  final UserModel user;

  const ReportIncidentScreen({super.key, required this.user});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final IncidentService _incidentService = IncidentService();
  final DisasterService _disasterService = DisasterService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final LiveLocationService _locationService = LiveLocationService();
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _incidentType = DisasterIncidentModel.typeFlood;
  String _severity = 'medium';
  int _affectedPeople = 0;
  bool _rescueRequired = false;
  int _rescuePeopleCount = 0;
  bool _medicalRequired = false;
  final Set<String> _resourcesRequired = {};

  // NOTE: _resourcesRequired is mutated via clear/add, never reassigned.

  File? _photoFile;
  bool _isUploadingPhoto = false;

  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  String? _locationError;

  DisasterEventModel? _activeDisaster;
  bool _isLoadingContext = true;
  bool _isSubmitting = false;
  bool _draftRestored = false;

  /// Optional section visibility (progressive disclosure).
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    // 1. Resolve the active disaster for the user's area (auto-association).
    DisasterEventModel? disaster;
    try {
      disaster = await _disasterService.getPrimaryDisasterForAreaStream(
        village: widget.user.village,
        mandal: widget.user.mandal,
        district: widget.user.district,
      ).first;
    } catch (_) {
      disaster = null;
    }

    // 2. Capture GPS immediately (do not wait for user action).
    await _captureLocation();

    // 3. Restore draft if one exists.
    final draft = await IncidentDraftService.loadDraft();
    if (draft != null && mounted) {
      setState(() {
        _incidentType = (draft['incidentType'] ?? _incidentType).toString();
        _severity = (draft['severity'] ?? _severity).toString();
        _descriptionController.text = (draft['description'] ?? '').toString();
        _affectedPeople = (draft['affectedPeople'] as num?)?.toInt() ?? 0;
        _rescueRequired = draft['rescueRequired'] == true;
        _rescuePeopleCount =
            (draft['rescuePeopleCount'] as num?)?.toInt() ?? 0;
        _medicalRequired = draft['medicalRequired'] == true;
        _resourcesRequired
          ..clear()
          ..addAll(((draft['resourcesRequired'] as List?) ?? const [])
              .map((e) => e.toString()));
        final lat = (draft['latitude'] as num?)?.toDouble();
        final lng = (draft['longitude'] as num?)?.toDouble();
        if (_latitude == null && lat != null && lng != null) {
          _latitude = lat;
          _longitude = lng;
        }
        final photoPath = draft['photoPath']?.toString();
        if (photoPath != null && File(photoPath).existsSync()) {
          _photoFile = File(photoPath);
        }

        // Restore optional section state when the draft has detail data.
        _showDetails = _draftHasDetails(draft);
        _draftRestored = _descriptionController.text.trim().isNotEmpty;
      });
    }

    if (mounted) {
      setState(() {
        _activeDisaster = disaster;
        _isLoadingContext = false;
      });
    }
  }

  bool _draftHasDetails(Map<String, dynamic> draft) {
    final affected = (draft['affectedPeople'] as num?)?.toInt() ?? 0;
    final resources = ((draft['resourcesRequired'] as List?) ?? const []);
    return draft['rescueRequired'] == true ||
        draft['medicalRequired'] == true ||
        affected > 0 ||
        resources.isNotEmpty;
  }

  Future<void> _captureLocation() async {
    if (_latitude != null && _longitude != null) return;
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final position = await _locationService.getCurrentLocation(
        allowPermissionRequest: true,
        allowOpenSettings: false,
      );
      if (mounted) {
        setState(() {
          _latitude = position?.latitude;
          _longitude = position?.longitude;
          _isLocating = false;
          if (position == null) {
            _locationError =
                'Location unavailable. The report will still reach your '
                'village authority via your profile address.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationError = 'Location unavailable. The report will still '
              'reach your village authority via your profile address.';
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    await IncidentDraftService.saveDraft(
      IncidentDraftService.formToDraft(
        incidentType: _incidentType,
        severity: _severity,
        description: _descriptionController.text,
        affectedPeople: _affectedPeople,
        rescueRequired: _rescueRequired,
        rescuePeopleCount: _rescuePeopleCount,
        medicalRequired: _medicalRequired,
        resourcesRequired: _resourcesRequired.toList(),
        photoPath: _photoFile?.path,
        latitude: _latitude,
        longitude: _longitude,
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      setState(() {
        _photoFile = File(picked.path);
      });
      await _saveDraft();
    } catch (e) {
      debugPrint('Photo pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the camera. Please try again.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload photo (optional, never blocks the report on failure).
      List<String> media = const [];
      if (_photoFile != null) {
        setState(() {
          _isUploadingPhoto = true;
        });
        try {
          final url = await _cloudinaryService.uploadImage(_photoFile!);
          if (url.isNotEmpty) media = [url];
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Photo upload failed — submitting the report without the photo.'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      }

      final incidentId = await _incidentService.reportIncident(
        incidentType: _incidentType,
        severity: _severity,
        description: _descriptionController.text.trim(),
        village: widget.user.village,
        mandal: widget.user.mandal,
        district: widget.user.district,
        latitude: _latitude,
        longitude: _longitude,
        disasterId: _activeDisaster?.id,
        affectedPeople: _affectedPeople,
        rescueRequired: _rescueRequired,
        rescuePeopleCount: _rescuePeopleCount,
        medicalRequired: _medicalRequired,
        resourcesRequired: _resourcesRequired.toList(),
        media: media,
      );

      // Submission succeeded — clear the draft.
      await IncidentDraftService.clearDraft();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _SubmissionConfirmationDialog(
          incidentId: incidentId,
          village: widget.user.village,
          severity: _severity,
          submittedAt: DateTime.now(),
          incidentType: _incidentType,
        ),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MyIncidentsScreen(user: widget.user),
          ),
        );
      }
    } catch (e) {
      debugPrint('Incident submit failed: $e');
      // Keep the draft — the citizen can retry when connectivity returns.
      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not submit right now. Your report has been saved as a '
              'draft on this device — reopen this screen and try again.',
            ),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        actions: [
          IconButton(
            tooltip: 'My Reports',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyIncidentsScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),

      // Strong bottom action — always reachable and safe-area padded. The
      // button keeps the existing _submit logic, loading state and
      // duplicate-submission guard unchanged.
      bottomNavigationBar: _isLoadingContext
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen, AppSpacing.md, AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_isSubmitting || _isUploadingPhoto)
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.danger.withAlpha(120),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 19),
                          label: Text(
                            _isSubmitting
                                ? 'Sending your report…'
                                : 'Submit Incident',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your report goes to your village and mandal '
                        'authorities',
                        style: AppText.metadata,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: _isLoadingContext
            ? const LoadingState(message: 'Preparing the report form…')
            : Form(
                key: _formKey,
                onChanged: _saveDraft,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen, AppSpacing.md, AppSpacing.screen,
                    AppSpacing.xxl,
                  ),
                  children: [
                    // Subtitle under the screen title
                    Text(
                      'Help us respond faster. Your report can save lives.',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (_draftRestored) _draftRestoredBanner(),

                    // ── 1. What is happening? ──
                    const _NumberedSection(
                        number: 1, title: 'What is happening?'),
                    const SizedBox(height: AppSpacing.sm + 2),
                    LayoutBuilder(builder: (context, constraints) {
                      final count = constraints.maxWidth >= 480 ? 3 : 2;
                      final cardWidth =
                          (constraints.maxWidth - (count - 1) * AppSpacing.sm) /
                              count;
                      return Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: DisasterIncidentModel.incidentTypes
                            .map((type) => SizedBox(
                                  width: cardWidth,
                                  height: 84,
                                  child: _IncidentTypeCard(
                                    label:
                                        DisasterIncidentModel.typeLabel(type),
                                    icon: _typeIcon(type),
                                    selected: _incidentType == type,
                                    onTap: () {
                                      setState(() => _incidentType = type);
                                      _saveDraft();
                                    },
                                  ),
                                ))
                            .toList(),
                      );
                    }),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 2. How serious is it? ──
                    const _NumberedSection(
                        number: 2, title: 'How serious is it?'),
                    const SizedBox(height: AppSpacing.sm + 2),
                    Row(
                      children: DisasterIncidentModel.severities
                          .map((s) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s ==
                                            DisasterIncidentModel
                                                .severities.last
                                        ? 0
                                        : AppSpacing.sm,
                                  ),
                                  child: _SeverityOption(
                                    label: DisasterIncidentModel.severityLabel(
                                        s),
                                    color: severityColor(s),
                                    selected: _severity == s,
                                    onTap: () {
                                      setState(() => _severity = s);
                                      _saveDraft();
                                    },
                                  ),
                                ),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 3. Describe what you see ──
                    const _NumberedSection(
                        number: 3, title: 'Describe what you see'),
                    Text(
                      'Provide as much detail as possible',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. Water entering houses near the temple street',
                        alignLabelWithHint: true,
                        counterStyle: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      maxLines: 5,
                      maxLength: 1000,
                      validator: (value) =>
                          AppHelpers.validateRequired(value, 'Description'),
                      textInputAction: TextInputAction.newline,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 4. Where is it? ──
                    const _NumberedSection(number: 4, title: 'Where is it?'),
                    const SizedBox(height: AppSpacing.sm + 2),
                    _locationCard(),

                    const SizedBox(height: AppSpacing.xl),

                    // ── 5. Add evidence (optional, progressive disclosure) ──
                    const _NumberedSection(
                        number: 5, title: 'Add evidence (if applicable)'),
                    const SizedBox(height: AppSpacing.sm + 2),
                    _DetailsDisclosure(
                      expanded: _showDetails,
                      hasContent: _detailsHaveContent,
                      onToggle: () =>
                          setState(() => _showDetails = !_showDetails),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // People affected
                          TextFormField(
                            initialValue:
                                _affectedPeople > 0 ? '$_affectedPeople' : '',
                            decoration: const InputDecoration(
                              labelText: 'Number of people affected',
                              hintText: 'Leave empty if unknown',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final parsed = int.tryParse(value.trim());
                              _affectedPeople = (parsed == null || parsed < 0)
                                  ? 0
                                  : parsed;
                              _saveDraft();
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Rescue / medical
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('People need to be rescued',
                                style: AppText.body),
                            subtitle: Text(
                                'Trapped or unable to reach safety on their own',
                                style: AppText.metadata),
                            value: _rescueRequired,
                            activeThumbColor: AppColors.danger,
                            onChanged: (value) {
                              setState(() => _rescueRequired = value);
                              _saveDraft();
                            },
                          ),
                          if (_rescueRequired)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.md),
                              child: TextFormField(
                                initialValue: _rescuePeopleCount > 0
                                    ? '$_rescuePeopleCount'
                                    : '',
                                decoration: const InputDecoration(
                                  labelText: 'How many people need rescue?',
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final parsed = int.tryParse(value.trim());
                                  _rescuePeopleCount =
                                      (parsed == null || parsed < 0)
                                          ? 0
                                          : parsed;
                                  _saveDraft();
                                },
                              ),
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Medical assistance required',
                                style: AppText.body),
                            value: _medicalRequired,
                            activeThumbColor: AppColors.danger,
                            onChanged: (value) {
                              setState(() => _medicalRequired = value);
                              _saveDraft();
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Resources
                          Text('Supplies needed (optional)',
                              style: AppText.caption
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children:
                                DisasterIncidentModel.commonResources
                                    .map((resource) => FilterChip(
                                          label: Text(
                                            DisasterIncidentModel.resourceLabel(
                                                resource),
                                          ),
                                          selected: _resourcesRequired
                                              .contains(resource),
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _resourcesRequired.add(
                                                    resource);
                                              } else {
                                                _resourcesRequired.remove(
                                                    resource);
                                              }
                                            });
                                            _saveDraft();
                                          },
                                        ))
                                    .toList(),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Photo
                          _photoCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  bool get _detailsHaveContent =>
      _affectedPeople > 0 ||
      _rescueRequired ||
      _medicalRequired ||
      _resourcesRequired.isNotEmpty ||
      _photoFile != null;


  Widget _draftRestoredBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.amber.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_edu_rounded,
              color: AppColors.warning, size: 22),
          const SizedBox(width: AppSpacing.sm + 2),
          const Expanded(
            child: Text(
              'Unfinished report restored from this device.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () async {
              await IncidentDraftService.clearDraft();
              if (mounted) {
                setState(() {
                  _draftRestored = false;
                  _descriptionController.clear();
                  _affectedPeople = 0;
                  _rescueRequired = false;
                  _rescuePeopleCount = 0;
                  _medicalRequired = false;
                  _resourcesRequired.clear();
                  _photoFile = null;
                });
              }
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: _latitude != null
              ? AppColors.success.withAlpha(90)
              : AppColors.outlineStrong,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _latitude != null
                ? Icons.location_on_rounded
                : Icons.location_searching_rounded,
            size: 20,
            color: _latitude != null
                ? AppColors.success
                : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLocating
                      ? 'Finding your location…'
                      : _latitude != null
                          ? 'Location attached automatically'
                          : (_locationError ?? 'Location unavailable'),
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _latitude != null
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.user.village.isNotEmpty ? widget.user.village : 'Village'}'
                  ' • ${widget.user.mandal.isNotEmpty ? widget.user.mandal : 'Mandal'}'
                  ' • ${widget.user.district.isNotEmpty ? widget.user.district : 'District'}',
                  style: AppText.metadata,
                ),
              ],
            ),
          ),
          if (_isLocating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_latitude == null)
            TextButton(
              onPressed: _captureLocation,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.outlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm + 2),
              Text('Photo (optional)', style: AppText.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (_photoFile != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Image.file(
                    _photoFile!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    onPressed: () {
                      setState(() => _photoFile = null);
                      _saveDraft();
                    },
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Take a photo of the situation'),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Severity selector option
// ─────────────────────────────────────────────────────────────────────────

class _SeverityOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SeverityOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: selected ? color : AppColors.outlineStrong,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Numbered section header (visual hierarchy only — single scrollable form)
// ─────────────────────────────────────────────────────────────────────────

class _NumberedSection extends StatelessWidget {
  final int number;
  final String title;

  const _NumberedSection({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(title, style: AppText.sectionTitle),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Incident type selection card
// ─────────────────────────────────────────────────────────────────────────

class _IncidentTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IncidentTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.danger.withAlpha(16)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
          border: Border.all(
            color: selected ? AppColors.danger : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppColors.danger : AppColors.textSecondary,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Icon per incident type — purely presentational.
// ─────────────────────────────────────────────────────────────────────────

IconData _typeIcon(String type) {
  switch (type) {
    case DisasterIncidentModel.typeFlood:
      return Icons.water_rounded;
    case DisasterIncidentModel.typeCyclone:
      return Icons.cyclone_rounded;
    case DisasterIncidentModel.typeFire:
      return Icons.local_fire_department_rounded;
    case DisasterIncidentModel.typeEarthquake:
      return Icons.vibration_rounded;
    case DisasterIncidentModel.typeLandslide:
      return Icons.landscape_rounded;
    case DisasterIncidentModel.typeInfrastructure:
      return Icons.home_repair_service_rounded;
    case DisasterIncidentModel.typePersonTrapped:
      return Icons.support_rounded;
    case DisasterIncidentModel.typeMedical:
      return Icons.medical_services_rounded;
    case DisasterIncidentModel.typeMissingPerson:
      return Icons.person_search_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Progressive disclosure container
// ─────────────────────────────────────────────────────────────────────────

class _DetailsDisclosure extends StatelessWidget {
  final bool expanded;
  final bool hasContent;
  final VoidCallback onToggle;
  final Widget child;

  const _DetailsDisclosure({
    required this.expanded,
    required this.hasContent,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: hasContent
              ? AppColors.primary.withAlpha(90)
              : AppColors.outline,
        ),
        boxShadow: appCardShadow(),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color:
                        hasContent ? AppColors.primary : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      'Photos, people affected & rescue needs',
                      style: AppText.cardTitle.copyWith(
                        fontSize: 14,
                        color: hasContent
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasContent)
                    StatusChip('Added', AppColors.primary),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Submission confirmation
// ─────────────────────────────────────────────────────────────────────────

class _SubmissionConfirmationDialog extends StatelessWidget {
  final String incidentId;
  final String village;
  final String severity;
  final DateTime submittedAt;
  final String incidentType;

  const _SubmissionConfirmationDialog({
    required this.incidentId,
    required this.village,
    required this.severity,
    required this.submittedAt,
    required this.incidentType,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLarge)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 72),
          const SizedBox(height: AppSpacing.md),
          Text('Report sent', style: AppText.headline.copyWith(fontSize: 20)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your ${DisasterIncidentModel.typeLabel(incidentType).toLowerCase()} '
            'report has reached your village and mandal authorities. '
            'Track its status in My Reports.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Column(
              children: [
                InfoRow('Area', village),
                InfoRow('Severity', DisasterIncidentModel.severityLabel(severity)),
                InfoRow(
                  'Submitted',
                  '${submittedAt.hour.toString().padLeft(2, "0")}:'
                  '${submittedAt.minute.toString().padLeft(2, "0")}',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('View My Reports'),
          ),
        ),
      ],
    );
  }
}
