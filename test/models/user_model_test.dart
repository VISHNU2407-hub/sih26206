import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:village_verse/models/user_model.dart';

void main() {
  group('UserModel', () {
    const uid = 'test_uid_123';
    final now = DateTime(2025, 6, 11, 12, 0, 0);

    test('fromFirestore creates model correctly with all fields', () {
      final data = <String, dynamic>{
        'name': 'Test User',
        'phone': '9876543210',
        'state': 'Andhra Pradesh',
        'district': 'Guntur',
        'village': 'Guntur Rural',      // Firestore 'village' → UserModel.mandal
        'street': 'Pedapalakaluru',      // Firestore 'street' → UserModel.village
        'photoUrl': 'https://example.com/photo.jpg',
        'age': '28',
        'dateOfBirth': Timestamp.fromDate(DateTime(1997, 5, 20)),
        'bloodGroup': 'O+',
        'role': 'citizen',
        'isBloodDonor': true,
        'createdAt': Timestamp.fromDate(now),
        'latitude': 16.3,
        'longitude': 80.4,
      };

      final user = UserModel.fromFirestore(data, uid);

      expect(user.uid, uid);
      expect(user.name, 'Test User');
      expect(user.phone, '9876543210');
      expect(user.state, 'Andhra Pradesh');
      expect(user.district, 'Guntur');
      expect(user.mandal, 'Guntur Rural');    // from Firestore 'village'
      expect(user.village, 'Pedapalakaluru'); // from Firestore 'street'
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.age, '28');
      expect(user.dateOfBirth, DateTime(1997, 5, 20));
      expect(user.bloodGroup, 'O+');
      expect(user.role, 'citizen');
      expect(user.isBloodDonor, true);
      expect(user.latitude, 16.3);
      expect(user.longitude, 80.4);
    });

    test('fromFirestore uses defaults for missing fields', () {
      final data = <String, dynamic>{
        'name': 'Minimal User',
        'phone': '9123456789',
        'mandal': 'Test Mandal',
        'village': 'Test Village',
        'createdAt': Timestamp.fromDate(now),
      };

      final user = UserModel.fromFirestore(data, uid);

      expect(user.uid, uid);
      expect(user.name, 'Minimal User');
      expect(user.state, '');
      expect(user.district, '');
      expect(user.photoUrl, '');
      expect(user.age, '');
      expect(user.dateOfBirth, isNull); // no dateOfBirth stored
      expect(user.bloodGroup, '');
      expect(user.role, 'citizen');  // default
      expect(user.isBloodDonor, false); // default
      expect(user.latitude, isNull);
      expect(user.longitude, isNull);
    });

    test('fromFirestore handles null createdAt', () {
      final data = <String, dynamic>{
        'name': 'No Date',
        'phone': '9123456789',
        'village': 'Test',
        'street': 'Test',
      };

      final user = UserModel.fromFirestore(data, uid);
      // createdAt should be close to now (within 5 seconds)
      expect(
        user.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('toFirestore correctly maps mandal→village and village→street', () {
      final user = UserModel(
        uid: uid,
        name: 'Map Test',
        phone: '9988776655',
        state: 'AP',
        district: 'Krishna',
        mandal: 'MandalName',     // → Firestore 'village'
        village: 'VillageName',   // → Firestore 'street'
        photoUrl: '',
        age: '25',
        dateOfBirth: DateTime(2000, 1, 15),
        bloodGroup: 'B+',
        role: 'admin',
        isBloodDonor: false,
        createdAt: now,
        latitude: null,
        longitude: null,
      );

      final map = user.toFirestore();

      expect(map['name'], 'Map Test');
      expect(map['village'], 'MandalName');   // mandal → 'village'
      expect(map['street'], 'VillageName');   // village → 'street'
      expect(map['role'], 'admin');
      expect(map['isBloodDonor'], false);
      expect(map['latitude'], isNot(contains('latitude'))); // not present when null
      expect((map['dateOfBirth'] as Timestamp).toDate(), DateTime(2000, 1, 15));
    });

    test('toFirestore omits age when empty and omits dateOfBirth when null', () {
      final user = UserModel(
        uid: uid,
        name: 'No Age',
        phone: '9988776655',
        state: '',
        district: '',
        mandal: '',
        village: '',
        photoUrl: '',
        age: '',
        bloodGroup: '',
        role: 'citizen',
        createdAt: now,
      );

      final map = user.toFirestore();

      expect(map.containsKey('age'), isFalse); // no manually entered age stored
      expect(map.containsKey('dateOfBirth'), isFalse);
    });

    test('copyWith updates only specified fields', () {
      final user = UserModel(
        uid: uid,
        name: 'Original',
        phone: '1111111111',
        state: 'State',
        district: 'District',
        mandal: 'Mandal',
        village: 'Village',
        photoUrl: '',
        age: '20',
        bloodGroup: 'A+',
        role: 'citizen',
        isBloodDonor: false,
        createdAt: now,
      );

      final updated = user.copyWith(name: 'Updated', isBloodDonor: true);

      expect(updated.name, 'Updated');
      expect(updated.isBloodDonor, true);
      expect(updated.phone, '1111111111'); // unchanged
      expect(updated.uid, uid);            // unchanged
    });

    test('equality operator works on uid', () {
      final user1 = UserModel(
        uid: uid,
        name: 'A',
        phone: '1',
        state: '',
        district: '',
        mandal: '',
        village: '',
        photoUrl: '',
        age: '',
        bloodGroup: '',
        role: 'citizen',
        createdAt: now,
      );

      final user2 = UserModel(
        uid: uid,
        name: 'B', // different name but same uid
        phone: '2',
        state: '',
        district: '',
        mandal: '',
        village: '',
        photoUrl: '',
        age: '',
        bloodGroup: '',
        role: 'citizen',
        createdAt: now,
      );

      expect(user1 == user2, true);
      expect(user1.hashCode, user2.hashCode);
    });
  });
}
