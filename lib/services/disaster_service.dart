import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/disaster_event_model.dart';
import '../models/shelter_model.dart';
import '../models/user_model.dart';
import '../models/village_preparedness_model.dart';
import '../utils/geo_match.dart';
import '../utils/roles.dart';
import 'disaster_alert_notification_service.dart';

/// SATS Disaster — Firestore access for disaster events, shelters and
/// village preparedness.
///
/// Geographic identity uses the user profile values (district / mandal /
/// village). NOTE the legacy users-document field mapping (see
/// [UserFieldKeys]): this service receives correct Dart-side values from
/// [UserModel] and never reads raw `users` fields itself.
class DisasterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _disasters =>
      _firestore.collection('disasters');
  CollectionReference<Map<String, dynamic>> get _shelters =>
      _firestore.collection('shelters');
  CollectionReference<Map<String, dynamic>> get _preparedness =>
      _firestore.collection('preparedness');

  // ────────────────────────────────────────────────────────────────────────
  //  DISASTER EVENTS
  // ────────────────────────────────────────────────────────────────────────

  /// Creates a disaster event. Caller must be an authority (enforced by
  /// Firestore rules; the app UI must also gate this).
  ///
  /// Phase 4: after the event is saved, targeted `disaster_alert` in-app
  /// notifications are fanned out to users inside the affected geographic
  /// scope. Notification failures never fail the alert creation itself —
  /// the alert is already live via realtime streams.
  Future<String> createDisasterEvent(DisasterEventModel event) async {
    final doc = await _disasters.add(event.toFirestore());

    try {
      final created = DisasterEventModel.fromFirestore(
        event.toFirestore()..['id'] = doc.id,
        doc.id,
      );
      if (created != null) {
        final sent = await DisasterAlertNotificationService()
            .createNotificationsForDisaster(created);
        debugPrint(
          'createDisasterEvent - $sent targeted disaster_alert '
          'notification(s) sent for "${event.title}".',
        );
      }
    } catch (e) {
      // Log but never fail alert creation due to notification errors.
      debugPrint('createDisasterEvent - notification fan-out skipped: $e');
    }

    return doc.id;
  }

  /// Updates an existing disaster event (status transitions, edits).
  ///
  /// Writes through [DisasterEventModel.toFirestoreUpdate], which never
  /// sends `createdAt` / `createdBy` — the document ID and creation audit
  /// fields are preserved automatically. Editing does NOT fan out
  /// notifications; targeted fan-out only happens on creation so citizens
  /// never receive a duplicate alert when an authority tweaks wording.
  Future<void> updateDisasterEvent(
    String disasterId,
    DisasterEventModel event,
  ) async {
    await _disasters.doc(disasterId).update(event.toFirestoreUpdate());
  }

  /// Marks an existing alert closed using the existing lifecycle value
  /// ('closed'). The document is never deleted — history is preserved and
  /// [DisasterEventModel.isActive] simply stops matching it.
  ///
  /// Returns `false` when the alert was already closed (no second write,
  /// no second `endedAt`), so the UI can tell the authority instead of
  /// silently overwriting history.
  Future<bool> closeDisasterEvent(String disasterId) async {
    final doc = await _disasters.doc(disasterId).get();
    if (!doc.exists) {
      throw StateError('Disaster alert not found');
    }
    final current = DisasterEventModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
    if (current == null || current.isClosed) {
      return false;
    }

    await _disasters.doc(disasterId).update({
      'status': 'closed',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Validation shared by the alert edit path. Field rules mirror what the
  /// composer enforces at creation; call before any update write.
  static String? validateEventUpdate(DisasterEventModel event) {
    if (event.title.trim().isEmpty) {
      return 'Alert title is required';
    }
    const allowedTypes = [
      'cyclone', 'flood', 'fire', 'earthquake', 'landslide',
      'infrastructure_collapse', 'other',
    ];
    if (!allowedTypes.contains(event.type)) {
      return 'Unknown disaster type';
    }
    const allowedSeverities = ['low', 'medium', 'high', 'critical'];
    if (!allowedSeverities.contains(event.severity)) {
      return 'Unknown severity';
    }
    const allowedStatuses = ['monitoring', 'active', 'contained', 'closed'];
    if (!allowedStatuses.contains(event.status)) {
      return 'Unknown lifecycle status';
    }
    return null;
  }

  /// Streams all non-closed disaster events, newest first.
  /// Used by the citizen home (filtered client-side to the user's area) and
  /// by the authority dashboard (all events).
  Stream<List<DisasterEventModel>> getActiveDisastersStream() {
    return _disasters
        .where('status', whereIn: ['monitoring', 'active', 'contained'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDisasterDocs);
  }

  /// Streams every disaster event (including closed), newest first.
  /// Used for the authority overview / history.
  Stream<List<DisasterEventModel>> getAllDisastersStream() {
    return _disasters
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDisasterDocs);
  }

  /// Streams disaster events affecting the given geographic identity.
  /// Client-side `affects()` filtering — the affected-village arrays cannot
  /// be queried with array-contains-any across three fields in one query.
  Stream<List<DisasterEventModel>> getDisastersForAreaStream({
    required String? village,
    required String? mandal,
    required String? district,
  }) {
    return getActiveDisastersStream().map((events) => events
        .where((e) => e.affects(
              village: village,
              mandal: mandal,
              district: district,
            ))
        .toList());
  }

  /// The single most relevant active disaster for a citizen's area, or null
  /// when nothing affects them ("No Active Disaster" state).
  ///
  /// Deterministic ordering (most specific scope first) so the same input
  /// always picks the same event — see [pickActiveDisaster].
  Stream<DisasterEventModel?> getPrimaryDisasterForAreaStream({
    required String? village,
    required String? mandal,
    required String? district,
  }) {
    return getDisastersForAreaStream(
      village: village,
      mandal: mandal,
      district: district,
    ).map((events) => pickActiveDisaster(
          events,
          village: village,
          mandal: mandal,
          district: district,
        ));
  }

  Future<DisasterEventModel?> getDisasterEvent(String disasterId) async {
    final doc = await _disasters.doc(disasterId).get();
    if (!doc.exists) return null;
    return DisasterEventModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  List<DisasterEventModel> _mapDisasterDocs(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => DisasterEventModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .whereType<DisasterEventModel>()
        .toList();
  }

  /// Deterministically selects the most relevant active disaster for an
  /// area from the candidate list.
  ///
  /// Ranking (most specific scope wins):
  ///   1. Disaster explicitly listing the VILLAGE
  ///   2. Disaster listing the MANDAL
  ///   3. Disaster listing the DISTRICT only
  /// Ties are broken by severity, then by newest createdAt, then by id —
  /// so multiple matching events never attach an incident to a random one.
  static DisasterEventModel? pickActiveDisaster(
    List<DisasterEventModel> events, {
    required String? village,
    required String? mandal,
    required String? district,
  }) {
    if (events.isEmpty) return null;

    int scopeRank(DisasterEventModel e) {
      final v = GeoMatch.normalize(village);
      if (v.isNotEmpty &&
          e.affectedVillages.any((x) => GeoMatch.normalize(x) == v)) {
        return 0;
      }
      final m = GeoMatch.normalize(mandal);
      if (m.isNotEmpty &&
          e.affectedMandals.any((x) => GeoMatch.normalize(x) == m)) {
        return 1;
      }
      return 2;
    }

    int severityRank(String severity) {
      switch (severity) {
        case 'critical':
          return 0;
        case 'high':
          return 1;
        case 'medium':
          return 2;
        default:
          return 3;
      }
    }

    final sorted = [...events]..sort((a, b) {
        final byScope = scopeRank(a).compareTo(scopeRank(b));
        if (byScope != 0) return byScope;
        final bySeverity =
            severityRank(a.severity).compareTo(severityRank(b.severity));
        if (bySeverity != 0) return bySeverity;
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });

    return sorted.first;
  }

  // ────────────────────────────────────────────────────────────────────────
  //  SHELTERS
  // ────────────────────────────────────────────────────────────────────────

  /// Streams shelters for one village.
  Stream<List<ShelterModel>> getSheltersForVillageStream(String village) {
    return _shelters
        .where('village', isEqualTo: GeoMatch.normalize(village))
        .snapshots()
        .map(_mapShelterDocs);
  }

  /// Streams all shelters in a mandal.
  Stream<List<ShelterModel>> getSheltersForMandalStream(String mandal) {
    return _shelters
        .where('mandal', isEqualTo: GeoMatch.normalize(mandal))
        .snapshots()
        .map(_mapShelterDocs);
  }

  /// Streams every shelter (authority overview).
  Stream<List<ShelterModel>> getAllSheltersStream() {
    return _shelters.snapshots().map(_mapShelterDocs);
  }

  Future<String> createShelter(ShelterModel shelter) async {
    final doc = await _shelters.add(shelter.toFirestore());
    return doc.id;
  }

  /// Updates shelter capacity/occupancy/status. Authority-only (rules).
  Future<void> updateShelter(String shelterId, ShelterModel shelter) async {
    await _shelters.doc(shelterId).update(shelter.toFirestoreUpdate());
  }

  List<ShelterModel> _mapShelterDocs(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) =>
            ShelterModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .whereType<ShelterModel>()
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  PREPAREDNESS
  // ────────────────────────────────────────────────────────────────────────

  /// Streams the preparedness record for a village (document id is the
  /// village key). Emits an empty list when the village has no record.
  Stream<List<VillagePreparednessModel>> getPreparednessForVillageStream(
    String village,
  ) {
    return _preparedness
        .doc(VillagePreparednessModel.keyFor(village))
        .snapshots()
        .map((doc) {
      if (!doc.exists) return const <VillagePreparednessModel>[];
      final model = VillagePreparednessModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
      return model == null
          ? const <VillagePreparednessModel>[]
          : <VillagePreparednessModel>[model];
    });
  }

  /// Writes (upserts) a village preparedness record. Authority-only (rules).
  Future<void> savePreparedness(VillagePreparednessModel record) async {
    await _preparedness
        .doc(record.villageKey)
        .set(record.toFirestore(), SetOptions(merge: true));
  }

  /// Fetches preparedness records for all villages of a mandal
  /// (district/mandal authority overview).
  Future<List<VillagePreparednessModel>> getPreparednessForMandal(
    String mandal,
  ) async {
    final snapshot = await _preparedness
        .where('mandal', isEqualTo: mandal)
        .get();
    return snapshot.docs
        .map((doc) => VillagePreparednessModel.fromFirestore(
              doc.data(),
              doc.id,
            ))
        .whereType<VillagePreparednessModel>()
        .toList();
  }

  // ────────────────────────────────────────────────────────────────────────
  //  AUTHORITY LOOKUP
  // ────────────────────────────────────────────────────────────────────────

  /// Loads authority users (village_authority / district_authority / legacy
  /// admin) matching the given geographic identity. Used by Phase 4's
  /// server-side fan-out and for incident notification routing.
  ///
  /// Matching is done client-side on normalized strings to avoid a
  /// three-field composite index, mirroring
  /// [FirestoreService.getAdminUsersByVillageAndMandal].
  Future<List<Map<String, dynamic>>> getAuthorityUsersForArea({
    String? village,
    String? mandal,
    String? district,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .where(UserFieldKeys.role, whereIn: AppRoles.authorityRolesForQuery)
        .get();

    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .where((data) {
      if (district != null && district.isNotEmpty) {
        if (!GeoMatch.fieldMatches(data['district'], district)) return false;
      }
      if (mandal != null && mandal.isNotEmpty) {
        // Legacy field: users docs store the mandal name in 'village'.
        if (!GeoMatch.fieldMatches(data[UserFieldKeys.mandal], mandal)) return false;
      }
      if (village != null && village.isNotEmpty) {
        // Legacy field: users docs store the village name in 'street'.
        final v = GeoMatch.normalize(data[UserFieldKeys.village]);
        // Village-level authority may cover a whole mandal (empty village
        // field) — include them for mandal/district scope.
        if (v.isNotEmpty && v != GeoMatch.normalize(village)) return false;
      }
      return true;
    }).toList();
  }
}
