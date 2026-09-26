import 'package:cloud_firestore/cloud_firestore.dart';

class MissingPersonAlertModel {
  final String id;
  final String createdBy;
  final String createdByName;
  final String userVillage;
  final String userMandal;
  final String userDistrict;
  final String photoUrl;
  final String fullName;
  final int age;
  final String gender;
  final String lastSeenLocation;
  final DateTime missingDateTime;
  final String clothesDescription;
  final String additionalNotes;
  final String guardianContactNumber;
  final String whatsappNumber;
  final String status;
  final DateTime createdAt;
  final DateTime? foundAt;

  /// Phase 5: optional link to a disaster event (`disasters/{id}`) when the
  /// person went missing during an active disaster. Empty/null for ordinary
  /// (non-disaster) alerts — fully backward compatible.
  final String? disasterId;

  const MissingPersonAlertModel({
    required this.id,
    required this.createdBy,
    required this.createdByName,
    required this.userVillage,
    required this.userMandal,
    this.userDistrict = '',
    required this.photoUrl,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.lastSeenLocation,
    required this.missingDateTime,
    required this.clothesDescription,
    required this.additionalNotes,
    required this.guardianContactNumber,
    required this.whatsappNumber,
    required this.status,
    required this.createdAt,
    this.foundAt,
    this.disasterId,
  });

  bool get isFoundSafe => status == 'found_safe';

  static MissingPersonAlertModel? fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    try {
      return MissingPersonAlertModel(
        id: id,
        createdBy: data['createdBy']?.toString() ?? '',
        createdByName: data['createdByName']?.toString() ?? '',
        userVillage: data['userVillage']?.toString() ?? '',
        userMandal: data['userMandal']?.toString() ?? '',
        userDistrict: data['userDistrict']?.toString() ?? '',
        photoUrl: data['photoUrl']?.toString() ?? '',
        fullName: data['fullName']?.toString() ?? '',
        age: (data['age'] as num?)?.toInt() ?? 0,
        gender: data['gender']?.toString() ?? '',
        lastSeenLocation: data['lastSeenLocation']?.toString() ?? '',
        missingDateTime: _readDate(data['missingDateTime']),
        clothesDescription: data['clothesDescription']?.toString() ?? '',
        additionalNotes: data['additionalNotes']?.toString() ?? '',
        guardianContactNumber:
            data['guardianContactNumber']?.toString() ?? '',
        whatsappNumber: data['whatsappNumber']?.toString() ?? '',
        status: data['status']?.toString() ?? 'active',
        createdAt: _readDate(data['createdAt']),
        foundAt: _readNullableDate(data['foundAt']),
        disasterId: data['disasterId']?.toString(),
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdBy': createdBy,
      'createdByName': createdByName,
      'userVillage': userVillage,
      'userMandal': userMandal,
      'userDistrict': userDistrict,
      'photoUrl': photoUrl,
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'lastSeenLocation': lastSeenLocation,
      'missingDateTime': Timestamp.fromDate(missingDateTime),
      'clothesDescription': clothesDescription,
      'additionalNotes': additionalNotes,
      'guardianContactNumber': guardianContactNumber,
      'whatsappNumber': whatsappNumber,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'foundAt': foundAt == null ? null : Timestamp.fromDate(foundAt!),
      'disasterId': disasterId,
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value == null) return null;
    return _readDate(value);
  }
}
