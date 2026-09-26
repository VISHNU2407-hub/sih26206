import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/maps_directions.dart';
import 'package:village_verse/services/shelter_service.dart';

/// SATS Disaster — shelter location + Google Maps directions feature tests.
///
/// Covers: coordinate serialization round-trips, backward compatibility with
/// legacy documents missing the new fields, lat/lng range validation,
/// location text handling, directions URL generation, and guarantees that
/// missing coordinates never crash.
ShelterModel _shelter({
  String? locationText,
  double? latitude,
  double? longitude,
  String status = 'active',
  int capacity = 100,
  int occupancy = 40,
}) {
  return ShelterModel(
    name: 'Government High School',
    district: 'East Godavari',
    mandal: 'Ambajipeta',
    village: 'Mukkamala',
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    status: status,
    capacity: capacity,
    occupancy: occupancy,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ShelterModel serialization with coordinates', () {
    test('fromFirestore reads locationText, latitude and longitude', () {
      final map = {
        'name': 'Community Hall',
        'district': 'East Godavari',
        'mandal': 'Ambajipeta',
        'village': 'Mukkamala',
        'locationText': 'Government High School, Mukkamala',
        'latitude': 16.8161,
        'longitude': 82.1221,
        'capacity': 150,
        'occupancy': 30,
        'status': 'active',
        'createdAt': DateTime(2026, 3, 15),
        'updatedAt': DateTime(2026, 3, 15),
      };

      final shelter = ShelterModel.fromFirestore(map, 'shelter-1');

      expect(shelter, isNotNull);
      expect(shelter!.locationText, 'Government High School, Mukkamala');
      expect(shelter.latitude, 16.8161);
      expect(shelter.longitude, 82.1221);
      expect(shelter.hasLocation, isTrue);
      expect(shelter.hasValidCoordinates, isTrue);
    });

    test('toFirestore writes the location fields', () {
      final map = _shelter(
        locationText: 'Panchayat Office',
        latitude: 16.5,
        longitude: 82.0,
      ).toFirestore();

      expect(map['locationText'], 'Panchayat Office');
      expect(map['latitude'], 16.5);
      expect(map['longitude'], 82.0);
    });

    test('toFirestoreUpdate round-trips through fromFirestore', () {
      final original = _shelter(
        locationText: 'Government High School, Mukkamala',
        latitude: -16.8161,
        longitude: -82.1221,
      );
      final doc = original.toFirestore()
        ..remove('createdAt')
        ..remove('updatedAt');

      final restored = ShelterModel.fromFirestore(doc, 'id-1');

      expect(restored, isNotNull);
      expect(restored!.locationText, original.locationText);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
    });

    test('copyWith updates location fields and preserves the rest', () {
      final updated = _shelter().copyWith(
        locationText: 'New Address',
        latitude: 17.0,
        longitude: 83.0,
      );

      expect(updated.locationText, 'New Address');
      expect(updated.latitude, 17.0);
      expect(updated.longitude, 83.0);
      expect(updated.name, 'Government High School');
      expect(updated.capacity, 100);
      expect(updated.occupancy, 40);
    });
  });

  group('ShelterModel backward compatibility', () {
    test('legacy document without location fields loads without crashing', () {
      final legacyMap = {
        'name': 'Old Shelter',
        'district': 'East Godavari',
        'mandal': 'Ambajipeta',
        'village': 'Mukkamala',
        'capacity': 80,
        'occupancy': 10,
        'status': 'active',
        'createdAt': DateTime(2026, 1, 1),
        'updatedAt': DateTime(2026, 1, 1),
      };

      final shelter = ShelterModel.fromFirestore(legacyMap, 'legacy-1');

      expect(shelter, isNotNull);
      expect(shelter!.locationText, isNull);
      expect(shelter.latitude, isNull);
      expect(shelter.longitude, isNull);
      expect(shelter.hasLocation, isFalse);
      expect(shelter.hasValidCoordinates, isFalse);
      expect(shelter.name, 'Old Shelter');
      expect(shelter.capacity, 80);
    });

    test('null locationText in constructor is allowed', () {
      final shelter = _shelter();
      expect(shelter.locationText, isNull);
      expect(shelter.hasLocation, isFalse);
    });
  });

  group('ShelterModel coordinate validity', () {
    test('accepts valid latitude and longitude', () {
      expect(_shelter(latitude: 0, longitude: 0).hasValidCoordinates, isTrue);
      expect(
        _shelter(latitude: 90, longitude: 180).hasValidCoordinates,
        isTrue,
      );
      expect(
        _shelter(latitude: -90, longitude: -180).hasValidCoordinates,
        isTrue,
      );
      expect(
        _shelter(latitude: 16.8161, longitude: 82.1221).hasValidCoordinates,
        isTrue,
      );
    });

    test('rejects out-of-range latitude', () {
      expect(
        _shelter(latitude: 90.0001, longitude: 0).hasValidCoordinates,
        isFalse,
      );
      expect(
        _shelter(latitude: -90.0001, longitude: 0).hasValidCoordinates,
        isFalse,
      );
    });

    test('rejects out-of-range longitude', () {
      expect(
        _shelter(latitude: 0, longitude: 180.0001).hasValidCoordinates,
        isFalse,
      );
      expect(
        _shelter(latitude: 0, longitude: -180.0001).hasValidCoordinates,
        isFalse,
      );
    });

    test('requires both latitude and longitude', () {
      expect(_shelter(latitude: 16.0).hasLocation, isFalse);
      expect(_shelter(longitude: 82.0).hasLocation, isFalse);
      expect(_shelter(latitude: 16.0).hasValidCoordinates, isFalse);
      expect(_shelter(longitude: 82.0).hasValidCoordinates, isFalse);
    });
  });

  group('ShelterModel location text handling', () {
    test('locationDisplay prefers locationText when present', () {
      expect(
        _shelter(locationText: 'Government High School, Mukkamala')
            .locationDisplay,
        'Government High School, Mukkamala',
      );
    });

    test('locationDisplay falls back to village when address is empty', () {
      expect(_shelter(locationText: '').locationDisplay, 'Mukkamala');
      expect(_shelter(locationText: '   ').locationDisplay, 'Mukkamala');
      expect(_shelter().locationDisplay, 'Mukkamala');
    });

    test('blank locationText is rejected by validateLocation', () {
      expect(
        ShelterService.validateLocation(locationText: '   '),
        'Location cannot be blank',
      );
    });
  });

  group('ShelterService.validateLocation', () {
    test('accepts a valid full location block', () {
      expect(
        ShelterService.validateLocation(
          locationText: 'Government High School, Mukkamala',
          latitude: 16.8161,
          longitude: 82.1221,
        ),
        isNull,
      );
    });

    test('accepts text-only location (coordinates optional)', () {
      expect(
        ShelterService.validateLocation(locationText: 'Panchayat Office'),
        isNull,
      );
    });

    test('rejects latitude-only or longitude-only input', () {
      expect(
        ShelterService.validateLocation(latitude: 16.0),
        'Both latitude and longitude are needed for coordinates',
      );
      expect(
        ShelterService.validateLocation(longitude: 82.0),
        'Both latitude and longitude are needed for coordinates',
      );
    });

    test('rejects out-of-range latitude', () {
      expect(
        ShelterService.validateLocation(latitude: 91, longitude: 0),
        'Latitude must be between -90 and 90',
      );
      expect(
        ShelterService.validateLocation(latitude: -91, longitude: 0),
        'Latitude must be between -90 and 90',
      );
    });

    test('rejects out-of-range longitude', () {
      expect(
        ShelterService.validateLocation(latitude: 0, longitude: 181),
        'Longitude must be between -180 and 180',
      );
      expect(
        ShelterService.validateLocation(latitude: 0, longitude: -181),
        'Longitude must be between -180 and 180',
      );
    });

    test('boundary values are valid', () {
      expect(
        ShelterService.validateLocation(latitude: 90, longitude: 180),
        isNull,
      );
      expect(
        ShelterService.validateLocation(latitude: -90, longitude: -180),
        isNull,
      );
    });
  });

  group('MapsDirections.buildDirectionsUrl', () {
    test('builds an api=1 directions URL with coordinate destination', () {
      final url = MapsDirections.buildDirectionsUrl(
        latitude: 16.8161,
        longitude: 82.1221,
      );

      expect(url, isNotNull);
      expect(
        url,
        'https://www.google.com/maps/dir/?api=1&destination=16.8161,82.1221',
      );
      expect(url!.contains('api=1'), isTrue);
      expect(url.contains('destination=16.8161,82.1221'), isTrue);
    });

    test('returns null when coordinates are missing', () {
      expect(
        MapsDirections.buildDirectionsUrl(latitude: null, longitude: null),
        isNull,
      );
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 16.0, longitude: null),
        isNull,
      );
      expect(
        MapsDirections.buildDirectionsUrl(latitude: null, longitude: 82.0),
        isNull,
      );
    });

    test('returns null for out-of-range coordinates', () {
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 91, longitude: 0),
        isNull,
      );
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 0, longitude: -181),
        isNull,
      );
    });
  });

  group('MapsDirections.buildViewUrl', () {
    test('builds a coordinate pin URL', () {
      expect(
        MapsDirections.buildViewUrl(16.8161, 82.1221),
        'https://www.google.com/maps/search/?api=1&query=16.8161,82.1221',
      );
    });
  });
}
