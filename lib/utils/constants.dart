import 'package:flutter/material.dart';

class AppConstants {
  // App info
  static const String appName = 'SATS';
  static const String appVersion = '1.0.0';

  // Colors
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color secondaryColor = Color(0xFF42A5F5);
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

  // Emergency types
  static const List<Map<String, dynamic>> emergencyTypes = [
    {
      'type': 'sos',
      'title': 'SOS ALERTS',
      'icon': Icons.sos,
      'color': Color(0xFFE91E63),
      'description': 'Women and Child Safety',
    },
    {
      'type': 'medical',
      'title': 'MEDICAL EMERGENCY',
      'icon': Icons.local_hospital,
      'color': Color(0xFFF44336),
      'description': 'Ambulance and Medical Help',
    },
    {
      'type': 'missing_person',
      'title': 'MISSING PERSON ALERTS',
      'icon': Icons.person_search,
      'color': Color(0xFFFF9800),
      'description': 'Report and Track Missing People',
    },
    {
      'type': 'blood_bank',
      'title': 'Blood Bank',
      'icon': Icons.bloodtype,
      'color': Color(0xFFD32F2F),
      'description': 'Find emergency blood donors nearby',
    },
  ];

  // Emergency numbers
  static const Map<String, String> emergencyNumbers = {
    'police': '100',
    'ambulance': '108',
    'fire': '101',
    'women_helpline': '1091',
    'child_helpline': '1098',
  };

  // Validation
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 10;
  static const int maxGuardians = 3;

  // Firestore collections
  static const String usersCollection = 'users';
  static const String guardiansCollection = 'guardians';
  static const String complaintsCollection = 'complaints';

  // Storage paths
  static const String profileImagesPath = 'profile_images';
}

class AppStrings {
  // Common
  static const String appName = 'SATS';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String remove = 'Remove';

  // Auth
  static const String signInWithGoogle = 'Continue with Google';
  static const String signingIn = 'Signing in...';
  static const String signInFailed = 'Sign in was cancelled or failed';

  // Profile
  static const String profileSetup = 'Profile Setup';
  static const String completeProfile = 'Complete your profile to continue';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';
  static const String state = 'State';
  static const String district = 'District';
  static const String mandal = 'Mandal';
  static const String village = 'Village';
  static const String profilePicture = 'Profile Picture';
  static const String selectImage = 'Select Image';
  static const String takePhoto = 'Take Photo';
  static const String chooseFromGallery = 'Choose from Gallery';

  // Guardian
  static const String guardianSetup = 'Guardian Setup';
  static const String addGuardian = 'Add Guardian';
  static const String guardianName = 'Guardian Name';
  static const String relation = 'Relation';

  // Profile
  static const String dateOfBirth = 'Date of Birth';
  static const String selectDateOfBirth = 'Select Date of Birth';

  // Validation messages
  static const String nameRequired = 'Name is required';
  static const String phoneRequired = 'Phone number is required';
  static const String phoneInvalid =
      'Please enter a valid 10-digit phone number';
  static const String mandalRequired = 'Mandal is required';
  static const String villageRequired = 'Village is required';
  static const String relationRequired = 'Relation is required';
  static const String dateOfBirthRequired = 'Date of Birth is required';
  static const String dateOfBirthInvalid =
      'Date of Birth cannot be in the future';
  static const String bloodDonorSelectDob =
      'Select your Date of Birth to check blood donor eligibility.';
  static const String bloodDonorAgeRestriction =
      'Blood donation registration is available for users aged 18 and above.';

  // Success messages
  static const String profileSaved = 'Profile saved successfully';
  static const String guardianSaved = 'Guardian added successfully';
  static const String guardianDeleted = 'Guardian removed successfully';
  static const String complaintSubmitted = 'Complaint submitted successfully';

  // Complaint screen
  static const String complaintTitle = 'Complaint Title';
  static const String complaintDescription = 'Complaint Description';
}
