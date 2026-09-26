import 'package:cloud_firestore/cloud_firestore.dart';

class GuardianModel {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final DateTime createdAt;

  GuardianModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.createdAt,
  });

  // Create from Firestore document
  factory GuardianModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GuardianModel(
      id: id,
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
      phone: data['phone'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'relation': relation,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create copy with updated fields
  GuardianModel copyWith({
    String? name,
    String? relation,
    String? phone,
  }) {
    return GuardianModel(
      id: id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GuardianModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GuardianModel(id: $id, name: $name, relation: $relation, phone: $phone, createdAt: $createdAt)';
  }
}
