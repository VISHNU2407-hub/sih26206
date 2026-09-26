import 'package:cloud_firestore/cloud_firestore.dart';

/// SATS Disaster — village-level preparedness record ("BEFORE DISASTER").
///
/// Firestore collection: `preparedness`
///
/// Document ID convention (`villageKey`): the village name lowercased and
/// with whitespace collapsed, e.g. `mukkamala`. Village names within the AP
/// dataset are unique per mandal and the seed data assumes unique names for
/// the demo mandal. Village keys keep citizen reads cacheable and stable.
class VillagePreparednessModel {
  final String district;
  final String mandal;
  final String village;

  /// low | moderate | high | severe — current multi-hazard risk level.
  final String riskLevel;

  /// e.g. ['cyclone', 'flood'] — hazards this village is exposed to.
  final List<String> hazards;

  /// Preparedness checklist: id → {label, done}.
  /// e.g. {'siren_test': {'label': 'Village siren tested', 'done': true}}
  final Map<String, Map<String, dynamic>> checklist;

  /// Count of vulnerable residents (elderly, disabled, infants, pregnant).
  final int vulnerableCount;

  /// Number of designated shelters serving this village.
  final int sheltersCount;

  /// Human-readable evacuation route descriptions.
  final List<String> evacuationRoutes;

  /// Emergency contacts: [{name, phone}] (village officer, 108, 100, ...).
  final List<Map<String, dynamic>> emergencyContacts;

  /// Demo-data marker. TRUE for seeded prototype records — the app can then
  /// label demo-prepared data honestly ("Demo data") instead of presenting
  /// it as live government data.
  final bool isDemoData;

  final DateTime updatedAt;

  const VillagePreparednessModel({
    required this.district,
    required this.mandal,
    required this.village,
    this.riskLevel = 'moderate',
    this.hazards = const [],
    this.checklist = const {},
    this.vulnerableCount = 0,
    this.sheltersCount = 0,
    this.evacuationRoutes = const [],
    this.emergencyContacts = const [],
    this.isDemoData = false,
    required this.updatedAt,
  });

  String get villageKey => keyFor(village);

  /// Canonical village document key: lowercase, whitespace collapsed.
  static String keyFor(String village) =>
      village.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Fraction (0.0–1.0) of checklist items marked done.
  double get checklistProgress {
    if (checklist.isEmpty) return 0;
    final done = checklist.values
        .where((item) => item['done'] == true)
        .length;
    return done / checklist.length;
  }

  bool get hasSevereRisk => riskLevel == 'high' || riskLevel == 'severe';

  static VillagePreparednessModel? fromFirestore(
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

      Map<String, Map<String, dynamic>> readChecklist(dynamic value) {
        if (value is! Map) return const {};
        return value.map(
          (k, v) => MapEntry(
            k.toString(),
            v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map),
          ),
        );
      }

      List<Map<String, dynamic>> readContactList(dynamic value) {
        if (value is! List) return const [];
        return value
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      return VillagePreparednessModel(
        district: (data['district'] ?? '').toString(),
        mandal: (data['mandal'] ?? '').toString(),
        village: (data['village'] ?? '').toString(),
        riskLevel: (data['riskLevel'] ?? 'moderate').toString(),
        hazards: readList(data['hazards']),
        checklist: readChecklist(data['checklist']),
        vulnerableCount: (data['vulnerableCount'] as num?)?.toInt() ?? 0,
        sheltersCount: (data['sheltersCount'] as num?)?.toInt() ?? 0,
        evacuationRoutes: readList(data['evacuationRoutes']),
        emergencyContacts: readContactList(data['emergencyContacts']),
        isDemoData: data['isDemoData'] == true,
        updatedAt: readDate(data['updatedAt']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'district': district,
      'mandal': mandal,
      'village': village,
      'riskLevel': riskLevel,
      'hazards': hazards,
      'checklist': checklist,
      'vulnerableCount': vulnerableCount,
      'sheltersCount': sheltersCount,
      'evacuationRoutes': evacuationRoutes,
      'emergencyContacts': emergencyContacts,
      'isDemoData': isDemoData,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String riskLabel(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return 'Low';
      case 'moderate':
        return 'Moderate';
      case 'high':
        return 'High';
      case 'severe':
        return 'Severe';
      default:
        return riskLevel;
    }
  }

  VillagePreparednessModel copyWith({
    String? riskLevel,
    List<String>? hazards,
    Map<String, Map<String, dynamic>>? checklist,
    int? vulnerableCount,
    int? sheltersCount,
    List<String>? evacuationRoutes,
    List<Map<String, dynamic>>? emergencyContacts,
    bool? isDemoData,
  }) {
    return VillagePreparednessModel(
      district: district,
      mandal: mandal,
      village: village,
      riskLevel: riskLevel ?? this.riskLevel,
      hazards: hazards ?? this.hazards,
      checklist: checklist ?? this.checklist,
      vulnerableCount: vulnerableCount ?? this.vulnerableCount,
      sheltersCount: sheltersCount ?? this.sheltersCount,
      evacuationRoutes: evacuationRoutes ?? this.evacuationRoutes,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isDemoData: isDemoData ?? this.isDemoData,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'VillagePreparednessModel($village, risk: $riskLevel, '
      'checklist: ${checklistProgress.toStringAsFixed(2)})';
}
