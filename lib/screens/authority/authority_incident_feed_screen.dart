import 'package:flutter/material.dart';

import '../../models/incident_model.dart';
import '../../models/user_model.dart';
import '../../services/dashboard_metrics.dart';
import '../../services/incident_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/roles.dart';
import 'authority_incident_detail_screen.dart';

/// SATS Disaster — live authority incident feed.
///
/// Realtime stream of citizen-reported incidents within the authority's
/// scope, with severity/status filters and quick triage actions. This is
/// the "Receive → Inspect → Triage → Dispatch" workbench.
class AuthorityIncidentFeedScreen extends StatefulWidget {
  final UserModel currentUser;

  const AuthorityIncidentFeedScreen({super.key, required this.currentUser});

  @override
  State<AuthorityIncidentFeedScreen> createState() =>
      _AuthorityIncidentFeedScreenState();
}

class _AuthorityIncidentFeedScreenState
    extends State<AuthorityIncidentFeedScreen> {
  final IncidentService _incidentService = IncidentService();

  /// 'all' | 'critical' | 'high' | 'medium' | 'low'
  String _severityFilter = 'all';

  /// 'all' | any status value
  String _statusFilter = 'all';

  bool get _isDistrictLevel =>
      AppRoles.isDistrictLevel(widget.currentUser.role);

  Stream<List<DisasterIncidentModel>> get _incidentStream => _isDistrictLevel
      ? _incidentService.getIncidentsForDistrictStream(
          widget.currentUser.district.isNotEmpty
              ? widget.currentUser.district
              : widget.currentUser.mandal,
        )
      : _incidentService.getIncidentsForMandalStream(widget.currentUser.mandal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Incidents — '
          '${_isDistrictLevel ? widget.currentUser.district : widget.currentUser.mandal}',
          style: AppText.screenTitle.copyWith(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<DisasterIncidentModel>>(
                stream: _incidentStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ErrorState(
                      message:
                          'Something went wrong while loading incidents. '
                          'Please try again shortly.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LoadingState(
                        message: 'Loading live incident feed…');
                  }

                  final incidents = _applyFilters(snapshot.data!);
                  final ordered =
                      DashboardMetrics.sortForAuthorityFeed(incidents);

                  if (ordered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      // Realtime stream — nothing to refresh manually.
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: ordered.length,
                      itemBuilder: (context, index) => _IncidentFeedCard(
                        incident: ordered[index],
                        onTap: () => _openDetail(ordered[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DisasterIncidentModel> _applyFilters(
    List<DisasterIncidentModel> incidents,
  ) {
    return incidents.where((i) {
      final matchesSeverity = _severityFilter == 'all' ||
          i.severity == _severityFilter;
      final matchesStatus =
          _statusFilter == 'all' || i.status == _statusFilter;
      return matchesSeverity && matchesStatus;
    }).toList();
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  value: 'all',
                  selected: _severityFilter,
                  onSelected: (v) => setState(() => _severityFilter = v),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Critical',
                  value: 'critical',
                  selected: _severityFilter,
                  color: AppColors.danger,
                  onSelected: (v) => setState(() => _severityFilter = v),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'High',
                  value: 'high',
                  selected: _severityFilter,
                  color: AppColors.warning,
                  onSelected: (v) => setState(() => _severityFilter = v),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Medium',
                  value: 'medium',
                  selected: _severityFilter,
                  color: AppColors.amber,
                  onSelected: (v) => setState(() => _severityFilter = v),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Low',
                  value: 'low',
                  selected: _severityFilter,
                  color: AppColors.success,
                  onSelected: (v) => setState(() => _severityFilter = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Status filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Any status',
                value: 'all',
                selected: _statusFilter,
                onSelected: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(width: 6),
              for (final status in const [
                'reported',
                'verified',
                'triaged',
                'dispatched',
                'resolved',
                'rejected',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildFilterChip(
                    label: DisasterIncidentModel.statusLabel(status),
                    value: status,
                    selected: _statusFilter,
                    color: incidentStatusColor(status),
                    onSelected: (v) => setState(() => _statusFilter = v),
                  ),
                ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String selected,
    Color? color,
    required ValueChanged<String> onSelected,
  }) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? Colors.white : (color ?? AppColors.textSecondary),
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? AppColors.primary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : (color ?? AppColors.textTertiary).withAlpha(70),
      ),
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _buildEmptyState() {
    final filtered = _severityFilter != 'all' || _statusFilter != 'all';
    return EmptyState(
      icon: filtered ? Icons.filter_alt_off_outlined : Icons.inbox_rounded,
      title: filtered ? 'Nothing matches these filters' : 'No incidents yet',
      message: filtered
          ? 'Try clearing a filter — citizen reports appear here the moment '
              'they are submitted.'
          : 'Citizen reports appear here in realtime. When someone reports '
              'a disaster incident, it lands in this feed for triage.',
    );
  }

  void _openDetail(DisasterIncidentModel incident) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthorityIncidentDetailScreen(
          incident: incident,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }
}

/// One incident row in the authority feed.
/// Shared timestamp formatting (project does not bundle `intl`).
String _formatTimestamp(DateTime utc) {
  final local = utc.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${local.day} ${months[local.month - 1]}, '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _IncidentFeedCard extends StatelessWidget {
  final DisasterIncidentModel incident;
  final VoidCallback onTap;

  const _IncidentFeedCard({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final severityColorValue = severityColor(incident.severity);
    final time = _formatTimestamp(incident.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: incident.needsResponse
                    ? severityColorValue.withAlpha(120)
                    : AppColors.outline,
                width: incident.severity == 'critical' && incident.needsResponse
                    ? 1.6
                    : 1,
              ),
              boxShadow: appCardShadow(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: severity badge + type + status
                  Row(
                    children: [
                      StatusChip(
                        incident.severity.toUpperCase(),
                        severityColorValue,
                        filled: true,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DisasterIncidentModel.typeLabel(
                            incident.incidentType,
                          ),
                          style: AppText.cardTitle.copyWith(fontSize: 14.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusChip(
                        DisasterIncidentModel.statusLabel(incident.status),
                        incidentStatusColor(incident.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  // Description
                  Text(
                    incident.description.isEmpty
                        ? '(no description)'
                        : incident.description,
                    style: AppText.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  // Meta + flags + time row
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          incident.village,
                          style: AppText.metadata,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (incident.rescueRequired) ...[
                        const Icon(Icons.support_rounded,
                            size: 14, color: AppColors.danger),
                        const SizedBox(width: 3),
                        Text(
                          'Rescue${incident.rescuePeopleCount > 0 ? ' (${incident.rescuePeopleCount})' : ''}',
                          style: AppText.metadata.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (incident.medicalRequired) ...[
                        const Icon(Icons.medical_services_outlined,
                            size: 14, color: AppColors.danger),
                        const SizedBox(width: 3),
                        Text(
                          'Medical',
                          style: AppText.metadata.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        time,
                        style: AppText.metadata,
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
}
