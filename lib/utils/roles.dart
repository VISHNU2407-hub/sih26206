/// SATS Disaster — role model.
///
/// Roles are stored on the `users/{uid}` document in the `role` field.
///
/// SECURITY:
/// - Ordinary sign-up must always create a `citizen` (enforced by Firestore
///   rules: create is only allowed with role == 'citizen').
/// - Authority / rescue roles are provisioned out-of-band (Firebase console or
///   the controlled seed script using the Admin SDK, which bypasses rules).
/// - Firestore rules make `role` immutable after creation for client writes.
class AppRoles {
  AppRoles._();

  /// Regular villager. Can receive alerts, report incidents, view shelters.
  static const String citizen = 'citizen';

  /// Village-level operator. Manages their village: triages incidents,
  /// maintains shelter/preparedness data, composes village-scope alerts.
  static const String villageAuthority = 'village_authority';

  /// Mandal/district-level disaster authority. Sees the whole situation
  /// across villages, composes mandal/district-scope alerts.
  static const String districtAuthority = 'district_authority';

  /// Response team member (assigned incidents, rescue coordination).
  /// Reserved for later phases; already valid in rules.
  static const String rescue = 'rescue';

  /// Legacy admin role from the pre-disaster SATS app.
  /// Kept for backwards compatibility with existing documents; treated as a
  /// full district-level authority. Do NOT assign to new accounts.
  static const String legacyAdmin = 'admin';

  /// All roles accepted in Firestore rules.
  static const List<String> all = [
    citizen,
    villageAuthority,
    districtAuthority,
    rescue,
    legacyAdmin,
  ];

  /// Roles that may write disaster data (disasters, shelters, preparedness)
  /// and triage incidents.
  static const List<String> authorityRoles = [
    villageAuthority,
    districtAuthority,
    legacyAdmin,
  ];

  /// Roles used for querying authority users from Firestore.
  ///
  /// Includes `rescue`: response teams are given the Incident feed in the app,
  /// so they must be part of the incident-notification fan-out
  /// (`DisasterService.getAuthorityUsersForArea`). Kept as a distinct constant
  /// from [authorityRoles] only for call-site clarity.
  ///
  /// Note: Firestore `in` / `whereIn` allows up to 30 values, so this list has
  /// plenty of headroom.
  static const List<String> authorityRolesForQuery = [
    villageAuthority,
    districtAuthority,
    rescue,
    legacyAdmin,
  ];

  static bool isCitizen(String? role) => role == citizen;

  /// Village or district authority (includes legacy admin).
  static bool isAuthority(String? role) => authorityRoles.contains(role);

  /// District-level authority: sees all villages, composes wide-scope alerts.
  static bool isDistrictLevel(String? role) =>
      role == districtAuthority || role == legacyAdmin;

  /// Roles allowed to self-assign at sign-up.
  static const List<String> selfServiceRoles = [citizen];

  /// Display label for a role.
  static String label(String role) {
    switch (role) {
      case villageAuthority:
        return 'Village Authority';
      case districtAuthority:
        return 'District Authority';
      case rescue:
        return 'Rescue Team';
      case legacyAdmin:
        return 'Administrator';
      case citizen:
      default:
        return 'Citizen';
    }
  }
}
