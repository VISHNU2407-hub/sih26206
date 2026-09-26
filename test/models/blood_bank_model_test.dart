import 'package:flutter_test/flutter_test.dart';
import 'package:village_verse/models/blood_bank_model.dart';

void main() {
  group('BloodBank', () {
    test('fromJson creates model correctly', () {
      final json = <String, dynamic>{
        'name': 'City Blood Bank',
        'address': 'Main Road, Guntur',
        'phone': '0863-223344',
        'email': 'info@citybloodbank.com',
        'hospitalType': 'Blood Bank',
        'latitude': 16.3,
        'longitude': 80.4,
      };

      final bank = BloodBank.fromJson(json);

      expect(bank.name, 'City Blood Bank');
      expect(bank.address, 'Main Road, Guntur');
      expect(bank.phone, '0863-223344');
      expect(bank.email, 'info@citybloodbank.com');
      expect(bank.hospitalType, 'Blood Bank');
      expect(bank.latitude, 16.3);
      expect(bank.longitude, 80.4);
      expect(bank.distanceKm, 0.0);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{};

      final bank = BloodBank.fromJson(json);

      expect(bank.name, '');
      expect(bank.address, '');
      expect(bank.phone, '');
      expect(bank.email, '');
      expect(bank.hospitalType, '');
      expect(bank.latitude, 0.0);
      expect(bank.longitude, 0.0);
    });

    test('fromJson trims whitespace from string fields', () {
      final json = <String, dynamic>{
        'name': '  Blood Bank  ',
        'address': '  Main Road  ',
        'phone': '  0863-223344  ',
        'email': '  test@test.com  ',
        'hospitalType': '  Type  ',
        'latitude': 16.3,
        'longitude': 80.4,
      };

      final bank = BloodBank.fromJson(json);

      expect(bank.name, 'Blood Bank');
      expect(bank.address, 'Main Road');
      expect(bank.phone, '0863-223344');
      expect(bank.email, 'test@test.com');
    });

    test('hasValidCoordinates returns true for non-zero coordinates', () {
      final bank = BloodBank(
        name: 'Test',
        address: '',
        phone: '',
        email: '',
        hospitalType: '',
        latitude: 16.3,
        longitude: 80.4,
      );

      expect(bank.hasValidCoordinates, true);
    });

    test('hasValidCoordinates returns false for zero coordinates', () {
      final bank = BloodBank(
        name: 'Test',
        address: '',
        phone: '',
        email: '',
        hospitalType: '',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(bank.hasValidCoordinates, false);
    });

    test('hasPhone returns true when phone is not empty', () {
      final bank = BloodBank(
        name: 'Test',
        address: '',
        phone: '1234567890',
        email: '',
        hospitalType: '',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(bank.hasPhone, true);
    });

    test('hasPhone returns false when phone is empty', () {
      final bank = BloodBank(
        name: 'Test',
        address: '',
        phone: '',
        email: '',
        hospitalType: '',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(bank.hasPhone, false);
    });

    test('toJson includes all fields', () {
      final bank = BloodBank(
        name: 'Test Bank',
        address: 'Test Address',
        phone: '12345',
        email: 'a@b.com',
        hospitalType: 'Center',
        latitude: 10.0,
        longitude: 20.0,
        distanceKm: 5.5,
      );

      final json = bank.toJson();

      expect(json['name'], 'Test Bank');
      expect(json['latitude'], 10.0);
      expect(json['distanceKm'], 5.5);
    });
  });
}
