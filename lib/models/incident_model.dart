import 'package:cloud_firestore/cloud_firestore.dart';

/// SATS Disaster — a citizen-reported disaster incident.
///
/// Firestore collection: `incidents`
///
/// This is the disaster-domain successor of the civic `complaints`
/// architecture (which remains untouched for now). Incidents carry disaster
/// context: type/severity, GPS, affected people, rescue/medical/resource
/// requirements, and an authority triage workflow.
class DisasterIncidentModel {
  /// Firestore document ID. Empty until loaded from Firestore.
  final String id;

  /// flood | cyclone | fire | earthquake | landslide |
  /// infrastructure_collapse | person_trapped | medical | other
  final String incidentType;

  /// low | medium | high | critical
  final String severity;

  final String description;

  /// GPS coordinates of the incident (optional — may be unavailable
  /// without a fix).
  final double? latitude;
  final double? longitude;

  final String district;
  final String mandal;
  final String village;

  /// Links the incident to a disaster event (`disasters/{id}`), if reported
  /// during an active event.
  final String? disasterId;

  /// User ID of the reporter.
  final String reportedBy;

  /// Display name of the reporter (denormalized for the dashboard).
  final String reportedByName;

  /// Approximate number of people affected.
  final int affectedPeople;

  final bool rescueRequired;

  /// Number of people requiring rescue (used for prioritization when
  /// [rescueRequired] is true).
  final int rescuePeopleCount;

  final bool medicalRequired;

  /// e.g. ['boats', 'food', 'medical_team', 'tarpaulins', 'drinking_water']
  final List<String> resourcesRequired;

  /// Cloudinary URLs of damage/scene photos.
  final List<String> media;

  /// reported | verified | triaged | dispatched | resolved | rejected
  final String status;

  /// User ID of the rescue team / authority assigned to this incident.
  final String? assignedTo;

  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// TRUE for seeded prototype records ("Demo data" indicator in the UI).
  final bool isDemoData;

  const DisasterIncidentModel({
    this.id = '',
    this.isDemoData = false,
    required this.incidentType,
    required this.severity,
    required this.description,
    this.latitude,
    this.longitude,
    required this.district,
    required this.mandal,
    required this.village,
    this.disasterId,
    required this.reportedBy,
    this.reportedByName = '',
    this.affectedPeople = 0,
    this.rescueRequired = false,
    this.rescuePeopleCount = 0,
    this.medicalRequired = false,
    this.resourcesRequired = const [],
    this.media = const [],
    this.status = 'reported',
    this.assignedTo,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get isResolved => status == 'resolved' || status == 'rejected';
  bool get needsResponse => !isResolved;

  /// Google Maps link for the incident location (matches the app-wide
  /// convention of links instead of an embedded map).
  String? get locationLink => hasLocation
      ? 'https://maps.google.com/?q=$latitude,$longitude'
      : null;

  static DisasterIncidentModel? fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    try {
      DateTime readDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return DateTime.now();
      }

      List<String> readList(dynamic value) {
        if (value is List) return value.map((e) => e.toString()).toList();
        return const [];
      }

      return DisasterIncidentModel(
        id: id,
        isDemoData: data['isDemoData'] == true || data['demo'] == true,
        incidentType: (data['incidentType'] ?? 'other').toString(),
        severity: (data['severity'] ?? 'medium').toString(),
        description: (data['description'] ?? '').toString(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        district: (data['district'] ?? '').toString(),
        mandal: (data['mandal'] ?? '').toString(),
        village: (data['village'] ?? '').toString(),
        disasterId: data['disasterId']?.toString(),
        reportedBy: (data['reportedBy'] ?? '').toString(),
        reportedByName: (data['reportedByName'] ?? '').toString(),
        affectedPeople: (data['affectedPeople'] as num?)?.toInt() ?? 0,
        rescueRequired: data['rescueRequired'] == true,
        rescuePeopleCount:
            (data['rescuePeopleCount'] as num?)?.toInt() ?? 0,
        medicalRequired: data['medicalRequired'] == true,
        resourcesRequired: readList(data['resourcesRequired']),
        media: readList(data['media']),
        status: (data['status'] ?? 'reported').toString(),
        assignedTo: data['assignedTo']?.toString(),
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
      'incidentType': incidentType,
      'severity': severity,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'district': district,
      'mandal': mandal,
      'village': village,
      'disasterId': disasterId,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'affectedPeople': affectedPeople,
      'rescueRequired': rescueRequired,
      'rescuePeopleCount': rescuePeopleCount,
      'medicalRequired': medicalRequired,
      'resourcesRequired': resourcesRequired,
      'media': media,
      'status': status,
      'assignedTo': assignedTo,
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

  // ── Vocabulary shared with the dashboard / report form ──

  static const String typeFlood = 'flood';
  static const String typeCyclone = 'cyclone';
  static const String typeFire = 'fire';
  static const String typeEarthquake = 'earthquake';
  static const String typeLandslide = 'landslide';
  static const String typeInfrastructure = 'infrastructure_collapse';
  static const String typePersonTrapped = 'person_trapped';
  static const String typeMedical = 'medical';
  static const String typeMissingPerson = 'missing_person';
  static const String typeOther = 'other';

  static const List<String> incidentTypes = [
    typeFlood,
    typeCyclone,
    typeFire,
    typeEarthquake,
    typeLandslide,
    typeInfrastructure,
    typePersonTrapped,
    typeMedical,
    typeMissingPerson,
    typeOther,
  ];

  static const List<String> severities = ['low', 'medium', 'high', 'critical'];

  static const List<String> commonResources = [
    'boats',
    'food',
    'drinking_water',
    'medical_team',
    'tarpaulins',
    'rescue_team',
    'generator',
    'transport',
  ];

  /// Human-readable label for a resource key (falls back to the raw value).
  static String resourceLabel(String resource) {
    switch (resource) {
      case 'boats':
        return 'Boats';
      case 'food':
        return 'Food';
      case 'drinking_water':
        return 'Drinking Water';
      case 'medical_team':
        return 'Medical Team';
      case 'tarpaulins':
        return 'Tarpaulins';
      case 'rescue_team':
        return 'Rescue Team';
      case 'generator':
        return 'Generator';
      case 'transport':
        return 'Transport';
      default:
        return resource
            .replaceAll('_', ' ')
            .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());
    }
  }

  static String typeLabel(String type) {
    switch (type) {
      case typeFlood:
        return 'Flood';
      case typeCyclone:
        return 'Cyclone';
      case typeFire:
        return 'Fire';
      case typeEarthquake:
        return 'Earthquake';
      case typeLandslide:
        return 'Landslide';
      case typeInfrastructure:
        return 'Infrastructure Collapse';
      case typePersonTrapped:
        return 'Person Trapped';
      case typeMedical:
        return 'Medical Emergency';
      case typeMissingPerson:
        return 'Missing Person';
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
      case 'triaged':
        return 'Triaged';
      case 'dispatched':
        return 'Dispatched';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Invalid';
      default:
        return status;
    }
  }

  /// Canonical triage progression shown to authorities.
  /// The stored values are exactly the model's supported statuses — no
  /// invented states. Rejection is offered separately as "Mark Invalid".
  static const List<String> triageFlow = [
    'reported',
    'verified',
    'triaged',
    'dispatched',
    'resolved',
  ];

  /// The single next forward triage status, or null when the incident is at
  /// the end of the flow (resolved / rejected). Drives the dashboard's
  /// primary action button so authorities cannot invent a status.
  static String? nextTriageStatus(String status) {
    final index = triageFlow.indexOf(status);
    if (index < 0 || index >= triageFlow.length - 1) return null;
    return triageFlow[index + 1];
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

  DisasterIncidentModel copyWith({
    String? incidentType,
    String? severity,
    String? description,
    double? latitude,
    double? longitude,
    String? disasterId,
    int? affectedPeople,
    bool? rescueRequired,
    int? rescuePeopleCount,
    bool? medicalRequired,
    List<String>? resourcesRequired,
    List<String>? media,
    String? status,
    String? assignedTo,
    String? updatedBy,
  }) {
    return DisasterIncidentModel(
      id: id,
      isDemoData: isDemoData,
      incidentType: incidentType ?? this.incidentType,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      district: district,
      mandal: mandal,
      village: village,
      disasterId: disasterId ?? this.disasterId,
      reportedBy: reportedBy,
      reportedByName: reportedByName,
      affectedPeople: affectedPeople ?? this.affectedPeople,
      rescueRequired: rescueRequired ?? this.rescueRequired,
      rescuePeopleCount: rescuePeopleCount ?? this.rescuePeopleCount,
      medicalRequired: medicalRequired ?? this.medicalRequired,
      resourcesRequired: resourcesRequired ?? this.resourcesRequired,
      media: media ?? this.media,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'DisasterIncidentModel($incidentType, $severity, $village, $status)';
}
