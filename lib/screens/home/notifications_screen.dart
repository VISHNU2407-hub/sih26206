import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/complaint_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/disaster_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import 'admin_complaint_detail_screen.dart';
import 'complaint_detail_screen.dart';
import 'disaster_alert_detail_screen.dart';
import 'info_screen.dart';
import 'missing_person_alerts_screen.dart';
import 'my_incidents_screen.dart';
import 'shelters_screen.dart';

/// Category filter options for notification type filtering.
enum NotificationCategory {
  all('All', null),
  disasterAlert('Disaster', 'disaster_alert'),
  incident('Incident', 'incident'),
  shelter('Shelter', 'shelter'),
  evacuation('Evacuation', 'evacuation'),
  relief('Relief', 'relief'),
  rescue('Rescue', 'rescue'),
  sos('SOS', 'sos'),
  missingPerson('Missing Person', 'missing_person'),
  complaint('Complaint', 'complaint'),
  communityPost('Community Post', 'community_post'),
  system('System', 'system');

  final String label;
  final String? filterType;

  const NotificationCategory(this.label, this.filterType);
}

class NotificationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Currently selected category filter.
  NotificationCategory _selectedCategory = NotificationCategory.all;

  /// Whether a "Mark all as read" operation is in progress.
  bool _isMarkingAllRead = false;

  /// Whether a "Delete all" operation is in progress.
  bool _isDeletingAll = false;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Mark all as read button — only shown when there is at least
          // one unread notification in the current filter.
          StreamBuilder<List<NotificationModel>>(
            stream: _firestoreService.getNotificationsForUser(
              userId: userId,
              userMandal: widget.currentUser.mandal,
            ),
            builder: (context, snapshot) {
              final allNotifications =
                  snapshot.data ?? <NotificationModel>[];
              final filteredNotifications =
                  _filterByCategory(allNotifications);
              final hasUnread =
                  filteredNotifications.any((n) => !n.isRead);
              if (!hasUnread || _isMarkingAllRead) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Mark all as read',
                icon: const Icon(Icons.done_all),
                onPressed: () => _onMarkAllRead(context, userId),
              );
            },
          ),
          // Delete all overflow menu — only shown when there are
          // notifications in the current filter.
          StreamBuilder<List<NotificationModel>>(
            stream: _firestoreService.getNotificationsForUser(
              userId: userId,
              userMandal: widget.currentUser.mandal,
            ),
            builder: (context, snapshot) {
              final allNotifications =
                  snapshot.data ?? <NotificationModel>[];
              final filteredNotifications =
                  _filterByCategory(allNotifications);
              if (filteredNotifications.isEmpty || _isDeletingAll) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'delete_all') {
                    _onDeleteAll(context, userId);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Delete All Notifications'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _firestoreService.getNotificationsForUser(
          userId: userId,
          userMandal: widget.currentUser.mandal,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final allNotifications = snapshot.data ?? <NotificationModel>[];
          final filteredNotifications = _filterByCategory(allNotifications);

          return Column(
            children: [
              // ── Category filter chips ──
              _buildCategoryFilterChips(allNotifications),

              // ── Notification list or empty state ──
              Expanded(
                child: filteredNotifications.isEmpty
                    ? _buildEmptyState(_selectedCategory)
                    : _buildNotificationList(
                        context,
                        userId,
                        filteredNotifications,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  CATEGORY FILTERING
  // ───────────────────────────────────────────────────────────────────────────

  /// Filters [notifications] by the currently selected category.
  List<NotificationModel> _filterByCategory(List<NotificationModel> notifications) {
    if (_selectedCategory.filterType == null) return notifications;
    return notifications
        .where((n) => n.type == _selectedCategory.filterType)
        .toList();
  }

  /// Counts unread notifications within [notifications] that match
  /// the given [category].
  int _unreadCountForCategory(
    NotificationCategory category,
    List<NotificationModel> allNotifications,
  ) {
    final relevant = category.filterType == null
        ? allNotifications
        : allNotifications.where((n) => n.type == category.filterType);
    return relevant.where((n) => !n.isRead).length;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  ACTIONS
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onMarkAllRead(
    BuildContext context,
    String userId,
  ) async {
    // Show confirmation dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark all as read'),
        content: Text(
          _selectedCategory == NotificationCategory.all
              ? 'Mark all notifications as read?'
              : 'Mark all "${_selectedCategory.label}" notifications as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Read'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isMarkingAllRead = true);

    try {
      final count = await _firestoreService.markAllNotificationsAsRead(
        userId: userId,
        userMandal: widget.currentUser.mandal,
      );

      if (!mounted) return;

      setState(() => _isMarkingAllRead = false);

      AppHelpers.showSnackBar(
        context,
        count > 0
            ? '$count notification${count == 1 ? '' : 's'} marked as read'
            : 'No unread notifications',
        color: AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMarkingAllRead = false);
      AppHelpers.showSnackBar(
        context,
        'Failed to mark notifications as read',
        color: AppColors.danger,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  DELETE ALL
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onDeleteAll(
    BuildContext context,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text(
          'Delete all notifications in the current view?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAll = true);

    try {
      final count = await _firestoreService.deleteAllNotifications(
        userId: userId,
        userMandal: widget.currentUser.mandal,
      );

      if (!mounted) return;

      setState(() => _isDeletingAll = false);

      AppHelpers.showSnackBar(
        context,
        count > 0
            ? '$count notification${count == 1 ? '' : 's'} deleted'
            : 'No notifications to delete',
        color: AppColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAll = false);
      AppHelpers.showSnackBar(
        context,
        'Failed to delete notifications',
        color: AppColors.danger,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BUILD: CATEGORY FILTER CHIPS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildCategoryFilterChips(List<NotificationModel> allNotifications) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationCategory.values.map((category) {
            final isSelected = _selectedCategory == category;
            final unreadCount = _unreadCountForCategory(
              category,
              allNotifications,
            );

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.label),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(64)
                              : AppColors.danger.withAlpha(38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                backgroundColor: AppColors.surfaceMuted,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.outline,
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BUILD: NOTIFICATION LIST
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildNotificationList(
    BuildContext context,
    String userId,
    List<NotificationModel> notifications,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return Dismissible(
          key: ValueKey(notification.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Notification'),
                content: const Text(
                  'Are you sure you want to delete this notification?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (direction) async {
            try {
              await _firestoreService.deleteNotification(
                notification.id,
              );
              if (context.mounted) {
                AppHelpers.showSnackBar(
                  context,
                  'Notification deleted',
                  color: AppColors.success,
                );
              }
            } catch (e) {
              if (context.mounted) {
                AppHelpers.showSnackBar(
                  context,
                  'Failed to delete notification',
                  color: AppColors.danger,
                );
              }
            }
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(vertical: 0),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 28,
            ),
          ),
          child: _NotificationCard(
            notification: notification,
            onTap: () async {
              if (!notification.isRead) {
                await _firestoreService.markNotificationAsRead(
                  notification.id,
                );
              }
              await _navigateFromNotification(context, notification);
            },
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  BUILD: STATES
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(NotificationCategory category) {
    // Choose appropriate icon and message based on category.
    final (IconData icon, String title, String subtitle) =
        _emptyStateContent(category);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns (icon, title, subtitle) appropriate for the category.
  (IconData, String, String) _emptyStateContent(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.all:
        return (
          Icons.notifications_off_outlined,
          'No notifications yet',
          'You will see alerts and updates here.',
        );
      case NotificationCategory.disasterAlert:
        return (
          Icons.warning_amber_rounded,
          'No disaster alerts',
          'Disaster warnings for your area will appear here.',
        );
      case NotificationCategory.incident:
        return (
          Icons.report_problem_outlined,
          'No incident updates',
          'Incident status updates will appear here.',
        );
      case NotificationCategory.shelter:
        return (
          Icons.night_shelter,
          'No shelter updates',
          'Shelter information will appear here.',
        );
      case NotificationCategory.evacuation:
        return (
          Icons.directions_run,
          'No evacuation notices',
          'Evacuation orders will appear here.',
        );
      case NotificationCategory.relief:
        return (
          Icons.volunteer_activism,
          'No relief updates',
          'Relief coordination updates will appear here.',
        );
      case NotificationCategory.rescue:
        return (
          Icons.support,
          'No rescue updates',
          'Rescue coordination updates will appear here.',
        );
      case NotificationCategory.sos:
        return (
          Icons.sos,
          'No SOS alerts',
          'SOS emergency alerts will appear here.',
        );
      case NotificationCategory.missingPerson:
        return (
          Icons.person_search,
          'No missing person alerts',
          'Missing person alerts in your area will appear here.',
        );
      case NotificationCategory.complaint:
        return (
          Icons.report_problem_outlined,
          'No complaint updates',
          'Complaint status updates will appear here.',
        );
      case NotificationCategory.communityPost:
        return (
          Icons.campaign_outlined,
          'No community posts',
          'Community posts will appear here.',
        );
      case NotificationCategory.system:
        return (
          Icons.notifications_active_outlined,
          'No system notifications',
          'System updates will appear here.',
        );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  DEEP LINK NAVIGATION (preserved from original)
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _navigateFromNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final relatedId = notification.relatedDocumentId?.trim() ?? '';

    // ── SATS Disaster deep links ──
    switch (notification.type) {
      case 'disaster_alert':
      case 'evacuation':
        // Phase 4: relatedDocumentId carries the exact disaster document
        // ID — fetch it and open THAT alert. Fall back to the user's
        // primary area alert only when the notification predates the
        // disaster fan-out (no relatedDocumentId stored).
        if (relatedId.isNotEmpty) {
          try {
            final disaster = await DisasterService().getDisasterEvent(relatedId);
            if (!context.mounted) return;
            if (disaster == null) {
              _showAlertUnavailableMessage(context);
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DisasterAlertDetailScreen(
                  user: widget.currentUser,
                  disaster: disaster,
                ),
              ),
            );
          } catch (_) {
            if (context.mounted) _showAlertUnavailableMessage(context);
          }
          return;
        }
        // Legacy notification without a disaster reference: keep the
        // previous behavior (primary active disaster for the user's area).
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DisasterAlertDetailScreen(
              user: widget.currentUser,
              disaster: null,
            ),
          ),
        );
        return;
      case 'shelter':
      case 'relief':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SheltersScreen(user: widget.currentUser),
          ),
        );
        return;
      case 'incident':
      case 'rescue':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MyIncidentsScreen(user: widget.currentUser),
          ),
        );
        return;
    }

    // ── Legacy notification types ──
    switch (notification.type) {
      case 'missing_person':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MissingPersonAlertsScreen(initialAlertId: relatedId),
          ),
        );
        return;
      case 'complaint':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        final complaintDoc = await FirebaseFirestore.instance
            .collection('complaints')
            .doc(relatedId)
            .get();
        if (!complaintDoc.exists || complaintDoc.data() == null) {
          _showRecordNotFoundMessage(context);
          return;
        }
        final complaint = ComplaintModel.fromFirestore(
          complaintDoc.data()!,
          complaintDoc.id,
        );

        // Route to the correct screen based on user role.
        // widget.currentUser is already available — no extra Firestore read needed.
        final isAdmin = widget.currentUser.role.toLowerCase() == 'admin';

        if (isAdmin) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => AdminComplaintDetailScreen(complaint: complaint),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailScreen(complaint: complaint),
            ),
          );
        }
        return;
      case 'community_post':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoScreen(initialPostId: relatedId),
          ),
        );
        return;
      case 'system':
        AppHelpers.showSnackBar(
          context,
          'Opened: ${notification.title}',
          color: AppColors.success,
        );
        break;
      default:
        AppHelpers.showSnackBar(
          context,
          'Opened notification',
          color: AppColors.success,
        );
    }
  }

  /// Graceful state when a linked disaster no longer exists (closed and
  /// pruned, or id stale) — never crash, just inform.
  void _showAlertUnavailableMessage(BuildContext context) {
    AppHelpers.showSnackBar(
      context,
      'Alert no longer available.',
      color: AppColors.warning,
    );
  }

  void _showMissingLinkMessage(BuildContext context) {
    AppHelpers.showSnackBar(
      context,
      'This notification has no linked item.',
      color: AppColors.danger,
    );
  }

  void _showRecordNotFoundMessage(BuildContext context) {
    AppHelpers.showSnackBar(
      context,
      'The related item was not found.',
      color: AppColors.danger,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NOTIFICATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? AppColors.outline
                  : iconColor.withAlpha(115),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(20, 35, 60, 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(31),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppHelpers.formatDateTime(notification.createdAt),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isRead
                                  ? AppColors.textTertiary
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRead ? 'Read' : 'Unread',
                            style: TextStyle(
                              fontSize: 12,
                              color: isRead? AppColors.textTertiary

                              : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withAlpha(31),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _categoryLabel(notification.type),
                              style: TextStyle(
                                fontSize: 10,
                                color: iconColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String type) {
    switch (type) {
      case 'disaster_alert':
        return 'Disaster';
      case 'incident':
        return 'Incident';
      case 'shelter':
        return 'Shelter';
      case 'evacuation':
        return 'Evacuation';
      case 'relief':
        return 'Relief';
      case 'rescue':
        return 'Rescue';
      case 'sos':
        return 'SOS';
      case 'missing_person':
        return 'Alert';
      case 'complaint':
        return 'Complaint';
      case 'community_post':
        return 'Post';
      case 'system':
      default:
        return 'System';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'disaster_alert':
        return Icons.warning_amber_rounded;
      case 'incident':
        return Icons.report_problem_outlined;
      case 'shelter':
        return Icons.night_shelter;
      case 'evacuation':
        return Icons.directions_run;
      case 'relief':
        return Icons.volunteer_activism;
      case 'rescue':
        return Icons.support;
      case 'sos':
        return Icons.sos;
      case 'missing_person':
        return Icons.person_search;
      case 'complaint':
        return Icons.report_problem_outlined;
      case 'community_post':
        return Icons.campaign_outlined;
      case 'system':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'disaster_alert':
      case 'evacuation':
        return AppColors.warning;
      case 'incident':
      case 'rescue':
        return AppColors.danger;
      case 'shelter':
        return AppColors.primary;
      case 'relief':
        return AppColors.success;
      case 'sos':
        return AppColors.danger;
      case 'missing_person':
        return AppColors.amber;
      case 'complaint':
        return AppColors.danger;
      case 'community_post':
        return AppColors.info;
      case 'system':
      default:
        return AppColors.violet;
    }
  }
}
