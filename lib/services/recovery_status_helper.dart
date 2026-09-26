import '../models/damage_assessment_model.dart';
import '../models/disaster_event_model.dart';
import '../models/incident_model.dart';
import '../models/resource_model.dart';
import '../models/shelter_model.dart';

/// SATS Disaster — Phase 5: recovery status derivation.
///
/// Pure functions (no Firestore, no Flutter) deriving a village's position
/// in the disaster lifecycle — BEFORE → DURING → AFTER — from actual stored
/// data. No separate state machine: the display status is computed from
/// incidents, damage assessments, resources and shelters each time.
class RecoveryStatusHelper {
  RecoveryStatusHelper._();

  /// Display statuses for "where is this village in the recovery process?"
  ///
  /// affected  — damage exists / people affected, response is running
  /// response  — unresolved incidents or critical damage dominate
  /// recovery  — incidents handled, damage still being repaired, relief moving
  /// restored  — nothing unresolved; all recorded damage recovered
  static const String statusAffected = 'affected';
  static const String statusResponse = 'response';
  static const String statusRecovery = 'recovery';
  static const String statusRestored = 'restored';

  /// Derives the recovery status for one village from its stored records.
  static String deriveForVillage({
    required List<DisasterIncidentModel> incidents,
    required List<DamageAssessmentModel> damage,
    required List<ResourceModel> resources,
    required List<ShelterModel> shelters,
  }) {
    final openIncidents =
        incidents.where((i) => i.needsResponse).toList();
    final unresolvedDamage =
        damage.where((d) => !d.isResolved).toList();
    final resourceShortages =
        resources.where((r) => r.shortfall > 0 && !r.isExhausted).toList();

    // Still dealing with the emergency itself.
    if (openIncidents.isNotEmpty) return statusResponse;

    // Nothing recorded at all — either untouched or genuinely quiet.
    if (damage.isEmpty && resources.isEmpty) {
      return shelters.any((s) => s.occupancy > 0)
          ? statusResponse
          : statusRestored;
    }

    // Damage all recovered and no shortages → restored.
    if (unresolvedDamage.isEmpty && resourceShortages.isEmpty) {
      return statusRestored;
    }

    // Incidents handled but damage/relief work remains.
    return statusRecovery;
  }

  /// Label for a derived status.
  static String label(String status) {
    switch (status) {
      case statusAffected:
        return 'Affected';
      case statusResponse:
        return 'Response Ongoing';
      case statusRecovery:
        return 'In Recovery';
      case statusRestored:
        return 'Restored';
      default:
        return status;
    }
  }

  /// Progress through the lifecycle (0.0 – 1.0) for compact UI meters.
  /// affected/response → recovery → restored.
  static double progress(String status) {
    switch (status) {
      case statusAffected:
        return 0.1;
      case statusResponse:
        return 0.35;
      case statusRecovery:
        return 0.7;
      case statusRestored:
        return 1.0;
      default:
        return 0.0;
    }
  }

  /// Overall recovery status across a whole disaster event: derived from the
  /// linked damage assessments, resources and incidents.
  static String deriveForDisaster({
    required DisasterEventModel disaster,
    required List<DisasterIncidentModel> incidents,
    required List<DamageAssessmentModel> damage,
    required List<ResourceModel> resources,
  }) {
    if (disaster.isClosed) {
      return damage.every((d) => d.isResolved) ? statusRestored : statusRecovery;
    }
    return deriveForVillage(
      incidents: incidents,
      damage: damage,
      resources: resources,
      shelters: const [],
    );
  }
}
