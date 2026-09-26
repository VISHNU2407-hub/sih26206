import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/shelter_service.dart';

void main() {
  group('ShelterService.validateCapacity', () {
    test('accepts valid capacity and occupancy', () {
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: 50),
        isNull,
      );
    });

    test('accepts zero capacity and occupancy', () {
      expect(
        ShelterService.validateCapacity(capacity: 0, occupancy: 0),
        isNull,
      );
    });

    test('rejects null capacity', () {
      expect(
        ShelterService.validateCapacity(capacity: null, occupancy: 0),
        'Capacity must be 0 or more',
      );
    });

    test('rejects null occupancy', () {
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: null),
        'Occupancy must be 0 or more',
      );
    });

    test('rejects negative capacity', () {
      expect(
        ShelterService.validateCapacity(capacity: -1, occupancy: 0),
        'Capacity must be 0 or more',
      );
    });

    test('rejects negative occupancy', () {
      expect(
        ShelterService.validateCapacity(capacity: 100, occupancy: -5),
        'Occupancy must be 0 or more',
      );
    });

    test('rejects occupancy exceeding capacity', () {
      expect(
        ShelterService.validateCapacity(capacity: 10, occupancy: 11),
        'Occupancy cannot exceed capacity',
      );
    });

    test('allows occupancy equal to capacity', () {
      expect(
        ShelterService.validateCapacity(capacity: 50, occupancy: 50),
        isNull,
      );
    });
  });

  group('ShelterModel creation fields', () {
    test('constructs with all required fields and defaults', () {
      final shelter = ShelterModel(
        name: 'Test Shelter',
        district: 'East Godavari',
        mandal: 'Ambajipeta',
        village: 'Mukkamala',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.name, 'Test Shelter');
      expect(shelter.village, 'Mukkamala');
      expect(shelter.capacity, 0);
      expect(shelter.occupancy, 0);
      expect(shelter.status, 'active');
      expect(shelter.amenities, isEmpty);
      expect(shelter.supplies, isEmpty);
      expect(shelter.isDemoData, isFalse);
    });

    test('toFirestore includes all creation fields', () {
      final shelter = ShelterModel(
        name: 'Community Hall',
        district: 'East Godavari',
        mandal: 'Ambajipeta',
        village: 'Mukkamala',
        capacity: 200,
        occupancy: 0,
        status: 'active',
        amenities: ['Drinking water', 'First aid'],
        supplies: ['Blankets'],
        contactPhone: '9876543210',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      final map = shelter.toFirestore();
      expect(map['name'], 'Community Hall');
      expect(map['village'], 'Mukkamala');
      expect(map['mandal'], 'Ambajipeta');
      expect(map['district'], 'East Godavari');
      expect(map['capacity'], 200);
      expect(map['occupancy'], 0);
      expect(map['status'], 'active');
      expect(map['amenities'], ['Drinking water', 'First aid']);
      expect(map['supplies'], ['Blankets']);
      expect(map['contactPhone'], '9876543210');
      expect(map['isDemoData'], isFalse);
      expect(map.containsKey('createdAt'), isTrue);
    });

    test('fromFirestore round-trips creation fields', () {
      final map = {
        'name': 'School Building',
        'district': 'West Godavari',
        'mandal': 'Narsapur',
        'village': 'Palacole',
        'capacity': 150,
        'occupancy': 30,
        'status': 'active',
        'amenities': ['Generator', 'Toilets'],
        'supplies': ['Rice bags'],
        'contactPhone': '9123456789',
        'isDemoData': false,
        'createdAt': DateTime(2026, 3, 15),
        'updatedAt': DateTime(2026, 3, 15),
      };
      final shelter = ShelterModel.fromFirestore(map, 'shelter-1');
      expect(shelter, isNotNull);
      expect(shelter!.id, 'shelter-1');
      expect(shelter.name, 'School Building');
      expect(shelter.capacity, 150);
      expect(shelter.occupancy, 30);
      expect(shelter.amenities, ['Generator', 'Toilets']);
      expect(shelter.supplies, ['Rice bags']);
      expect(shelter.isDemoData, isFalse);
    });
  });

  group('ShelterModel computed properties', () {
    test('availableSpace clamps to zero when closed', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 100,
        occupancy: 50,
        status: 'closed',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.availableSpace, 0);
    });

    test('availableSpace is capacity minus occupancy when active', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 100,
        occupancy: 70,
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.availableSpace, 30);
    });

    test('hasSpace is false when closed', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 100,
        occupancy: 0,
        status: 'closed',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.hasSpace, isFalse);
    });

    test('hasSpace is true when active with room', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 100,
        occupancy: 50,
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.hasSpace, isTrue);
    });

    test('occupancyPercent is null when capacity is zero', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 0,
        occupancy: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.occupancyPercent, isNull);
    });

    test('occupancyPercent calculates correctly', () {
      final shelter = ShelterModel(
        name: 'S',
        district: 'd',
        mandal: 'm',
        village: 'v',
        capacity: 200,
        occupancy: 50,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(shelter.occupancyPercent, 25.0);
    });
  });

  group('ShelterModel statusLabel', () {
    test('maps known statuses', () {
      expect(ShelterModel.statusLabel('active'), 'Open');
      expect(ShelterModel.statusLabel('full'), 'Full');
      expect(ShelterModel.statusLabel('closed'), 'Closed');
    });

    test('returns raw string for unknown status', () {
      expect(ShelterModel.statusLabel('maintenance'), 'maintenance');
    });
  });
}
