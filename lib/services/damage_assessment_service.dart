import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/damage_assessment_model.dart';

/// SATS Disaster — Phase 5: Firestore access for damage assessments.
class DamageAssessmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _assessments =>
      _firestore.collection('damage_assessments');

  /// Creates a damage assessment. Caller must be an authority (rules).
  Future<String> createAssessment(DamageAssessmentModel assessment) async {
    final doc = await _assessments.add(assessment.toFirestore());
    return doc.id;
  }

  /// Updates an existing assessment (status transitions, edits). Authority-only (rules).
  Future<void> updateAssessment(
    String assessmentId,
    DamageAssessmentModel assessment,
  ) async {
    await _assessments.doc(assessmentId).update(assessment.toFirestoreUpdate());
  }

  /// Streams every damage assessment, unresolved first (severity, then
  /// newest). Realtime.
  Stream<List<DamageAssessmentModel>> getAssessmentsStream() {
    return _assessments.orderBy('createdAt', descending: true).snapshots().map(
      _mapDocs,
    );
  }

  /// Streams assessments linked to one disaster event.
  Stream<List<DamageAssessmentModel>> getAssessmentsForDisasterStream(
    String disasterId,
  ) {
    return _assessments
        .where('disasterId', isEqualTo: disasterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams assessments for a village.
  Stream<List<DamageAssessmentModel>> getAssessmentsForVillageStream(
    String village,
  ) {
    return _assessments
        .where('village', isEqualTo: village)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams assessments for a mandal (village authority scope).
  Stream<List<DamageAssessmentModel>> getAssessmentsForMandalStream(
    String mandal,
  ) {
    return _assessments
        .where('mandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams assessments for a district (district authority scope).
  Stream<List<DamageAssessmentModel>> getAssessmentsForDistrictStream(
    String district,
  ) {
    return _assessments
        .where('district', isEqualTo: district)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  List<DamageAssessmentModel> _mapDocs(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => DamageAssessmentModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .whereType<DamageAssessmentModel>()
        .toList();
  }

  /// List ordering: unresolved damage first, within that severity (critical
  /// on top), then newest. Pure and unit-testable.
  static List<DamageAssessmentModel> sortForAuthorityList(
    List<DamageAssessmentModel> assessments,
  ) {
    final sorted = [...assessments]..sort((a, b) {
        final byOpen =
            (a.isResolved ? 1 : 0).compareTo(b.isResolved ? 1 : 0);
        if (byOpen != 0) return byOpen;
        final bySeverity = DamageAssessmentModel.severityRank(a.severity)
            .compareTo(DamageAssessmentModel.severityRank(b.severity));
        if (bySeverity != 0) return bySeverity;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
  }
}
