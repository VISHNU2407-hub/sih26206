import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/complaint_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/profile_image_widget.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final ComplaintModel complaint;

  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();

  bool _isSendingMessage = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final message = {
        'senderType': 'user',
        'senderId': currentUser.uid,
        'senderName': widget.complaint.userName,
        'message': _messageController.text.trim(),
        'createdAt': DateTime.now(),
      };

      await _firestoreService.addComplaintMessage(
        widget.complaint.complaintId,
        message,
      );

      if (mounted) {
        _messageController.clear();
        AppHelpers.showSuccessSnackBar(context, 'Message sent');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to send message: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
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

            // Messages Section
            _buildMessagesSection(),
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
                    // Status circle
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
                    // Status label
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

            // Messages list
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
                    final isCurrentUser =
                        message['senderId'] == _auth.currentUser?.uid;

                    return _buildMessageBubble(message, isAdmin, isCurrentUser);
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 16),

            // Message input
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  IconButton(
                    onPressed: _isSendingMessage ? null : _sendMessage,
                    icon: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isAdmin,
    bool isCurrentUser,
  ) {
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
          // Sender name
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
          // Message bubble
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
          // Timestamp
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
