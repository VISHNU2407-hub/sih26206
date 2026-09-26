import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class EmergencyHistoryScreen extends StatelessWidget {
  const EmergencyHistoryScreen({super.key});

  Stream<List<_EmergencyHistoryItem>> _emergencyHistoryStream(String userId) {
    return FirebaseFirestore.instance
        .collection('emergencies')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final emergencies = snapshot.docs
              .map(_EmergencyHistoryItem.fromDocument)
              .toList();
          emergencies.sort((a, b) => b.startedAt.compareTo(a.startedAt));
          return emergencies;
        });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Emergency History',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: currentUser == null
            ? _buildMessageState(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Please sign in to view emergency history.',
              )
            : StreamBuilder<List<_EmergencyHistoryItem>>(
                stream: _emergencyHistoryStream(currentUser.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildMessageState(
                      icon: Icons.error_outline,
                      title: 'Unable to load history',
                      message: 'Please try again later.',
                    );
                  }

                  final emergencies = snapshot.data ?? [];
                  if (emergencies.isEmpty) {
                    return _buildMessageState(
                      icon: Icons.history,
                      title: 'No emergencies yet',
                      message: 'Your past SOS emergencies will appear here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: emergencies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _EmergencyHistoryCard(item: emergencies[index]);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHistoryCard extends StatelessWidget {
  const _EmergencyHistoryCard({required this.item});

  final _EmergencyHistoryItem item;

  Future<void> _openLocation(BuildContext context) async {
    final link = item.locationLink;
    if (link == null) {
      AppHelpers.showErrorSnackBar(context, 'Location is not available');
      return;
    }

    final uri = Uri.parse(link);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppHelpers.showErrorSnackBar(context, 'Unable to open maps');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isActive
        ? AppColors.danger
        : AppColors.success;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(item.isActive ? Icons.sos : Icons.check_circle, color: statusColor),
        ),
        title: Text(
          item.dateLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.schedule, label: item.timeLabel),
              _InfoChip(icon: Icons.touch_app, label: item.triggerModeLabel),
              _InfoChip(
                icon: Icons.group,
                label: '${item.guardianCount} guardians',
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.35)),
          ),
          child: Text(
            item.statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          const Divider(height: 20),
          _DetailRow(label: 'Date', value: item.dateLabel),
          _DetailRow(label: 'Time', value: item.timeLabel),
          _DetailRow(label: 'Trigger mode', value: item.triggerModeLabel),
          _DetailRow(label: 'Status', value: item.statusLabel),
          _DetailRow(label: 'Guardian count', value: '${item.guardianCount}'),
          if (item.coordinatesLabel != null)
            _DetailRow(label: 'Location', value: item.coordinatesLabel!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: item.locationLink == null
                  ? null
                  : () => _openLocation(context),
              icon: const Icon(Icons.map),
              label: const Text('Open in Maps'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyHistoryItem {
  const _EmergencyHistoryItem({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.triggerMode,
    required this.guardianCount,
    required this.latitude,
    required this.longitude,
    required this.locationLink,
  });

  final String id;
  final DateTime startedAt;
  final String status;
  final String triggerMode;
  final int guardianCount;
  final double? latitude;
  final double? longitude;
  final String? locationLink;

  factory _EmergencyHistoryItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['timestamp'];
    final latitude = data['latitude'];
    final longitude = data['longitude'];

    return _EmergencyHistoryItem(
      id: document.id,
      startedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      status: (data['status'] as String?) ?? 'resolved',
      triggerMode: (data['triggerMode'] as String?) ?? 'manual',
      guardianCount: (data['guardianCount'] as num?)?.toInt() ?? 0,
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      locationLink: _readLocationLink(data),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';

  String get statusLabel => isActive ? 'Active' : 'Resolved';

  String get triggerModeLabel {
    final normalized = triggerMode.toLowerCase();
    if (normalized.contains('stealth')) {
      return 'Stealth';
    }
    return 'Manual';
  }

  String get dateLabel {
    final day = startedAt.day.toString().padLeft(2, '0');
    final month = startedAt.month.toString().padLeft(2, '0');
    return '$day/$month/${startedAt.year}';
  }

  String get timeLabel {
    final hour = startedAt.hour;
    final minute = startedAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  String? get coordinatesLabel {
    if (latitude == null || longitude == null) {
      return null;
    }
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  static String? _readLocationLink(Map<String, dynamic> data) {
    final existingLink = data['locationLink'];
    if (existingLink is String && existingLink.isNotEmpty) {
      return existingLink;
    }

    final latitude = data['latitude'];
    final longitude = data['longitude'];
    if (latitude is num && longitude is num) {
      return 'https://maps.google.com/?q=${latitude.toDouble()},${longitude.toDouble()}';
    }

    return null;
  }
}
