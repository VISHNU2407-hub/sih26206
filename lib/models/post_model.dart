import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String userName;
  final String userType;
  final String userVillage;
  final String userMandal;
  final String title;
  final String description;
  final String? userProfileImage;
  final String? postImage; // Deprecated - kept for backward compatibility
  final List<Map<String, dynamic>>? media; // New media array structure
  final DateTime createdAt;
  final int likeCount;
  final int dislikeCount;
  final int heartCount;
  final DateTime? editedAt;

  PostModel({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userType,
    required this.userVillage,
    required this.userMandal,
    required this.title,
    required this.description,
    required this.createdAt,
    this.userProfileImage,
    this.postImage, // Deprecated
    this.media,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.heartCount = 0,
    this.editedAt,
  });

  // Create from Firestore document - returns null if parsing fails
  static PostModel? fromFirestore(Map<String, dynamic> data, String postId) {
    try {
      // Safe createdAt conversion - handle Timestamp, null, missing, or wrong type
      DateTime createdAt;
      try {
        final createdAtValue = data['createdAt'];
        if (createdAtValue == null) {
          createdAt = DateTime.now();
        } else if (createdAtValue is Timestamp) {
          createdAt = createdAtValue.toDate();
        } else if (createdAtValue is DateTime) {
          createdAt = createdAtValue;
        } else if (createdAtValue is String) {
          // Try to parse string date
          createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
        } else {
          print(
            'WARNING: Unexpected createdAt type: ${createdAtValue.runtimeType} for post $postId',
          );
          createdAt = DateTime.now();
        }
      } catch (e) {
        print('ERROR: Failed to parse createdAt for post $postId: $e');
        createdAt = DateTime.now();
      }

      // Safe editedAt conversion
      DateTime? editedAt;
      try {
        final editedAtValue = data['editedAt'];
        if (editedAtValue != null) {
          if (editedAtValue is Timestamp) {
            editedAt = editedAtValue.toDate();
          } else if (editedAtValue is DateTime) {
            editedAt = editedAtValue;
          }
        }
      } catch (e) {
        print('WARNING: Failed to parse editedAt for post $postId: $e');
      }

      // Handle media array - parse from Firestore
      List<Map<String, dynamic>>? media;
      if (data['media'] != null && data['media'] is List) {
        try {
          media = (data['media'] as List)
              .map(
                (item) => item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              )
              .toList();
        } catch (e) {
          print('WARNING: Failed to parse media array for post $postId: $e');
        }
      }

      // Backward compatibility: if postImage exists but media doesn't, convert postImage to media
      if (media == null || media.isEmpty) {
        final postImage = data['postImage']?.toString();
        if (postImage != null && postImage.isNotEmpty) {
          media = [
            {'type': 'image', 'url': postImage},
          ];
        }
      }

      return PostModel(
        postId: postId,
        userId: data['userId']?.toString() ?? '',
        userName: data['userName']?.toString() ?? '',
        userType: data['userType']?.toString() ?? 'Citizen',
        userVillage: data['userVillage']?.toString() ?? '',
        userMandal: data['userMandal']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        userProfileImage: data['userProfileImage']?.toString(),
        postImage: data['postImage']
            ?.toString(), // Deprecated - kept for backward compatibility
        media: media,
        createdAt: createdAt,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        dislikeCount: (data['dislikeCount'] as num?)?.toInt() ?? 0,
        heartCount: (data['heartCount'] as num?)?.toInt() ?? 0,
        editedAt: editedAt,
      );
    } catch (e) {
      print('ERROR: Failed to parse PostModel for post $postId: $e');
      print('ERROR: Data: $data');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userType': userType,
      'userVillage': userVillage,
      'userMandal': userMandal,
      'title': title,
      'description': description,
      'userProfileImage': userProfileImage,
      'postImage': postImage, // Deprecated - kept for backward compatibility
      'media': media,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
      'heartCount': heartCount,
      'editedAt': editedAt,
    };
  }

  @override
  String toString() {
    return 'PostModel(postId: $postId, userId: $userId, userName: $userName, userType: $userType, userVillage: $userVillage, userMandal: $userMandal, title: $title, description: $description, createdAt: $createdAt)';
  }
}
