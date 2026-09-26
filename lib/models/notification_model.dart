import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool isRead;
  final String targetMandal;
  final String? targetUserId;
  final String? relatedDocumentId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
    required this.targetMandal,
    required this.targetUserId,
    required this.relatedDocumentId,
  });

  factory NotificationModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final createdAtValue = data['createdAt'];
    DateTime createdAt = DateTime.now();

    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    }

    return NotificationModel(
      id: id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      type: (data['type'] ?? 'system').toString(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
      targetMandal: (data['targetMandal'] ?? '').toString(),
      targetUserId: data['targetUserId']?.toString(),
      relatedDocumentId:
          data['relatedDocumentId']?.toString() ??
          data['relatedAlertId']?.toString() ??
          data['relatedComplaintId']?.toString() ??
          data['relatedPostId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'targetMandal': targetMandal,
      'targetUserId': targetUserId,
      'relatedDocumentId': relatedDocumentId,
    };
  }
}
