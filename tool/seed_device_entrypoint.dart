// SATS Disaster — Android-device entrypoint for the demo seed runner.
//
// WHY THIS EXISTS (no seed logic changed):
// - `dart run tool/seed_disaster_demo_data.dart` cannot compile in the plain
//   Dart VM (cloud_firestore's import chain pulls in dart:ui).
// - A `flutter test` harness cannot initialize Firebase for real: the plugins
//   talk to the native embedder over platform channels, which do not exist in
//   the test environment ("channel-error" from FirebaseCoreHostApi).
// - Therefore the seed must run inside a REAL Flutter app. This headless
//   entrypoint runs on the connected Android device via:
//     flutter run -t tool/seed_device_entrypoint.dart -d tscqtorcojylfmon
//
// WHAT IT DOES:
//   1. Initializes Firebase with DefaultFirebaseOptions.currentPlatform.
//      On the device this resolves to the ANDROID entry in
//      lib/firebase_options.dart → projectId: sats-disaster-sih.
//   2. Signs in ANONYMOUSLY so Firestore's isAuthenticated() rules are
//      satisfied for collections gated only on authentication.
//   3. Runs the EXISTING, unmodified seed: seed.main(['--notify']).
//      (The seed's own Firebase.initializeApp call with identical options
//      is a no-op returning the already-initialized default app.)
//
// PRE-FLIGHT (Firebase Console, one-time):
//   sats-disaster-sih → Authentication → Sign-in method → enable "Anonymous".
//
// NOTE ON RULES: collections gated on isAuthority()/isRescueTeam()
// (disasters, shelters, preparedness, resources, damage_assessments) also
// require the signed-in user's users/{uid} document to carry an authority
// role. If the repo rules are deployed to sats-disaster-sih, the anonymous
// user (no profile document) will be denied on those collections while
// notifications + missing_person_alerts writes still succeed. If the new
// project is still in open test-mode rules, everything seeds.
// ignore_for_file: avoid_print
import 'dart:io' show exit;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'package:village_verse/firebase_options.dart';

import 'seed_disaster_demo_data.dart' as seed;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase initialization (device → android options → sats-disaster-sih).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    _fail('FIREBASE INITIALIZATION FAILED', e);
  }
  print('Firebase project: ${Firebase.app().options.projectId}');

  // 2. Anonymous sign-in (satisfies isAuthenticated() rules).
  try {
    final cred = await FirebaseAuth.instance.signInAnonymously();
    final user = cred.user;
    if (user == null) {
      _fail('ANONYMOUS SIGN-IN RETURNED NO USER', null);
    }
    print('Signed in anonymously as uid: ${user.uid}');
  } catch (e) {
    _fail(
      'ANONYMOUS AUTHENTICATION FAILED — enable the Anonymous sign-in '
      'provider in the sats-disaster-sih Firebase Console '
      '(Authentication → Sign-in method) and retry',
      e,
    );
  }

  // 3. Run the existing, unmodified demo seed.
  print('── Running SATS Disaster demo seed (--notify) ──');
  try {
    await seed.main(['--notify']);
  } catch (e) {
    _fail('SEED EXECUTION FAILED (see Firestore rules state if '
        'permission-denied)', e);
  }
  print('── Seed complete. Exiting. ──');
  exit(0);
}

Never _fail(String message, Object? error) {
  print('');
  print('❌ $message');
  if (error != null) {
    print('   $error');
  }
  print('');
  exit(1);
}
