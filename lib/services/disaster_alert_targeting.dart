import '../models/disaster_event_model.dart';
import '../models/user_model.dart';
import '../utils/geo_match.dart';

/// SATS Disaster — Phase 4: deterministic geographic targeting for
/// `disaster_alert` in-app notifications.
///
/// Given a disaster event's affected-area lists (villages / mandals /
/// districts) and a user profile, decides whether that user is inside the
/// affected scope and at which level. Pure string logic — no Firestore, no
/// Flutter — so it is trivially unit-testable.
///
/// Matching rules (most specific scope wins, mirroring
/// [DisasterEventModel.affects] and `DisasterService.pickActiveDisaster`):
///   1. affectedVillages contains the user's village  → `village`
///   2. affectedMandals  contains the user's mandal   → `mandal`
///   3. affectedDistricts contains the user's district → `district`
///   4. otherwise                                     → `none`
///
/// Comparison uses [GeoMatch.normalize] for whitespace/case insensitivity;
/// blank user fields never match.
class DisasterAlertTargeting {
  DisasterAlertTargeting._();

  static bool _listHas(List<String> list, String? value) {
    if (value == null || value.isEmpty) return false;
    final v = GeoMatch.normalize(value);
    return list.any((item) => GeoMatch.normalize(item) == v);
  }

  /// Resolves the targeting scope for a user against a disaster's
  /// affected areas.
  static DisasterAlertScope matchScope({
    required List<String> affectedVillages,
    required List<String> affectedMandals,
    required List<String> affectedDistricts,
    required String? userVillage,
    required String? userMandal,
    required String? userDistrict,
  }) {
    if (_listHas(affectedVillages, userVillage)) {
      return DisasterAlertScope.village;
    }
    if (_listHas(affectedMandals, userMandal)) {
      return DisasterAlertScope.mandal;
    }
    if (_listHas(affectedDistricts, userDistrict)) {
      return DisasterAlertScope.district;
    }
    return DisasterAlertScope.none;
  }

  /// Convenience wrapper taking the model objects used by the app.
  /// Reads only geographic fields from [user] (legacy mapping already
  /// normalized by [UserModel]).
  static DisasterAlertScope matchScopeFor({
    required DisasterEventModel disaster,
    required UserModel user,
  }) {
    return matchScope(
      affectedVillages: disaster.affectedVillages,
      affectedMandals: disaster.affectedMandals,
      affectedDistricts: disaster.affectedDistricts,
      userVillage: user.village,
      userMandal: user.mandal,
      userDistrict: user.district,
    );
  }

  /// Deterministic notification document ID for a (disaster, user) pair.
  ///
  /// Using a derived ID instead of a random one guarantees that
  /// re-processing the same disaster never creates duplicate notifications
  /// for the same citizen — the second write simply overwrites the same
  /// document (mirrors the existing `community_{postId}_{userId}`
  /// convention in FirestoreService).
  static String notificationDocId(String disasterId, String userId) =>
      'disaster_${disasterId}_$userId';
}

/// Result of [DisasterAlertTargeting.matchScope].
enum DisasterAlertScope {
  /// User's village is explicitly listed — most specific.
  village,

  /// Village not listed but the user's mandal is.
  mandal,

  /// Only the user's district is listed — widest scope.
  district,

  /// User is not in the affected scope — no notification.
  none,
}
