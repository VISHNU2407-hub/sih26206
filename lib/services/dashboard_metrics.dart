import '../models/disaster_event_model.dart';
import '../models/incident_model.dart';
import '../models/shelter_model.dart';
import 'disaster_service.dart';

/// SATS Disaster — command dashboard metrics.
///
/// Pure functions (no Firestore) so the counters and incident ordering are
/// unit-testable. The dashboard feeds these from realtime streams.
class DashboardMetrics {
  DashboardMetrics._();

  /// Count of incidents that still need a response
  /// (not resolved, not rejected/invalid).
  static int activeIncidents(List<DisasterIncidentModel> incidents) =>
      incidents.where((i) => i.needsResponse).length;

  /// Count of unresolved incidents with critical severity.
  static int criticalIncidents(List<DisasterIncidentModel> incidents) =>
      incidents
          .where((i) => i.needsResponse && i.severity == 'critical')
          .length;

  /// Total people affected across unresolved incidents.
  static int peopleAffected(List<DisasterIncidentModel> incidents) =>
      incidents.where((i) => i.needsResponse).fold(0, (sum, i) => sum + i.affectedPeople);

  /// People explicitly awaiting rescue across unresolved incidents.
  static int peopleAwaitingRescue(List<DisasterIncidentModel> incidents) =>
      incidents
          .where((i) => i.needsResponse && i.rescueRequired)
          .fold(0, (sum, i) => sum + i.rescuePeopleCount);

  /// Shelters at/near capacity (>= 80% occupancy but not closed).
  static int sheltersWithLimitedCapacity(List<ShelterModel> shelters) =>
      shelters
          .where((s) =>
              s.status != 'closed' &&
              s.occupancyPercent != null &&
              s.occupancyPercent! >= 80)
          .length;

  /// Count of closed shelters.
  static int closedShelters(List<ShelterModel> shelters) =>
      shelters.where((s) => s.status == 'closed').length;

  /// Total available shelter spaces across open shelters.
  static int availableShelterSpaces(List<ShelterModel> shelters) =>
      shelters.fold(0, (sum, s) => sum + s.availableSpace);

  /// Authority feed ordering: severity first (critical on top), then
  /// newest. Unresolved incidents always rank above resolved/rejected ones
  /// so the work queue stays on top.
  static List<DisasterIncidentModel> sortForAuthorityFeed(
    List<DisasterIncidentModel> incidents,
  ) {
    final sorted = [...incidents]..sort((a, b) {
        final byOpen = (a.isResolved ? 1 : 0).compareTo(b.isResolved ? 1 : 0);
        if (byOpen != 0) return byOpen;
        final bySeverity =
            DisasterIncidentModel.severityRank(a.severity)
                .compareTo(DisasterIncidentModel.severityRank(b.severity));
        if (bySeverity != 0) return bySeverity;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
  }

  /// The single most relevant active disaster for an area (delegates to the
  /// deterministic Phase 2 picker; re-exported here for dashboard use).
  static DisasterEventModel? primaryDisaster(
    List<DisasterEventModel> events, {
    required String? village,
    required String? mandal,
    required String? district,
  }) {
    return DisasterService.pickActiveDisaster(
      events,
      village: village,
      mandal: mandal,
      district: district,
    );
  }
}
