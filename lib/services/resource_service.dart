import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/resource_model.dart';

/// SATS Disaster — Phase 5: Firestore access for relief resources.
class ResourceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _resources =>
      _firestore.collection('resources');

  /// Creates a resource requirement. Caller must be an authority (rules).
  /// Deterministic document ID (village + resourceType) keeps records unique
  /// per village/item and makes re-seeding idempotent.
  Future<String> createResource(ResourceModel resource) async {
    final docId = _docIdFor(resource);
    await _resources.doc(docId).set(resource.toFirestore(), SetOptions(merge: true));
    return docId;
  }

  /// Updates quantities/status/notes. Authority-only (rules).
  Future<void> updateResource(String resourceId, ResourceModel resource) async {
    await _resources.doc(resourceId).update(resource.toFirestoreUpdate());
  }

  /// Streams every resource record, realtime (authority overview).
  Stream<List<ResourceModel>> getResourcesStream() {
    return _resources.orderBy('createdAt', descending: true).snapshots().map(
      _mapDocs,
    );
  }

  /// Streams resources linked to one disaster event.
  Stream<List<ResourceModel>> getResourcesForDisasterStream(
    String disasterId,
  ) {
    return _resources
        .where('disasterId', isEqualTo: disasterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams resources for a village (citizen relief view).
  Stream<List<ResourceModel>> getResourcesForVillageStream(String village) {
    return _resources
        .where('village', isEqualTo: village)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams resources for a mandal (village authority scope).
  Stream<List<ResourceModel>> getResourcesForMandalStream(String mandal) {
    return _resources
        .where('mandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Streams resources for a district (district authority scope).
  Stream<List<ResourceModel>> getResourcesForDistrictStream(String district) {
    return _resources
        .where('district', isEqualTo: district)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  List<ResourceModel> _mapDocs(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) =>
            ResourceModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .whereType<ResourceModel>()
        .toList();
  }

  /// Deterministic document ID from village + resource type so the same
  /// (village, item) pair never duplicates — re-adding updates in place.
  static String _docIdFor(ResourceModel resource) {
    String key(String s) => s.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          '_',
        );
    return 'res_${key(resource.village)}_${key(resource.resourceType)}';
  }

  /// List ordering: shortages first (largest shortfall), then exhausted,
  /// then the rest. Pure and unit-testable.
  static List<ResourceModel> sortForAuthorityList(List<ResourceModel> items) {
    int rank(ResourceModel r) {
      if (r.shortfall > 0 && !r.isExhausted) return 0;
      if (r.isExhausted) return 1;
      return 2;
    }

    final sorted = [...items]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        // Within shortages: bigger shortfall first.
        final byShortfall = b.shortfall.compareTo(a.shortfall);
        if (byShortfall != 0) return byShortfall;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
  }
}
