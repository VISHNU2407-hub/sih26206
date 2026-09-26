import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/damage_assessment_model.dart';
import '../../models/user_model.dart';
import '../../services/damage_assessment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/roles.dart';

/// SATS Disaster — Phase 5: damage assessment detail with the
/// reported → verified → assessed → recovered administrative workflow.
///
/// The status records the administrative state only — the UI says so
/// explicitly so a database change is never presented as physical recovery.
class DamageAssessmentDetailScreen extends StatelessWidget {
  final DamageAssessmentModel item;
  final UserModel? currentUser;

  const DamageAssessmentDetailScreen({
    super.key,
    required this.item,
    this.currentUser,
  });

  Future<void> _advanceStatus(BuildContext context) async {
    final next = DamageAssessmentModel.nextStatus(item.status);
    if (next == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Mark as ${DamageAssessmentModel.statusLabel(next)}?'),
        content: const Text(
          'This records the administrative state of this damage item. '
          'It does not by itself confirm that physical recovery work '
          'has finished.',
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

    try {
      final updated = item.copyWith(
        status: next,
        updatedBy: currentUser?.uid,
      );
      await DamageAssessmentService().updateAssessment(item.id, updated);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(item.severity);
    // Fail closed: a missing/unknown user is never treated as an authority.
    final canManage = currentUser != null &&
        (AppRoles.isAuthority(currentUser!.role) ||
            currentUser!.role == AppRoles.rescue);
    final next = DamageAssessmentModel.nextStatus(item.status);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Damage Assessment',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: severityColor, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home_repair_service,
                          color: severityColor, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          DamageAssessmentModel.typeLabel(item.damageType),
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor,
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${item.village}, ${item.mandal} mandal, ${item.district} district',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${item.id.isEmpty ? '—' : item.id}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Status flow ──
            _StatusFlow(status: item.status),
            const SizedBox(height: 16),

            // ── Details ──
            _row('Status',
                DamageAssessmentModel.statusLabel(item.status)),
            if (item.description.isNotEmpty)
              _row('Description', item.description),
            if (item.estimatedAffectedPeople > 0)
              _row('Estimated people affected',
                  '~${item.estimatedAffectedPeople}'),
            _row('Recorded by', item.reportedByName),
            _row(
              'Recorded',
              '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} '
              '${item.createdAt.hour.toString().padLeft(2, "0")}:'
              '${item.createdAt.minute.toString().padLeft(2, "0")}',
            ),
            _row(
              'Updated',
              '${item.updatedAt.day}/${item.updatedAt.month}/${item.updatedAt.year} '
              '${item.updatedAt.hour.toString().padLeft(2, "0")}:'
              '${item.updatedAt.minute.toString().padLeft(2, "0")}',
            ),
            if (item.disasterId != null && item.disasterId!.isNotEmpty)
              _row('Linked disaster', item.disasterId!),

            // ── Location ──
            if (item.hasLocation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(item.locationLink!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View Location on Map'),
                ),
              ),
            ],

            // ── Photo ──
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  item.photoUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    color: Colors.grey.shade100,
                    child: Center(
                      child: Text('Photo unavailable',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Status advance action (authority/rescue only) ──
            if (canManage && next != null)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  label: Text(
                    'Mark as ${DamageAssessmentModel.statusLabel(next)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _advanceStatus(context),
                ),
              ),
            if (canManage && next == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recorded as recovered — administrative workflow '
                        'complete for this item.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  static Color _severityColor(String severity) {
    switch (severity) {
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
}

/// Horizontal administrative status indicator.
class _StatusFlow extends StatelessWidget {
  final String status;

  const _StatusFlow({required this.status});

  @override
  Widget build(BuildContext context) {
    final currentIndex = DamageAssessmentModel.statusFlow.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          for (var i = 0; i < DamageAssessmentModel.statusFlow.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    i < currentIndex
                        ? Icons.check_circle
                        : i == currentIndex
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                    size: 20,
                    color: i <= currentIndex
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DamageAssessmentModel.statusLabel(
                        DamageAssessmentModel.statusFlow[i]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: i == currentIndex
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: i <= currentIndex
                          ? Colors.grey.shade800
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (i < DamageAssessmentModel.statusFlow.length - 1)
              Container(
                height: 1.5,
                width: 12,
                color: i < currentIndex
                    ? AppColors.primary
                    : Colors.grey.shade300,
              ),
          ],
        ],
      ),
    );
  }
}
