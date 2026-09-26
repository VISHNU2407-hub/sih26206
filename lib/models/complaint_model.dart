import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String complaintId;
  final String title;
  final String description;
  final List<String> media;
  final String userId;
  final String userName;
  final String userVillage;
  final String userMandal;
  final String? userProfileImage;
  final String status;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComplaintModel({
    required this.complaintId,
    required this.title,
    required this.description,
    required this.media,
    required this.userId,
    required this.userName,
    required this.userVillage,
    required this.userMandal,
    this.userProfileImage,
    required this.status,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create from Firestore document
  factory ComplaintModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Handle media array - convert single imageUrl to array for backward compatibility
    List<String> media = [];
    if (data['media'] != null && data['media'] is List) {
      media = (data['media'] as List).map((e) => e.toString()).toList();
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      // Backward compatibility: convert old imageUrl to media array
      media = [data['imageUrl'].toString()];
    }

    return ComplaintModel(
      complaintId: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      media: media,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userVillage: data['userVillage'] ?? '',
      userMandal: data['userMandal'] ?? '',
      userProfileImage: data['userProfileImage']?.toString(),
      status: data['status'] ?? 'pending',
      category: data['category'] ?? 'Other',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'media': media,
      'userId': userId,
      'userName': userName,
      'userVillage': userVillage,
      'userMandal': userMandal,
      'userProfileImage': userProfileImage,
      'status': status,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create copy with updated fields
  ComplaintModel copyWith({
    String? complaintId,
    String? title,
    String? description,
    List<String>? media,
    String? userId,
    String? userName,
    String? userVillage,
    String? userMandal,
    String? userProfileImage,
    String? status,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      complaintId: complaintId ?? this.complaintId,
      title: title ?? this.title,
      description: description ?? this.description,
      media: media ?? this.media,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userVillage: userVillage ?? this.userVillage,
      userMandal: userMandal ?? this.userMandal,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      status: status ?? this.status,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ComplaintModel(complaintId: $complaintId, title: $title, description: $description, media: $media, userId: $userId, userName: $userName, userVillage: $userVillage, userMandal: $userMandal, status: $status, category: $category, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
