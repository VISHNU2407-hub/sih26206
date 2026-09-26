import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/hospital_model.dart';
import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/services/hospital_service.dart';
import 'package:village_verse/services/maps_directions.dart';

/// SATS Disaster — Public Hospitals feature tests (migrated from the
/// original SATS hospital directory).
///
/// Covers: data loading from the bundled district assets, model parsing
/// (incl. legacy `nan` data), search by name/district/address, district
/// filtering, missing phone / missing coordinates handling, directions
/// URL generation, and a regression check that shelter directions keep
/// working through the same shared MapsDirections helper.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HospitalService.clearCache();
  });

  group('Hospital data loading', () {
    test('loads the full public hospital dataset from district assets',
        () async {
      final hospitals = await HospitalService.loadAllHospitals();

      expect(hospitals, isNotEmpty);
      // The bundled dataset covers all 16 Andhra Pradesh districts.
      final districts = HospitalService.districtsIn(hospitals);
      expect(districts.length, 16);
      expect(districts, contains('kurnool'));
      expect(districts, contains('visakhapatnam'));
    });

    test('caches hospitals after the first load', () async {
      final first = await HospitalService.loadAllHospitals();
      final second = await HospitalService.loadAllHospitals();

      expect(identical(first, second), isTrue);
    });

    test('every loaded hospital has valid coordinates', () async {
      final hospitals = await HospitalService.loadAllHospitals();

      for (final hospital in hospitals) {
        expect(hospital.hasValidCoordinates, isTrue,
            reason: '${hospital.name} was loaded without coordinates');
      }
    });
  });

  group('Hospital model parsing', () {
    test('parses a complete hospital record', () {
      final hospital = Hospital.fromJson(const {
        'name': 'Government General Hospital',
        'district': 'kurnool',
        'address': 'Main Road, Kurnool',
        'phone': '08512-234567',
        'latitude': 15.8281,
        'longitude': 78.0373,
      });

      expect(hospital.name, 'Government General Hospital');
      expect(hospital.district, 'kurnool');
      expect(hospital.address, 'Main Road, Kurnool');
      expect(hospital.phone, '08512-234567');
      expect(hospital.latitude, 15.8281);
      expect(hospital.longitude, 78.0373);
      expect(hospital.hasPhone, isTrue);
      expect(hospital.hasValidCoordinates, isTrue);
    });

    test('treats legacy "nan" address as unavailable', () {
      final hospital = Hospital.fromJson(const {
        'name': 'Allagadda',
        'district': 'kurnool',
        'address': 'nan',
        'phone': '',
        'latitude': 15.134484,
        'longitude': 78.503172,
      });

      expect(hospital.address, 'Address not available');
      expect(hospital.hasValidCoordinates, isTrue);
    });

    test('derives a PHC display name from legacy village-style names', () {
      final hospital = Hospital.fromJson(const {
        'name': 'Owk',
        'district': 'kurnool',
        'address': 'nan',
        'phone': '',
        'latitude': 15.208364,
        'longitude': 78.117957,
      });

      // Legacy records name the village, not the facility — the model
      // falls back to a generic display name, but preserves the raw
      // village name for search.
      expect(hospital.name, 'Health Center');
      expect(hospital.searchName, 'Owk');
      expect(
        HospitalService.searchHospitals([hospital], 'owk'),
        hasLength(1),
      );
    });

    test('missing fields never crash parsing', () {
      final hospital = Hospital.fromJson(const {});

      expect(hospital.name, 'Health Center');
      expect(hospital.district, 'Unknown');
      // A missing address stays empty ('Address not available' is only
      // for legacy "nan" records); the UI hides empty addresses.
      expect(hospital.address, '');
      expect(hospital.phone, '');
      expect(hospital.latitude, 0.0);
      expect(hospital.longitude, 0.0);
      expect(hospital.hasPhone, isFalse);
      expect(hospital.hasValidCoordinates, isFalse);
    });
  });

  group('Hospital search', () {
    final list = [
      Hospital(
        name: 'Government General Hospital',
        district: 'kurnool',
        address: 'Main Road, Kurnool',
        phone: '08512',
        latitude: 15.8,
        longitude: 78.0,
      ),
      Hospital(
        name: 'Area Hospital Nandyal',
        district: 'nandyal',
        address: 'NH-40, Nandyal',
        phone: '',
        latitude: 15.4,
        longitude: 78.4,
      ),
      Hospital(
        name: 'PHC - Owk',
        district: 'kurnool',
        address: 'Address not available',
        phone: '',
        latitude: 15.2,
        longitude: 78.1,
      ),
    ];

    test('finds hospitals by name (case-insensitive)', () {
      final results =
          HospitalService.searchHospitals(list, 'general hospital');
      expect(results, hasLength(1));
      expect(results.first.name, 'Government General Hospital');
    });

    test('finds hospitals by district display name', () {
      final results = HospitalService.searchHospitals(list, 'Kurnool');
      expect(results, hasLength(2));
    });

    test('finds hospitals by address', () {
      final results = HospitalService.searchHospitals(list, 'NH-40');
      expect(results, hasLength(1));
      expect(results.first.district, 'nandyal');
    });

    test('empty query returns everything (new list)', () {
      final results = HospitalService.searchHospitals(list, '   ');
      expect(results, hasLength(3));
      expect(identical(results, list), isFalse);
    });

    test('no match returns an empty list', () {
      final results = HospitalService.searchHospitals(list, 'zxyzzy');
      expect(results, isEmpty);
    });

    test('search also matches the raw district slug', () {
      final results = HospitalService.searchHospitals(list, 'spsr_nellore');
      expect(results, isEmpty); // not in this fixture — sanity check
      final bySlug = HospitalService.searchHospitals(list, 'nandyal');
      expect(bySlug, hasLength(1));
    });
  });

  group('District filtering', () {
    test('filters to one district', () async {
      final all = await HospitalService.loadAllHospitals();
      final kurnool = HospitalService.filterByDistrict(all, 'kurnool');

      expect(kurnool, isNotEmpty);
      for (final hospital in kurnool) {
        expect(hospital.district, 'kurnool');
      }
    });

    test('district filter is case-insensitive and tolerant of whitespace',
        () async {
      final all = await HospitalService.loadAllHospitals();
      final a = HospitalService.filterByDistrict(all, 'Kurnool');
      final b = HospitalService.filterByDistrict(all, ' kurnool ');
      expect(a.length, b.length);
    });

    test('empty district returns all hospitals', () async {
      final all = await HospitalService.loadAllHospitals();
      final result = HospitalService.filterByDistrict(all, '');
      expect(result.length, all.length);
    });

    test('formatDistrictName produces readable labels', () {
      expect(HospitalService.formatDistrictName('kurnool'), 'Kurnool');
      expect(HospitalService.formatDistrictName('spsr_nellore'),
          'SPSR Nellore');
      expect(HospitalService.formatDistrictName('ysr_kadapa'), 'YSR Kadapa');
      expect(HospitalService.formatDistrictName('east_godavari'),
          'East Godavari');
      expect(HospitalService.formatDistrictName(''), '');
    });
  });

  group('Hospitals with missing phone / coordinates', () {
    test('hospital with missing phone cannot be called but stays usable',
        () {
      final hospital = Hospital(
        name: 'Area Hospital',
        district: 'kurnool',
        address: 'Kurnool',
        phone: '',
        latitude: 15.8,
        longitude: 78.0,
      );

      expect(hospital.hasPhone, isFalse);
      expect(hospital.hasValidCoordinates, isTrue);
    });

    test('hospital with missing coordinates has no valid directions target',
        () {
      final hospital = Hospital(
        name: 'Clinic without pin',
        district: 'kurnool',
        address: 'Kurnool',
        phone: '08512',
        latitude: 0.0,
        longitude: 0.0,
      );

      // The model gate (hasValidCoordinates) is what keeps (0,0) from
      // ever reaching the directions helper / the Get Directions button.
      expect(hospital.hasValidCoordinates, isFalse);
    });

    test('hospital with out-of-range coordinates cannot build a route', () {
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 999, longitude: 78),
        isNull,
      );
    });
  });

  group('Directions through the shared MapsDirections helper', () {
    test('builds a keyless Google Maps directions URL for hospital coordinates',
        () {
      final url = MapsDirections.buildDirectionsUrl(
        latitude: 15.8281,
        longitude: 78.0373,
      );
      expect(url,
          'https://www.google.com/maps/dir/?api=1&destination=15.8281,78.0373');
    });

    test('rejects out-of-range hospital coordinates', () {
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 999, longitude: 78),
        isNull,
      );
      expect(
        MapsDirections.buildDirectionsUrl(latitude: 15.8, longitude: 9999),
        isNull,
      );
      expect(
        MapsDirections.buildDirectionsUrl(latitude: null, longitude: null),
        isNull,
      );
    });
  });

  group('Existing shelter directions still work', () {
    test('shelter coordinates route through the same helper', () {
      final shelter = ShelterModel(
        name: 'Government High School',
        district: 'East Godavari',
        mandal: 'Ambajipeta',
        village: 'Mukkamala',
        latitude: 16.8161,
        longitude: 82.1221,
        status: 'active',
        capacity: 100,
        occupancy: 40,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(shelter.hasLocation, isTrue);
      final url = MapsDirections.buildDirectionsUrl(
        latitude: shelter.latitude,
        longitude: shelter.longitude,
      );
      expect(url, isNotNull);
      expect(url, contains('destination=16.8161,82.1221'));
    });
  });
}
