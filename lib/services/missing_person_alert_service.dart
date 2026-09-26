import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/missing_person_alert_model.dart';

class MissingPersonAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _firestore.collection('missing_person_alerts');

  Future<void> createAlert(MissingPersonAlertModel alert) async {
    await _alerts.doc(alert.id).set(alert.toFirestore());
    await _createMissingPersonNotifications(alert);
  }

  Future<void> updateAlert(MissingPersonAlertModel alert) async {
    await _alerts.doc(alert.id).update({
      'createdBy': alert.createdBy,
      'createdByName': alert.createdByName,
      'userVillage': alert.userVillage,
      'userMandal': alert.userMandal,
      'photoUrl': alert.photoUrl,
      'fullName': alert.fullName,
      'age': alert.age,
      'gender': alert.gender,
      'lastSeenLocation': alert.lastSeenLocation,
      'missingDateTime': Timestamp.fromDate(alert.missingDateTime),
      'clothesDescription': alert.clothesDescription,
      'additionalNotes': alert.additionalNotes,
      'guardianContactNumber': alert.guardianContactNumber,
      'whatsappNumber': alert.whatsappNumber,
      'status': alert.status,
      'foundAt': alert.foundAt == null ? null : Timestamp.fromDate(alert.foundAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<MissingPersonAlertModel>> getAlertsStream() {
    return _alerts.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => MissingPersonAlertModel.fromFirestore(doc.data(), doc.id))
          .whereType<MissingPersonAlertModel>()
          .toList();
    });
  }

  Future<void> markFoundSafe(String alertId) async {
    await _alerts.doc(alertId).update({
      'status': 'found_safe',
      'foundAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify the alert creator that it was marked found safe
    try {
      final alertDoc = await _alerts.doc(alertId).get();
      if (alertDoc.exists) {
        final data = alertDoc.data()!;
        final createdBy = data['createdBy'] as String?;
        final fullName = data['fullName'] as String? ?? 'Person';
        if (createdBy != null && createdBy.isNotEmpty) {
          final notificationId = 'found_safe_${alertId}_$createdBy';
          await _firestore.collection('notifications').doc(notificationId).set({
            'title': 'Found Safe',
            'body': '$fullName has been marked as found safe.',
            'type': 'missing_person',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'targetMandal': data['userMandal'] ?? '',
            'targetUserId': createdBy,
            'relatedDocumentId': alertId,
            'relatedAlertId': alertId,
          });
        }
      }
    } catch (e) {
      // Log but do not fail the found-safe update if notification creation fails
      print('Error creating found-safe notification: $e');
    }
  }

  Future<void> deleteAlert(String alertId) async {
    await _alerts.doc(alertId).delete();
  }

  Future<void> _createMissingPersonNotifications(
    MissingPersonAlertModel alert,
  ) async {
    final usersSnapshot = await _firestore
        .collection('users')
        .where('village', isEqualTo: alert.userMandal)
        .get();

    if (usersSnapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();

    for (final userDoc in usersSnapshot.docs) {
      final targetUserId = userDoc.id;
      if (targetUserId == alert.createdBy) {
        continue;
      }
      final notificationId = 'missing_${alert.id}_$targetUserId';
      final notificationRef = _firestore
          .collection('notifications')
          .doc(notificationId);

      batch.set(notificationRef, {
        'title': 'Missing Person Alert',
        'body': '${alert.fullName} reported missing in your mandal',
        'type': 'missing_person',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetMandal': alert.userMandal,
        'targetUserId': targetUserId,
        'relatedDocumentId': alert.id,
        'relatedAlertId': alert.id,
      });
    }

    await batch.commit();
  }
}
