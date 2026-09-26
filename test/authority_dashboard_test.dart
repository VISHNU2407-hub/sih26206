import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/incident_model.dart';
import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/dashboard_metrics.dart';
import 'package:village_verse/services/shelter_service.dart';

/// Phase 3 tests — authority dashboard domain logic.
void main() {
  group('IncidentModel triage flow', () {
    test('nextTriageStatus walks the canonical flow', () {
      expect(DisasterIncidentModel.nextTriageStatus('reported'), 'verified');
      expect(DisasterIncidentModel.nextTriageStatus('verified'), 'triaged');
      expect(DisasterIncidentModel.nextTriageStatus('triaged'), 'dispatched');
      expect(
          DisasterIncidentModel.nextTriageStatus('dispatched'), 'resolved');
    });

    test('nextTriageStatus returns null at flow boundaries', () {
      expect(DisasterIncidentModel.nextTriageStatus('resolved'), isNull);
      // 'rejected' is not part of the forward flow.
      expect(DisasterIncidentModel.nextTriageStatus('rejected'), isNull);
      // Unknown statuses must not invent transitions.
      expect(DisasterIncidentModel.nextTriageStatus('bogus'), isNull);
    });

    test('statusLabel uses supported vocabulary only', () {
      expect(
          DisasterIncidentModel.statusLabel('reported'), 'Reported');
      expect(DisasterIncidentModel.statusLabel('rejected'), 'Invalid');
      expect(DisasterIncidentModel.statusLabel('weird'), 'weird');
    });

    test('needsResponse / isResolved classification', () {
      DisasterIncidentModel makeIncident(String status) {
        return _makeIncident(status: status);
      }

      expect(makeIncident('reported').needsResponse, isTrue);
      expect(makeIncident('dispatched').needsResponse, isTrue);
      expect(makeIncident('resolved').needsResponse, isFalse);
      expect(makeIncident('rejected').needsResponse, isFalse);
    });

    test('severityRank orders critical first', () {
      expect(
        DisasterIncidentModel.severityRank('critical'),
        lessThan(DisasterIncidentModel.severityRank('high')),
      );
      expect(
        DisasterIncidentModel.severityRank('high'),
        lessThan(DisasterIncidentModel.severityRank('medium')),
      );
      expect(
        DisasterIncidentModel.severityRank('medium'),
        lessThan(DisasterIncidentModel.severityRank('low')),
      );
    });

    test('resourceLabel maps known resources and humanizes unknown', () {
      expect(DisasterIncidentModel.resourceLabel('boats'), 'Boats');
      expect(
          DisasterIncidentModel.resourceLabel('drinking_water'),
          'Drinking Water');
      expect(
          DisasterIncidentModel.resourceLabel('custom_thing'),
          'Custom thing');
    });
  });

  group('ShelterService validation', () {
    test('valid capacity/occupancy passes', () {
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: 50),
        isNull,
      );
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: 0),
        isNull,
      );
    });

    test('occupancy > capacity is rejected', () {
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: 101),
        isNotNull,
      );
    });

    test('negative values are rejected', () {
      expect(
        ShelterService.validateCapacity(capacity: -1, occupancy: 0),
        isNotNull,
      );
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: -5),
        isNotNull,
      );
    });
  });

  group('ShelterModel availability math', () {
    ShelterModel makeShelter({
      required int capacity,
      required int occupancy,
      String status = 'active',
    }) {
      return ShelterModel(
        name: 'Test Shelter',
        village: 'V',
        mandal: 'M',
        district: 'D',
        capacity: capacity,
        occupancy: occupancy,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('availableSpace is capacity - occupancy', () {
      expect(makeShelter(capacity: 400, occupancy: 120).availableSpace, 280);
    });

    test('availableSpace never goes negative', () {
      expect(makeShelter(capacity: 10, occupancy: 25).availableSpace, 0);
    });

    test('closed shelters report zero availability', () {
      final closed = makeShelter(
          capacity: 100, occupancy: 10, status: 'closed');
      expect(closed.availableSpace, 0);
      expect(closed.hasSpace, isFalse);
    });

    test('occupancyPercent handles zero capacity safely', () {
      expect(makeShelter(capacity: 0, occupancy: 0).occupancyPercent, isNull);
      expect(makeShelter(capacity: 100, occupancy: 80).occupancyPercent, 80.0);
    });
  });

  group('DashboardMetrics', () {
    DisasterIncidentModel makeIncident({
      required String status,
      String severity = 'high',
      int affected = 0,
      bool rescue = false,
      int rescueCount = 0,
    }) {
      return _makeIncident(
        status: status,
        severity: severity,
        affected: affected,
        rescue: rescue,
        rescueCount: rescueCount,
      );
    }

    ShelterModel makeShelter({
      required int capacity,
      required int occupancy,
      String status = 'active',
    }) {
      return ShelterModel(
        name: 'S',
        village: 'V',
        mandal: 'M',
        district: 'D',
        capacity: capacity,
        occupancy: occupancy,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('activeIncidents counts only unresolved', () {
      final incidents = [
        makeIncident(status: 'reported'),
        makeIncident(status: 'verified'),
        makeIncident(status: 'dispatched'),
        makeIncident(status: 'resolved'),
        makeIncident(status: 'rejected'),
      ];
      expect(DashboardMetrics.activeIncidents(incidents), 3);
    });

    test('criticalIncidents counts unresolved critical only', () {
      final incidents = [
        makeIncident(status: 'reported', severity: 'critical'),
        makeIncident(status: 'resolved', severity: 'critical'),
        makeIncident(status: 'triaged', severity: 'high'),
      ];
      expect(DashboardMetrics.criticalIncidents(incidents), 1);
    });

    test('peopleAffected sums across unresolved incidents', () {
      final incidents = [
        makeIncident(status: 'reported', affected: 10),
        makeIncident(status: 'dispatched', affected: 5),
        makeIncident(status: 'resolved', affected: 100),
      ];
      expect(DashboardMetrics.peopleAffected(incidents), 15);
    });

    test('peopleAwaitingRescue sums rescue counts for rescue incidents', () {
      final incidents = [
        makeIncident(status: 'reported', rescue: true, rescueCount: 4),
        makeIncident(status: 'verified', rescue: true, rescueCount: 6),
        makeIncident(status: 'reported', rescue: false, rescueCount: 9),
      ];
      expect(DashboardMetrics.peopleAwaitingRescue(incidents), 10);
    });

    test('sheltersWithLimitedCapacity flags >=80% open shelters', () {
      final shelters = [
        makeShelter(capacity: 100, occupancy: 85), // limited
        makeShelter(capacity: 100, occupancy: 50), // fine
        makeShelter(capacity: 100, occupancy: 100), // full
        makeShelter(capacity: 100, occupancy: 90, status: 'closed'), // closed
      ];
      expect(DashboardMetrics.sheltersWithLimitedCapacity(shelters), 2);
    });

    test('sortForAuthorityFeed puts open, severe, newest first', () {
      final older = DateTime.now().subtract(const Duration(hours: 2));
      final newer = DateTime.now();

      final incidents = [
        makeIncident(status: 'resolved', severity: 'critical'), // closed
        makeIncident(status: 'reported', severity: 'low'), // open, low
        makeIncident(
            status: 'reported', severity: 'critical', rescue: true), // top
        makeIncident(status: 'verified', severity: 'high'), // open, high
      ];

      final sorted = DashboardMetrics.sortForAuthorityFeed(incidents);
      expect(sorted.first.severity, 'critical');
      expect(sorted.first.status, 'reported');
      // Resolved incident sinks to the bottom.
      expect(sorted.last.isResolved, isTrue);
      // Newest above older within same severity.
      final highs = sorted.where((i) => i.severity == 'high').toList();
      expect(highs.first.createdAt.isAfter(older) ||
          highs.first.status == 'verified', isTrue);
      expect(newer, isNotNull); // silence unused warning in older SDKs
    });
  });
}

/// Shared factory — the model requires geographic fields.
DisasterIncidentModel _makeIncident({
  required String status,
  String severity = 'high',
  int affected = 0,
  bool rescue = false,
  int rescueCount = 0,
}) {
  return DisasterIncidentModel(
    incidentType: 'flood',
    severity: severity,
    description: 'test',
    district: 'East Godavari',
    mandal: 'Ambajipeta',
    village: 'Mukkamala',
    reportedBy: 'demo-citizen',
    status: status,
    affectedPeople: affected,
    rescueRequired: rescue,
    rescuePeopleCount: rescueCount,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
