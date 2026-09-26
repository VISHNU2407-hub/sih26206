import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Firebase initialized successfully');
  print('Starting hospital upload...');

  // Read the JSON file
  final file = File('assets/data/hospital_data.csv.json');
  if (!await file.exists()) {
    print('ERROR: JSON file not found at ${file.path}');
    return;
  }

  print('Reading JSON file...');
  final jsonString = await file.readAsString();
  final List<dynamic> jsonData = json.decode(jsonString);

  print('Found ${jsonData.length} hospital records');
  print('Starting upload to Firestore...');

  int successCount = 0;
  int skipCount = 0;
  int errorCount = 0;

  final firestore = FirebaseFirestore.instance;

  // Check if hospitals collection already exists and has data
  print('Checking if hospitals collection already exists...');
  final existingSnapshot = await firestore
      .collection('hospitals')
      .limit(1)
      .get();
  if (existingSnapshot.docs.isNotEmpty) {
    print(
      'WARNING: Hospitals collection already exists with ${existingSnapshot.docs.length}+ documents.',
    );
    print('Skipping upload to prevent duplicates.');
    print('========================================');
    return;
  }
  print('Hospitals collection is empty. Proceeding with upload...\n');

  for (int i = 0; i < jsonData.length; i++) {
    final record = jsonData[i] as Map<String, dynamic>;

    try {
      // Extract and parse coordinates
      final coordinatesStr = record['Location_Coordinates'] as String?;
      double? latitude;
      double? longitude;

      if (coordinatesStr != null &&
          coordinatesStr.isNotEmpty &&
          coordinatesStr != '0') {
        final parts = coordinatesStr.split(',');
        if (parts.length == 2) {
          try {
            latitude = double.parse(parts[0].trim());
            longitude = double.parse(parts[1].trim());
          } catch (e) {
            print(
              'WARNING: Invalid coordinate format at record $i: $coordinatesStr',
            );
            latitude = null;
            longitude = null;
          }
        }
      }

      // Skip records with invalid coordinates
      if (latitude == null || longitude == null) {
        print('SKIPPED: Record $i - Invalid or missing coordinates');
        skipCount++;
        continue;
      }

      // Extract phone number (use empty string if missing or invalid)
      final phone = record['Telephone'] as String?;
      final phoneStr = (phone != null && phone.isNotEmpty && phone != '0')
          ? phone
          : '';

      // Build hospital document
      final hospitalData = {
        'name': record['Hospital_Name'] as String? ?? '',
        'address': record['Address_Original_First_Line'] as String? ?? '',
        'category': record['Hospital_Category'] as String? ?? '',
        'type': record['Hospital_Care_Type'] as String? ?? '',
        'system': record['Discipline_Systems_of_Medicine'] as String? ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'phone': phoneStr,
        'state': record['State'] as String? ?? '',
        'district': record['District'] as String? ?? '',
      };

      // Upload to Firestore
      await firestore.collection('hospitals').add(hospitalData);

      successCount++;

      // Print progress for each hospital
      print('Uploading hospital $successCount: ${hospitalData['name']}');
    } catch (e) {
      print('ERROR: Failed to upload record $i: $e');
      errorCount++;
    }
  }

  print('\n========================================');
  print('Upload Complete!');
  print('========================================');
  print('Successfully uploaded: $successCount hospitals');
  print('Skipped (invalid coordinates): $skipCount');
  print('Errors: $errorCount');
  print('Total processed: ${jsonData.length}');
  print('========================================');
  print('Hospitals uploaded successfully');
}
