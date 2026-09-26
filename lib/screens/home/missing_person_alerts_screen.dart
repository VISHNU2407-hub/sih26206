import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/missing_person_alert_model.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/missing_person_alert_service.dart';
import '../../utils/helpers.dart';
import '../../utils/roles.dart';
import '../../utils/geo_match.dart';
import 'create_missing_person_alert_screen.dart';

class MissingPersonAlertsScreen extends StatefulWidget {
  final String? initialAlertId;

  const MissingPersonAlertsScreen({super.key, this.initialAlertId});

  @override
  State<MissingPersonAlertsScreen> createState() =>
      _MissingPersonAlertsScreenState();
}

class _MissingPersonAlertsScreenState extends State<MissingPersonAlertsScreen> {
  final MissingPersonAlertService _alertService = MissingPersonAlertService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _updatingAlerts = {};
  UserModel? _currentUser;
  bool _openedInitialAlert = false;

  /// Phase 5: optional filter to show only disaster-linked alerts
  /// (available to authority users). null = no disaster filtering.
  bool? _disasterOnly;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final data = await _firestoreService.getUser(user.uid);
      if (mounted) {
        setState(() => _currentUser = data);
      }
    } catch (_) {}
  }

  Future<void> _openCreateAlert({MissingPersonAlertModel? alert}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMissingPersonAlertScreen(existingAlert: alert),
      ),
    );
  }

  bool _isOwner(MissingPersonAlertModel alert) {
    return _auth.currentUser?.uid == alert.createdBy;
  }

  bool get _isAuthority {
    final role = _currentUser?.role;
    return role != null &&
        (AppRoles.isAuthority(role) || role == AppRoles.rescue);
  }

  /// Phase 5: authority-only filter chips for disaster-linked alerts.
  Widget _buildDisasterFilterChips() {
    return Row(
      children: [
        Expanded(
          child: FilterChip(
            label: const Text('All alerts'),
            selected: _disasterOnly == null,
            onSelected: (_) => setState(() => _disasterOnly = null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilterChip(
            label: const Text('Disaster-linked'),
            selected: _disasterOnly == true,
            onSelected: (_) => setState(() => _disasterOnly = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilterChip(
            label: const Text('Non-disaster'),
            selected: _disasterOnly == false,
            onSelected: (_) => setState(() => _disasterOnly = false),
          ),
        ),
      ],
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    final launched = await launchUrl(phoneUri);
    if (!launched && mounted) {
      AppHelpers.showErrorSnackBar(context, 'Could not open phone dialer');
    }
  }

  Future<void> _openWhatsApp(MissingPersonAlertModel alert) async {
    final formattedNumber = _formatWhatsAppNumber(alert.whatsappNumber);
    if (formattedNumber.length < 12) {
      AppHelpers.showErrorSnackBar(context, 'Invalid WhatsApp number');
      return;
    }
    final message =
        '''I saw the missing person alert for ${alert.fullName}.

Last seen: ${alert.lastSeenLocation}

I am contacting regarding this alert.''';
    final whatsappUrl = Uri.parse(
      'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}',
    );
    final launched = await launchUrl(
      whatsappUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      AppHelpers.showErrorSnackBar(context, 'Unable to open WhatsApp');
    }
  }

  Future<void> _markFoundSafe(MissingPersonAlertModel alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Found Safe?'),
        content: Text(
          'This will move ${alert.fullName} out of active missing alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Found Safe'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingAlerts.add(alert.id));
    try {
      await _alertService.markFoundSafe(alert.id);
      if (mounted) {
        AppHelpers.showSuccessSnackBar(context, 'Alert marked found safe');
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to update alert');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAlerts.remove(alert.id));
      }
    }
  }

  Future<void> _deleteAlert(MissingPersonAlertModel alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Alert?'),
        content: Text('Delete alert for ${alert.fullName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _alertService.deleteAlert(alert.id);
      if (mounted) {
        AppHelpers.showSuccessSnackBar(context, 'Alert deleted');
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to delete alert');
      }
    }
  }

  List<MissingPersonAlertModel> _sortByMandalPriority(
    List<MissingPersonAlertModel> alerts,
  ) {
    final myMandal = GeoMatch.normalize(_currentUser?.mandal);
    if (myMandal.isEmpty) return alerts;
    final sorted = [...alerts];
    sorted.sort((a, b) {
      final aSame = GeoMatch.normalize(a.userMandal) == myMandal;
      final bSame = GeoMatch.normalize(b.userMandal) == myMandal;
      if (aSame == bSame) return b.createdAt.compareTo(a.createdAt);
      return aSame ? -1 : 1;
    });
    return sorted;
  }

  /// Strict 3-level geographic matching: citizen sees an alert only if
  /// village AND mandal AND district all match.
  List<MissingPersonAlertModel> _filterToCurrentArea(
    List<MissingPersonAlertModel> alerts,
  ) {
    if (_currentUser == null) return alerts;
    return alerts
        .where((alert) => GeoMatch.matches3Level(
              itemVillage: alert.userVillage,
              itemMandal: alert.userMandal,
              itemDistrict: alert.userDistrict,
              userVillage: _currentUser!.village,
              userMandal: _currentUser!.mandal,
              userDistrict: _currentUser!.district,
            ))
        .toList();
  }

  /// Phase 5: authority filter — show only disaster-associated alerts.
  List<MissingPersonAlertModel> _applyDisasterFilter(
    List<MissingPersonAlertModel> alerts,
  ) {
    if (_disasterOnly == null) return alerts;
    return alerts
        .where((a) => _disasterOnly!
            ? (a.disasterId != null && a.disasterId!.isNotEmpty)
            : (a.disasterId == null || a.disasterId!.isEmpty))
        .toList();
  }

  void _maybeOpenInitialAlert(List<MissingPersonAlertModel> alerts) {
    if (_openedInitialAlert) return;
    final targetId = widget.initialAlertId?.trim();
    if (targetId == null || targetId.isEmpty) return;

    final match = alerts.where((a) => a.id == targetId).toList();
    if (match.isEmpty) return;

    _openedInitialAlert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alert = match.first;
      _showAlertDetails(alert, isResolved: alert.isFoundSafe);
    });
  }

  String _formatWhatsAppNumber(String phoneNumber) {
    final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedPhone.length == 10) return '91$cleanedPhone';
    if (cleanedPhone.length == 12 && cleanedPhone.startsWith('91')) {
      return cleanedPhone;
    }
    return cleanedPhone;
  }

  String _formatMissingDuration(DateTime missingDateTime) {
    final difference = DateTime.now().difference(missingDateTime);
    if (difference.inMinutes < 1) return 'Just reported';
    if (difference.inHours < 1) return 'Missing ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Missing ${difference.inHours} hr';
    if (difference.inDays < 30) return 'Missing ${difference.inDays} days';
    final months = (difference.inDays / 30).floor();
    return 'Missing $months month${months == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    const alertRed = AppColors.danger;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: alertRed),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Missing Person Alerts',
          style: TextStyle(color: alertRed, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateAlert,
        backgroundColor: alertRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Create Alert'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MissingPersonAlertModel>>(
          stream: _alertService.getAlertsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildStateMessage(
                icon: Icons.error_outline,
                title: 'Unable to load alerts',
                subtitle: 'Please try again later.',
              );
            }

            final alerts = snapshot.data ?? [];
            if (alerts.isEmpty) {
              return _buildStateMessage(
                icon: Icons.person_search,
                title: 'No missing person alerts',
                subtitle: 'Create an alert if someone needs urgent help.',
              );
            }

            final mandalAlerts = _applyDisasterFilter(
              _filterToCurrentArea(alerts),
            );
            _maybeOpenInitialAlert(mandalAlerts);

            if (mandalAlerts.isEmpty) {
              return _buildStateMessage(
                icon: Icons.person_search,
                title: _disasterOnly == null
                    ? 'No alerts in your mandal'
                    : 'No alerts match this filter',
                subtitle: 'You will see missing alerts reported in your local area.',
              );
            }

            final activeAlerts = _sortByMandalPriority(
              mandalAlerts.where((a) => !a.isFoundSafe).toList(),
            );
            final foundAlerts = _sortByMandalPriority(
              mandalAlerts.where((a) => a.isFoundSafe).toList(),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _buildEmergencyHeader(activeAlerts.length),
                if (_isAuthority) ...[
                  const SizedBox(height: 10),
                  _buildDisasterFilterChips(),
                ],
                const SizedBox(height: 18),
                if (activeAlerts.isNotEmpty) ...[
                  _buildSectionTitle('Active Alerts', activeAlerts.length, alertRed),
                  const SizedBox(height: 10),
                  ...activeAlerts.map(
                    (alert) => _buildCompactAlertCard(alert, isResolved: false),
                  ),
                ],
                if (foundAlerts.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildSectionTitle('Found Safe', foundAlerts.length, AppColors.success),
                  const SizedBox(height: 10),
                  ...foundAlerts.map(
                    (alert) => _buildCompactAlertCard(alert, isResolved: true),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmergencyHeader(int activeCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$activeCount active alert${activeCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAlertCard(
    MissingPersonAlertModel alert, {
    required bool isResolved,
  }) {
    final primaryColor = isResolved ? AppColors.success : AppColors.danger;
    final softColor =
        isResolved ? AppColors.success.withAlpha(20) : AppColors.amber.withAlpha(38);
    final borderColor =
        isResolved ? AppColors.success.withAlpha(115) : AppColors.warning;

    return Opacity(
      opacity: isResolved ? 0.75 : 1,
      child: InkWell(
        onTap: () => _showAlertDetails(alert, isResolved: isResolved),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: alert.photoUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${alert.age}y',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatMissingDuration(alert.missingDateTime),
                      style: TextStyle(
                        color: isResolved ? AppColors.success : AppColors.dangerDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          icon: Icons.map,
                          label: alert.userMandal.isEmpty ? 'Unknown Mandal' : alert.userMandal,
                          color: const Color(0xFFEF6C00),
                        ),
                        _buildBadge(
                          icon: Icons.location_on,
                          label: alert.lastSeenLocation,
                          color: Colors.red.shade700,
                        ),
                        _buildStatusPill(alert, primaryColor, isResolved),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlertDetails(
    MissingPersonAlertModel alert, {
    required bool isResolved,
  }) async {
    final owner = _isOwner(alert);
    final isUpdating = _updatingAlerts.contains(alert.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: alert.photoUrl,
                    height: 260,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (context, url, error) => Container(
                      height: 260,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 42),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${alert.fullName}, ${alert.age}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusPill(
                      alert,
                      isResolved ? AppColors.success : AppColors.danger,
                      isResolved,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.schedule,
                  '${_formatMissingDuration(alert.missingDateTime)} · ${AppHelpers.formatDateTime(alert.missingDateTime)}',
                ),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on, 'Last seen: ${alert.lastSeenLocation}'),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.map, 'Mandal: ${alert.userMandal}'),
                if (alert.disasterId != null && alert.disasterId!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    Icons.warning_amber_rounded,
                    'Linked to disaster event: ${alert.disasterId}',
                  ),
                ],
                const SizedBox(height: 12),
                _buildDetailBlock('Clothes Details', alert.clothesDescription),
                if (alert.additionalNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailBlock('Additional Description', alert.additionalNotes),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makeCall(alert.guardianContactNumber),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(alert),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openWhatsApp(alert),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Report Sighting'),
                  ),
                ),
                if (!isResolved) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isUpdating
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _markFoundSafe(alert);
                            },
                      icon: const Icon(Icons.verified),
                      label: const Text('Mark FOUND SAFE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(color: AppColors.success),
                      ),
                    ),
                  ),
                ],
                if (owner) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _openCreateAlert(alert: alert);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _deleteAlert(alert);
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusPill(
    MissingPersonAlertModel alert,
    Color color,
    bool isResolved,
  ) {
    final label = isResolved ? 'FOUND SAFE' : 'MISSING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.grey.shade700),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade800, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBlock(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openCreateAlert,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
