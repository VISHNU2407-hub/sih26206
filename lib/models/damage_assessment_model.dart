import 'package:cloud_firestore/cloud_firestore.dart';

/// SATS Disaster — Phase 5: a post-disaster damage assessment record.
///
/// Firestore collection: `damage_assessments`
///
/// Created by authorities while surveying an affected area after a disaster
/// event. The status is the recorded ADMINISTRATIVE state of the assessment
/// (reported → verified → assessed → recovered); it never claims that
/// physical recovery has happened — only that the authority recorded it.
class DamageAssessmentModel {
  /// Firestore document ID. Empty until loaded from Firestore.
  final String id;

  /// Linked disaster event (`disasters/{id}`), if assessed during one.
  final String? disasterId;

  /// User ID of the authority who recorded this assessment.
  final String reportedBy;

  /// Display name of the recorder (denormalized for the list UI).
  final String reportedByName;

  final String district;
  final String mandal;
  final String village;

  final double? latitude;
  final double? longitude;

  /// house | road | bridge | electricity | water | communication |
  /// public_building | agriculture | other — see [damageTypes].
  final String damageType;

  /// low | medium | high | critical (shared severity vocabulary).
  final String severity;

  final String description;

  /// Approximate number of people affected by this damage.
  final int estimatedAffectedPeople;

  /// Optional Cloudinary URL of a damage photo.
  final String? photoUrl;

  /// reported | verified | assessed | recovered
  final String status;

  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// TRUE for seeded prototype records ("Demo data" indicator in the UI).
  final bool isDemoData;

  const DamageAssessmentModel({
    this.id = '',
    this.isDemoData = false,
    this.disasterId,
    required this.reportedBy,
    this.reportedByName = '',
    required this.district,
    required this.mandal,
    required this.village,
    this.latitude,
    this.longitude,
    required this.damageType,
    required this.severity,
    this.description = '',
    this.estimatedAffectedPeople = 0,
    this.photoUrl,
    this.status = 'reported',
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get isResolved => status == 'recovered';

  /// Google Maps link for the assessment location (app-wide convention).
  String? get locationLink => hasLocation
      ? 'https://maps.google.com/?q=$latitude,$longitude'
      : null;

  static DamageAssessmentModel? fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    try {
      DateTime readDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return DateTime.now();
      }

      return DamageAssessmentModel(
        id: id,
        isDemoData: data['isDemoData'] == true || data['demo'] == true,
        disasterId: data['disasterId']?.toString(),
        reportedBy: (data['reportedBy'] ?? '').toString(),
        reportedByName: (data['reportedByName'] ?? '').toString(),
        district: (data['district'] ?? '').toString(),
        mandal: (data['mandal'] ?? '').toString(),
        village: (data['village'] ?? '').toString(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        damageType: (data['damageType'] ?? 'other').toString(),
        severity: (data['severity'] ?? 'medium').toString(),
        description: (data['description'] ?? '').toString(),
        estimatedAffectedPeople: data['estimatedAffectedPeople'] is num
            ? (data['estimatedAffectedPeople'] as num).toInt()
            : 0,
        photoUrl: data['photoUrl']?.toString(),
        status: (data['status'] ?? 'reported').toString(),
        updatedBy: data['updatedBy']?.toString(),
        createdAt: readDate(data['createdAt']),
        updatedAt: readDate(data['updatedAt']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'disasterId': disasterId,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'district': district,
      'mandal': mandal,
      'village': village,
      'latitude': latitude,
      'longitude': longitude,
      'damageType': damageType,
      'severity': severity,
      'description': description,
      'estimatedAffectedPeople': estimatedAffectedPeople,
      'photoUrl': photoUrl,
      'status': status,
      'isDemoData': isDemoData,
      'updatedBy': updatedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update-only map (does not touch createdAt / reportedBy).
  Map<String, dynamic> toFirestoreUpdate() {
    final map = toFirestore()
      ..remove('createdAt')
      ..remove('reportedBy');
    return map;
  }

  // ── Vocabulary ──

  static const String typeHouse = 'house';
  static const String typeRoad = 'road';
  static const String typeBridge = 'bridge';
  static const String typeElectricity = 'electricity';
  static const String typeWater = 'water';
  static const String typeCommunication = 'communication';
  static const String typePublicBuilding = 'public_building';
  static const String typeAgriculture = 'agriculture';
  static const String typeOther = 'other';

  static const List<String> damageTypes = [
    typeHouse,
    typeRoad,
    typeBridge,
    typeElectricity,
    typeWater,
    typeCommunication,
    typePublicBuilding,
    typeAgriculture,
    typeOther,
  ];

  static const List<String> severities = ['low', 'medium', 'high', 'critical'];

  /// Canonical administrative progression.
  static const List<String> statusFlow = [
    'reported',
    'verified',
    'assessed',
    'recovered',
  ];

  /// The single next forward status, or null at the end of the flow.
  /// Drives the detail screen's primary action so authorities cannot
  /// invent a status.
  static String? nextStatus(String status) {
    final index = statusFlow.indexOf(status);
    if (index < 0 || index >= statusFlow.length - 1) return null;
    return statusFlow[index + 1];
  }

  static String typeLabel(String type) {
    switch (type) {
      case typeHouse:
        return 'House Damage';
      case typeRoad:
        return 'Road Damage';
      case typeBridge:
        return 'Bridge Damage';
      case typeElectricity:
        return 'Electricity';
      case typeWater:
        return 'Water Supply';
      case typeCommunication:
        return 'Communication';
      case typePublicBuilding:
        return 'Public Building';
      case typeAgriculture:
        return 'Agriculture';
      default:
        return 'Other';
    }
  }

  static String severityLabel(String severity) {
    switch (severity) {
      case 'low':
        return 'LOW';
      case 'medium':
        return 'MEDIUM';
      case 'high':
        return 'HIGH';
      case 'critical':
        return 'CRITICAL';
      default:
        return severity.toUpperCase();
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'reported':
        return 'Reported';
      case 'verified':
        return 'Verified';
      case 'assessed':
        return 'Assessed';
      case 'recovered':
        return 'Recovered';
      default:
        return status;
    }
  }

  /// Severity rank for sorting (critical first). Unknown = lowest priority.
  static int severityRank(String severity) {
    switch (severity) {
      case 'critical':
        return 0;
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }

  DamageAssessmentModel copyWith({
    String? damageType,
    String? severity,
    String? description,
    int? estimatedAffectedPeople,
    String? photoUrl,
    String? status,
    double? latitude,
    double? longitude,
    String? updatedBy,
  }) {
    return DamageAssessmentModel(
      id: id,
      isDemoData: isDemoData,
      disasterId: disasterId,
      reportedBy: reportedBy,
      reportedByName: reportedByName,
      district: district,
      mandal: mandal,
      village: village,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      damageType: damageType ?? this.damageType,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      estimatedAffectedPeople:
          estimatedAffectedPeople ?? this.estimatedAffectedPeople,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'DamageAssessmentModel($damageType, $severity, $village, $status)';
}
