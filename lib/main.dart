import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';

import 'screens/splash_screen.dart';
import 'screens/profile/guardian_setup_screen.dart';

import 'services/guardian_alert_service.dart';
import 'services/stealth_sos_trigger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence so the app works with cached
  // data when the network is unavailable — critical for emergency use.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await GuardianAlertService.instance.initialize();
  await StealthSOSTriggerService.instance.initialize();

  runApp(const VillageOneApp());
}

class VillageOneApp extends StatelessWidget {
  const VillageOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SATS',
      debugShowCheckedModeBanner: false,
      routes: {'/guardian-setup': (context) => const GuardianSetupScreen()},
      theme: buildAppTheme(),

      // SplashScreen handles the entire initial routing:
      // 1. Animated splash for 2.5 seconds
      // 2. Checks authentication status
      // 3. Navigates to AuthScreen, ProfileSetupScreen, or MainScreen
      home: const SplashScreen(),
    );
  }
}
