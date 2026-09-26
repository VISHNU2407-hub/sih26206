// SATS Disaster — Flutter-engine harness for the demo seed runner.
//
// WHY THIS EXISTS (no seed logic changed):
// `dart run tool/seed_disaster_demo_data.dart` fails in the plain Dart VM
// ("type 'InvalidType' is not a subtype of type 'FunctionType'" from the
// _FfiUseSiteTransformer) because cloud_firestore's import chain pulls in
// dart:ui, which only exists inside the Flutter engine. A Flutter test runs
// that same seed main() inside the engine, so the VM compilation error
// disappears. `flutter run -d windows` would also work in principle but this
// machine has no Visual Studio toolchain, so the desktop app can't compile.
//
// SAFETY GATE: the seed only executes when SATS_SEED=1 is set in the
// environment. A plain `flutter test` run therefore SKIPS it — nothing is
// written to Firestore unless the gate is explicitly opened.
//
// Firebase targeting is untouched: the seed calls Firebase.initializeApp(
// options: DefaultFirebaseOptions.currentPlatform) and the Flutter test
// engine resolves that to the android entry in lib/firebase_options.dart,
// which targets sats-disaster-sih.
//
// Run the seed:
//   bash:       SATS_SEED=1 flutter test test/tool/seed_flutter_harness_test.dart
//   PowerShell: $env:SATS_SEED='1'; flutter test test/tool/seed_flutter_harness_test.dart
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_disaster_demo_data.dart' as seed;

void main() {
  // cloud_firestore calls ServicesBinding.instance during Firebase
  // initialization; that binding only exists after test-binding setup.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SATS disaster demo seed (Flutter-engine harness)',
    timeout: const Timeout(Duration(minutes: 15)),
    () async {
      if (Platform.environment['SATS_SEED'] != '1') {
        // ignore: avoid_print
        print(
          'SKIPPED — no Firestore writes. Set SATS_SEED=1 to run the seed.',
        );
        return;
      }
      await seed.main(['--notify']);
    },
  );
}
