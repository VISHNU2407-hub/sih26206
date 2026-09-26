import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/complaint_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/profile_image_widget.dart';

class AdminComplaintDetailScreen extends StatefulWidget {
  final ComplaintModel complaint;

  const AdminComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<AdminComplaintDetailScreen> createState() =>
      _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState
    extends State<AdminComplaintDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _replyController = TextEditingController();

  UserModel? _currentUser;
  bool _isSendingReply = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUser = userData;
          });
        }
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> _updateComplaintStatus(String newStatus) async {
    try {
      await _firestoreService.updateComplaintStatus(
        widget.complaint.complaintId,
        newStatus,
      );

      // Create notification for the complaint creator
      String title;
      String body;
      switch (newStatus) {
        case 'reviewing':
          title = 'Complaint Updated';
          body = 'Your complaint is now under review.';
          break;
        case 'in_progress':
          title = 'Complaint In Progress';
          body = 'Work has started on your complaint.';
          break;
        case 'resolved':
          title = 'Complaint Resolved';
          body = 'Your complaint has been marked as resolved.';
          break;
        case 'rejected':
          title = 'Complaint Rejected';
          body = 'Your complaint has been rejected.';
          break;
        default:
          title = 'Complaint Updated';
          body = 'Your complaint has been updated.';
      }

      // Create notification for the complaint creator
      try {
        final notification = NotificationModel(
          id: '',
          title: title,
          body: body,
          type: 'complaint',
          createdAt: DateTime.now(),
          isRead: false,
          targetMandal: widget.complaint.userMandal,
          targetUserId: widget.complaint.userId,
          relatedDocumentId: widget.complaint.complaintId,
        );
        await _firestoreService.createNotification(notification);
      } catch (notificationError) {
        // Log but do not fail status update if notification fails
        print('Error creating status-change notification: $notificationError');
      }

      if (mounted) {
        AppHelpers.showSuccessSnackBar(
          context,
          'Status updated to ${_formatStatus(newStatus)}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() {
      _isSendingReply = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final message = {
        'senderType': 'admin',
        'senderId': currentUser.uid,
        'senderName': _currentUser?.name ?? 'Admin',
        'message': _replyController.text.trim(),
        'createdAt': DateTime.now(),
      };

      await _firestoreService.addComplaintMessage(
        widget.complaint.complaintId,
        message,
      );

      // Notify the citizen about the admin reply
      try {
        final notification = NotificationModel(
          id: '',
          title: 'New Reply on Your Complaint',
          body: 'Admin replied: ${_replyController.text.trim()}',
          type: 'complaint',
          createdAt: DateTime.now(),
          isRead: false,
          targetMandal: widget.complaint.userMandal,
          targetUserId: widget.complaint.userId,
          relatedDocumentId: widget.complaint.complaintId,
        );
        await _firestoreService.createNotification(notification);
      } catch (notificationError) {
        // Log but do not fail reply sending if notification creation fails
        print('Error creating reply notification: $notificationError');
      }

      if (mounted) {
        _replyController.clear();
        AppHelpers.showSuccessSnackBar(context, 'Reply sent');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to send reply: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReply = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Complaint Details',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Timeline
            _buildStatusTimeline(),

            const SizedBox(height: 24),

            // Complaint Info Card
            _buildComplaintInfo(),

            const SizedBox(height: 24),

            // Status Update Section
            _buildStatusUpdateSection(),

            const SizedBox(height: 24),

            // Messages Section
            _buildMessagesSection(),

            const SizedBox(height: 24),

            // Admin Reply Section
            _buildAdminReplySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final statuses = ['pending', 'reviewing', 'in_progress', 'resolved'];
    final currentStatusIndex = statuses.indexOf(
      widget.complaint.status.toLowerCase(),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(statuses.length, (index) {
              final isCompleted = index <= currentStatusIndex;
              final isCurrent = index == currentStatusIndex;
              final status = statuses[index];

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? (isCurrent
                                  ? _getStatusColor(status)
                                  : Colors.green)
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? (isCurrent
                                    ? _getStatusColor(status)
                                    : Colors.green)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : Icon(
                                Icons.circle,
                                color: Colors.grey[400],
                                size: 12,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatStatus(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent
                            ? _getStatusColor(status)
                            : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.complaint.title.isNotEmpty
                  ? widget.complaint.title
                  : 'No Title',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(
                  widget.complaint.status,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(widget.complaint.status),
                  width: 1,
                ),
              ),
              child: Text(
                _formatStatus(widget.complaint.status),
                style: TextStyle(
                  color: _getStatusColor(widget.complaint.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(widget.complaint.category),
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.complaint.category,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.complaint.description,
              style: const TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 16),

            // Media
            if (widget.complaint.media.isNotEmpty) ...[
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.complaint.media.first,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Metadata
            Row(
              children: [
                ProfileImageWidget(
                  imageUrl: widget.complaint.userProfileImage,
                  name: widget.complaint.userName,
                  size: 24,
                  showBorder: false,
                ),
                const SizedBox(width: 8),
                Text(
                  'Submitted by: ${widget.complaint.userName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${AppHelpers.formatDate(widget.complaint.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.update, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${AppHelpers.formatDate(widget.complaint.updatedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusUpdateSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.complaint.status,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'reviewing',
                      child: Text('Reviewing'),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _updateComplaintStatus(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getComplaintMessages(
                widget.complaint.complaintId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: messages.map((doc) {
                    final message = doc.data() as Map<String, dynamic>;
                    final isAdmin = message['senderType'] == 'admin';
                    return _buildMessageBubble(message, isAdmin);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminReplySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Reply',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSendingReply ? null : _sendReply,
                child: _isSendingReply
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isAdmin) {
    final senderName = message['senderName'] ?? 'Unknown';
    final messageText = message['message'] ?? '';
    final createdAt =
        (message['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isAdmin
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isAdmin
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: [
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAdmin
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAdmin ? AppColors.primary : Colors.blue,
                width: 1,
              ),
            ),
            child: Text(messageText, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 4),
          Text(
            AppHelpers.formatDate(createdAt),
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    return AppHelpers.getStatusColor(status);
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'reviewing':
        return 'Reviewing';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  IconData _getCategoryIcon(String category) {
    return AppHelpers.getCategoryIcon(category);
  }
}
