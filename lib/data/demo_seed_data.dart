// SATS Disaster — DEMO / PROTOTYPE SEED DATA.
//
// ⚠️  ALL DATA IN THIS FILE IS SYNTHETIC DEMO DATA FOR THE SIH26206
//     PROTOTYPE. It is NOT live government data and must never be
//     presented as such. Every seeded document carries `isDemoData: true`
//     (or a `demo: true` field) so the UI can label it honestly
//     ("Demo data").
//
// Scenario: pre-cyclone situation in the Ambajipeta mandal, East Godavari
// district, Andhra Pradesh — a realistic coastal Godavari delta location
// for cyclone/flood drills. Villages are real names from the bundled AP
// dataset (assets/data/andhra_pradesh.json); all statistics, contacts and
// statuses are invented for demonstration.
//
// This file is a pure data layer — NO Firestore calls, NO UI. The seed
// runner (`tool/seed_disaster_demo_data.dart`) writes these documents to
// Firestore. UI code must import this file only when a demo flag needs a
// default value, never to hardcode scenario data inline.

library;

// ─────────────────────────────────────────────────────────────────────────
//  Demo geography
// ─────────────────────────────────────────────────────────────────────────

const String kDemoDistrict = 'East Godavari';
const String kDemoMandal = 'Ambajipeta';

/// The five demo villages (real names from the AP dataset).
const List<String> kDemoVillages = [
  'Mukkamala',
  'Gangalakurru',
  'Irusumanda',
  'Mosalipalle',
  'Thondavaram',
];

/// Approximate coastal-delta coordinates per village (demo values).
const Map<String, List<double>> kDemoVillageCoords = {
  'Mukkamala': [16.6870, 82.0446],
  'Gangalakurru': [16.6952, 82.0581],
  'Irusumanda': [16.7018, 82.0312],
  'Mosalipalle': [16.6794, 82.0633],
  'Thondavaram': [16.7108, 82.0497],
};

// ─────────────────────────────────────────────────────────────────────────
//  Disaster events (2 scenarios)
// ─────────────────────────────────────────────────────────────────────────

/// Cyclone warning (the PRIMARY SIH demo scenario — step 1 of the flow).
final Map<String, dynamic> demoCycloneEvent = {
  'type': 'cyclone',
  'severity': 'high',
  'status': 'active',
  'title': 'Cyclone Warning — Ambajipeta Mandal',
  'summary':
      'A severe cyclonic storm is approaching the coastal Godavari delta. '
      'Heavy rainfall and gale winds expected within 24 hours.',
  'instructions':
      '1. Move to the nearest shelter before 6:00 PM. '
      '2. Carry drinking water, medicines and ID documents. '
      '3. Fishermen must not venture into the sea. '
      '4. Report stranded persons via Report Incident or call 1077.',
  'affectedVillages': kDemoVillages,
  'affectedMandals': [kDemoMandal],
  'affectedDistricts': [kDemoDistrict],
  'evacuationRequired': true,
  'createdBy': 'DEMO_AUTHORITY_UID',
  'createdByName': 'Demo District Authority',
  'startedAt': 'DEMO_STARTED_AT',
  'demo': true,
};

/// Flood follow-up scenario (secondary).
final Map<String, dynamic> demoFloodEvent = {
  'type': 'flood',
  'severity': 'medium',
  'status': 'monitoring',
  'title': 'Flood Watch — Low-lying villages',
  'summary':
      'Rising backwaters in the delta may flood low-lying areas near the '
      'canals. Authorities are monitoring water levels.',
  'instructions':
      'Do not enter floodwater on foot. Keep livestock on higher ground. '
      'Keep phones charged and follow further advisories.',
  'affectedVillages': ['Mukkamala', 'Mosalipalle'],
  'affectedMandals': [kDemoMandal],
  'affectedDistricts': [],
  'evacuationRequired': false,
  'createdBy': 'DEMO_AUTHORITY_UID',
  'createdByName': 'Demo Village Authority',
  'startedAt': 'DEMO_STARTED_AT',
  'demo': true,
};

final List<Map<String, dynamic>> demoDisasterEvents = [
  demoCycloneEvent,
  demoFloodEvent,
];

// ─────────────────────────────────────────────────────────────────────────
//  Shelters (5 — one per village)
// ─────────────────────────────────────────────────────────────────────────

final List<Map<String, dynamic>> demoShelters = [
  {
    'name': 'Mukkamala ZP High School Shelter',
    'district': kDemoDistrict,
    'mandal': kDemoMandal,
    'village': 'Mukkamala',
    'latitude': 16.6885,
    'longitude': 82.0431,
    'capacity': 400,
    'occupancy': 120,
    'status': 'active',
    'amenities': ['Drinking water', 'Cooked food', 'Toilets', 'Generator'],
    'supplies': ['Orc tablets', 'Blankets', 'Rice bags'],
    'contactPhone': '9000000001',
    'demo': true,
  },
  {
    'name': 'Gangalakurru Elementary School Shelter',
    'district': kDemoDistrict,
    'mandal': kDemoMandal,
    'village': 'Gangalakurru',
    'latitude': 16.6961,
    'longitude': 82.0570,
    'capacity': 250,
    'occupancy': 0,
    'status': 'active',
    'amenities': ['Drinking water', 'First aid'],
    'supplies': ['Orc tablets', 'Candles'],
    'contactPhone': '9000000002',
    'demo': true,
  },
  {
    'name': 'Irusumanda Panchayat Community Hall',
    'district': kDemoDistrict,
    'mandal': kDemoMandal,
    'village': 'Irusumanda',
    'latitude': 16.7025,
    'longitude': 82.0300,
    'capacity': 300,
    'occupancy': 0,
    'status': 'active',
    'amenities': ['Drinking water', 'Toilets'],
    'supplies': ['Blankets'],
    'contactPhone': '9000000003',
    'demo': true,
  },
  {
    'name': 'Mosalipalle Anganwadi Centre Shelter',
    'district': kDemoDistrict,
    'mandal': kDemoMandal,
    'village': 'Mosalipalle',
    'latitude': 16.6801,
    'longitude': 82.0620,
    'capacity': 150,
    'occupancy': 150,
    'status': 'full',
    'amenities': ['Drinking water'],
    'supplies': [],
    'contactPhone': '9000000004',
    'demo': true,
  },
  {
    'name': 'Thondavaram Church Hall Shelter',
    'district': kDemoDistrict,
    'mandal': kDemoMandal,
    'village': 'Thondavaram',
    'latitude': 16.7115,
    'longitude': 82.0485,
    'capacity': 200,
    'occupancy': 45,
    'status': 'active',
    'amenities': ['Drinking water', 'Cooked food', 'Medical support'],
    'supplies': ['Orc tablets', 'Blankets', 'Rice bags'],
    'contactPhone': '9000000005',
    'demo': true,
  },
];

// ─────────────────────────────────────────────────────────────────────────
//  Village preparedness records
// ─────────────────────────────────────────────────────────────────────────

const List<String> demoEvacuationRoutes = [
  'Main route: village centre → Ambajipeta–Kakinada road (left bank) → '
      'Kakinada relief camps, 14 km. Motorable except during peak surge.',
  'Alternative: canal bund footpath → Amalapuram relief centre, 9 km. '
      'For pedestrians and two-wheelers only.',
];

const List<Map<String, dynamic>> demoEmergencyContacts = [
  {'name': 'Village Secretary', 'phone': '9000010001'},
  {'name': 'Sarpanch', 'phone': '9000010002'},
  {'name': 'Disaster Helpline (State)', 'phone': '1077'},
  {'name': 'Ambulance', 'phone': '108'},
  {'name': 'Police', 'phone': '100'},
];

/// Preparedness template per village; varies risk/vulnerable counts so the
/// dashboard shows a realistic spread.
List<Map<String, dynamic>> demoPreparednessRecords() {
  const villageProfiles = <List<dynamic>>[
    // [village, riskLevel, vulnerableCount, checklistDoneCount]
    ['Mukkamala', 'severe', 85, 4],
    ['Gangalakurru', 'high', 40, 3],
    ['Irusumanda', 'high', 52, 2],
    ['Mosalipalle', 'moderate', 25, 5],
    ['Thondavaram', 'moderate', 31, 4],
  ];

  return villageProfiles.map((profile) {
    final doneCount = profile[3] as int;
    final checklist = <String, Map<String, dynamic>>{};
    var i = 0;
    for (final item in demoChecklistItems) {
      checklist[item['id'] as String] = {
        'label': item['label'],
        'done': i < doneCount,
      };
      i++;
    }

    return <String, dynamic>{
      'village': profile[0] as String,
      'riskLevel': profile[1] as String,
      'hazards': ['cyclone', 'flood'],
      'checklist': checklist,
      'vulnerableCount': profile[2] as int,
      'sheltersCount': 1,
      'evacuationRoutes': demoEvacuationRoutes,
      'emergencyContacts': demoEmergencyContacts,
      'isDemoData': true,
    };
  }).toList();
}

const List<Map<String, dynamic>> demoChecklistItems = [
  {'id': 'siren_test', 'label': 'Village warning siren tested'},
  {'id': 'shelter_ready', 'label': 'Shelters cleaned and stocked'},
  {'id': 'vulnerable_list', 'label': 'Vulnerable residents list updated'},
  {'id': 'evacuation_drill', 'label': 'Evacuation drill conducted'},
  {'id': 'boat_owners', 'label': 'Local boat owners contacted'},
  {'id': 'comms_check', 'label': 'PA / communication system checked'},
];

// ─────────────────────────────────────────────────────────────────────────
//  Demo user accounts
// ─────────────────────────────────────────────────────────────────────────
//
// These are NOT created by the seed script directly — role assignment
// requires the Admin SDK (client rules forbid privileged self-signup).
// The seed script documents the process: create auth users with the emails
// below via console/admin, then set the users/{uid} documents.

final List<Map<String, dynamic>> demoUserSpecs = [
  {
    'email': 'demo.village.authority@sats-disaster.test',
    'name': 'Demo Village Authority',
    'phone': '9000001001',
    'role': 'village_authority',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'purpose': 'Runs the village-level dashboard for Mukkamala.',
  },
  {
    'email': 'demo.district.authority@sats-disaster.test',
    'name': 'Demo District Authority',
    'phone': '9000001002',
    'role': 'district_authority',
    'village': '',
    'mandal': '',
    'district': kDemoDistrict,
    'purpose': 'Runs the mandal/district dashboard and composes alerts.',
  },
  {
    'email': 'demo.rescue@sats-disaster.test',
    'name': 'Demo Rescue Team',
    'phone': '9000001003',
    'role': 'rescue',
    'village': '',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'purpose': 'Assigned incident response (Phase 6+).',
  },
  {
    'email': 'demo.citizen1@sats-disaster.test',
    'name': 'Demo Citizen — Mukkamala',
    'phone': '9000002001',
    'role': 'citizen',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'purpose': 'Primary demo citizen in the warned village.',
  },
  {
    'email': 'demo.citizen2@sats-disaster.test',
    'name': 'Demo Citizen — Gangalakurru',
    'phone': '9000002002',
    'role': 'citizen',
    'village': 'Gangalakurru',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'purpose': 'Second citizen for multi-village targeting demo.',
  },
];

// ─────────────────────────────────────────────────────────────────────────
//  Sample incidents (for the authority dashboard)
// ─────────────────────────────────────────────────────────────────────────

final List<Map<String, dynamic>> demoIncidents = [
  {
    'incidentType': 'flood',
    'severity': 'critical',
    'description':
        'Water entering houses near the canal bund. About 10 families '
        'stranded on rooftops, requesting boats.',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6874,
    'longitude': 82.0450,
    'disasterRef': 'cyclone', // resolved to the seeded cyclone event ID at seed time
    'affectedPeople': 48,
    'rescueRequired': true,
    'rescuePeopleCount': 12,
    'medicalRequired': true,
    'resourcesRequired': ['boats', 'rescue_team', 'drinking_water'],
    'status': 'reported',
    'demo': true,
  },
  {
    'incidentType': 'person_trapped',
    'severity': 'high',
    'description':
        'Two elderly residents unable to walk to the shelter; need help '
        'with evacuation.',
    'village': 'Irusumanda',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.7020,
    'longitude': 82.0316,
    'disasterRef': 'cyclone',
    'affectedPeople': 2,
    'rescueRequired': true,
    'rescuePeopleCount': 2,
    'medicalRequired': false,
    'resourcesRequired': ['rescue_team', 'transport'],
    'status': 'verified',
    'demo': true,
  },
  {
    'incidentType': 'infrastructure_collapse',
    'severity': 'medium',
    'description': 'Power line snapped near the panchayat office; area '
        'without electricity since morning.',
    'village': 'Gangalakurru',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6957,
    'longitude': 82.0578,
    'disasterRef': 'cyclone',
    'affectedPeople': 120,
    'rescueRequired': false,
    'rescuePeopleCount': 0,
    'medicalRequired': false,
    'resourcesRequired': ['generator'],
    'status': 'dispatched',
    'demo': true,
  },
  {
    'incidentType': 'medical',
    'severity': 'high',
    'description': 'Pregnant woman requires transfer to hospital; road '
        'approach partially flooded.',
    'village': 'Thondavaram',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.7110,
    'longitude': 82.0490,
    'disasterRef': null,
    'affectedPeople': 1,
    'rescueRequired': true,
    'rescuePeopleCount': 1,
    'medicalRequired': true,
    'resourcesRequired': ['medical_team', 'transport'],
    'status': 'triaged',
    'demo': true,
  },
  {
    'incidentType': 'other',
    'severity': 'low',
    'description': 'Fallen tree blocking the school-lane road; no '
        'casualties.',
    'village': 'Mosalipalle',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6798,
    'longitude': 82.0627,
    'disasterRef': 'flood',
    'affectedPeople': 0,
    'rescueRequired': false,
    'rescuePeopleCount': 0,
    'medicalRequired': false,
    'resourcesRequired': [],
    'status': 'resolved',
    'demo': true,
  },
];

/// Sample evacuation states per village for the dashboard (Phase 5 makes
/// these live-computed; for now they exist as preparedness/alert context).
const Map<String, String> demoEvacuationStatus = {
  'Mukkamala': 'In progress — 120 of ~600 residents at shelter',
  'Gangalakurru': 'Not started',
  'Irusumanda': 'Not started',
  'Mosalipalle': 'Complete — shelter at capacity',
  'Thondavaram': 'In progress — 45 of ~350 residents at shelter',
};

// ─────────────────────────────────────────────────────────────────────────
//  Phase 5 (AFTER): damage assessments
// ─────────────────────────────────────────────────────────────────────────
//  `disasterRef` is resolved to the seeded cyclone/flood event ID at seed
//  time ('cyclone' | 'flood' | null). Scenario: the cyclone has passed
//  Mukkamala; damage is being surveyed, relief is moving, one village is
//  already in recovery.

final List<Map<String, dynamic>> demoDamageAssessments = [
  {
    'disasterRef': 'cyclone',
    'damageType': 'house',
    'severity': 'critical',
    'description':
        'Six houses near the canal bund lost roofs; walls cracked and '
        'uninhabitable until inspected.',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6880,
    'longitude': 82.0448,
    'estimatedAffectedPeople': 32,
    'status': 'verified',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'damageType': 'road',
    'severity': 'high',
    'description':
        'Panchayat road to the school washed out for ~40 m; only tractors '
        'passable. Relief trucks need a detour.',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6866,
    'longitude': 82.0461,
    'estimatedAffectedPeople': 600,
    'status': 'assessed',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'damageType': 'electricity',
    'severity': 'medium',
    'description':
        'Three poles down on the Gangalakurru feeder; part of the village '
        'without power since the storm.',
    'village': 'Gangalakurru',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.6955,
    'longitude': 82.0575,
    'estimatedAffectedPeople': 120,
    'status': 'reported',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'damageType': 'public_building',
    'severity': 'medium',
    'description':
        'Irusumanda community hall shelter roof panels torn; needs tarpaulin '
        'before the next shower.',
    'village': 'Irusumanda',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'latitude': 16.7016,
    'longitude': 82.0310,
    'estimatedAffectedPeople': 0,
    'status': 'recovered', // the one village already in recovery
    'demo': true,
  },
];

// ─────────────────────────────────────────────────────────────────────────
//  Phase 5 (AFTER): relief resources
// ─────────────────────────────────────────────────────────────────────────
//  One record per (village, resourceType). Includes at least one deliberate
//  shortage for the demo. Units are village-realistic.

final List<Map<String, dynamic>> demoResources = [
  {
    'disasterRef': 'cyclone',
    'resourceType': 'drinking_water',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 2000,
    'requiredQuantity': 6000,
    'allocatedQuantity': 2000,
    'unit': 'litres',
    'status': 'needed', // SHORTAGE: 4000 litres short
    'notes': 'Distribution at ZP High School shelter, 6–10 AM daily.',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'resourceType': 'food_packets',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 400,
    'requiredQuantity': 400,
    'allocatedQuantity': 400,
    'unit': 'packets',
    'status': 'allocated', // fully covered and dispatched
    'notes': 'One packet per family per day.',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'resourceType': 'tarpaulins',
    'village': 'Mukkamala',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 12,
    'requiredQuantity': 40,
    'allocatedQuantity': 12,
    'unit': 'units',
    'status': 'needed', // SHORTAGE for roof repairs
    'notes': 'For the six damaged houses and community hall.',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'resourceType': 'generators',
    'village': 'Gangalakurru',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 2,
    'requiredQuantity': 2,
    'allocatedQuantity': 1,
    'unit': 'units',
    'status': 'allocated',
    'notes': 'One running at the panchayat office for mobile charging.',
    'demo': true,
  },
  {
    'disasterRef': 'cyclone',
    'resourceType': 'medicines',
    'village': 'Irusumanda',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 0,
    'requiredQuantity': 25,
    'allocatedQuantity': 0,
    'unit': 'packets',
    'status': 'exhausted', // exhausted: needs resupply
    'notes': 'Fever/ORC stock ran out at the camp; resupply requested.',
    'demo': true,
  },
  {
    'disasterRef': null, // routine stock, not disaster-linked
    'resourceType': 'blankets',
    'village': 'Thondavaram',
    'mandal': kDemoMandal,
    'district': kDemoDistrict,
    'quantity': 150,
    'requiredQuantity': 100,
    'allocatedQuantity': 50,
    'unit': 'units',
    'status': 'available',
    'notes': 'Panchayat stock; available for neighbouring villages.',
    'demo': true,
  },
];

// ─────────────────────────────────────────────────────────────────────────
//  Phase 5 (AFTER): disaster-linked missing person example
// ─────────────────────────────────────────────────────────────────────────

final Map<String, dynamic> demoDisasterMissingPerson = {
  'fullName': 'Lakshmi Gadde',
  'age': 68,
  'gender': 'Female',
  'userVillage': 'Mukkamala',
  'userMandal': kDemoMandal,
  'lastSeenLocation': 'Near the canal bund, west side',
  'clothesDescription': 'Green saree, spectacles',
  'additionalNotes':
      'Last seen during the evacuation of the canal-side houses; may have '
      'moved to relatives in the next village.',
  'disasterRef': 'cyclone', // resolved to the seeded cyclone event ID
  'demo': true,
};
