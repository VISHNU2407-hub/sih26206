import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_verse/utils/helpers.dart';

void main() {
  group('AppHelpers', () {
    group('validatePhone', () {
      test('returns null for valid 10-digit phone', () {
        expect(AppHelpers.validatePhone('9876543210'), isNull);
      });

      test('returns error for empty value', () {
        expect(
          AppHelpers.validatePhone(''),
          'Phone number is required',
        );
      });

      test('returns error for null value', () {
        expect(
          AppHelpers.validatePhone(null),
          'Phone number is required',
        );
      });

      test('returns error for short phone number', () {
        expect(
          AppHelpers.validatePhone('12345'),
          'Please enter a valid 10-digit phone number',
        );
      });

      test('returns error for long phone number', () {
        expect(
          AppHelpers.validatePhone('12345678901'),
          'Please enter a valid 10-digit phone number',
        );
      });

      test('strips non-digit characters before validation', () {
        // After stripping non-digits, "987-654-3210" → "9876543210" (10 digits)
        expect(AppHelpers.validatePhone('987-654-3210'), isNull);
      });

      test('still fails when stripped phone is wrong length', () {
        // After stripping: "99-88" → "9988" (4 digits)
        expect(
          AppHelpers.validatePhone('99-88'),
          'Please enter a valid 10-digit phone number',
        );
      });
    });

    group('validateRequired', () {
      test('returns null for non-empty value', () {
        expect(AppHelpers.validateRequired('Hello', 'Name'), isNull);
      });

      test('returns error for empty value', () {
        expect(
          AppHelpers.validateRequired('', 'Name'),
          'Name is required',
        );
      });

      test('returns error for whitespace-only value', () {
        expect(
          AppHelpers.validateRequired('   ', 'Name'),
          'Name is required',
        );
      });
    });

    group('formatPhoneNumber', () {
      test('formats 10-digit phone', () {
        expect(AppHelpers.formatPhoneNumber('9876543210'), '98765-43210');
      });

      test('returns raw string for non-10-digit phone', () {
        expect(AppHelpers.formatPhoneNumber('123'), '123');
      });
    });

    group('formatDate', () {
      test('formats date correctly', () {
        final date = DateTime(2025, 6, 11);
        expect(AppHelpers.formatDate(date), '11/6/2025');
      });
    });

    group('validateDateOfBirth', () {
      test('returns error for null DOB', () {
        expect(AppHelpers.validateDateOfBirth(null), isNotNull);
      });

      test('returns null for a valid past DOB', () {
        expect(
          AppHelpers.validateDateOfBirth(DateTime(2000, 1, 1)),
          isNull,
        );
      });

      test('returns error for a future DOB', () {
        expect(
          AppHelpers.validateDateOfBirth(
            DateTime.now().add(const Duration(days: 1)),
          ),
          isNotNull,
        );
      });
    });

    group('calculateAge', () {
      test('returns null for null DOB', () {
        expect(AppHelpers.calculateAge(null), isNull);
      });

      test('returns null for a future DOB', () {
        expect(
          AppHelpers.calculateAge(
            DateTime.now().add(const Duration(days: 1)),
          ),
          isNull,
        );
      });

      test('subtracts a year when the birthday has not occurred yet', () {
        final now = DateTime(2026, 8, 9);
        // Born 10 Aug 2000 -> still 25 on 9 Aug 2026 (birthday tomorrow)
        expect(AppHelpers.calculateAge(DateTime(2000, 8, 10), now: now), 25);
        // Born 9 Aug 2000 -> turns 26 today
        expect(AppHelpers.calculateAge(DateTime(2000, 8, 9), now: now), 26);
        // Born 8 Aug 2000 -> already 26
        expect(AppHelpers.calculateAge(DateTime(2000, 8, 8), now: now), 26);
      });

      test('handles year boundaries and leap day birthdays', () {
        expect(
          AppHelpers.calculateAge(
            DateTime(2000, 12, 31),
            now: DateTime(2026, 1, 1),
          ),
          25,
        );
        expect(
          AppHelpers.calculateAge(
            DateTime(2000, 2, 29),
            now: DateTime(2026, 2, 28),
          ),
          25,
        );
        expect(
          AppHelpers.calculateAge(
            DateTime(2000, 2, 29),
            now: DateTime(2026, 3, 1),
          ),
          26,
        );
      });

      test('is 17 before the 18th birthday and 18 on/after it', () {
        final dob = DateTime(2008, 8, 10);
        expect(AppHelpers.calculateAge(dob, now: DateTime(2026, 8, 9)), 17);
        expect(AppHelpers.calculateAge(dob, now: DateTime(2026, 8, 10)), 18);
        expect(AppHelpers.calculateAge(dob, now: DateTime(2026, 8, 11)), 18);
      });
    });

    group('formatDateTime', () {
      test('formats date time correctly', () {
        final date = DateTime(2025, 6, 11, 14, 30);
        final result = AppHelpers.formatDateTime(date);
        expect(result, contains('11/6/2025'));
        expect(result, contains('14:30'));
      });

      test('handles null input gracefully', () {
        final result = AppHelpers.formatDateTime(null);
        expect(result, contains(DateTime.now().day.toString()));
      });
    });

    group('capitalize', () {
      test('capitalizes first letter', () {
        expect(AppHelpers.capitalize('hello'), 'Hello');
      });

      test('lowercases remaining letters', () {
        expect(AppHelpers.capitalize('HELLO'), 'Hello');
      });

      test('returns empty string unchanged', () {
        expect(AppHelpers.capitalize(''), '');
      });
    });

    group('isEmpty', () {
      test('returns true for null', () {
        expect(AppHelpers.isEmpty(null), true);
      });

      test('returns true for empty string', () {
        expect(AppHelpers.isEmpty(''), true);
      });

      test('returns true for whitespace', () {
        expect(AppHelpers.isEmpty('   '), true);
      });

      test('returns false for non-empty string', () {
        expect(AppHelpers.isEmpty('abc'), false);
      });
    });

    group('getGreeting', () {
      test('returns a greeting string', () {
        final greeting = AppHelpers.getGreeting();
        expect(
          ['Good Morning', 'Good Afternoon', 'Good Evening', 'Good Night'],
          contains(greeting),
        );
      });
    });

    group('getEmergencyIcon', () {
      test('returns correct icon for medical', () {
        expect(AppHelpers.getEmergencyIcon('medical'), isNotNull);
      });

      test('returns default icon for unknown type', () {
        expect(AppHelpers.getEmergencyIcon('unknown'), isNotNull);
      });
    });

    group('getEmergencyColor', () {
      test('returns correct color for medical', () {
        expect(AppHelpers.getEmergencyColor('medical'), isNotNull);
      });
    });

    group('getStatusColor', () {
      test('maps every status to its standard color', () {
        expect(AppHelpers.getStatusColor('pending'), Colors.orange);
        expect(AppHelpers.getStatusColor('in_progress'), Colors.blue);
        expect(AppHelpers.getStatusColor('reviewing'), Colors.purple);
        expect(AppHelpers.getStatusColor('resolved'), Colors.green);
        expect(AppHelpers.getStatusColor('rejected'), Colors.red);
      });

      test('is case-insensitive and falls back to grey', () {
        expect(AppHelpers.getStatusColor('PENDING'), Colors.orange);
        expect(AppHelpers.getStatusColor('unknown'), Colors.grey);
      });
    });

    group('getCategoryIcon', () {
      test('returns a Material icon for every category', () {
        const categories = [
          'Roads',
          'Water',
          'Electricity',
          'Drainage',
          'Garbage',
          'Street Lights',
          'Internet',
          'Public Safety',
          'Other',
        ];
        for (final category in categories) {
          expect(
            AppHelpers.getCategoryIcon(category),
            isNotNull,
            reason: 'Category "$category" should have an icon',
          );
        }
      });

      test('returns a default icon for unknown categories', () {
        expect(AppHelpers.getCategoryIcon('Unknown'), isNotNull);
      });
    });
  });
}
