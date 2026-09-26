import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SATS Disaster — incident draft persistence (low-connectivity support).
///
/// The report-incident form autosaves its state here so a citizen's typed
/// data survives app kills and connectivity drops. NOTE: this is DRAFT
/// persistence only — actual submission requires connectivity and is NOT
/// queued offline (the submission UX must not claim otherwise).
class IncidentDraftService {
  IncidentDraftService._();

  static const String _storageKey = 'sats_disaster_incident_draft_v1';

  /// Serializable snapshot of the report form.
  static Map<String, dynamic> formToDraft({
    required String incidentType,
    required String severity,
    required String description,
    required int affectedPeople,
    required bool rescueRequired,
    required int rescuePeopleCount,
    required bool medicalRequired,
    required List<String> resourcesRequired,
    String? photoPath,
    double? latitude,
    double? longitude,
  }) {
    return {
      'incidentType': incidentType,
      'severity': severity,
      'description': description,
      'affectedPeople': affectedPeople,
      'rescueRequired': rescueRequired,
      'rescuePeopleCount': rescuePeopleCount,
      'medicalRequired': medicalRequired,
      'resourcesRequired': resourcesRequired,
      if (photoPath != null) 'photoPath': photoPath,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Persists the draft. Silent best-effort: storage failure must never
  /// crash the reporting flow.
  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(draft));
    } catch (_) {
      // Draft persistence is best-effort.
    }
  }

  /// Returns the saved draft, or null when none exists. Corrupt drafts are
  /// discarded rather than thrown.
  static Future<Map<String, dynamic>?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// True when a non-empty draft exists (used to offer restore on reopen).
  static Future<bool> hasDraft() async {
    final draft = await loadDraft();
    if (draft == null) return false;
    final description = (draft['description'] ?? '').toString();
    return description.trim().isNotEmpty;
  }

  /// Clears the draft (called after successful submission or explicit
  /// discard).
  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Best-effort.
    }
  }
}
