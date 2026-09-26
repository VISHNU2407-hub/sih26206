import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/guardian_model.dart';
import '../models/complaint_model.dart';
import '../models/post_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User operations
  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
    }
    return null;
  }

  Future<bool> userExists(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(user.toFirestore());
  }

  /// Updates specific fields on the user document without
  /// overwriting the entire document (e.g. FCM token, location).
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> updateUserLocation(
    String uid,
    double latitude,
    double longitude,
  ) async {
    await _firestore.collection('users').doc(uid).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Guardian operations
  Future<void> saveGuardian(String uid, GuardianModel guardian) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardian.id)
        .set(guardian.toFirestore());
  }

  Future<List<GuardianModel>> getGuardians(String uid) async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map(
          (doc) => GuardianModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<void> deleteGuardian(String uid, String guardianId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardianId)
        .delete();
  }

  Future<void> updateGuardian(String uid, GuardianModel guardian) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardian.id)
        .update(guardian.toFirestore());
  }

  Future<bool> hasGuardians(String uid) async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Complaint operations
  Future<String> submitComplaint(Map<String, dynamic> complaint) async {
    final docRef = await _firestore.collection('complaints').add(complaint);
    return docRef.id;
  }

  // Get complaints by user ID (realtime stream)
  Stream<QuerySnapshot> getComplaintsByUserId(String userId) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get complaints by mandal for admins (realtime stream)
  Stream<QuerySnapshot> getComplaintsByMandal(String mandal) {
    return _firestore
        .collection('complaints')
        .where('userMandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get complaints by village AND mandal for admins (realtime stream)
  // Both village and mandal must match — enforces village-level sachivalayam routing.
  Stream<QuerySnapshot> getComplaintsByVillageAndMandal(
    String village,
    String mandal,
  ) {
    return _firestore
        .collection('complaints')
        .where('userVillage', isEqualTo: village)
        .where('userMandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Admin operations - get all complaints
  Future<List<ComplaintModel>> getAllComplaints() async {
    QuerySnapshot snapshot = await _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => ComplaintModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // Update complaint status
  Future<void> updateComplaintStatus(String complaintId, String status) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Add message to complaint
  Future<void> addComplaintMessage(
    String complaintId,
    Map<String, dynamic> message,
  ) async {
    await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .add(message);
  }

  // Get messages for a complaint (realtime stream)
  Stream<QuerySnapshot> getComplaintMessages(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Delete complaint and its messages
  Future<void> deleteComplaint(String complaintId) async {
    // Delete complaint messages subcollection
    final messagesSnapshot = await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .get();

    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete complaint document
    await _firestore.collection('complaints').doc(complaintId).delete();
  }

  // Post operations
  Future<void> createPost(PostModel post) async {
    debugPrint('createPost - Creating post with ID: ${post.postId}');
    debugPrint(
      'createPost - Post userVillage: ${post.userVillage}, userMandal: ${post.userMandal}',
    );
    debugPrint('createPost - Post data: ${post.toString()}');
    try {
      await _firestore
          .collection('posts')
          .doc(post.postId)
          .set(post.toFirestore());
      debugPrint('createPost - Successfully saved post to Firestore');

      // Create in-app notifications for all users sharing the same
      // village (street) + mandal (village), excluding the post creator.
      try {
        await _createCommunityPostNotifications(post);
      } catch (notificationError) {
        // Log but never fail post creation due to notification errors.
        debugPrint(
          'createPost - Error creating community notifications: $notificationError',
        );
      }
    } catch (e) {
      debugPrint('createPost - Error saving post: $e');
      rethrow;
    }
  }

  /// Creates a [NotificationModel] document for every user whose village
  /// and mandal match [post.userVillage] and [post.userMandal], excluding
  /// the post author ([post.userId]).
  ///
  /// Firestore field mapping (UserModel legacy):
  ///   - Firestore 'street' stores the village name (UserModel.village)
  ///   - Firestore 'village' stores the mandal name (UserModel.mandal)
  Future<void> _createCommunityPostNotifications(PostModel post) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('street', isEqualTo: post.userVillage)
        .where('village', isEqualTo: post.userMandal)
        .get();

    if (usersSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();

    for (final userDoc in usersSnapshot.docs) {
      final targetUserId = userDoc.id;
      // Don't notify the post creator.
      if (targetUserId == post.userId) continue;

      final notificationDocId = 'community_${post.postId}_$targetUserId';
      final notificationRef = _firestore
          .collection('notifications')
          .doc(notificationDocId);

      batch.set(notificationRef, {
        'title': 'New Community Post',
        'body': '${post.userName} posted: ${post.title}',
        'type': 'community_post',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetMandal': post.userMandal,
        'targetUserId': targetUserId,
        'relatedDocumentId': post.postId,
      });
    }

    await batch.commit();
  }

  Stream<QuerySnapshot> getPostsByVillage(String village) {
    debugPrint('getPostsByVillage called with village: $village');
    return _firestore
        .collection('posts')
        .where('userVillage', isEqualTo: village)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPostsByVillageAndMandal(
    String village,
    String mandal,
  ) {
    debugPrint(
      'getPostsByVillageAndMandal called with village: $village, mandal: $mandal',
    );
    return _firestore
        .collection('posts')
        .where('userVillage', isEqualTo: village)
        .where('userMandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPostsByUserId(String userId) {
    debugPrint('getPostsByUserId called with userId: $userId');
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deletePost(String postId) async {
    // Delete post document
    await _firestore.collection('posts').doc(postId).delete();

    // Best-effort cleanup of reactions subcollection.
    // The reactions list query requires read access to EVERY reaction document;
    // since reaction doc IDs equal the reactor's UID, the post owner can only
    // read reactions they created themselves. If other users' reactions exist,
    // the query is denied — but the post document was already deleted, so we
    // should not propagate this as a deletion failure.
    try {
      final reactionsSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('reactions')
          .get();

      for (var doc in reactionsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Log and swallow — post deletion already succeeded.
      // Orphaned reactions will be cleaned up by a background job if needed.
      debugPrint('deletePost: reactions cleanup skipped ($e)');
    }

    // Note: Pinned posts are stored separately and will be handled by cleanup logic
    // They reference postId, so when post is deleted, the pin reference becomes invalid
    // We could add a cleanup job later to remove orphaned pin references
  }

  // Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await _firestore.collection('posts').doc(postId).update(updates);
  }

  // Pin operations
  Future<void> pinPost(String userId, String postId, Duration duration) async {
    final expiresAt = DateTime.now().add(duration);
    await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .set({
          'postId': postId,
          'pinnedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
  }

  Future<void> unpinPost(String userId, String postId) async {
    await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .delete();
  }

  Stream<QuerySnapshot> getPinnedPosts(String userId) {
    return _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .orderBy('pinnedAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot> checkIfPinned(String userId, String postId) {
    return _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .snapshots();
  }

  Future<bool> isPostPinned(String userId, String postId) async {
    final doc = await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .get();

    if (!doc.exists) return false;

    // Check if pin has expired
    final data = doc.data() as Map<String, dynamic>;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      // Pin has expired, delete it
      await unpinPost(userId, postId);
      return false;
    }

    return true;
  }

  // Reaction operations
  Future<void> toggleReaction(
    String postId,
    String userId,
    String reactionType,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(postId);
      final reactionRef = postRef.collection('reactions').doc(userId);

      final postDoc = await transaction.get(postRef);
      final reactionDoc = await transaction.get(reactionRef);

      if (!postDoc.exists) {
        throw Exception('Post does not exist');
      }

      final currentReaction = reactionDoc.exists
          ? (reactionDoc.data()?['reaction'] as String?)
          : null;

      if (currentReaction == null) {
        // CASE 1: User has no previous reaction - add new reaction
        transaction.set(reactionRef, {'reaction': reactionType});
        transaction.update(postRef, {
          '${reactionType}Count': FieldValue.increment(1),
        });
      } else if (currentReaction == reactionType) {
        // CASE 2: User already selected same reaction - remove it (toggle off)
        transaction.delete(reactionRef);
        transaction.update(postRef, {
          '${reactionType}Count': FieldValue.increment(-1),
        });
      } else {
        // CASE 3: User changes reaction - switch from old to new
        transaction.set(reactionRef, {'reaction': reactionType});
        transaction.update(postRef, {
          '${currentReaction}Count': FieldValue.increment(-1),
          '${reactionType}Count': FieldValue.increment(1),
        });
      }
    });
  }

  Future<String?> getUserReaction(String postId, String userId) async {
    final doc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .get();

    if (doc.exists) {
      return doc.data()?['reaction'] as String?;
    }
    return null;
  }

  Stream<DocumentSnapshot> getUserReactionStream(String postId, String userId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .snapshots();
  }

  /// Finds admin users whose village and mandal match the given values.
  /// Used to notify admins when a complaint is submitted in their area.
  ///
  /// Firestore field mapping (UserModel legacy):
  ///   - Firestore 'village' stores the mandal name (UserModel.mandal)
  ///   - Firestore 'street' stores the village name (UserModel.village)
  ///
  /// We filter by role='admin' server-side, then match village+mandal client-side
  /// to avoid requiring a 3-field composite index.
  Future<List<UserModel>> getAdminUsersByVillageAndMandal(
    String village,
    String mandal,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    final matchingAdmins = <UserModel>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final adminVillage =
          (data['street'] as String?)?.trim().toLowerCase() ?? '';
      final adminMandal =
          (data['village'] as String?)?.trim().toLowerCase() ?? '';

      if (adminVillage == village.trim().toLowerCase() &&
          adminMandal == mandal.trim().toLowerCase()) {
        matchingAdmins.add(
          UserModel.fromFirestore(data, doc.id),
        );
      }
    }
    return matchingAdmins;
  }

  // Blood donor operations
  Stream<QuerySnapshot> getBloodDonors(
    String bloodGroup,
    String currentUserId,
  ) {
    debugPrint('getBloodDonors called');
    debugPrint('  bloodGroup: $bloodGroup');
    debugPrint('  currentUserId: $currentUserId');

    return _firestore
        .collection('users')
        .where('isBloodDonor', isEqualTo: true)
        .where('bloodGroup', isEqualTo: bloodGroup)
        .snapshots();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  NOTIFICATION OPERATIONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Creates a new notification document in the `notifications` collection.
  Future<void> createNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .add(notification.toFirestore());
  }

  /// Returns a real-time stream of notifications targeted specifically
  /// at [userId].
  Stream<List<NotificationModel>> getNotificationsForUser({
    required String userId,
    required String userMandal,
  }) {
    return _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationModel.fromFirestore(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Returns a real-time stream of the unread notification count for
  /// the given [userId] / [userMandal].
  Stream<int> getUnreadNotificationCount({
    required String userId,
    required String userMandal,
  }) {
    return getNotificationsForUser(userId: userId, userMandal: userMandal).map(
      (notifications) => notifications.where((n) => !n.isRead).length,
    );
  }

  /// Marks a single notification as read.
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Deletes a single notification document by its Firestore document ID.
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  /// Marks all unread notifications for [userId] as read using a
  /// Firestore batch write.
  Future<int> markAllNotificationsAsRead({
    required String userId,
    required String userMandal,
  }) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final unreadDocs = snapshot.docs.where((doc) {
      return doc.data()['isRead'] != true;
    }).toList();

    if (unreadDocs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in unreadDocs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    return unreadDocs.length;
  }

  /// Deletes all notifications targeted at [userId] using a Firestore
  /// batch write.
  Future<int> deleteAllNotifications({
    required String userId,
    required String userMandal,
  }) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final docs = snapshot.docs.toList();

    if (docs.isEmpty) return 0;

    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    return docs.length;
  }
}
