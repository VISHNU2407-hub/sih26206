import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/disaster_event_model.dart';
import 'package:village_verse/models/incident_model.dart';
import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/models/village_preparedness_model.dart';
import 'package:village_verse/services/disaster_service.dart';

// Minimal Firestore-style maps for model parsing tests.
Map<String, dynamic> disasterMap({
  String type = 'cyclone',
  String severity = 'high',
  String status = 'active',
  List<String> villages = const ['Mukkamala'],
  List<String> mandals = const ['Ambajipeta'],
  List<String> districts = const [],
  bool demo = true,
  String id = 'd1',
  DateTime? createdAt,
}) {
  return {
    'type': type,
    'severity': severity,
    'status': status,
    'title': 'Test Event',
    'summary': 'Test summary',
    'instructions': 'Test instructions',
    'affectedVillages': villages,
    'affectedMandals': mandals,
    'affectedDistricts': districts,
    'evacuationRequired': true,
    'createdBy': 'authority-uid',
    'createdByName': 'Authority',
    'demo': demo,
    'createdAt': createdAt,
  };
}

DateTime fixedDate(int y) => DateTime(y, 1, 1);

void main() {
  group('DisasterEventModel', () {
    test('parses from Firestore map with id and demo flag', () {
      final event = DisasterEventModel.fromFirestore(
        disasterMap(),
        'event-1',
      );

      expect(event, isNotNull);
      expect(event!.id, 'event-1');
      expect(event.type, 'cyclone');
      expect(event.severity, 'high');
      expect(event.status, 'active');
      expect(event.isDemoData, isTrue);
      expect(event.evacuationRequired, isTrue);
      expect(event.isActive, isTrue);
    });

    test('affects() matches village, mandal and district scope', () {
      final event = DisasterEventModel.fromFirestore(
        disasterMap(
          villages: ['Mukkamala'],
          mandals: ['Ambajipeta'],
          districts: ['East Godavari'],
        ),
        'e',
      )!;

      expect(
        event.affects(
          village: 'Mukkamala',
          mandal: 'Ambajipeta',
          district: 'East Godavari',
        ),
        isTrue,
      );
      // Village listed → any other village in the same mandal does NOT match
      // unless the mandal scope also lists it (it does here).
      expect(
        event.affects(village: 'OtherVillage', mandal: 'Ambajipeta', district: ''),
        isTrue,
      );
      expect(
        event.affects(village: 'OtherVillage', mandal: 'OtherMandal', district: ''),
        isFalse,
      );
    });

    test('labels resolve for known and unknown types', () {
      expect(DisasterEventModel.typeLabel('flood'), 'Flood');
      expect(DisasterEventModel.typeLabel('cyclone'), 'Cyclone');
      expect(DisasterEventModel.typeLabel('unknown_type'), 'Disaster');
      expect(DisasterEventModel.severityLabel('critical'), 'CRITICAL');
      expect(DisasterEventModel.statusLabel('contained'), 'Contained');
    });
  });

  group('DisasterService.pickActiveDisaster (deterministic matching)', () {
    final villageEvent = DisasterEventModel.fromFirestore(
      disasterMap(
        villages: ['Mukkamala'],
        mandals: [],
        id: 'village-event',
        severity: 'medium',
        createdAt: fixedDate(2020),
      ),
      'village-event',
    )!;
    final mandalEvent = DisasterEventModel.fromFirestore(
      disasterMap(
        villages: [],
        mandals: ['Ambajipeta'],
        id: 'mandal-event',
        severity: 'high',
        createdAt: fixedDate(2021),
      ),
      'mandal-event',
    )!;
    final districtEvent = DisasterEventModel.fromFirestore(
      disasterMap(
        villages: [],
        mandals: [],
        districts: ['East Godavari'],
        id: 'district-event',
        severity: 'critical',
        createdAt: fixedDate(2022),
      ),
      'district-event',
    )!;

    test('village-scope disaster beats wider scopes regardless of severity',
        () {
      final picked = DisasterService.pickActiveDisaster(
        [districtEvent, mandalEvent, villageEvent],
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        district: 'East Godavari',
      );
      expect(picked!.id, 'village-event');
    });

    test('mandal-scope beats district-scope when no village match', () {
      final picked = DisasterService.pickActiveDisaster(
        [districtEvent, mandalEvent],
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        district: 'East Godavari',
      );
      expect(picked!.id, 'mandal-event');
    });

    test('falls back to district-scope only when nothing closer matches', () {
      final picked = DisasterService.pickActiveDisaster(
        [districtEvent],
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        district: 'East Godavari',
      );
      expect(picked!.id, 'district-event');
    });

    test('same scope: higher severity wins', () {
      final mandalCritical = DisasterEventModel.fromFirestore(
        disasterMap(
          villages: [],
          mandals: ['Ambajipeta'],
          id: 'mandal-critical',
          severity: 'critical',
          createdAt: fixedDate(2020),
        ),
        'mandal-critical',
      )!;
      final picked = DisasterService.pickActiveDisaster(
        [mandalEvent, mandalCritical],
        village: 'X',
        mandal: 'Ambajipeta',
        district: '',
      );
      expect(picked!.id, 'mandal-critical');
    });

    test('identical scope+severity: newest event wins (stable)', () {
      final older = DisasterEventModel.fromFirestore(
        disasterMap(
          villages: ['Mukkamala'],
          mandals: [],
          id: 'older',
          severity: 'high',
          createdAt: fixedDate(2020),
        ),
        'older',
      )!;
      final newer = DisasterEventModel.fromFirestore(
        disasterMap(
          villages: ['Mukkamala'],
          mandals: [],
          id: 'newer',
          severity: 'high',
          createdAt: fixedDate(2023),
        ),
        'newer',
      )!;
      final picked = DisasterService.pickActiveDisaster(
        [older, newer],
        village: 'Mukkamala',
        mandal: '',
        district: '',
      );
      expect(picked!.id, 'newer');

      // Order independence — deterministic regardless of input order.
      final pickedReversed = DisasterService.pickActiveDisaster(
        [newer, older],
        village: 'Mukkamala',
        mandal: '',
        district: '',
      );
      expect(pickedReversed!.id, 'newer');
    });

    test('empty candidate list returns null (No Active Disaster state)', () {
      final picked = DisasterService.pickActiveDisaster(
        [],
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        district: 'East Godavari',
      );
      expect(picked, isNull);
    });
  });

  group('ShelterModel', () {
    test('availableSpace clamps at zero for overflow occupancy', () {
      final shelter = ShelterModel.fromFirestore({
        'name': 'S',
        'district': 'D',
        'mandal': 'M',
        'village': 'V',
        'capacity': 100,
        'occupancy': 120, // data entry overflow
        'status': 'active',
        'demo': true,
      }, 's1')!;

      expect(shelter.id, 's1');
      expect(shelter.isDemoData, isTrue);
      expect(shelter.capacity, 100);
      expect(shelter.occupancy, 120);
      expect(shelter.availableSpace, 0, reason: 'overflow must clamp to 0');
      expect(shelter.hasSpace, isFalse);
      expect(shelter.occupancyPercent, 100.0);
    });

    test('closed shelter reports zero availability', () {
      final shelter = ShelterModel.fromFirestore({
        'name': 'S',
        'district': 'D',
        'mandal': 'M',
        'village': 'V',
        'capacity': 100,
        'occupancy': 10,
        'status': 'closed',
      }, 's2')!;

      expect(shelter.availableSpace, 0);
      expect(shelter.hasSpace, isFalse);
    });

    test('normal shelter computes availability', () {
      final shelter = ShelterModel.fromFirestore({
        'name': 'S',
        'district': 'D',
        'mandal': 'M',
        'village': 'V',
        'capacity': 400,
        'occupancy': 120,
        'status': 'active',
      }, 's3')!;

      expect(shelter.availableSpace, 280);
      expect(shelter.hasSpace, isTrue);
      expect(shelter.occupancyPercent, closeTo(30.0, 0.01));
    });
  });

  group('DisasterIncidentModel', () {
    test('parses with disaster association and location', () {
      final incident = DisasterIncidentModel.fromFirestore({
        'incidentType': 'flood',
        'severity': 'critical',
        'description': 'Water entering houses',
        'latitude': 16.687,
        'longitude': 82.0446,
        'district': 'East Godavari',
        'mandal': 'Ambajipeta',
        'village': 'Mukkamala',
        'disasterId': 'event-1',
        'reportedBy': 'citizen-1',
        'affectedPeople': 48,
        'rescueRequired': true,
        'rescuePeopleCount': 12,
        'medicalRequired': false,
        'resourcesRequired': ['boats'],
        'media': [],
        'status': 'reported',
        'demo': true,
      }, 'i1')!;

      expect(incident.id, 'i1');
      expect(incident.disasterId, 'event-1');
      expect(incident.isDemoData, isTrue);
      expect(incident.hasLocation, isTrue);
      expect(incident.locationLink,
          'https://maps.google.com/?q=16.687,82.0446');
      expect(incident.status, 'reported');
      expect(incident.needsResponse, isTrue);
    });

    test('status labels cover the full triage workflow', () {
      expect(DisasterIncidentModel.statusLabel('reported'), 'Reported');
      expect(DisasterIncidentModel.statusLabel('verified'), 'Verified');
      expect(DisasterIncidentModel.statusLabel('triaged'), 'Triaged');
      expect(DisasterIncidentModel.statusLabel('dispatched'), 'Dispatched');
      expect(DisasterIncidentModel.statusLabel('resolved'), 'Resolved');
      expect(DisasterIncidentModel.statusLabel('rejected'), 'Invalid');
    });

    test('vocabulary lists match the SIH spec incident types', () {
      expect(
        DisasterIncidentModel.incidentTypes,
        containsAll([
          'flood',
          'cyclone',
          'fire',
          'earthquake',
          'landslide',
          'infrastructure_collapse',
          'person_trapped',
          'medical',
          'missing_person',
          'other',
        ]),
      );
      expect(DisasterIncidentModel.incidentTypes.length, 10);
    });
  });

  group('VillagePreparednessModel', () {
    test('villageKey normalizes names', () {
      expect(VillagePreparednessModel.keyFor('  Mukkamala '),
          'mukkamala');
      expect(
        VillagePreparednessModel.keyFor('K  Pedapudi'),
        'k pedapudi',
      );
    });

    test('checklistProgress computes completion fraction', () {
      final record = VillagePreparednessModel.fromFirestore({
        'district': 'East Godavari',
        'mandal': 'Ambajipeta',
        'village': 'Mukkamala',
        'riskLevel': 'severe',
        'hazards': ['cyclone', 'flood'],
        'checklist': {
          'a': {'label': 'A', 'done': true},
          'b': {'label': 'B', 'done': true},
          'c': {'label': 'C', 'done': false},
          'd': {'label': 'D', 'done': false},
        },
        'vulnerableCount': 85,
        'sheltersCount': 1,
        'evacuationRoutes': ['Route A'],
        'emergencyContacts': [
          {'name': 'Sarpanch', 'phone': '9000010002'},
        ],
        'isDemoData': true,
      }, 'mukkamala')!;

      expect(record.checklistProgress, 0.5);
      expect(record.riskLevel, 'severe');
      expect(record.hasSevereRisk, isTrue);
      expect(record.emergencyContacts.first['phone'], '9000010002');
      expect(record.isDemoData, isTrue);
    });
  });
}
