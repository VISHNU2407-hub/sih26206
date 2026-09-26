// SATS Disaster — Phase 1: seed runner for the demo dataset.
//
// ⚠️  Writes SYNTHETIC DEMO DATA (from lib/data/demo_seed_data.dart) to the
//     Firestore project configured in lib/firebase_options.dart. Every
//     document is tagged demo: true / isDemoData: true.
//
// Run with:   dart run tool/seed_disaster_demo_data.dart
//
// AUTHORITY ACCOUNTS: client-side code cannot create authority roles
// (Firestore rules forbid role escalation, by design). The script
// demonstrates the correct provisioning path:
//   1. Create auth users for the demo emails (Firebase console or Admin SDK).
//   2. Set their users/{uid} documents with the required role using the
//      Admin SDK (bypasses rules) — see `seedAuthorityUsers` below, which
//      is invoked only when --with-users is passed AND an admin credential
//      is available.
//
// Idempotent: re-running updates the same deterministic documents.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:village_verse/data/demo_seed_data.dart';
import 'package:village_verse/firebase_options.dart';
import 'package:village_verse/models/damage_assessment_model.dart';
import 'package:village_verse/models/disaster_event_model.dart';
import 'package:village_verse/models/missing_person_alert_model.dart';
import 'package:village_verse/models/resource_model.dart';
import 'package:village_verse/models/shelter_model.dart';
import 'package:village_verse/models/village_preparedness_model.dart';
import 'package:village_verse/services/disaster_alert_notification_service.dart';

Future<void> main(List<String> args) async {
  final withUsers = args.contains('--with-users');
  // Phase 4: also fan out targeted `disaster_alert` in-app notifications
  // for the seeded disaster events (deterministic IDs — idempotent).
  final withNotifications = args.contains('--notify');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final db = FirebaseFirestore.instance;

  print('── SATS Disaster demo seed (DEMO DATA, not real government data) ──');

  // ── 1. Disaster events ────────────────────────────────────────────────
  final disasterIds = <String, String>{};
  for (final event in demoDisasterEvents) {
    final ref = db.collection('disasters').doc(_key(event['title'] as String));
    final startedAt = DateTime.now().subtract(const Duration(hours: 6));
    final eventData = Map<String, dynamic>.from(event)
      ..remove('disasterRef') // only incidents carry this key
      ..['startedAt'] = Timestamp.fromDate(startedAt)
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(eventData, SetOptions(merge: true));
    disasterIds[event['title'] as String] = ref.id;
    print('  disasters/${ref.id}  (${event['type']}, ${event['severity']})');
  }
  final cycloneId = disasterIds[demoCycloneEvent['title'] as String]!;
  final floodId = disasterIds[demoFloodEvent['title'] as String]!;

  // ── 1b. Targeted disaster_alert notifications (optional, Phase 4) ──
  if (withNotifications) {
    for (final entry in disasterIds.entries) {
      final raw = demoDisasterEvents
          .firstWhere((e) => e['title'] == entry.key);
      final event = DisasterEventModel.fromFirestore(
        {
          ...Map<String, dynamic>.from(raw)
            ..remove('disasterRef')
            ..remove('startedAt')
            ..remove('createdAt')
            ..remove('updatedAt'),
          'startedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 6))),
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
        entry.value,
      );
      if (event == null) continue;
      final sent = await DisasterAlertNotificationService()
          .createNotificationsForDisaster(event);
      print('  notifications: $sent targeted disaster_alert doc(s) for '
          '"${entry.key}"');
    }
  }

  // ── 2. Shelters ───────────────────────────────────────────────────────
  for (final shelter in demoShelters) {
    final model = ShelterModel(
      name: shelter['name'] as String,
      district: shelter['district'] as String,
      mandal: shelter['mandal'] as String,
      village: shelter['village'] as String,
      latitude: shelter['latitude'] as double?,
      longitude: shelter['longitude'] as double?,
      capacity: shelter['capacity'] as int,
      occupancy: shelter['occupancy'] as int,
      status: shelter['status'] as String,
      amenities: (shelter['amenities'] as List).cast<String>(),
      supplies: (shelter['supplies'] as List).cast<String>(),
      contactPhone: shelter['contactPhone'] as String,
      updatedBy: 'demo_seed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final ref = db.collection('shelters').doc(_key(shelter['name'] as String));
    await ref.set(model.toFirestore(), SetOptions(merge: true));
    print('  shelters/${ref.id}  (${shelter['village']})');
  }

  // ── 3. Preparedness records ───────────────────────────────────────────
  for (final record in demoPreparednessRecords()) {
    final model = VillagePreparednessModel(
      district: kDemoDistrict,
      mandal: kDemoMandal,
      village: record['village'] as String,
      riskLevel: record['riskLevel'] as String,
      hazards: (record['hazards'] as List).cast<String>(),
      checklist: (record['checklist'] as Map<String, Map<String, dynamic>>),
      vulnerableCount: record['vulnerableCount'] as int,
      sheltersCount: record['sheltersCount'] as int,
      evacuationRoutes: (record['evacuationRoutes'] as List).cast<String>(),
      emergencyContacts:
          (record['emergencyContacts'] as List).cast<Map<String, dynamic>>(),
      isDemoData: true,
      updatedAt: DateTime.now(),
    );
    final ref = db.collection('preparedness').doc(model.villageKey);
    await ref.set(model.toFirestore(), SetOptions(merge: true));
    print('  preparedness/${ref.id}  (risk: ${model.riskLevel})');
  }

  // ── 4. Sample incidents ───────────────────────────────────────────────
  for (final incident in demoIncidents) {
    final disasterId = incident['disasterRef'] == 'cyclone'
        ? cycloneId
        : incident['disasterRef'] == 'flood'
            ? floodId
            : null;
    final ref =
        await db.collection('incidents').add({
      'incidentType': incident['incidentType'],
      'severity': incident['severity'],
      'description': incident['description'],
      'latitude': incident['latitude'],
      'longitude': incident['longitude'],
      'district': incident['district'],
      'mandal': incident['mandal'],
      'village': incident['village'],
      'disasterId': disasterId,
      'reportedBy': 'DEMO_CITIZEN_UID',
      'reportedByName': 'Demo Citizen',
      'affectedPeople': incident['affectedPeople'],
      'rescueRequired': incident['rescueRequired'],
      'rescuePeopleCount': incident['rescuePeopleCount'],
      'medicalRequired': incident['medicalRequired'],
      'resourcesRequired': incident['resourcesRequired'],
      'media': const [],
      'status': incident['status'],
      'assignedTo': null,
      'updatedBy': 'demo_seed',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'demo': true,
    });
    print('  incidents/${ref.id}  (${incident['incidentType']}, '
        '${incident['village']}, ${incident['status']})');
  }

  // ── 4b. Damage assessments (Phase 5 — idempotent keys) ─────────────
  for (final item in demoDamageAssessments) {
    final disasterId = item['disasterRef'] == 'cyclone'
        ? cycloneId
        : item['disasterRef'] == 'flood'
            ? floodId
            : null;
    final model = DamageAssessmentModel(
      disasterId: disasterId,
      reportedBy: 'DEMO_AUTHORITY_UID',
      reportedByName: 'Demo District Authority',
      district: item['district'] as String,
      mandal: item['mandal'] as String,
      village: item['village'] as String,
      latitude: item['latitude'] as double?,
      longitude: item['longitude'] as double?,
      damageType: item['damageType'] as String,
      severity: item['severity'] as String,
      description: item['description'] as String,
      estimatedAffectedPeople: item['estimatedAffectedPeople'] as int,
      status: item['status'] as String,
      updatedBy: 'demo_seed',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now(),
      isDemoData: true,
    );
    final ref = db
        .collection('damage_assessments')
        .doc(_key('${item['village']}_${item['damageType']}'));
    await ref.set(model.toFirestore(), SetOptions(merge: true));
    print('  damage_assessments/${ref.id}  '
        '(${item['damageType']}, ${item['severity']}, ${item['village']})');
  }

  // ── 4c. Relief resources (Phase 5 — idempotent keys) ───────────────
  for (final item in demoResources) {
    final disasterId = item['disasterRef'] == 'cyclone'
        ? cycloneId
        : item['disasterRef'] == 'flood'
            ? floodId
            : null;
    final model = ResourceModel(
      disasterId: disasterId,
      district: item['district'] as String,
      mandal: item['mandal'] as String,
      village: item['village'] as String,
      resourceType: item['resourceType'] as String,
      quantity: item['quantity'] as int,
      requiredQuantity: item['requiredQuantity'] as int,
      allocatedQuantity: item['allocatedQuantity'] as int,
      unit: item['unit'] as String,
      status: item['status'] as String,
      notes: item['notes'] as String,
      updatedBy: 'demo_seed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDemoData: true,
    );
    final ref = db
        .collection('resources')
        .doc(_key('${item['village']}_${item['resourceType']}'));
    await ref.set(model.toFirestore(), SetOptions(merge: true));
    print('  resources/${ref.id}  (${item['resourceType']}, '
        '${item['village']}, ${item['status']})');
  }

  // ── 4d. Disaster-linked missing person example (Phase 5) ───────────
  {
    final mp = demoDisasterMissingPerson;
    final model = MissingPersonAlertModel(
      id: 'demo_missing_cyclone',
      createdBy: 'DEMO_CITIZEN_UID',
      createdByName: 'Demo Citizen',
      userVillage: mp['userVillage'] as String,
      userMandal: mp['userMandal'] as String,
      photoUrl: '', // demo record carries no photo
      fullName: mp['fullName'] as String,
      age: mp['age'] as int,
      gender: mp['gender'] as String,
      lastSeenLocation: mp['lastSeenLocation'] as String,
      missingDateTime:
          DateTime.now().subtract(const Duration(hours: 8)),
      clothesDescription: mp['clothesDescription'] as String,
      additionalNotes: mp['additionalNotes'] as String,
      guardianContactNumber: '9000002001',
      whatsappNumber: '9000002001',
      status: 'active',
      createdAt: DateTime.now(),
      disasterId: cycloneId,
    );
    final ref = db.collection('missing_person_alerts').doc(model.id);
    await ref.set(model.toFirestore(), SetOptions(merge: true));
    print('  missing_person_alerts/${ref.id}  '
        '(${model.fullName}, linked to cyclone)');
  }

  // ── 5. Authority / demo users (controlled path) ───────────────────────
  if (withUsers) {
    await seedAuthorityUsers(db);
  } else {
    print('');
    print('NOTE: demo users NOT seeded. Authority roles require the Admin');
    print('SDK (client rules forbid self-escalation). Re-run with:');
    print('  dart run tool/seed_disaster_demo_data.dart --with-users');
    print('after creating auth users for the demo emails, or set roles via');
    print('the Firebase console. Demo user specs are in');
    print('lib/data/demo_seed_data.dart (demoUserSpecs).');
  }

  if (!withNotifications) {
    print('');
    print('NOTE: disaster_alert notifications NOT created. To fan out');
    print('targeted in-app notifications for the seeded disasters, re-run with:');
    print('  dart run tool/seed_disaster_demo_data.dart --notify');
  }

  print('');
  print('Seed complete. All documents are tagged demo data.');
  print('Evacuation status (demo): $demoEvacuationStatus');
}

/// Prints the exact Admin SDK / console steps for authority provisioning.
/// Requires an environment with admin credentials (out of scope for the
/// client runner) — this documents and validates the spec.
Future<void> seedAuthorityUsers(FirebaseFirestore db) async {
  print('');
  print('Authority provisioning checklist (Admin SDK / console):');
  for (final spec in demoUserSpecs) {
    print('  • ${spec['email']} → role=${spec['role']} '
        '(${spec['purpose']})');
  }
  print('');
  print('For each: create the Auth user, then set users/{uid}:');
  print('  admin.auth().createUser({email, password})');
  print('  admin.firestore().collection("users").doc(uid).set({');
  print('    name, phone, email, role,');
  print('    district,');
  print('    village: <mandal>,   // LEGACY mapping: mandal → "village"');
  print('    street: <village>,   // LEGACY mapping: village → "street"');
  print('    state: "Andhra Pradesh", isDemoData: true,');
  print('    createdAt: admin.firestore.FieldValue.serverTimestamp(),');
  print('  });');
}

/// Deterministic document key from a display name.
String _key(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
