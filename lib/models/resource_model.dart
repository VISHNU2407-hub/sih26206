import 'package:cloud_firestore/cloud_firestore.dart';

/// SATS Disaster — Phase 5: a relief resource requirement/stock record.
///
/// Firestore collection: `resources`
///
/// One document per (disaster, village, resourceType): how much of a relief
/// item a village needs, how much is available on the ground, and how much
/// has been allocated/dispatched by authorities.
class ResourceModel {
  /// Firestore document ID. Empty until loaded from Firestore.
  final String id;

  /// Linked disaster event (`disasters/{id}`), if tracked during one.
  final String? disasterId;

  final String district;
  final String mandal;
  final String village;

  /// Resource type key, e.g. drinking_water | food_packets | medicines |
  /// blankets | emergency_kits | boats | generators | rescue_equipment.
  /// Free strings so new types can be added without a migration — labels
  /// resolve via [resourceLabel].
  final String resourceType;

  /// Units currently available on the ground in the village.
  final int quantity;

  /// Units required to cover the need.
  final int requiredQuantity;

  /// Units allocated/dispatched by authorities from stock.
  final int allocatedQuantity;

  /// Unit name shown after counts, e.g. "litres", "packets", "units".
  final String unit;

  /// needed | available | allocated | exhausted
  final String status;

  final String notes;

  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime createdAt;

  /// TRUE for seeded prototype records ("Demo data" indicator in the UI).
  final bool isDemoData;

  const ResourceModel({
    this.id = '',
    this.isDemoData = false,
    this.disasterId,
    required this.district,
    required this.mandal,
    required this.village,
    required this.resourceType,
    this.quantity = 0,
    this.requiredQuantity = 0,
    this.allocatedQuantity = 0,
    this.unit = 'units',
    this.status = 'needed',
    this.notes = '',
    this.updatedBy,
    required this.updatedAt,
    required this.createdAt,
  });

  // ── Derived figures ──

  /// Units still missing: required − available (never negative).
  int get shortfall =>
      requiredQuantity > quantity ? requiredQuantity - quantity : 0;

  /// True when the requirement is fully covered by available stock.
  bool get isCovered => requiredQuantity > 0 && quantity >= requiredQuantity;

  /// 0.0–1.0 coverage of the requirement by available stock
  /// (null when no requirement has been recorded).
  double? get coverage {
    if (requiredQuantity <= 0) return null;
    return (quantity / requiredQuantity).clamp(0.0, 1.0);
  }

  bool get isExhausted => status == 'exhausted';

  static ResourceModel? fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    try {
      DateTime readDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return DateTime.now();
      }

      return ResourceModel(
        id: id,
        isDemoData: data['isDemoData'] == true || data['demo'] == true,
        disasterId: data['disasterId']?.toString(),
        district: (data['district'] ?? '').toString(),
        mandal: (data['mandal'] ?? '').toString(),
        village: (data['village'] ?? '').toString(),
        resourceType: (data['resourceType'] ?? 'other').toString(),
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        requiredQuantity: (data['requiredQuantity'] as num?)?.toInt() ?? 0,
        allocatedQuantity: (data['allocatedQuantity'] as num?)?.toInt() ?? 0,
        unit: (data['unit'] ?? 'units').toString(),
        status: (data['status'] ?? 'needed').toString(),
        notes: (data['notes'] ?? '').toString(),
        updatedBy: data['updatedBy']?.toString(),
        updatedAt: readDate(data['updatedAt']),
        createdAt: readDate(data['createdAt']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'disasterId': disasterId,
      'district': district,
      'mandal': mandal,
      'village': village,
      'resourceType': resourceType,
      'quantity': quantity,
      'requiredQuantity': requiredQuantity,
      'allocatedQuantity': allocatedQuantity,
      'unit': unit,
      'status': status,
      'notes': notes,
      'updatedBy': updatedBy,
      'isDemoData': isDemoData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Update-only map (does not touch createdAt / village identity).
  Map<String, dynamic> toFirestoreUpdate() {
    final map = toFirestore()..remove('createdAt');
    return map;
  }

  // ── Vocabulary ──

  static const String statusNeeded = 'needed';
  static const String statusAvailable = 'available';
  static const String statusAllocated = 'allocated';
  static const String statusExhausted = 'exhausted';

  static const List<String> statuses = [
    statusNeeded,
    statusAvailable,
    statusAllocated,
    statusExhausted,
  ];

  static String statusLabel(String status) {
    switch (status) {
      case statusNeeded:
        return 'Needed';
      case statusAvailable:
        return 'Available';
      case statusAllocated:
        return 'Allocated';
      case statusExhausted:
        return 'Exhausted';
      default:
        return status;
    }
  }

  static String resourceLabel(String type) {
    switch (type) {
      case 'drinking_water':
        return 'Drinking Water';
      case 'food_packets':
        return 'Food Packets';
      case 'medicines':
        return 'Medicines';
      case 'blankets':
        return 'Blankets';
      case 'emergency_kits':
        return 'Emergency Kits';
      case 'boats':
        return 'Boats';
      case 'generators':
        return 'Generators';
      case 'rescue_equipment':
        return 'Rescue Equipment';
      case 'tarpaulins':
        return 'Tarpaulins';
      case 'cooked_food':
        return 'Cooked Food';
      default:
        return type
            .replaceAll('_', ' ')
            .replaceFirstMapped(RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());
    }
  }

  /// Validation for a resource write. Returns a human-readable error or
  /// null when the values are consistent. Pure — unit-testable.
  ///
  /// Rules:
  /// - quantities must be >= 0
  /// - allocatedQuantity may not exceed available quantity (you cannot
  ///   dispatch more than you hold)
  /// - allocatedQuantity may not exceed requiredQuantity when a
  ///   requirement has been recorded (never over-allocate a need)
  /// - resourceType must be non-empty; village identity must be present
  static String? validate({
    required int quantity,
    required int requiredQuantity,
    required int allocatedQuantity,
    required String resourceType,
    required String village,
  }) {
    if (resourceType.trim().isEmpty) return 'Resource type is required';
    if (village.trim().isEmpty) return 'Village is required';
    if (quantity < 0) return 'Available quantity cannot be negative';
    if (requiredQuantity < 0) return 'Required quantity cannot be negative';
    if (allocatedQuantity < 0) return 'Allocated quantity cannot be negative';
    if (allocatedQuantity > quantity) {
      return 'Allocated cannot exceed available quantity';
    }
    if (requiredQuantity > 0 && allocatedQuantity > requiredQuantity) {
      return 'Allocated cannot exceed required quantity';
    }
    return null;
  }

  ResourceModel copyWith({
    String? disasterId,
    int? quantity,
    int? requiredQuantity,
    int? allocatedQuantity,
    String? status,
    String? notes,
    String? updatedBy,
  }) {
    return ResourceModel(
      id: id,
      isDemoData: isDemoData,
      disasterId: disasterId ?? this.disasterId,
      district: district,
      mandal: mandal,
      village: village,
      resourceType: resourceType,
      quantity: quantity ?? this.quantity,
      requiredQuantity: requiredQuantity ?? this.requiredQuantity,
      allocatedQuantity: allocatedQuantity ?? this.allocatedQuantity,
      unit: unit,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'ResourceModel($resourceType, $village, need: $requiredQuantity, '
      'have: $quantity, allocated: $allocatedQuantity, $status)';
}
