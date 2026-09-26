/// SATS Disaster — geographic normalization and strict 3-level matching.
///
/// Every disaster-related item shown to citizens must pass strict 3-level
/// matching: village AND mandal AND district must all match. If even one
/// differs, the citizen must not see the item.
///
/// Normalization: lowercase → trim → remove ALL internal whitespace.
/// This is applied to BOTH the stored value and the comparison value.
class GeoMatch {
  GeoMatch._();

  /// Normalizes a geographic string for comparison.
  ///
  /// Steps:
  /// 1. Convert to lowercase
  /// 2. Trim leading/trailing whitespace
  /// 3. Remove ALL internal whitespace
  ///
  /// Examples:
  /// - "Mukkamala" → "mukkamala"
  /// - " MUKKAMALA " → "mukkamala"
  /// - "mukka mala" → "mukkamala"
  /// - "MUKKA MALA" → "mukkamala"
  /// - null → ""
  /// - "" → ""
  static String normalize(String? value) {
    if (value == null) return '';
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '');
  }

  /// Returns true if [stored] matches [comparison] after normalization.
  static bool fieldMatches(String? stored, String? comparison) {
    return normalize(stored) == normalize(comparison);
  }

  /// Strict 3-level geographic matching for items that have
  /// village/mandal/district fields (shelters, incidents, damage
  /// assessments, resources, missing person alerts).
  ///
  /// Returns true ONLY if ALL THREE fields match:
  /// - village matches AND
  /// - mandal matches AND
  /// - district matches
  ///
  /// Blank/missing fields never match (a blank stored field cannot
  /// match a non-blank comparison field, and vice versa).
  static bool matches3Level({
    required String? itemVillage,
    required String? itemMandal,
    required String? itemDistrict,
    required String? userVillage,
    required String? userMandal,
    required String? userDistrict,
  }) {
    return fieldMatches(itemVillage, userVillage) &&
        fieldMatches(itemMandal, userMandal) &&
        fieldMatches(itemDistrict, userDistrict);
  }

  /// Strict matching for disaster alerts. A disaster alert has
  /// affectedVillages/affectedMandals/affectedDistricts lists instead of
  /// a single village/mandal/district.
  ///
  /// The alert is visible to the citizen ONLY if:
  /// - affectedVillages contains the user's village, OR
  /// - affectedMandals contains the user's mandal, OR
  /// - affectedDistricts contains the user's district
  ///
  /// Each list match uses normalized comparison (case-insensitive,
  /// whitespace-insensitive). Blank user fields never match.
  static bool affectsStrict({
    required List<String> affectedVillages,
    required List<String> affectedMandals,
    required List<String> affectedDistricts,
    required String? userVillage,
    required String? userMandal,
    required String? userDistrict,
  }) {
    final uv = normalize(userVillage);
    final um = normalize(userMandal);
    final ud = normalize(userDistrict);

    if (uv.isNotEmpty &&
        affectedVillages.any((v) => normalize(v) == uv)) {
      return true;
    }
    if (um.isNotEmpty &&
        affectedMandals.any((m) => normalize(m) == um)) {
      return true;
    }
    if (ud.isNotEmpty &&
        affectedDistricts.any((d) => normalize(d) == ud)) {
      return true;
    }
    return false;
  }
}
