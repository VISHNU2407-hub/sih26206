import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/damage_assessment_model.dart';
import 'package:village_verse/models/disaster_event_model.dart';
import 'package:village_verse/models/incident_model.dart';
import 'package:village_verse/models/resource_model.dart';
import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/damage_assessment_service.dart';
import 'package:village_verse/services/recovery_status_helper.dart';
import 'package:village_verse/services/resource_service.dart';

// ── Firestore-style map builders ────────────────────────────────────────

Map<String, dynamic> damageMap({
  String damageType = 'house',
  String severity = 'high',
  String status = 'reported',
  String village = 'Mukkamala',
  String? disasterId = 'd1',
  Map<String, dynamic> extra = const {},
}) {
  final map = <String, dynamic>{
    'disasterId': disasterId,
    'reportedBy': 'auth-1',
    'reportedByName': 'Authority',
    'district': 'East Godavari',
    'mandal': 'Ambajipeta',
    'village': village,
    'latitude': 16.687,
    'longitude': 82.044,
    'damageType': damageType,
    'severity': severity,
    'description': 'Test damage',
    'estimatedAffectedPeople': 10,
    'status': status,
    'demo': true,
  };
  map.addAll(extra);
  return map;
}

Map<String, dynamic> resourceMap({
  int quantity = 0,
  int requiredQuantity = 10,
  int allocatedQuantity = 0,
  String status = 'needed',
  String resourceType = 'drinking_water',
  String village = 'Mukkamala',
}) {
  return {
    'disasterId': 'd1',
    'district': 'East Godavari',
    'mandal': 'Ambajipeta',
    'village': village,
    'resourceType': resourceType,
    'quantity': quantity,
    'requiredQuantity': requiredQuantity,
    'allocatedQuantity': allocatedQuantity,
    'unit': 'litres',
    'status': status,
    'notes': '',
    'demo': true,
  };
}

DamageAssessmentModel damage({
  String severity = 'high',
  String status = 'reported',
  String village = 'Mukkamala',
  String? disasterId = 'd1',
  int affected = 10,
}) {
  return DamageAssessmentModel(
    id: 'a1',
    disasterId: disasterId,
    reportedBy: 'auth-1',
    district: 'East Godavari',
    mandal: 'Ambajipeta',
    village: village,
    damageType: 'house',
    severity: severity,
    description: 'Test',
    estimatedAffectedPeople: affected,
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

ResourceModel resource({
  int quantity = 0,
  int requiredQuantity = 10,
  int allocatedQuantity = 0,
  String status = 'needed',
  String village = 'Mukkamala',
}) {
  return ResourceModel(
    id: 'r1',
    disasterId: 'd1',
    district: 'East Godavari',
    mandal: 'Ambajipeta',
    village: village,
    resourceType: 'drinking_water',
    quantity: quantity,
    requiredQuantity: requiredQuantity,
    allocatedQuantity: allocatedQuantity,
    unit: 'litres',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

DisasterIncidentModel incident({
  String status = 'reported',
  String village = 'Mukkamala',
  String? disasterId = 'd1',
}) {
  return DisasterIncidentModel(
    id: 'i1',
    incidentType: 'flood',
    severity: 'high',
    description: 'Test',
    district: 'East Godavari',
    mandal: 'Ambajipeta',
    village: village,
    disasterId: disasterId,
    reportedBy: 'u1',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('DamageAssessmentModel parsing', () {
    test('parses from Firestore map with demo flag', () {
      final item = DamageAssessmentModel.fromFirestore(
        damageMap(),
        'assess-1',
      );
      expect(item, isNotNull);
      expect(item!.id, 'assess-1');
      expect(item.damageType, 'house');
      expect(item.severity, 'high');
      expect(item.status, 'reported');
      expect(item.isDemoData, isTrue);
      expect(item.disasterId, 'd1');
      expect(item.hasLocation, isTrue);
      expect(item.locationLink, contains('maps.google.com'));
    });

    test('accepts demo flag as isDemoData too', () {
      final item = DamageAssessmentModel.fromFirestore(
        damageMap()..remove('demo')..['isDemoData'] = true,
        'a2',
      );
      expect(item!.isDemoData, isTrue);
    });

    test('falls back safely on malformed data', () {
      final item = DamageAssessmentModel.fromFirestore(
        {'estimatedAffectedPeople': 'not-a-number'},
        'a3',
      );
      expect(item, isNotNull);
      expect(item!.estimatedAffectedPeople, 0);
    });
  });

  group('Damage status transitions', () {
    test('nextStatus walks the canonical flow', () {
      expect(DamageAssessmentModel.nextStatus('reported'), 'verified');
      expect(DamageAssessmentModel.nextStatus('verified'), 'assessed');
      expect(DamageAssessmentModel.nextStatus('assessed'), 'recovered');
    });

    test('nextStatus returns null at flow boundaries', () {
      expect(DamageAssessmentModel.nextStatus('recovered'), isNull);
      expect(DamageAssessmentModel.nextStatus('bogus'), isNull);
    });

    test('statusLabel uses the supported vocabulary', () {
      expect(DamageAssessmentModel.statusLabel('reported'), 'Reported');
      expect(DamageAssessmentModel.statusLabel('recovered'), 'Recovered');
      expect(DamageAssessmentModel.statusLabel('weird'), 'weird');
    });

    test('isResolved only for recovered', () {
      expect(damage(status: 'recovered').isResolved, isTrue);
      expect(damage(status: 'assessed').isResolved, isFalse);
    });
  });

  group('Damage severity handling', () {
    test('severityRank orders critical first', () {
      expect(
        DamageAssessmentModel.severityRank('critical'),
        lessThan(DamageAssessmentModel.severityRank('high')),
      );
      expect(
        DamageAssessmentModel.severityRank('high'),
        lessThan(DamageAssessmentModel.severityRank('medium')),
      );
    });

    test('sortForAuthorityList puts unresolved+critical first', () {
      final sorted = DamageAssessmentService.sortForAuthorityList([
        damage(severity: 'low', status: 'recovered'),
        damage(severity: 'low'),
        damage(severity: 'critical'),
        damage(severity: 'medium'),
      ]);
      expect(sorted.first.severity, 'critical');
      expect(sorted.first.isResolved, isFalse);
      expect(sorted.last.isResolved, isTrue);
    });
  });

  group('Damage disaster association', () {
    test('disasterId round-trips through toFirestore', () {
      final item = damage(disasterId: 'cyclone-42');
      final map = item.toFirestore();
      expect(map['disasterId'], 'cyclone-42');
    });

    test('toFirestoreUpdate keeps createdAt/reportedBy immutable', () {
      final map = damage().toFirestoreUpdate();
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('reportedBy'), isFalse);
      expect(map.containsKey('status'), isTrue);
    });
  });

  group('ResourceModel validation', () {
    test('valid values pass', () {
      expect(
        ResourceModel.validate(
          quantity: 100,
          requiredQuantity: 200,
          allocatedQuantity: 50,
          resourceType: 'drinking_water',
          village: 'Mukkamala',
        ),
        isNull,
      );
    });

    test('allocated cannot exceed available', () {
      expect(
        ResourceModel.validate(
          quantity: 10,
          requiredQuantity: 100,
          allocatedQuantity: 11,
          resourceType: 'boats',
          village: 'Mukkamala',
        ),
        contains('Allocated cannot exceed available'),
      );
    });

    test('allocated cannot exceed required when a need is recorded', () {
      expect(
        ResourceModel.validate(
          quantity: 100,
          requiredQuantity: 20,
          allocatedQuantity: 21,
          resourceType: 'boats',
          village: 'Mukkamala',
        ),
        contains('Allocated cannot exceed required'),
      );
    });

    test('negative quantities rejected', () {
      expect(
        ResourceModel.validate(
          quantity: -1,
          requiredQuantity: 10,
          allocatedQuantity: 0,
          resourceType: 'boats',
          village: 'Mukkamala',
        ),
        contains('negative'),
      );
      expect(
        ResourceModel.validate(
          quantity: 0,
          requiredQuantity: -5,
          allocatedQuantity: 0,
          resourceType: 'boats',
          village: 'Mukkamala',
        ),
        contains('negative'),
      );
    });

    test('identity fields required', () {
      expect(
        ResourceModel.validate(
          quantity: 0,
          requiredQuantity: 0,
          allocatedQuantity: 0,
          resourceType: '  ',
          village: 'Mukkamala',
        ),
        contains('Resource type is required'),
      );
      expect(
        ResourceModel.validate(
          quantity: 0,
          requiredQuantity: 0,
          allocatedQuantity: 0,
          resourceType: 'boats',
          village: '',
        ),
        contains('Village is required'),
      );
    });
  });

  group('Resource allocation calculations', () {
    test('shortfall = required − available, never negative', () {
      expect(resource(quantity: 3, requiredQuantity: 10).shortfall, 7);
      expect(resource(quantity: 15, requiredQuantity: 10).shortfall, 0);
    });

    test('isCovered only when stock meets the requirement', () {
      expect(resource(quantity: 10, requiredQuantity: 10).isCovered, isTrue);
      expect(resource(quantity: 9, requiredQuantity: 10).isCovered, isFalse);
      expect(resource(quantity: 5, requiredQuantity: 0).isCovered, isFalse);
    });

    test('coverage clamps to 0.0–1.0 and is null without a requirement', () {
      expect(resource(quantity: 5, requiredQuantity: 10).coverage, 0.5);
      expect(resource(quantity: 20, requiredQuantity: 10).coverage, 1.0);
      expect(resource(quantity: 5, requiredQuantity: 0).coverage, isNull);
    });

    test('sortForAuthorityList ranks shortages first, exhausted next', () {
      final sorted = ResourceService.sortForAuthorityList([
        resource(quantity: 10, requiredQuantity: 10), // covered
        resource(quantity: 0, requiredQuantity: 5, status: 'exhausted'),
        resource(quantity: 1, requiredQuantity: 10), // small shortage
        resource(quantity: 0, requiredQuantity: 20), // big shortage
      ]);
      // Biggest shortage first.
      expect(sorted.first.shortfall, 20);
      // Then smaller shortage, then exhausted, then covered.
      expect(sorted[1].shortfall, 9);
      expect(sorted[2].isExhausted, isTrue);
      expect(sorted.last.isCovered, isTrue);
    });
  });

  group('Recovery status logic', () {
    test('open incidents → response', () {
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: [incident(status: 'reported')],
          damage: [damage(status: 'verified')],
          resources: [resource()],
          shelters: const [],
        ),
        RecoveryStatusHelper.statusResponse,
      );
    });

    test('all damage recovered, no shortages → restored', () {
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: const [],
          damage: [damage(status: 'recovered')],
          resources: [resource(quantity: 10, requiredQuantity: 10)],
          shelters: const [],
        ),
        RecoveryStatusHelper.statusRestored,
      );
    });

    test('unresolved damage or shortages → recovery', () {
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: const [],
          damage: [damage(status: 'assessed')],
          resources: const [],
          shelters: const [],
        ),
        RecoveryStatusHelper.statusRecovery,
      );
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: const [],
          damage: const [],
          resources: [resource(quantity: 0, requiredQuantity: 10)],
          shelters: const [],
        ),
        RecoveryStatusHelper.statusRecovery,
      );
    });

    test('occupied shelter with no records → response', () {
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: const [],
          damage: const [],
          resources: const [],
          shelters: [
            ShelterModel(
              name: 'S',
              district: 'd',
              mandal: 'm',
              village: 'v',
              capacity: 100,
              occupancy: 40,
              status: 'active',
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
        RecoveryStatusHelper.statusResponse,
      );
    });

    test('no data at all → restored', () {
      expect(
        RecoveryStatusHelper.deriveForVillage(
          incidents: const [],
          damage: const [],
          resources: const [],
          shelters: const [],
        ),
        RecoveryStatusHelper.statusRestored,
      );
    });

    test('progress increases through the lifecycle', () {
      expect(
        RecoveryStatusHelper.progress(RecoveryStatusHelper.statusResponse),
        lessThan(RecoveryStatusHelper.progress(RecoveryStatusHelper.statusRecovery)),
      );
      expect(
        RecoveryStatusHelper.progress(RecoveryStatusHelper.statusRecovery),
        lessThan(RecoveryStatusHelper.progress(RecoveryStatusHelper.statusRestored)),
      );
    });

    test('disaster-level derivation reuses village logic', () {
      final d = DisasterEventModel(
        id: 'd1',
        type: 'cyclone',
        severity: 'high',
        status: 'active',
        title: 'Cyclone',
        createdBy: 'a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(
        RecoveryStatusHelper.deriveForDisaster(
          disaster: d,
          incidents: [incident(status: 'dispatched')],
          damage: const [],
          resources: const [],
        ),
        RecoveryStatusHelper.statusResponse,
      );
      final closed = DisasterEventModel(
        id: 'd1',
        type: 'cyclone',
        severity: 'high',
        status: 'closed',
        title: 'Cyclone',
        createdBy: 'a',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(
        RecoveryStatusHelper.deriveForDisaster(
          disaster: closed,
          incidents: const [],
          damage: [damage(status: 'recovered')],
          resources: const [],
        ),
        RecoveryStatusHelper.statusRestored,
      );
    });
  });

  group('Geographic filtering (village grouping inputs)', () {
    test('records group cleanly by village for the recovery cards', () {
      final damageItems = [
        damage(village: 'Mukkamala'),
        damage(village: 'Gangalakurru', status: 'recovered'),
      ];
      final mukkamala =
          damageItems.where((d) => d.village == 'Mukkamala').toList();
      expect(mukkamala, hasLength(1));
      expect(mukkamala.first.village, 'Mukkamala');
    });

    test('resource map round-trips village identity', () {
      final item = ResourceModel.fromFirestore(
        resourceMap(village: 'Irusumanda'),
        'r9',
      );
      expect(item!.village, 'Irusumanda');
      expect(item.disasterId, 'd1');
      expect(item.isDemoData, isTrue);
    });
  });
}
