import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/incident_model.dart';
import '../../models/user_model.dart';
import '../../services/incident_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/roles.dart';

/// SATS Disaster — authority incident detail + triage.
///
/// Shows the full incident record and lets authority/rescue users move it
/// through the canonical triage flow:
/// reported → verified → triaged → dispatched → resolved
/// (plus reject/invalid where supported).
///
/// Status changes are recorded command statuses only — "dispatched" means
/// the dispatch was recorded, not that a team has physically arrived.
class AuthorityIncidentDetailScreen extends StatefulWidget {
  final DisasterIncidentModel incident;
  final UserModel currentUser;

  const AuthorityIncidentDetailScreen({
    super.key,
    required this.incident,
    required this.currentUser,
  });

  @override
  State<AuthorityIncidentDetailScreen> createState() =>
      _AuthorityIncidentDetailScreenState();
}

class _AuthorityIncidentDetailScreenState
    extends State<AuthorityIncidentDetailScreen> {
  final IncidentService _incidentService = IncidentService();

  bool _isUpdating = false;

  bool get _canTriage =>
      AppRoles.isAuthority(widget.currentUser.role) ||
      widget.currentUser.role == AppRoles.rescue;

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final sevColor = severityColor(incident.severity);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          incident.incidentType.isNotEmpty
              ? DisasterIncidentModel.typeLabel(incident.incidentType)
              : 'Incident',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: severity + type + status ──
              Row(
                children: [
                  StatusChip(
                    incident.severity.toUpperCase(),
                    sevColor,
                    filled: true,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      DisasterIncidentModel.typeLabel(incident.incidentType),
                      style: AppText.headline.copyWith(fontSize: 19),
                    ),
                  ),
                ],
              ),

              // ── Triage timeline (HIGH PRIORITY feature) ──
              if (_canTriage) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildTriageCard(incident),
              ],

              // ── What happened ──
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('What Happened'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.description.isEmpty
                          ? 'No description was provided by the reporter.'
                          : incident.description,
                      style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (incident.media.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.control),
                        child: Image.network(
                          incident.media.first,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 60,
                            alignment: Alignment.center,
                            color: AppColors.surfaceMuted,
                            child: Text(
                              'Photo unavailable',
                              style: AppText.caption,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Impact & requirements ──
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('People & Needs'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow(
                      'People affected',
                      '${incident.affectedPeople}',
                      bold: incident.affectedPeople > 0,
                    ),
                    if (incident.rescueRequired)
                      InfoRow(
                        'Rescue required',
                        incident.rescuePeopleCount > 0
                            ? 'Yes — ${incident.rescuePeopleCount} people'
                            : 'Yes',
                        valueColor: AppColors.danger,
                        bold: true,
                      ),
                    if (incident.medicalRequired)
                      InfoRow(
                        'Medical assistance',
                        'Required',
                        valueColor: AppColors.danger,
                        bold: true,
                      ),
                    if (incident.resourcesRequired.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: incident.resourcesRequired
                              .map(
                                (r) => StatusChip(
                                  DisasterIncidentModel.resourceLabel(r),
                                  AppColors.amber,
                                  icon: Icons.inventory_rounded,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Where ──
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Location'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow('Village', incident.village),
                    InfoRow('Mandal', incident.mandal),
                    InfoRow('District', incident.district),
                    if (incident.latitude != null &&
                        incident.longitude != null)
                      InfoRow(
                        'GPS',
                        '${incident.latitude!.toStringAsFixed(5)}, '
                        '${incident.longitude!.toStringAsFixed(5)}',
                      ),
                    if (_hasCoordinates) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Open in Maps'),
                        onPressed: _openLocation,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Report info ──
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Report Info'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow(
                      'Reported by',
                      incident.reportedByName.isNotEmpty
                          ? incident.reportedByName
                          : 'Registered user',
                    ),
                    InfoRow(
                        'Reported at', _formatTimestamp(incident.createdAt)),
                    InfoRow(
                        'Last update', _formatTimestamp(incident.updatedAt)),
                    if (incident.isDemoData) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: DemoTag(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Command-status honesty note.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        'Status changes record the command workflow only. '
                        '"Dispatched" means dispatch was recorded — it does '
                        'not confirm a team has arrived.',
                        style: AppText.metadata.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasCoordinates =>
      widget.incident.latitude != null && widget.incident.longitude != null;

  /// Shared timestamp formatting (no intl dependency — project does not
  /// bundle it).
  static String _formatTimestamp(DateTime utc) {
    final local = utc.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]}, '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openLocation() async {
    final lat = widget.incident.latitude!;
    final lng = widget.incident.longitude!;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open maps on this device')),
        );
      }
    }
  }

  Widget _buildTriageCard(DisasterIncidentModel incident) {
    final next = DisasterIncidentModel.nextTriageStatus(incident.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
        boxShadow: appCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Response Progress', style: AppText.cardTitle),
              ),
              StatusChip(
                DisasterIncidentModel.statusLabel(incident.status),
                incidentStatusColor(incident.status),
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Vertical stepper: reported → verified → triaged → dispatched → resolved
          for (int i = 0;
              i < DisasterIncidentModel.triageFlow.length;
              i++) ...[
            _TriageStep(
              label: DisasterIncidentModel.statusLabel(
                DisasterIncidentModel.triageFlow[i],
              ),
              state: _stepState(i, incident.status),
              isLast:
                  i == DisasterIncidentModel.triageFlow.length - 1,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Actions
          if (_isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else ...[
            if (next != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                      'Move to ${DisasterIncidentModel.statusLabel(next)}'),
                  onPressed: () => _changeStatus(next),
                ),
              ),
            // Rejection is offered for incidents that are still in the early
            // triage stages. The previous guard also required
            // `!needsResponse`, which is false for exactly these statuses
            // (`needsResponse == !isResolved`), so the button could never
            // render. The status allow-list below is the correct gate.
            if (incident.status == 'reported' ||
                incident.status == 'verified' ||
                incident.status == 'triaged')
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text('Mark as Invalid'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(
                          color: AppColors.outlineStrong, width: 1.2),
                    ),
                    onPressed: () => _changeStatus('rejected'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Whether step [index] is done / active / upcoming for [currentStatus].
  static _StepState _stepState(int index, String currentStatus) {
    final currentIdx =
        DisasterIncidentModel.triageFlow.indexOf(currentStatus);
    // 'rejected' is not in the flow — nothing is active.
    if (currentIdx < 0) return _StepState.upcoming;
    if (index < currentIdx) return _StepState.done;
    if (index == currentIdx) return _StepState.active;
    return _StepState.upcoming;
  }

  Future<void> _changeStatus(String newStatus) async {
    final incident = widget.incident;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.cardLarge)),
        title: Text(
            'Move to ${DisasterIncidentModel.statusLabel(newStatus)}?'),
        content: Text(
          '${DisasterIncidentModel.typeLabel(incident.incidentType)} in '
          '${incident.village}.\n\nThe reporter will see the updated status '
          'in My Reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // The screen may have been popped (system back) while the dialog was open.
    if (!mounted) return;

    setState(() => _isUpdating = true);
    try {
      await _incidentService.updateIncidentStatus(
        incident.id,
        newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Incident moved to ${DisasterIncidentModel.statusLabel(newStatus)}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Triage update failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not update the status. Check your connection and try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}

enum _StepState { done, active, upcoming }

class _TriageStep extends StatelessWidget {
  final String label;
  final _StepState state;
  final bool isLast;

  const _TriageStep({
    required this.label,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.primary,
      _StepState.upcoming => AppColors.outlineStrong,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail: dot + connector
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _StepState.upcoming
                      ? Colors.transparent
                      : color,
                  border: Border.all(color: color, width: 2),
                ),
                child: state == _StepState.done
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : state == _StepState.active
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == _StepState.done
                        ? AppColors.success
                        : AppColors.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: AppText.cardTitle.copyWith(
                    fontSize: 14,
                    color: state == _StepState.upcoming
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
