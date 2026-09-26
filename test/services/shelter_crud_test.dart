import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/shelter_service.dart';

/// SATS Disaster — shelter CRUD tests.
///
/// Covers the shared update validation used by the authority edit form
/// (same rules as creation), legacy-document compatibility, and the
/// guarantee that invalid data is rejected before any Firestore write.
///
/// Note: [ShelterService.updateShelter] / [ShelterService.deleteShelter]
/// target exactly one `shelters/{id}` document each (structural guarantee);
/// the Firestore round-trip itself is exercised on-device, consistent with
/// the existing test suite which tests the static validation layer.
void main() {
  group('ShelterService.validateShelterUpdate (edit path)', () {
    test('accepts fully valid updated data (same rules as creation)', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'Government High School',
          village: 'Mukkamala',
          mandal: 'Ambajipeta',
          capacity: 150,
          occupancy: 40,
          locationText: 'Government High School, Mukkamala',
          latitude: 16.8161,
          longitude: 82.1221,
        ),
        isNull,
      );
    });

    test('accepts valid update without coordinates (nullable pair)', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'Community Hall',
          village: 'Mukkamala',
          mandal: 'Ambajipeta',
          capacity: 100,
          occupancy: 0,
          locationText: 'Panchayat Office, Mukkamala',
        ),
        isNull,
      );
    });

    test('rejects blank name', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: '   ',
          village: 'Mukkamala',
          mandal: 'Ambajipeta',
          capacity: 100,
          occupancy: 0,
        ),
        'Shelter name is required',
      );
    });

    test('rejects blank village (GeoMatch identity must stay set)', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'Shelter',
          village: '',
          mandal: 'Ambajipeta',
          capacity: 100,
          occupancy: 0,
        ),
        'Village is required',
      );
    });

    test('rejects blank mandal (GeoMatch identity must stay set)', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'Shelter',
          village: 'Mukkamala',
          mandal: '',
          capacity: 100,
          occupancy: 0,
        ),
        'Mandal is required',
      );
    });

    test('validates latitude range', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          latitude: 91,
          longitude: 0,
        ),
        'Latitude must be between -90 and 90',
      );
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          latitude: -90.5,
          longitude: 0,
        ),
        'Latitude must be between -90 and 90',
      );
    });

    test('validates longitude range', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          latitude: 0,
          longitude: 181,
        ),
        'Longitude must be between -180 and 180',
      );
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          latitude: 0,
          longitude: -200,
        ),
        'Longitude must be between -180 and 180',
      );
    });

    test('rejects a lone coordinate (lat/lng must remain a pair)', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          latitude: 16.0,
        ),
        'Both latitude and longitude are needed for coordinates',
      );
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          longitude: 82.0,
        ),
        'Both latitude and longitude are needed for coordinates',
      );
    });

    test('rejects blank location text', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 0,
          locationText: '   ',
        ),
        'Location cannot be blank',
      );
    });

    test('rejects occupancy exceeding capacity on edit', () {
      expect(
        ShelterService.validateShelterUpdate(
          name: 'S',
          village: 'v',
          mandal: 'm',
          capacity: 10,
          occupancy: 11,
        ),
        'Occupancy cannot exceed capacity',
      );
    });
  });

  group('Shelter CRUD — legacy compatibility', () {
    test('legacy shelter (no location fields) stays a valid model', () {
      final legacy = ShelterModel.fromFirestore({
        'name': 'Old School Shelter',
        'district': 'East Godavari',
        'mandal': 'Ambajipeta',
        'village': 'Mukkamala',
        'capacity': 80,
        'occupancy': 20,
        'status': 'active',
        'createdAt': DateTime(2026, 1, 1),
        'updatedAt': DateTime(2026, 1, 1),
      }, 'legacy-1');

      expect(legacy, isNotNull);
      expect(legacy!.id, 'legacy-1');
      expect(legacy.locationText, isNull);
      expect(legacy.hasLocation, isFalse);
      // A legacy shelter can still pass edit validation untouched.
      expect(
        ShelterService.validateShelterUpdate(
          name: legacy.name,
          village: legacy.village,
          mandal: legacy.mandal,
          capacity: legacy.capacity,
          occupancy: legacy.occupancy,
        ),
        isNull,
      );
    });

    test('document ID is carried on the model, never regenerated on edit',
        () {
      final shelter = ShelterModel.fromFirestore({
        'name': 'Hall',
        'village': 'v',
        'mandal': 'm',
        'district': 'd',
        'capacity': 10,
        'occupancy': 0,
        'createdAt': DateTime(2026, 1, 1),
        'updatedAt': DateTime(2026, 1, 1),
      }, 'shelter-fixed-id');

      expect(shelter!.id, 'shelter-fixed-id');
      // copyWith must not mint a new id — the edit form round-trips through
      // pre-filled controllers, not through model mutation.
      expect(shelter.copyWith(name: 'Hall 2').id, 'shelter-fixed-id');
    });
  });

  group('Shelter CRUD — creation still works', () {
    test('createShelter validation parity with update validation', () {
      // The same data must be accepted by both paths' validators.
      final validData = (
        name: 'Evacuation Center',
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        capacity: 200,
        occupancy: 0,
        locationText: 'Government High School, Mukkamala',
        latitude: 16.8161,
        longitude: 82.1221,
      );

      expect(
        ShelterService.validateShelterUpdate(
          name: validData.name,
          village: validData.village,
          mandal: validData.mandal,
          capacity: validData.capacity,
          occupancy: validData.occupancy,
          locationText: validData.locationText,
          latitude: validData.latitude,
          longitude: validData.longitude,
        ),
        isNull,
      );
      // Creation's capacity + location rules.
      expect(
        ShelterService.validateCapacity(
          capacity: validData.capacity,
          occupancy: validData.occupancy,
        ),
        isNull,
      );
      expect(
        ShelterService.validateLocation(
          locationText: validData.locationText,
          latitude: validData.latitude,
          longitude: validData.longitude,
        ),
        isNull,
      );
    });
  });
}
