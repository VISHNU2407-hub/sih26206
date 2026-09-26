import 'package:flutter_test/flutter_test.dart';
import 'package:village_verse/utils/geo_match.dart';

/// Unit tests for incident geographic normalization.
///
/// These verify that GeoMatch.normalize() is applied consistently
/// to both the values written into incident documents and the values
/// used in authority query parameters. The actual Firestore queries
/// and Firebase Auth calls are not tested here — only the normalization
/// contract that makes case/whitespace-insensitive matching work.
void main() {
  group('Incident geographic normalization (write side)', () {
    test('lowercase village is stored as normalized', () {
      expect(GeoMatch.normalize('mukkamala'), equals('mukkamala'));
    });

    test('uppercase village is normalized to lowercase', () {
      expect(GeoMatch.normalize('MUKKAMALA'), equals('mukkamala'));
    });

    test('mixed case with leading/trailing spaces is normalized', () {
      expect(GeoMatch.normalize(' Mukkamala '), equals('mukkamala'));
    });

    test('village with internal spaces is normalized', () {
      expect(GeoMatch.normalize('mukka mala'), equals('mukkamala'));
    });

    test('mandal with mixed case and internal spaces is normalized', () {
      expect(GeoMatch.normalize(' AmbaJiPeta '), equals('ambajipeta'));
    });

    test('district with mixed case is normalized', () {
      expect(GeoMatch.normalize('East Godavari'), equals('eastgodavari'));
    });

    test('empty string stays empty', () {
      expect(GeoMatch.normalize(''), equals(''));
    });

    test('null stays empty', () {
      expect(GeoMatch.normalize(null), equals(''));
    });
  });

  group('Incident geographic normalization (read / query side)', () {
    test('query value with different casing matches stored value', () {
      const stored = 'ambajipeta'; // normalized on write
      const query = 'Ambajipeta'; // raw from authority profile
      expect(GeoMatch.normalize(stored), equals(GeoMatch.normalize(query)));
    });

    test('query value with leading spaces matches stored value', () {
      const stored = 'eastgodavari';
      const query = '  East Godavari  ';
      expect(GeoMatch.normalize(stored), equals(GeoMatch.normalize(query)));
    });

    test('query value with internal spaces matches stored value', () {
      const stored = 'eastgodavari';
      const query = 'East  Godavari';
      expect(GeoMatch.normalize(stored), equals(GeoMatch.normalize(query)));
    });

    test('different casing between citizen write and authority query', () {
      // Citizen writes "Mukkamala" (from profile)
      final written = GeoMatch.normalize('Mukkamala');
      // Authority queries with "mukkamala" (from their profile)
      final queried = GeoMatch.normalize('mukkamala');
      expect(written, equals(queried));
    });

    test('all-whitespace value normalizes to empty', () {
      expect(GeoMatch.normalize('   '), equals(''));
    });

    test('tab characters are removed', () {
      expect(GeoMatch.normalize('Mukkamala\t'), equals('mukkamala'));
    });

    test('newline characters are removed', () {
      expect(GeoMatch.normalize('Mukkamala\n'), equals('mukkamala'));
    });
  });

  group('Incident field matching (3-level)', () {
    test('exact match passes', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'mukkamala',
          itemMandal: 'ambajipeta',
          itemDistrict: 'eastgodavari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isTrue,
      );
    });

    test('case-insensitive match passes', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'Mukkamala',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isTrue,
      );
    });

    test('village mismatch fails', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'irusumanda',
          itemMandal: 'ambajipeta',
          itemDistrict: 'eastgodavari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isFalse,
      );
    });

    test('mandal mismatch fails', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'mukkamala',
          itemMandal: 'other_mandal',
          itemDistrict: 'eastgodavari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isFalse,
      );
    });

    test('district mismatch fails', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'mukkamala',
          itemMandal: 'ambajipeta',
          itemDistrict: 'other_district',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isFalse,
      );
    });

    test('blank stored village does not match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: '',
          itemMandal: 'ambajipeta',
          itemDistrict: 'eastgodavari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isFalse,
      );
    });

    test('blank user village does not match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'mukkamala',
          itemMandal: 'ambajipeta',
          itemDistrict: 'eastgodavari',
          userVillage: '',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isFalse,
      );
    });
  });

  group('Incident fieldMatches (individual field)', () {
    test('fieldMatches normalizes both sides', () {
      expect(GeoMatch.fieldMatches('Mukkamala', 'mukkamala'), isTrue);
      expect(GeoMatch.fieldMatches(' Ambajipeta ', 'ambajipeta'), isTrue);
      expect(GeoMatch.fieldMatches('East Godavari', 'eastgodavari'), isTrue);
    });

    test('fieldMatches rejects different values', () {
      expect(GeoMatch.fieldMatches('mukkamala', 'irusumanda'), isFalse);
    });

    test('fieldMatches with null', () {
      expect(GeoMatch.fieldMatches(null, 'mukkamala'), isFalse);
      expect(GeoMatch.fieldMatches('mukkamala', null), isFalse);
      expect(GeoMatch.fieldMatches(null, null), isTrue);
    });
  });
}
