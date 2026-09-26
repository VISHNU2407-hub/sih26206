import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:village_verse/models/post_model.dart';

void main() {
  group('PostModel', () {
    const postId = 'post_001';
    final now = DateTime(2025, 6, 1);

    test('fromFirestore creates model with all fields', () {
      final data = <String, dynamic>{
        'userId': 'user_1',
        'userName': 'Test User',
        'userType': 'Citizen',
        'userVillage': 'Pedapalakaluru',
        'userMandal': 'Guntur Rural',
        'title': 'Test Post',
        'description': 'This is a test post description.',
        'userProfileImage': 'https://example.com/profile.jpg',
        'postImage': 'https://example.com/post.jpg',
        'media': [
          {'type': 'image', 'url': 'https://example.com/media1.jpg'},
          {'type': 'image', 'url': 'https://example.com/media2.jpg'},
        ],
        'createdAt': Timestamp.fromDate(now),
        'likeCount': 10,
        'dislikeCount': 2,
        'heartCount': 5,
      };

      final post = PostModel.fromFirestore(data, postId);

      expect(post, isNotNull);
      expect(post!.postId, postId);
      expect(post.userId, 'user_1');
      expect(post.userName, 'Test User');
      expect(post.title, 'Test Post');
      expect(post.likeCount, 10);
      expect(post.dislikeCount, 2);
      expect(post.heartCount, 5);
      expect(post.media, hasLength(2));
      expect(post.media![0]['type'], 'image');
    });

    test('fromFirestore returns model with defaults for sparse data', () {
      // When critical fields are missing, fromFirestore should still
      // return a model (not null) with sensible empty defaults.
      final sparseData = <String, dynamic>{};

      final post = PostModel.fromFirestore(sparseData, postId);

      expect(post, isNotNull);
      expect(post!.userId, '');
      expect(post.title, '');
      expect(post.likeCount, 0);
    });

    test('fromFirestore handles null createdAt gracefully', () {
      final data = <String, dynamic>{
        'userId': 'user_1',
        'userName': 'Test',
        'title': 'Title',
        'description': 'Desc',
      };

      final post = PostModel.fromFirestore(data, postId);

      expect(post, isNotNull);
      expect(
        post!.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('fromFirestore converts deprecated postImage to media array', () {
      final data = <String, dynamic>{
        'userId': 'user_1',
        'userName': 'Test',
        'userType': 'Citizen',
        'userVillage': 'Village',
        'userMandal': 'Mandal',
        'title': 'Title',
        'description': 'Desc',
        'createdAt': Timestamp.fromDate(now),
        'postImage': 'https://example.com/old_image.jpg',
      };

      final post = PostModel.fromFirestore(data, postId);

      expect(post, isNotNull);
      expect(post!.media, isNotNull);
      expect(post.media!.length, 1);
      expect(post.media![0]['url'], 'https://example.com/old_image.jpg');
      expect(post.media![0]['type'], 'image');
    });

    test('toFirestore includes all fields', () {
      final post = PostModel(
        postId: postId,
        userId: 'user_1',
        userName: 'Test',
        userType: 'Admin',
        userVillage: 'Village',
        userMandal: 'Mandal',
        title: 'Title',
        description: 'Desc',
        createdAt: now,
        likeCount: 5,
        dislikeCount: 1,
        heartCount: 3,
        media: [
          {'type': 'image', 'url': 'https://example.com/img.jpg'},
        ],
      );

      final map = post.toFirestore();

      expect(map['title'], 'Title');
      expect(map['media'], isA<List>());
      expect(map['createdAt'], isA<FieldValue>()); // serverTimestamp
      expect(map['likeCount'], 5);
    });
  });
}
