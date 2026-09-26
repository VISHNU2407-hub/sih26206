import 'package:cloud_firestore/cloud_firestore.dart';

/// SATS Disaster — an evacuation shelter.
///
/// Firestore collection: `shelters`
///
/// Capacity/occupancy are updated by authorities as people evacuate
/// (Phase 5 adds the live update UI; the model is needed now because alerts
/// link citizens to shelters and the seed data must populate them).
class ShelterModel {
  /// Firestore document ID. Empty until loaded from Firestore.
  final String id;

  final String name;

  final String district;
  final String mandal;
  final String village;

  /// Human-readable location / address, e.g.
  /// "Government High School, Mukkamala". Nullable so existing shelter
  /// documents without this field keep loading unchanged.
  final String? locationText;

  final double? latitude;
  final double? longitude;

  /// Total shelter capacity (people).
  final int capacity;

  /// People currently accommodated.
  final int occupancy;

  /// active | full | closed
  final String status;

  /// e.g. ['Drinking water', 'First aid', 'Cooked food', 'Generator']
  final List<String> amenities;

  /// e.g. ['Orc tablets', 'Blankets', 'Rice bags']
  final List<String> supplies;

  /// Contact person / caretaker phone number.
  final String contactPhone;

  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// TRUE for seeded prototype records ("Demo data" indicator in the UI).
  final bool isDemoData;

  const ShelterModel({
    this.id = '',
    this.isDemoData = false,
    required this.name,
    required this.district,
    required this.mandal,
    required this.village,
    this.locationText,
    this.latitude,
    this.longitude,
    this.capacity = 0,
    this.occupancy = 0,
    this.status = 'active',
    this.amenities = const [],
    this.supplies = const [],
    this.contactPhone = '',
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasSpace => status != 'closed' && occupancy < capacity;
  int get availableSpace =>
      status == 'closed' ? 0 : (capacity - occupancy).clamp(0, capacity);

  double? get occupancyPercent =>
      capacity <= 0 ? null : (occupancy / capacity * 100).clamp(0.0, 100.0);

  bool get hasLocation => latitude != null && longitude != null;

  /// Latitude within [-90, 90] and longitude within [-180, 180].
  bool get hasValidCoordinates {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Location line for the UI: falls back through address → village →
  /// "" so callers can decide what to render when nothing is known.
  String get locationDisplay =>
      (locationText != null && locationText!.trim().isNotEmpty)
          ? locationText!.trim()
          : village;

  static ShelterModel? fromFirestore(Map<String, dynamic> data, String id) {
    try {
      DateTime readDate(dynamic value, DateTime fallback) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return fallback;
      }

      List<String> readList(dynamic value) {
        if (value is List) return value.map((e) => e.toString()).toList();
        return const [];
      }

      return ShelterModel(
        id: id,
        isDemoData: data['isDemoData'] == true || data['demo'] == true,
        name: (data['name'] ?? '').toString(),
        district: (data['district'] ?? '').toString(),
        mandal: (data['mandal'] ?? '').toString(),
        village: (data['village'] ?? '').toString(),
        locationText: (data['locationText'] as String?)?.toString(),
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        capacity: (data['capacity'] as num?)?.toInt() ?? 0,
        occupancy: (data['occupancy'] as num?)?.toInt() ?? 0,
        status: (data['status'] ?? 'active').toString(),
        amenities: readList(data['amenities']),
        supplies: readList(data['supplies']),
        contactPhone: (data['contactPhone'] ?? '').toString(),
        updatedBy: data['updatedBy']?.toString(),
        createdAt: readDate(data['createdAt'], DateTime.now()),
        updatedAt: readDate(data['updatedAt'], DateTime.now()),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'district': district,
      'mandal': mandal,
      'village': village,
      'locationText': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'occupancy': occupancy,
      'status': status,
      'amenities': amenities,
      'supplies': supplies,
      'contactPhone': contactPhone,
      'updatedBy': updatedBy,
      'isDemoData': isDemoData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update-only map (does not touch createdAt).
  Map<String, dynamic> toFirestoreUpdate() {
    final map = toFirestore()..remove('createdAt');
    return map;
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Open';
      case 'full':
        return 'Full';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  ShelterModel copyWith({
    String? name,
    String? locationText,
    double? latitude,
    double? longitude,
    int? capacity,
    int? occupancy,
    String? status,
    List<String>? amenities,
    List<String>? supplies,
    String? contactPhone,
    String? updatedBy,
  }) {
    return ShelterModel(
      id: id,
      isDemoData: isDemoData,
      name: name ?? this.name,
      district: district,
      mandal: mandal,
      village: village,
      locationText: locationText ?? this.locationText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      occupancy: occupancy ?? this.occupancy,
      status: status ?? this.status,
      amenities: amenities ?? this.amenities,
      supplies: supplies ?? this.supplies,
      contactPhone: contactPhone ?? this.contactPhone,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'ShelterModel($name, $village, cap: $capacity, occ: $occupancy, $status)';
}
