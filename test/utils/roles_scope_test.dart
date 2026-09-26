import 'package:flutter_test/flutter_test.dart';

import 'package:village_verse/utils/roles.dart';

/// Authority/responder access — role classification and scope rules.
///
/// These mirror the constraints enforced by firestore.rules and the
/// provisioning tool (functions/src/seedDemoUsers.ts):
/// - self-signup roles: citizen only
/// - authority navigation: authority roles + rescue
/// - district-level reads: district_authority + legacy admin only
void main() {
  group('AppRoles — self-service constraint', () {
    test('only citizen may self-assign', () {
      expect(AppRoles.selfServiceRoles, ['citizen']);
      expect(AppRoles.isCitizen('citizen'), isTrue);
      // Authority roles can never self-assign.
      for (final role in AppRoles.all) {
        if (role != AppRoles.citizen) {
          expect(AppRoles.selfServiceRoles.contains(role), isFalse,
              reason: '$role must not be self-service');
        }
      }
    });

    test('valid roles accepted by rules are exactly AppRoles.all', () {
      expect(AppRoles.all,
          ['citizen', 'village_authority', 'district_authority', 'rescue', 'admin']);
    });
  });

  group('AppRoles — authority navigation gate (main_screen)', () {
    test('authority roles get command navigation', () {
      for (final role in ['village_authority', 'district_authority', 'rescue', 'admin']) {
        final isAuthority =
            AppRoles.isAuthority(role) || role == AppRoles.rescue;
        expect(isAuthority, isTrue, reason: '$role must reach Command nav');
      }
    });

    test('citizen gets citizen navigation', () {
      final isAuthority = AppRoles.isAuthority('citizen') || 'citizen' == AppRoles.rescue;
      expect(isAuthority, isFalse);
    });

    test('unknown/missing role never gets authority navigation', () {
      expect(AppRoles.isAuthority(null), isFalse);
      expect(AppRoles.isAuthority('superadmin'), isFalse);
      expect(AppRoles.isAuthority(''), isFalse);
    });
  });

  group('AppRoles — district-level scope gate', () {
    test('district authority and legacy admin are district-level', () {
      expect(AppRoles.isDistrictLevel('district_authority'), isTrue);
      expect(AppRoles.isDistrictLevel('admin'), isTrue);
    });

    test('village authority is NOT district-level (scope containment)', () {
      // A village authority must not receive district-wide feeds — this is
      // the rule the dashboard streams rely on for location scoping.
      expect(AppRoles.isDistrictLevel('village_authority'), isFalse);
      expect(AppRoles.isDistrictLevel('rescue'), isFalse);
      expect(AppRoles.isDistrictLevel('citizen'), isFalse);
    });
  });

  group('AppRoles — notification fan-out membership', () {
    test('authority query roles include rescue but exclude citizens', () {
      expect(AppRoles.authorityRolesForQuery, contains('rescue'));
      expect(AppRoles.authorityRolesForQuery, isNot(contains('citizen')));
    });
  });
}
