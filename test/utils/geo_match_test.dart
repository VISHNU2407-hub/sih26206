import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/utils/geo_match.dart';

void main() {
  group('GeoMatch.normalize', () {
    test('lowercases', () {
      expect(GeoMatch.normalize('MUKKAMALA'), 'mukkamala');
    });

    test('trims leading/trailing whitespace', () {
      expect(GeoMatch.normalize('  Mukkamala  '), 'mukkamala');
    });

    test('removes all internal whitespace', () {
      expect(GeoMatch.normalize('mukka mala'), 'mukkamala');
      expect(GeoMatch.normalize('MUKKA MALA'), 'mukkamala');
    });

    test('handles combined transformations', () {
      expect(GeoMatch.normalize(' MUKKA MALA '), 'mukkamala');
      expect(GeoMatch.normalize('  East  Godavari  '), 'eastgodavari');
    });

    test('null returns empty string', () {
      expect(GeoMatch.normalize(null), '');
    });

    test('empty string returns empty string', () {
      expect(GeoMatch.normalize(''), '');
    });

    test('whitespace-only returns empty string', () {
      expect(GeoMatch.normalize('   '), '');
    });
  });

  group('GeoMatch.fieldMatches', () {
    test('exact match returns true', () {
      expect(GeoMatch.fieldMatches('Mukkamala', 'Mukkamala'), isTrue);
    });

    test('case-insensitive match returns true', () {
      expect(GeoMatch.fieldMatches('MUKKAMALA', 'mukkamala'), isTrue);
    });

    test('whitespace-insensitive match returns true', () {
      expect(GeoMatch.fieldMatches(' Mukka Mala ', 'mukkamala'), isTrue);
    });

    test('mismatch returns false', () {
      expect(GeoMatch.fieldMatches('Mukkamala', 'OtherVillage'), isFalse);
    });

    test('blank stored does not match non-blank comparison', () {
      expect(GeoMatch.fieldMatches('', 'mukkamala'), isFalse);
    });

    test('non-blank stored does not match blank comparison', () {
      expect(GeoMatch.fieldMatches('mukkamala', ''), isFalse);
    });

    test('both blank returns true', () {
      expect(GeoMatch.fieldMatches('', ''), isTrue);
    });

    test('null stored does not match non-blank comparison', () {
      expect(GeoMatch.fieldMatches(null, 'mukkamala'), isFalse);
    });

    test('null comparison does not match non-blank stored', () {
      expect(GeoMatch.fieldMatches('mukkamala', null), isFalse);
    });
  });

  group('GeoMatch.matches3Level', () {
    test('all three match → visible', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'Mukkamala',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('case differences → match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'MUKKAMALA',
          itemMandal: 'AMBAJIPTA',
          itemDistrict: 'EAST GODAVARI',
          userVillage: 'mukkamala',
          userMandal: 'ambajipta',
          userDistrict: 'east godavari',
        ),
        isTrue,
      );
    });

    test('leading/trailing spaces → match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: '  Mukkamala  ',
          itemMandal: '  Ambajipeta  ',
          itemDistrict: '  East Godavari  ',
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('internal spaces → match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'mukka mala',
          itemMandal: 'amba ji peta',
          itemDistrict: 'east go davari',
          userVillage: 'mukkamala',
          userMandal: 'ambajipeta',
          userDistrict: 'eastgodavari',
        ),
        isTrue,
      );
    });

    test('village mismatch → hidden', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'Mukkamala',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'OtherVillage',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });

    test('mandal mismatch → hidden', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'Mukkamala',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'Mukkamala',
          userMandal: 'OtherMandal',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });

    test('district mismatch → hidden', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: 'Mukkamala',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'West Godavari',
        ),
        isFalse,
      );
    });

    test('blank/missing geographic fields → no match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: '',
          itemMandal: 'Ambajipeta',
          itemDistrict: 'East Godavari',
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });

    test('null geographic fields → no match', () {
      expect(
        GeoMatch.matches3Level(
          itemVillage: null,
          itemMandal: null,
          itemDistrict: null,
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });
  });

  group('GeoMatch.affectsStrict', () {
    test('village in affected list → match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: ['Mukkamala', 'Other'],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('mandal in affected list → match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: [],
          affectedMandals: ['Ambajipeta'],
          affectedDistricts: [],
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('district in affected list → match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: [],
          affectedMandals: [],
          affectedDistricts: ['East Godavari'],
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('case-insensitive village match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: ['MUKKAMALA'],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: 'mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('whitespace-insensitive match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: ['  Mukka Mala '],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: 'mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );
    });

    test('no match when nothing in affected lists', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: [],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });

    test('blank user village does not match', () {
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: ['Mukkamala'],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: '',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isFalse,
      );
    });
  });
}
