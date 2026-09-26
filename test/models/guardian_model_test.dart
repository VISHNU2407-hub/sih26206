import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:village_verse/models/guardian_model.dart';

void main() {
  group('GuardianModel', () {
    const id = 'guardian_001';
    final now = DateTime(2025, 5, 15, 10, 30, 0);

    test('fromFirestore creates model correctly', () {
      final data = <String, dynamic>{
        'name': 'Mother',
        'relation': 'Mother',
        'phone': '9876543210',
        'createdAt': Timestamp.fromDate(now),
      };

      final guardian = GuardianModel.fromFirestore(data, id);

      expect(guardian.id, id);
      expect(guardian.name, 'Mother');
      expect(guardian.relation, 'Mother');
      expect(guardian.phone, '9876543210');
      expect(guardian.createdAt, now);
    });

    test('fromFirestore uses defaults for missing fields', () {
      final data = <String, dynamic>{};

      final guardian = GuardianModel.fromFirestore(data, id);

      expect(guardian.id, id);
      expect(guardian.name, '');
      expect(guardian.relation, '');
      expect(guardian.phone, '');
      expect(
        guardian.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('toFirestore returns correct map', () {
      final guardian = GuardianModel(
        id: id,
        name: 'Father',
        relation: 'Father',
        phone: '9123456789',
        createdAt: now,
      );

      final map = guardian.toFirestore();

      expect(map['name'], 'Father');
      expect(map['relation'], 'Father');
      expect(map['phone'], '9123456789');
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('copyWith updates only specified fields', () {
      final guardian = GuardianModel(
        id: id,
        name: 'Original',
        relation: 'Friend',
        phone: '1111111111',
        createdAt: now,
      );

      final updated = guardian.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.relation, 'Friend'); // unchanged
      expect(updated.phone, '1111111111'); // unchanged
      expect(updated.id, id); // unchanged
    });

    test('equality operator works on id', () {
      final g1 = GuardianModel(
        id: id,
        name: 'A',
        relation: 'X',
        phone: '1',
        createdAt: now,
      );

      final g2 = GuardianModel(
        id: id,
        name: 'B',
        relation: 'Y',
        phone: '2',
        createdAt: now,
      );

      expect(g1 == g2, true);
      expect(g1.hashCode, g2.hashCode);
    });
  });
}
