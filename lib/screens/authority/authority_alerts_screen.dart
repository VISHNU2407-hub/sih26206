import 'package:flutter/material.dart';

import '../../models/disaster_event_model.dart';
import '../../models/user_model.dart';
import '../../services/disaster_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo_match.dart';
import '../../utils/roles.dart';

/// SATS Disaster — authority alerts screen.
///
/// Lists all disaster events (active + closed history) and provides the
/// entry point to the Alert Composer for creating new disaster events.
class AuthorityAlertsScreen extends StatelessWidget {
  final UserModel user;

  const AuthorityAlertsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final disasterService = DisasterService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Disaster Alerts',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AuthorityAlertComposerScreen(user: user),
            ),
          );
          // Dashboard lists update automatically via the realtime stream.
          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Disaster alert created — affected citizens will see it in their home'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        icon: const Icon(Icons.add_alert),
        label: const Text('New Alert'),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<List<DisasterEventModel>>(
          stream: disasterService.getAllDisastersStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data!;
            // Only roles allowed to create alerts may edit/close them —
            // the same authority gate as creation.
            final canEdit = AppRoles.isAuthority(user.role);
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No disaster alerts yet',
                      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create one with the New Alert button',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _DisasterEventCard(
                  event: event,
                  canManage: AppRoles.isAuthority(user.role),
                  onEdit: canEdit
                      ? () async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AuthorityAlertComposerScreen(
                                user: user,
                                existing: event,
                              ),
                            ),
                          );
                          // List refreshes automatically via the realtime
                          // stream — no manual refresh needed.
                        }
                      : null,
                  onClose: canEdit
                      ? () => _confirmCloseAlert(context, event)
                      : null,
                  onStatusChanged: (newStatus) async {
                    final updated = event.copyWith(status: newStatus);
                    try {
                      await DisasterService()
                          .updateDisasterEvent(event.id, updated);
                    } catch (e) {
                      debugPrint('Alert status update failed: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Couldn\u2019t update the alert status. '
                                'Please try again.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
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

  /// Destructive-to-active-state lifecycle action: marks the alert closed
  /// after explicit confirmation. The document is never deleted — history
  /// is preserved and the alert simply leaves the active views.
  Future<void> _confirmCloseAlert(
    BuildContext context,
    DisasterEventModel event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        ),
        title: const Text('Close this disaster alert?'),
        content: Text(
          '"${event.title}" will be marked as closed and removed from '
          'active disaster views. The alert history is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Close Alert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final closed =
          await DisasterService().closeDisasterEvent(event.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closed
              ? '${event.title} closed'
              : 'This alert is already closed'),
          backgroundColor:
              closed ? AppColors.success : AppColors.warning,
        ),
      );
    } catch (e) {
      debugPrint('Alert close failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Couldn\u2019t close this alert. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// One disaster event row with lifecycle management.
class _DisasterEventCard extends StatelessWidget {
  final DisasterEventModel event;
  final bool canManage;
  final ValueChanged<String> onStatusChanged;

  /// Opens the shared composer pre-filled for editing. Null when the
  /// viewer may not manage alerts (citizens never receive these controls).
  final VoidCallback? onEdit;

  /// Opens the close-alert confirmation. Null when not allowed or when the
  /// alert is already closed.
  final VoidCallback? onClose;

  const _DisasterEventCard({
    required this.event,
    required this.canManage,
    required this.onStatusChanged,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(event.status);
    final severityColor = _severityColor(event.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: canManage ? () => _showLifecycleMenu(context) : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: severityColor.withOpacity(0.45)),
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
                          color: severityColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.severity.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (event.isDemoData) ...[
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
                    DisasterEventModel.typeLabel(event.type),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildScopeChip(
                        '${event.affectedVillages.length} villages',
                        Icons.location_on_outlined,
                      ),
                      if (event.evacuationRequired)
                        _buildScopeChip(
                          'Evacuation required',
                          Icons.directions_run,
                          color: AppColors.danger,
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          DisasterEventModel.statusLabel(event.status),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 8),
                    // Explicit management actions. EDIT = normal management,
                    // CLOSE = lifecycle action (confirmation-gated). There
                    // is deliberately NO delete for disaster alerts.
                    Row(
                      children: [
                        if (onEdit != null)
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded,
                                size: 15, color: AppColors.primary),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: const Size(0, 34),
                            ),
                          ),
                        const Spacer(),
                        if (onClose != null && !event.isClosed)
                          TextButton.icon(
                            onPressed: onClose,
                            icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 15,
                                color: AppColors.success),
                            label: const Text(
                              'Close Alert',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8),
                              minimumSize: const Size(0, 34),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Tap the card to change lifecycle status',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip(String label, IconData icon, {Color? color}) {
    final c = color ?? Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10.5, color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showLifecycleMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Disaster Lifecycle',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final status in const [
              'monitoring',
              'active',
              'contained',
              'closed',
            ])
              ListTile(
                leading: Icon(
                  event.status == status
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: event.status == status
                      ? AppColors.primary
                      : Colors.grey,
                ),
                title: Text(DisasterEventModel.statusLabel(status)),
                subtitle: Text(_lifecycleHint(status)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (status == event.status) return;
                  if (status == 'closed') {
                    // Lifecycle-destructive: always confirm first.
                    onClose?.call();
                  } else {
                    onStatusChanged(status);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _lifecycleHint(String status) {
    switch (status) {
      case 'monitoring':
        return 'Watching the situation — early warning issued';
      case 'active':
        return 'Disaster is impacting affected areas';
      case 'contained':
        return 'Situation under control, response winding down';
      case 'closed':
        return 'Event ended — moves to history';
      default:
        return '';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'monitoring':
        return AppColors.warning;
      case 'active':
        return AppColors.danger;
      case 'contained':
        return AppColors.primary;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Alert Composer
// ─────────────────────────────────────────────────────────────────────────

/// Authority-only form to create or edit a disaster event (alert).
///
/// One form, two modes: [existing] == null → create (with notification
/// fan-out), otherwise edit — every field pre-filled, the alert's identity
/// (document ID, createdAt, createdBy) and its derived geographic targeting
/// are preserved untouched. Geo targeting always follows the authority's
/// assigned village/mandal/district; there is no manual override.
class AuthorityAlertComposerScreen extends StatefulWidget {
  final UserModel user;

  /// Non-null → edit mode for this event; null → create mode.
  final DisasterEventModel? existing;

  const AuthorityAlertComposerScreen({
    super.key,
    required this.user,
    this.existing,
  });

  @override
  State<AuthorityAlertComposerScreen> createState() =>
      _AuthorityAlertComposerScreenState();
}

class _AuthorityAlertComposerScreenState
    extends State<AuthorityAlertComposerScreen> {
  final DisasterService _disasterService = DisasterService();
  final _formKey = GlobalKey<FormState>();

  late String _type;
  late String _severity;
  late String _status;
  late bool _evacuationRequired;

  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _instructionsController = TextEditingController();

  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  /// The authority's assigned geographic scope from their Firestore profile.
  late final String _village = widget.user.village;
  late final String _mandal = widget.user.mandal;
  late final String _district = widget.user.district;

  /// Whether the authority's profile has all three geographic fields.
  bool get _hasCompleteGeo =>
      _village.isNotEmpty && _mandal.isNotEmpty && _district.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? 'cyclone';
    _severity = existing?.severity ?? 'high';
    _status = existing?.status ?? 'active';
    _evacuationRequired = existing?.evacuationRequired ?? false;
    _titleController.text = existing?.title ?? '';
    _summaryController.text = existing?.summary ?? '';
    _instructionsController.text = existing?.instructions ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Disaster Alert' : 'Create Disaster Alert',
          style: const TextStyle(
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
              // Disaster type
              const Text('Disaster Type',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in const [
                    'cyclone',
                    'flood',
                    'fire',
                    'earthquake',
                    'landslide',
                    'infrastructure_collapse',
                    'other',
                  ])
                    ChoiceChip(
                      label: Text(DisasterEventModel.typeLabel(t)),
                      selected: _type == t,
                      selectedColor:
                          AppColors.primary.withOpacity(0.25),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Severity + lifecycle
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _severity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final s in const ['low', 'medium', 'high', 'critical'])
                          DropdownMenuItem(
                              value: s, child: Text(_severityLabels[s]!)),
                      ],
                      onChanged: (v) => setState(() => _severity = v!),
                    ),
                  ),
                  const SizedBox(width: 12),                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: _isEdit ? 'Lifecycle status' : 'Initial status',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        // Creation: monitoring/active. Edit: also offer the
                        // current status so the dropdown value always matches
                        // an item (e.g. contained / closed legacy states).
                        for (final s in const ['monitoring', 'active'])
                          DropdownMenuItem(
                              value: s, child: Text(DisasterEventModel.statusLabel(s))),
                        if (_isEdit &&
                            _status != 'monitoring' &&
                            _status != 'active')
                          DropdownMenuItem(
                              value: _status,
                              child: Text(DisasterEventModel.statusLabel(_status))),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Alert title *',
                  hintText: 'e.g. Cyclone Montha — Coastal Warning',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),

              // Summary
              TextFormField(
                controller: _summaryController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText: 'Short situation overview',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Safety instructions',
                  hintText: 'e.g. Move to the nearest shelter before 6 PM',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Target area — read-only, derived from the authority's profile.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Target Area',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _geoRow('Village', _village),
                    _geoRow('Mandal', _mandal),
                    _geoRow('District', _district),
                    const SizedBox(height: 6),
                    Text(
                      'Citizens matching all three fields will receive this alert.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Evacuation
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Evacuation required',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Citizens will see a prominent evacuation emphasis on the alert',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
                value: _evacuationRequired,
                activeColor: AppColors.danger,
                onChanged: (v) => setState(() => _evacuationRequired = v),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.campaign, size: 20),
                  label: const Text(
                    'Issue Disaster Alert',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _submitting ? null : _submit,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Targeted in-app notifications are delivered instantly to affected citizens via realtime streams.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that the authority has all three geographic fields.
    if (!_hasCompleteGeo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile is missing geographic information. '
            'Please contact your administrator to set your village, mandal, and district.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    // Alert always targets the authority's assigned 3-level area — the same
    // source shown in the read-only Target Area box. No manual override,
    // no GeoMatch changes.
    final affectedVillages = [GeoMatch.normalize(_village)];
    final affectedMandals = [GeoMatch.normalize(_mandal)];
    final affectedDistricts = [GeoMatch.normalize(_district)];

    try {
      final now = DateTime.now();
      final existing = widget.existing;
      final event = _isEdit
          ? existing!.copyWith(
              type: _type,
              severity: _severity,
              status: _status,
              title: _titleController.text.trim(),
              summary: _summaryController.text.trim(),
              instructions: _instructionsController.text.trim(),
              affectedVillages: affectedVillages,
              affectedMandals: affectedMandals,
              affectedDistricts: affectedDistricts,
              evacuationRequired: _evacuationRequired,
            )
          : DisasterEventModel(
              type: _type,
              severity: _severity,
              status: _status,
              title: _titleController.text.trim(),
              summary: _summaryController.text.trim(),
              instructions: _instructionsController.text.trim(),
              affectedVillages: affectedVillages,
              affectedMandals: affectedMandals,
              affectedDistricts: affectedDistricts,
              evacuationRequired: _evacuationRequired,
              createdBy: widget.user.uid,
              createdByName: widget.user.name,
              startedAt: now,
              createdAt: now,
              updatedAt: now,
            );

      // Same validation rules for create and edit.
      final validationError = DisasterService.validateEventUpdate(event);
      if (validationError != null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      if (_isEdit) {
        // Updates the existing document in place — the ID, createdAt and
        // creator audit fields are never sent. NO notification fan-out on
        // edit: citizens keep their original alert notification and the
        // alert content simply updates via realtime streams.
        await _disasterService.updateDisasterEvent(existing!.id, event);
        debugPrint('Disaster alert ${existing.id} updated (no fan-out).');
      } else {
        final disasterId =
            await _disasterService.createDisasterEvent(event);
        // Targeted `disaster_alert` notifications were fanned out to users
        // inside the selected scope by createDisasterEvent (failures there
        // never block the alert itself).
        debugPrint('Disaster alert $disasterId created with fan-out.');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Alert save failed: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit
              ? 'Couldn\u2019t save your changes. Check your connection '
                  'and try again.'
              : 'Couldn\u2019t create the alert. Check your connection '
                  'and try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  static Widget _geoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const Map<String, String> _severityLabels = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'critical': 'Critical',
  };
}
