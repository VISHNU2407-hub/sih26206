import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/blood_bank_model.dart';

class BloodBankService {
  static List<BloodBank>? _cachedBloodBanks;

  /// Loads blood banks from the local JSON asset.
  /// Filters out entries with invalid (0.0, 0.0) coordinates.
  /// Results are cached in memory after first load.
  static Future<List<BloodBank>> loadBloodBanks() async {
    if (_cachedBloodBanks != null) {
      return _cachedBloodBanks!;
    }

    final jsonString = await rootBundle.loadString(
      'assets/data/ap_blood_banks.json',
    );
    final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

    final bloodBanks = <BloodBank>[];
    for (final item in jsonData) {
      final bank = BloodBank.fromJson(item as Map<String, dynamic>);
      if (bank.hasValidCoordinates) {
        bloodBanks.add(bank);
      }
    }

    _cachedBloodBanks = bloodBanks;
    return bloodBanks;
  }

  /// Calculates distance from user to each blood bank and sorts nearest first.
  static List<BloodBank> sortByDistance({
    required List<BloodBank> banks,
    required double userLat,
    required double userLng,
  }) {
    for (final bank in banks) {
      final distanceInMeters = Geolocator.distanceBetween(
        userLat,
        userLng,
        bank.latitude,
        bank.longitude,
      );
      bank.distanceKm = double.parse(
        (distanceInMeters / 1000).toStringAsFixed(1),
      );
    }

    banks.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return banks;
  }

  /// Formats distance in km for display.
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Clears the cached blood bank list (useful for testing).
  static void clearCache() {
    _cachedBloodBanks = null;
  }
}
