import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/incident_model.dart';
import '../utils/geo_match.dart';
import 'disaster_service.dart';

/// SATS Disaster — citizen incident reports and authority triage.
///
/// Firestore collection: `incidents` (see [DisasterIncidentModel]).
///
/// When an incident is reported, an in-app notification is written for
/// authority users covering the incident's area (server-side FCM fan-out
/// replaces/augments this in Phase 4). Status transitions follow
/// reported → verified → triaged → dispatched → resolved (or rejected).
class IncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DisasterService _disasterService = DisasterService();

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _firestore.collection('incidents');

  // ────────────────────────────────────────────────────────────────────────
  //  REPORTING
  // ────────────────────────────────────────────────────────────────────────

  /// Submits a citizen incident report. Returns the new incident ID.
  ///
  /// [village]/[mandal]/[district] come from the user's profile so the
  /// report is routeable even without a GPS fix (lat/lng are optional).
  Future<String> reportIncident({
    required String incidentType,
    required String severity,
    required String description,
    required String village,
    required String mandal,
    required String district,
    double? latitude,
    double? longitude,
    String? disasterId,
    int affectedPeople = 0,
    bool rescueRequired = false,
    int rescuePeopleCount = 0,
    bool medicalRequired = false,
    List<String> resourcesRequired = const [],
    List<String> media = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    final incident = DisasterIncidentModel(
      incidentType: incidentType,
      severity: severity,
      description: description,
      latitude: latitude,
      longitude: longitude,
      district: GeoMatch.normalize(district),
      mandal: GeoMatch.normalize(mandal),
      village: GeoMatch.normalize(village),
      disasterId: disasterId,
      reportedBy: user.uid,
      affectedPeople: affectedPeople,
      rescueRequired: rescueRequired,
      rescuePeopleCount: rescuePeopleCount,
      medicalRequired: medicalRequired,
      resourcesRequired: resourcesRequired,
      media: media,
      status: 'reported',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final doc = await _incidents.add(incident.toFirestore());

    // Best-effort in-app notifications for authorities of the area.
    // Never fails the report submission.
    try {
      await _notifyAuthorities(incident, doc.id);
    } catch (_) {
      // Notification fan-out is auxiliary; ignore failures here.
    }

    return doc.id;
  }

  /// Fetches one incident ("My Reports" detail / submission confirmation).
  Future<DisasterIncidentModel?> getIncident(String incidentId) async {
    final doc = await _incidents.doc(incidentId).get();
    if (!doc.exists) return null;
    return DisasterIncidentModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Writes in-app notifications for authority users matching the incident
  /// area. Deduplicated by deterministic document ID so re-submits and
  /// duplicate reports do not spam duplicates.
  Future<void> _notifyAuthorities(
    DisasterIncidentModel incident,
    String incidentId,
  ) async {
    final authorityUsers = await _disasterService.getAuthorityUsersForArea(
      village: incident.village,
      mandal: incident.mandal,
      district: incident.district,
    );

    if (authorityUsers.isEmpty) return;

    final batch = _firestore.batch();
    for (final authority in authorityUsers) {
      final uid = authority['uid']?.toString();
      if (uid == null || uid.isEmpty || uid == incident.reportedBy) continue;

      final notificationId = 'incident_${incidentId}_$uid';
      batch.set(
        _firestore.collection('notifications').doc(notificationId),
        {
          'title': 'New Incident Reported',
          'body': '${DisasterIncidentModel.typeLabel(incident.incidentType)}'
              ' in ${incident.village}'
              '${incident.rescueRequired ? ' — RESCUE REQUIRED' : ''}',
          'type': 'incident',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'targetMandal': incident.mandal,
          'targetUserId': uid,
          'relatedDocumentId': incidentId,
        },
      );
    }
    await batch.commit();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  STREAMS
  // ────────────────────────────────────────────────────────────────────────

  /// Real-time incident feed for a village (authority dashboard).
  Stream<List<DisasterIncidentModel>> getIncidentsForVillageStream(
    String village,
  ) {
    return _incidents
        .where('village', isEqualTo: GeoMatch.normalize(village))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapIncidentDocs);
  }

  /// Real-time incident feed for a mandal.
  Stream<List<DisasterIncidentModel>> getIncidentsForMandalStream(
    String mandal,
  ) {
    return _incidents
        .where('mandal', isEqualTo: GeoMatch.normalize(mandal))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapIncidentDocs);
  }

  /// Real-time incident feed for a district.
  Stream<List<DisasterIncidentModel>> getIncidentsForDistrictStream(
    String district,
  ) {
    return _incidents
        .where('district', isEqualTo: GeoMatch.normalize(district))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapIncidentDocs);
  }

  /// Incidents reported by one user (citizen "My Reports").
  Stream<List<DisasterIncidentModel>> getIncidentsByReporterStream(
    String userId,
  ) {
    return _incidents
        .where('reportedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapIncidentDocs);
  }

  /// Incidents linked to a disaster event.
  Stream<List<DisasterIncidentModel>> getIncidentsForDisasterStream(
    String disasterId,
  ) {
    return _incidents
        .where('disasterId', isEqualTo: disasterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapIncidentDocs);
  }

  // ────────────────────────────────────────────────────────────────────────
  //  TRIAGE
  // ────────────────────────────────────────────────────────────────────────

  /// Authority status transition. Rules restrict updates to authority roles
  /// (and the reporter's own status is never changed here).
  Future<void> updateIncidentStatus(
    String incidentId,
    String status, {
    String? assignedTo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    await _incidents.doc(incidentId).update({
      'status': status,
      'assignedTo': assignedTo,
      'updatedBy': user?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify the reporter that their incident progressed.
    try {
      final doc = await _incidents.doc(incidentId).get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final reporter = (data['reportedBy'] ?? '').toString();
      if (reporter.isEmpty || reporter == user?.uid) return;

      await _firestore.collection('notifications').doc(
            'incident_status_${incidentId}_$status',
          ).set({
        'title': 'Incident Update',
        'body':
            'Your report is now: ${DisasterIncidentModel.statusLabel(status)}',
        'type': 'incident',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetMandal': data['mandal'] ?? '',
        'targetUserId': reporter,
        'relatedDocumentId': incidentId,
      });
    } catch (_) {
      // Auxiliary notification — ignore failures.
    }
  }

  List<DisasterIncidentModel> _mapIncidentDocs(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => DisasterIncidentModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .whereType<DisasterIncidentModel>()
        .toList();
  }
}
