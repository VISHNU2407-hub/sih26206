import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore field names for the legacy geographic mapping on `users` docs.
///
/// LEGACY COMPATIBILITY — DO NOT RENAME:
/// Existing documents (and several notification fan-out queries) store the
/// MANDAL name in the field `village` and the VILLAGE name in the field
/// `street`. [UserModel] keeps Dart-side names correct and centralizes the
/// mapping here so new code never hand-writes these field names.
abstract class UserFieldKeys {
  static const String village = 'street'; // stores the village name
  static const String mandal = 'village'; // stores the mandal name
  static const String district = 'district';
  static const String role = 'role';
  static const String phoneNormalized = 'phoneNormalized';
  static const String fcmToken = 'fcmToken';
}

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String state;
  final String district;
  final String mandal;
  final String village;
  final String photoUrl;
  // Legacy stored age (kept for backwards compatibility with existing
  // records). For new profiles age is derived dynamically from [dateOfBirth].
  final String age;
  final DateTime? dateOfBirth;
  final String bloodGroup;
  final String role;
  final bool isBloodDonor;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  // ── SATS Disaster extensions ──
  /// Email from the auth provider (Google sign-in). Denormalized for seed
  /// provisioning lookups.
  final String email;

  /// Number of people in the user's household (disaster impact estimation).
  final int householdSize;

  /// FCM registration token for push notifications (Phase 4 wires the
  /// messaging client; the field exists from Phase 1 so rules and the
  /// token-write path are stable).
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.state = '',
    this.district = '',
    required this.mandal,
    required this.village,
    required this.photoUrl,
    required this.age,
    this.dateOfBirth,
    required this.bloodGroup,
    required this.role,
    this.isBloodDonor = false,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.email = '',
    this.householdSize = 0,
    this.fcmToken,
  });

  // Create from Firestore document
  // Maps old field names (village/street) to new terminology (mandal/village)
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      state: data['state'] ?? '',
      district: data['district'] ?? '',
      mandal: data['village'] ?? '', // Maps Firestore 'village' to 'mandal'
      village: data['street'] ?? '', // Maps Firestore 'street' to 'village'
      photoUrl: data['photoUrl'] ?? '',
      age: data['age'] ?? '',
      dateOfBirth: data['dateOfBirth'] is Timestamp
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      bloodGroup: data['bloodGroup'] ?? '',
      role: data[UserFieldKeys.role] ?? 'citizen',
      isBloodDonor: data['isBloodDonor'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      email: data['email'] ?? '',
      householdSize: (data['householdSize'] as num?)?.toInt() ?? 0,
      fcmToken: data[UserFieldKeys.fcmToken]?.toString(),
    );
  }

  // Convert to Firestore document
  // Maps new terminology (mandal/village) to old field names (village/street)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'district': district,
      'village': mandal, // Maps 'mandal' to Firestore 'village'
      'street': village, // Maps 'village' to Firestore 'street'
      'photoUrl': photoUrl,
      // Do not persist a manually entered age for new profiles; the current
      // age is calculated dynamically from dateOfBirth. Legacy age values are
      // kept so existing records are not broken.
      if (age.isNotEmpty) 'age': age,
      if (dateOfBirth != null)
        'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
      'bloodGroup': bloodGroup,
      UserFieldKeys.role: role,
      'isBloodDonor': isBloodDonor,
      'createdAt': Timestamp.fromDate(createdAt),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'state': state,
      if (email.isNotEmpty) 'email': email,
      'householdSize': householdSize,
      if (fcmToken != null) UserFieldKeys.fcmToken: fcmToken,
    };
  }

  // Create copy with updated fields
  UserModel copyWith({
    String? name,
    String? phone,
    String? state,
    String? district,
    String? mandal,
    String? village,
    String? photoUrl,
    String? age,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? role,
    bool? isBloodDonor,
    double? latitude,
    double? longitude,
    String? email,
    int? householdSize,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      state: state ?? this.state,
      district: district ?? this.district,
      mandal: mandal ?? this.mandal,
      village: village ?? this.village,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      role: role ?? this.role,
      isBloodDonor: isBloodDonor ?? this.isBloodDonor,
      createdAt: createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      email: email ?? this.email,
      householdSize: householdSize ?? this.householdSize,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, phone: $phone, state: $state, district: $district, mandal: $mandal, village: $village, photoUrl: $photoUrl, age: $age, bloodGroup: $bloodGroup, role: $role, isBloodDonor: $isBloodDonor, createdAt: $createdAt)';
  }
}
