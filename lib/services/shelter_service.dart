import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shelter_model.dart';
import '../utils/geo_match.dart';

/// SATS Disaster — authority shelter management.
///
/// Thin Firestore access over `shelters` for the command dashboard:
/// reads via realtime streams and updates restricted to the shelter
/// management fields (Firestore rules also enforce authority-only writes
/// on exactly these fields).
class ShelterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _shelters =>
      _firestore.collection('shelters');

  /// All shelters (dashboard shelter management list).
  Stream<List<ShelterModel>> getAllSheltersStream() {
    return _shelters.snapshots().map(_mapDocs);
  }

  /// Shelters for one village.
  Stream<List<ShelterModel>> getSheltersForVillageStream(String village) {
    return _shelters
        .where('village', isEqualTo: GeoMatch.normalize(village))
        .snapshots()
        .map(_mapDocs);
  }

  /// Shelters for one mandal.
  Stream<List<ShelterModel>> getSheltersForMandalStream(String mandal) {
    return _shelters
        .where('mandal', isEqualTo: GeoMatch.normalize(mandal))
        .snapshots()
        .map(_mapDocs);
  }

  /// Validation result for a capacity/occupancy edit.
  /// [ShelterModel.availableSpace] already clamps display values; this
  /// prevents writing inconsistent data in the first place.
  static String? validateCapacity({
    required int? capacity,
    required int? occupancy,
  }) {
    if (capacity == null || capacity < 0) {
      return 'Capacity must be 0 or more';
    }
    if (occupancy == null || occupancy < 0) {
      return 'Occupancy must be 0 or more';
    }
    if (occupancy > capacity) {
      return 'Occupancy cannot exceed capacity';
    }
    return null;
  }

  /// Validation for the optional shelter location block.
  ///
  /// [latitude]/[longitude] must either both be null or both be valid
  /// numbers in range. Returns a human-readable message or null when OK.
  static String? validateLocation({
    String? locationText,
    double? latitude,
    double? longitude,
  }) {
    if (locationText != null && locationText.trim().isEmpty) {
      return 'Location cannot be blank';
    }
    final hasLat = latitude != null;
    final hasLng = longitude != null;
    if (hasLat != hasLng) {
      return 'Both latitude and longitude are needed for coordinates';
    }
    if (latitude != null &&
        (latitude < -90 || latitude > 90)) {
      return 'Latitude must be between -90 and 90';
    }
    if (longitude != null &&
        (longitude < -180 || longitude > 180)) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  /// Creates a new shelter document. The authority's geographic scope
  /// (village/mandal/district) is enforced by the caller before reaching
  /// this method. Firestore rules require `isAuthority()` for create.
  Future<String> createShelter({
    required String name,
    required String village,
    required String mandal,
    required String district,
    required int capacity,
    int occupancy = 0,
    String status = 'active',
    String? locationText,
    double? latitude,
    double? longitude,
    List<String> amenities = const [],
    List<String> supplies = const [],
    String contactPhone = '',
  }) async {
    final error = validateCapacity(
      capacity: capacity,
      occupancy: occupancy,
    );
    if (error != null) {
      throw ArgumentError(error);
    }

    final locationError = validateLocation(
      locationText: locationText,
      latitude: latitude,
      longitude: longitude,
    );
    if (locationError != null) {
      throw ArgumentError(locationError);
    }

    final now = FieldValue.serverTimestamp();
    final doc = await _shelters.add({
      'name': name,
      'village': GeoMatch.normalize(village),
      'mandal': GeoMatch.normalize(mandal),
      'district': GeoMatch.normalize(district),
      'locationText': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'occupancy': occupancy,
      'status': status,
      'amenities': amenities,
      'supplies': supplies,
      'contactPhone': contactPhone,
      'updatedBy': 'authority',
      'isDemoData': false,
      'createdAt': now,
      'updatedAt': now,
    });
    return doc.id;
  }

  /// Applies an authority shelter update. Only management fields are sent,
  /// matching the Firestore rule's allowed key set.
  Future<void> updateShelterManagement({
    required String shelterId,
    required ShelterModel current,
    required int capacity,
    required int occupancy,
    required String status,
    List<String>? amenities,
    List<String>? supplies,
    String? contactPhone,
  }) async {
    final error = validateCapacity(
      capacity: capacity,
      occupancy: occupancy,
    );
    if (error != null) {
      throw ArgumentError(error);
    }

    await _shelters.doc(shelterId).update({
      'capacity': capacity,
      'occupancy': occupancy,
      'status': status,
      if (amenities != null) 'amenities': amenities,
      if (supplies != null) 'supplies': supplies,
      if (contactPhone != null) 'contactPhone': contactPhone,
      'updatedBy': 'authority',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Full-field authority edit: updates every editable shelter attribute on
  /// the existing document — the document ID, createdAt and reporter-style
  /// audit fields are preserved automatically because they are never sent.
  ///
  /// Geography (village/mandal/district) is editable here; strict GeoMatch
  /// visibility continues to decide which citizens see the shelter. All
  /// values pass through the same validation rules as creation.
  Future<void> updateShelter({
    required String shelterId,
    required String name,
    required String village,
    required String mandal,
    required String district,
    required int capacity,
    required int occupancy,
    required String status,
    String? locationText,
    double? latitude,
    double? longitude,
    List<String> amenities = const [],
    List<String> supplies = const [],
    String contactPhone = '',
  }) async {
    final error = validateShelterUpdate(
      name: name,
      village: village,
      mandal: mandal,
      capacity: capacity,
      occupancy: occupancy,
      locationText: locationText,
      latitude: latitude,
      longitude: longitude,
    );
    if (error != null) {
      throw ArgumentError(error);
    }

    await _shelters.doc(shelterId).update({
      'name': name,
      'village': GeoMatch.normalize(village),
      'mandal': GeoMatch.normalize(mandal),
      'district': GeoMatch.normalize(district),
      'locationText': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'occupancy': occupancy,
      'status': status,
      'amenities': amenities,
      'supplies': supplies,
      'contactPhone': contactPhone,
      'updatedBy': 'authority',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes exactly one shelter document. Never touches other collections
  /// or documents. Firestore rules enforce authority-only deletion.
  Future<void> deleteShelter(String shelterId) async {
    await _shelters.doc(shelterId).delete();
  }

  /// Validation shared by the full-form edit path (and usable for creation).
  /// Same rules as creation: identity fields required, capacity sane,
  /// coordinates a valid in-range pair, location text not blank when given.
  static String? validateShelterUpdate({
    required String name,
    required String village,
    required String mandal,
    required int? capacity,
    required int? occupancy,
    String? locationText,
    double? latitude,
    double? longitude,
  }) {
    if (name.trim().isEmpty) {
      return 'Shelter name is required';
    }
    if (village.trim().isEmpty) {
      return 'Village is required';
    }
    if (mandal.trim().isEmpty) {
      return 'Mandal is required';
    }
    final capError = validateCapacity(
      capacity: capacity,
      occupancy: occupancy,
    );
    if (capError != null) {
      return capError;
    }
    return validateLocation(
      locationText: locationText,
      latitude: latitude,
      longitude: longitude,
    );
  }

  List<ShelterModel> _mapDocs(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => ShelterModel.fromFirestore(doc.data(), doc.id))
        .whereType<ShelterModel>()
        .toList();
  }
}
