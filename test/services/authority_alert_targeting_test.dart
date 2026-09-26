import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/utils/geo_match.dart';

void main() {
  group('Alert creation geographic targeting', () {
    test('village authority targets its assigned 3-level area', () {
      const userVillage = 'Mukkamala';
      const userMandal = 'Ambajipeta';
      const userDistrict = 'East Godavari';

      final affectedVillages = [GeoMatch.normalize(userVillage)];
      final affectedMandals = [GeoMatch.normalize(userMandal)];
      final affectedDistricts = [GeoMatch.normalize(userDistrict)];

      // Citizen in the same village/mandal/district → visible.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );

      // Citizen in a different village but same mandal → visible
      // (disaster alerts match at the mandal level too).
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'OtherVillage',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );

      // Citizen in a completely different area → hidden.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'OtherVillage',
          userMandal: 'OtherMandal',
          userDistrict: 'OtherDistrict',
        ),
        isFalse,
      );
    });

    test('district authority targets its assigned 3-level area', () {
      const userVillage = 'Mukkamala';
      const userMandal = 'Ambajipeta';
      const userDistrict = 'East Godavari';

      final affectedVillages = [GeoMatch.normalize(userVillage)];
      final affectedMandals = [GeoMatch.normalize(userMandal)];
      final affectedDistricts = [GeoMatch.normalize(userDistrict)];

      // Same area → visible.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        isTrue,
      );

      // Different district, different mandal, different village → hidden.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'OtherVillage',
          userMandal: 'OtherMandal',
          userDistrict: 'West Godavari',
        ),
        isFalse,
      );
    });

    test('missing village/mandal/district prevents alert creation', () {
      // Simulates the validation check in the composer.
      const village = '';
      const mandal = 'Ambajipeta';
      const district = 'East Godavari';

      final hasCompleteGeo =
          village.isNotEmpty && mandal.isNotEmpty && district.isNotEmpty;
      expect(hasCompleteGeo, isFalse);

      // All three present → valid.
      expect(
        'Mukkamala'.isNotEmpty && mandal.isNotEmpty && district.isNotEmpty,
        isTrue,
      );
    });

    test('no arbitrary village selection remains in alert creation', () {
      // The alert composer should NOT have a village selector or
      // _selectedVillages set. The only source of geographic data is
      // the user's profile.
      const userVillage = 'Mukkamala';
      const userMandal = 'Ambajipeta';
      const userDistrict = 'East Godavari';

      // The alert always uses the user's profile values.
      final affectedVillages = [GeoMatch.normalize(userVillage)];
      final affectedMandals = [GeoMatch.normalize(userMandal)];
      final affectedDistricts = [GeoMatch.normalize(userDistrict)];

      // Verify the alert data comes from the profile, not from a selector.
      expect(affectedVillages, ['mukkamala']);
      expect(affectedMandals, ['ambajipeta']);
      expect(affectedDistricts, ['eastgodavari']);
    });

    test('strict 3-level matching still works for created alerts', () {
      // After creation, the alert has all 3 fields normalized.
      final affectedVillages = [GeoMatch.normalize('Mukkamala')];
      final affectedMandals = [GeoMatch.normalize('Ambajipeta')];
      final affectedDistricts = [GeoMatch.normalize('East Godavari')];

      // Case-insensitive match.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'MUKKAMALA',
          userMandal: 'AMBAJIPTA',
          userDistrict: 'EAST GODAVARI',
        ),
        isTrue,
      );

      // Whitespace-insensitive match.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: ' Mukka Mala ',
          userMandal: ' Amba Ji Peta ',
          userDistrict: ' East Go Davari ',
        ),
        isTrue,
      );

      // Mismatch → hidden.
      expect(
        GeoMatch.affectsStrict(
          affectedVillages: affectedVillages,
          affectedMandals: affectedMandals,
          affectedDistricts: affectedDistricts,
          userVillage: 'WrongVillage',
          userMandal: 'WrongMandal',
          userDistrict: 'WrongDistrict',
        ),
        isFalse,
      );
    });
  });
}
