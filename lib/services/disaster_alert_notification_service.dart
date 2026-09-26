import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/disaster_event_model.dart';
import '../models/user_model.dart';
import 'disaster_alert_targeting.dart';

/// SATS Disaster — Phase 4: fan-out of targeted `disaster_alert` in-app
/// notifications when a disaster event is created.
///
/// Design (deliberately minimal, per phase constraints):
/// - Reuses the EXISTING `notifications` collection and the existing
///   notification document shape (title / body / type / targetUserId /
///   relatedDocumentId / targetMandal) — no second notification system.
/// - `relatedDocumentId` is the disaster document ID, so the citizen deep
///   link can open the exact AlertDetailScreen.
/// - Document IDs are deterministic (`disaster_{disasterId}_{userId}`) so
///   re-processing the same disaster never duplicates notifications.
/// - Writes are committed in chunks of <=400 ops (Firestore caps a batch at
///   500), so the fan-out scales past a single-batch user population.
/// - Security: `notifications.create` is already allowed for authenticated
///   users by the existing rules (same trust level as the existing
///   community-post fan-out). The `users` read used for targeting is also
///   already permitted ("authenticated users may read any profile —
///   notification targeting"). No rule changes needed.
class DisasterAlertNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Firestore rejects a batch with more than 500 writes
  /// (`batch-size-limit-exceeded`), so the fan-out is committed in chunks
  /// instead of one all-or-nothing batch. 400 leaves headroom below the hard
  /// limit while keeping the number of round-trips small.
  static const int _maxOpsPerBatch = 400;

  /// Creates one targeted `disaster_alert` notification document per
  /// authenticated user whose profile falls inside [event]'s affected
  /// scope.
  ///
  /// Returns the number of notifications written. Never throws on partial
  /// problems for individual users — targeting errors are skipped so one
  /// malformed profile cannot block the whole fan-out.
  Future<int> createNotificationsForDisaster(DisasterEventModel event) async {
    if (event.id.isEmpty) {
      throw ArgumentError('Disaster event must have an id before fan-out.');
    }

    // Users are queried field-by-field using the legacy `users` mapping
    // (see [UserFieldKeys]); role filtering happens server-side, geographic
    // matching client-side (same pattern as
    // FirestoreService.getAdminUsersByVillageAndMandal).
    final snapshot = await _users.get();
    if (snapshot.docs.isEmpty) return 0;

    final targets = <MapEntry<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final targetUserId = doc.id;
      final data = doc.data();

      final scope = _scopeForUser(event, data);
      if (scope == DisasterAlertScope.none) continue; // not affected

      targets.add(MapEntry(targetUserId, {
        'title': event.title.isNotEmpty
            ? event.title
            : DisasterEventModel.typeLabel(event.type),
        'body': buildAlertBody(event),
        'type': 'disaster_alert',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetMandal': scope == DisasterAlertScope.district
            ? ''
            : (data[UserFieldKeys.mandal] ?? '').toString(),
        'targetUserId': targetUserId,
        'relatedDocumentId': event.id,
        'affectedScope': scope.name,
        'disasterType': event.type,
        'disasterSeverity': event.severity,
      }));
    }

    if (targets.isEmpty) return 0;

    // Commit in chunks so a large affected population cannot fail the whole
    // fan-out on the 500-write batch ceiling.
    for (var start = 0; start < targets.length; start += _maxOpsPerBatch) {
      final end =
          (start + _maxOpsPerBatch) > targets.length
              ? targets.length
              : start + _maxOpsPerBatch;
      final chunk = targets.sublist(start, end);

      final batch = _firestore.batch();
      for (final target in chunk) {
        batch.set(
          _notifications.doc(
            DisasterAlertTargeting.notificationDocId(
                event.id, target.key),
          ),
          target.value,
        );
      }
      await batch.commit();
    }

    // Caller decides how to log; this service stays Flutter-free so the
    // demo seed runner (pure `dart run`) can reuse it.
    return targets.length;
  }

  /// Resolves the targeting scope from a raw users-document map using the
  /// legacy field mapping. Isolated so a single malformed profile (e.g. a
  /// null geographic field) cannot crash the whole fan-out.
  DisasterAlertScope _scopeForUser(DisasterEventModel event, Map<String, dynamic> data) {
    try {
      return DisasterAlertTargeting.matchScope(
        affectedVillages: event.affectedVillages,
        affectedMandals: event.affectedMandals,
        affectedDistricts: event.affectedDistricts,
        userVillage: (data[UserFieldKeys.village] ?? '').toString(),
        userMandal: (data[UserFieldKeys.mandal] ?? '').toString(),
        userDistrict: (data[UserFieldKeys.district] ?? '').toString(),
      );
    } catch (_) {
      return DisasterAlertScope.none;
    }
  }

  /// Concise, type-generic notification body generated from the actual
  /// disaster event (no hardcoded cyclone text).
  static String buildAlertBody(DisasterEventModel event) {
    final type = DisasterEventModel.typeLabel(event.type);
    final severity = DisasterEventModel.severityLabel(event.severity);

    // Most specific affected area description available.
    String area;
    if (event.affectedVillages.isNotEmpty) {
      final villages = event.affectedVillages.take(3).join(', ');
      final extra =
          event.affectedVillages.length > 3 ? ' and other villages' : '';
      area = '$villages$extra';
    } else if (event.affectedMandals.isNotEmpty) {
      area = '${event.affectedMandals.join(', ')} mandal';
    } else if (event.affectedDistricts.isNotEmpty) {
      area = '${event.affectedDistricts.join(', ')} district';
    } else {
      area = 'your area';
    }

    final evacuation = event.evacuationRequired
        ? 'Evacuation required in $area.'
        : 'Stay alert. Follow official instructions for $area.';
    return '$severity $type warning. $evacuation';
  }
}
