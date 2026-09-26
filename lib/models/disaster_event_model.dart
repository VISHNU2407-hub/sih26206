import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/geo_match.dart';

/// SATS Disaster — a disaster event covering one or more affected villages.
///
/// Firestore collection: `disasters`
///
/// Lifecycle: monitoring → active → contained → closed
/// An authority creates the event (e.g. a cyclone warning); citizens in the
/// affected villages see it as their active disaster alert.
class DisasterEventModel {
  /// Firestore document ID. Empty until the model is loaded from Firestore
  /// or the document is created.
  final String id;

  /// Disaster type identifier. Values mirror [DisasterIncidentModel.type]:
  /// flood, cyclone, fire, earthquake, landslide, infrastructure_collapse,
  /// other. Kept as free strings so new types can be added without a
  /// migration, with display labels resolved via [typeLabel].
  final String type;

  /// low | medium | high | critical
  final String severity;

  /// monitoring | active | contained | closed
  final String status;

  final String title;
  final String summary;

  /// Actionable instructions shown to citizens (e.g. "Move to the nearest
  /// shelter before 6 PM. Carry drinking water and medicines.").
  final String instructions;

  /// Village names affected by this disaster (matched against the user's
  /// profile village for alert targeting).
  final List<String> affectedVillages;

  /// Mandal names affected. A village is considered affected if it is listed
  /// in [affectedVillages], or if its mandal is listed here.
  final List<String> affectedMandals;

  /// District names affected (widest scope, e.g. mandal-level alerts).
  final List<String> affectedDistricts;

  final bool evacuationRequired;

  /// User ID of the authority who created this event.
  final String createdBy;

  /// Display name of the creator (denormalized for the alert UI).
  final String createdByName;

  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// TRUE for seeded prototype records — the UI shows a "Demo Scenario"
  /// indicator so demo data is never mistaken for a live government warning.
  final bool isDemoData;

  const DisasterEventModel({
    this.id = '',
    this.isDemoData = false,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    this.summary = '',
    this.instructions = '',
    this.affectedVillages = const [],
    this.affectedMandals = const [],
    this.affectedDistricts = const [],
    this.evacuationRequired = false,
    required this.createdBy,
    this.createdByName = '',
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active' || status == 'monitoring';
  bool get isClosed => status == 'closed';

  bool get hasEnded => endedAt != null;

  /// True when the given geographic identity is inside the affected scope.
  /// Uses [GeoMatch.affectsStrict] for normalized, case-insensitive,
  /// whitespace-insensitive matching against the affected area lists.
  bool affects({
    required String? village,
    required String? mandal,
    required String? district,
  }) {
    return GeoMatch.affectsStrict(
      affectedVillages: affectedVillages,
      affectedMandals: affectedMandals,
      affectedDistricts: affectedDistricts,
      userVillage: village,
      userMandal: mandal,
      userDistrict: district,
    );
  }

  static DisasterEventModel? fromFirestore(Map<String, dynamic> data, String id) {
    try {
      DateTime? readDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return null;
      }

      List<String> readList(dynamic value) {
        if (value is List) return value.map((e) => e.toString()).toList();
        return const [];
      }

      return DisasterEventModel(
        id: id,
        isDemoData: data['isDemoData'] == true || data['demo'] == true,
        type: (data['type'] ?? 'other').toString(),
        severity: (data['severity'] ?? 'medium').toString(),
        status: (data['status'] ?? 'monitoring').toString(),
        title: (data['title'] ?? '').toString(),
        summary: (data['summary'] ?? '').toString(),
        instructions: (data['instructions'] ?? '').toString(),
        affectedVillages: readList(data['affectedVillages']),
        affectedMandals: readList(data['affectedMandals']),
        affectedDistricts: readList(data['affectedDistricts']),
        evacuationRequired: data['evacuationRequired'] == true,
        createdBy: (data['createdBy'] ?? '').toString(),
        createdByName: (data['createdByName'] ?? '').toString(),
        startedAt: readDate(data['startedAt']),
        endedAt: readDate(data['endedAt']),
        createdAt: readDate(data['createdAt']) ?? DateTime.now(),
        updatedAt: readDate(data['updatedAt']) ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'severity': severity,
      'status': status,
      'title': title,
      'summary': summary,
      'instructions': instructions,
      'affectedVillages': affectedVillages,
      'affectedMandals': affectedMandals,
      'affectedDistricts': affectedDistricts,
      'evacuationRequired': evacuationRequired,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'startedAt':
          startedAt == null ? null : Timestamp.fromDate(startedAt!),
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
      'isDemoData': isDemoData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update-only map (does not touch createdAt / createdBy).
  Map<String, dynamic> toFirestoreUpdate() {
    final map = toFirestore()
      ..remove('createdAt')
      ..remove('createdBy');
    return map;
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'flood':
        return 'Flood';
      case 'cyclone':
        return 'Cyclone';
      case 'fire':
        return 'Fire';
      case 'earthquake':
        return 'Earthquake';
      case 'landslide':
        return 'Landslide';
      case 'infrastructure_collapse':
        return 'Infrastructure Collapse';
      default:
        return 'Disaster';
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
      case 'monitoring':
        return 'Monitoring';
      case 'active':
        return 'Active';
      case 'contained':
        return 'Contained';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  DisasterEventModel copyWith({
    String? type,
    String? severity,
    String? status,
    String? title,
    String? summary,
    String? instructions,
    List<String>? affectedVillages,
    List<String>? affectedMandals,
    List<String>? affectedDistricts,
    bool? evacuationRequired,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return DisasterEventModel(
      id: id,
      isDemoData: isDemoData,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      instructions: instructions ?? this.instructions,
      affectedVillages: affectedVillages ?? this.affectedVillages,
      affectedMandals: affectedMandals ?? this.affectedMandals,
      affectedDistricts: affectedDistricts ?? this.affectedDistricts,
      evacuationRequired: evacuationRequired ?? this.evacuationRequired,
      createdBy: createdBy,
      createdByName: createdByName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'DisasterEventModel($type, $severity, $status, $title, '
      'villages: $affectedVillages)';
}
