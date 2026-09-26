import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/models/disaster_event_model.dart';
import 'package:village_verse/models/user_model.dart';
import 'package:village_verse/services/disaster_alert_notification_service.dart';
import 'package:village_verse/services/disaster_alert_targeting.dart';

DisasterEventModel disaster({
  List<String> villages = const [],
  List<String> mandals = const [],
  List<String> districts = const [],
  bool evacuation = false,
  String id = 'd1',
  String type = 'cyclone',
  String severity = 'high',
}) {
  return DisasterEventModel(
    id: id,
    type: type,
    severity: severity,
    status: 'active',
    title: 'Test Disaster',
    affectedVillages: villages,
    affectedMandals: mandals,
    affectedDistricts: districts,
    evacuationRequired: evacuation,
    createdBy: 'authority',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

UserModel user({
  String village = '',
  String mandal = '',
  String district = '',
  String role = 'citizen',
}) {
  return UserModel(
    uid: 'u1',
    name: 'Test User',
    phone: '9999999999',
    mandal: mandal,
    village: village,
    photoUrl: '',
    age: '',
    bloodGroup: '',
    role: role,
    createdAt: DateTime(2026, 1, 1),
    district: district,
  );
}

void main() {
  group('DisasterAlertTargeting.matchScope', () {
    test('village match is the most specific scope', () {
      final scope = DisasterAlertTargeting.matchScope(
        affectedVillages: ['Mukkamala'],
        affectedMandals: ['Ambajipeta'],
        affectedDistricts: ['East Godavari'],
        userVillage: 'Mukkamala',
        userMandal: 'Ambajipeta',
        userDistrict: 'East Godavari',
      );
      expect(scope, DisasterAlertScope.village);
    });

    test('mandal match when village not listed', () {
      final scope = DisasterAlertTargeting.matchScope(
        affectedVillages: ['SomeOtherVillage'],
        affectedMandals: ['Ambajipeta'],
        affectedDistricts: ['East Godavari'],
        userVillage: 'Mukkamala',
        userMandal: 'Ambajipeta',
        userDistrict: 'East Godavari',
      );
      expect(scope, DisasterAlertScope.mandal);
    });

    test('district match is the widest scope', () {
      final scope = DisasterAlertTargeting.matchScope(
        affectedVillages: [],
        affectedMandals: [],
        affectedDistricts: ['East Godavari'],
        userVillage: 'Mukkamala',
        userMandal: 'Ambajipeta',
        userDistrict: 'East Godavari',
      );
      expect(scope, DisasterAlertScope.district);
    });

    test('no match when user is outside every scope', () {
      final scope = DisasterAlertTargeting.matchScope(
        affectedVillages: ['Mukkamala'],
        affectedMandals: ['Ambajipeta'],
        affectedDistricts: ['East Godavari'],
        userVillage: 'UnaffectedVillage',
        userMandal: 'OtherMandal',
        userDistrict: 'OtherDistrict',
      );
      expect(scope, DisasterAlertScope.none);
    });

    test('matching is case-insensitive and trims whitespace', () {
      final scope = DisasterAlertTargeting.matchScope(
        affectedVillages: [' mukkamala '],
        affectedMandals: [],
        affectedDistricts: [],
        userVillage: 'MUKKAMALA',
        userMandal: '',
        userDistrict: '',
      );
      expect(scope, DisasterAlertScope.village);
    });

    test('blank user fields never match', () {
      expect(
        DisasterAlertTargeting.matchScope(
          affectedVillages: ['Mukkamala'],
          affectedMandals: ['Ambajipeta'],
          affectedDistricts: ['East Godavari'],
          userVillage: '',
          userMandal: '',
          userDistrict: '',
        ),
        DisasterAlertScope.none,
      );
    });

    test('empty affected lists never match anyone', () {
      expect(
        DisasterAlertTargeting.matchScope(
          affectedVillages: [],
          affectedMandals: [],
          affectedDistricts: [],
          userVillage: 'Mukkamala',
          userMandal: 'Ambajipeta',
          userDistrict: 'East Godavari',
        ),
        DisasterAlertScope.none,
      );
    });

    test('matchScopeFor reads the legacy UserModel mapping', () {
      // UserModel.village = 'Mukkamala' (Firestore 'street'),
      // UserModel.mandal = 'Ambajipeta' (Firestore 'village').
      final u = user(
        village: 'Mukkamala',
        mandal: 'Ambajipeta',
        district: 'East Godavari',
      );
      expect(
        DisasterAlertTargeting.matchScopeFor(
          disaster: disaster(villages: ['Mukkamala']),
          user: u,
        ),
        DisasterAlertScope.village,
      );
      expect(
        DisasterAlertTargeting.matchScopeFor(
          disaster: disaster(mandals: ['Ambajipeta']),
          user: u,
        ),
        DisasterAlertScope.mandal,
      );
      expect(
        DisasterAlertTargeting.matchScopeFor(
          disaster: disaster(districts: ['East Godavari']),
          user: u,
        ),
        DisasterAlertScope.district,
      );
    });

    test('notificationDocId is deterministic per user+disaster', () {
      expect(
        DisasterAlertTargeting.notificationDocId('dis-1', 'user-9'),
        'disaster_dis-1_user-9',
      );
      expect(
        DisasterAlertTargeting.notificationDocId('dis-1', 'user-9'),
        DisasterAlertTargeting.notificationDocId('dis-1', 'user-9'),
      );
      // Different user or disaster → different id (no collisions).
      expect(
        DisasterAlertTargeting.notificationDocId('dis-1', 'user-9'),
        isNot(DisasterAlertTargeting.notificationDocId('dis-1', 'user-10')),
      );
      expect(
        DisasterAlertTargeting.notificationDocId('dis-1', 'user-9'),
        isNot(DisasterAlertTargeting.notificationDocId('dis-2', 'user-9')),
      );
    });
  });

  group('DisasterAlertNotificationService.buildAlertBody', () {
    test('village-scope cyclone with evacuation lists villages', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(
          villages: ['Mukkamala', 'Gangalakurru'],
          evacuation: true,
        ),
      );
      expect(body, contains('HIGH Cyclone'));
      expect(body, contains('Mukkamala'));
      expect(body, contains('Gangalakurru'));
      expect(body, contains('Evacuation required'));
      expect(body, isNot(contains('cyclone-specific'))); // generic text only
    });

    test('mandal-scope alert names the mandal', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(mandals: ['Ambajipeta']),
      );
      expect(body, contains('Ambajipeta mandal'));
      expect(body, contains('Stay alert'));
    });

    test('district-scope alert names the district', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(districts: ['East Godavari'], type: 'flood'),
      );
      expect(body, contains('East Godavari district'));
      expect(body, contains('Flood'));
    });

    test('more than three villages collapses to "and other villages"', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(villages: ['A', 'B', 'C', 'D', 'E']),
      );
      expect(body, contains('A, B, C and other villages'));
      expect(body, isNot(contains('D')));
    });

    test('severity and type labels are reflected', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(type: 'fire', severity: 'critical'),
      );
      expect(body, startsWith('CRITICAL Fire'));
    });

    test('falls back to "your area" when no scope is set', () {
      final body = DisasterAlertNotificationService.buildAlertBody(
        disaster(),
      );
      expect(body, contains('your area'));
    });
  });
}
