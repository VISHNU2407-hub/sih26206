import 'package:flutter/material.dart';

import '../../models/incident_model.dart';
import '../../models/user_model.dart';
import '../../services/incident_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';

/// SATS Disaster — "My Reports": the citizen's submitted disaster incidents
/// with their current triage status (reported → verified → triaged →
/// dispatched → resolved/invalid).
class MyIncidentsScreen extends StatelessWidget {
  final UserModel user;

  const MyIncidentsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final service = IncidentService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: SafeArea(
        child: StreamBuilder<List<DisasterIncidentModel>>(
          stream: service.getIncidentsByReporterStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LoadingState(message: 'Loading your reports…');
            }
            if (snapshot.hasError) {
              return const ErrorState(
                message: 'Something went wrong while loading your reports. '
                    'Please try again.',
              );
            }

            final incidents = snapshot.data ?? const <DisasterIncidentModel>[];
            if (incidents.isEmpty) {
              return EmptyState(
                icon: Icons.fact_check_rounded,
                title: 'No reports yet',
                message:
                    'Disaster incidents you report appear here with their '
                    'response status — from Reported through Resolved.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screen),
              itemCount: incidents.length,
              itemBuilder: (context, index) =>
                  _IncidentCard(incident: incidents[index]),
            );
          },
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final DisasterIncidentModel incident;

  const _IncidentCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final statusColor = incidentStatusColor(incident.status);
    final sevColor = severityColor(incident.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + severity + status
            Row(
              children: [
                StatusChip(
                  DisasterIncidentModel.severityLabel(incident.severity),
                  sevColor,
                  filled: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    DisasterIncidentModel.typeLabel(incident.incidentType),
                    style: AppText.cardTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip(
                  DisasterIncidentModel.statusLabel(incident.status),
                  statusColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),

            // Progress hint — plain language for the current stage
            Text(_stageHint(incident.status), style: AppText.caption),

            if (incident.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                incident.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: AppColors.textPrimary),
              ),
            ],

            const SizedBox(height: AppSpacing.sm + 2),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: 4,
              children: [
                _meta(Icons.location_on_outlined, incident.village),
                if (incident.affectedPeople > 0)
                  _meta(Icons.groups_rounded,
                      '${incident.affectedPeople} affected'),
                if (incident.rescueRequired)
                  const _MetaIcon(
                      icon: Icons.support_rounded, label: 'Rescue needed'),
                if (incident.medicalRequired)
                  const _MetaIcon(
                      icon: Icons.medical_services_rounded, label: 'Medical'),
                if (incident.isDemoData) const DemoTag(),
              ],
            ),

            const SizedBox(height: AppSpacing.sm + 2),
            Text(AppHelpers.formatDateTime(incident.createdAt),
                style: AppText.metadata),
          ],
        ),
      ),
    );
  }

  /// Plain-language explanation of the current triage stage.
  String _stageHint(String status) {
    switch (status) {
      case 'reported':
        return 'Sent to your village authority — waiting for review';
      case 'verified':
        return 'Verified by authorities — being prioritized';
      case 'triaged':
        return 'Prioritized — response team being organized';
      case 'dispatched':
        return 'Help has been dispatched';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Marked invalid by authorities';
      default:
        return '';
    }
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: AppText.metadata),
      ],
    );
  }
}

class _MetaIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.danger),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppText.metadata.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
