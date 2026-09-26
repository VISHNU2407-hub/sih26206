import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/hospital_model.dart';

/// SATS Disaster — Public Hospitals directory service (migrated from the
/// original SATS app; same bundled district JSON assets, no Firebase reads).
///
/// Hospitals are a DIRECTORY, not disaster-targeted records: they may
/// legitimately sit outside the user's village, so GeoMatch is deliberately
/// NOT applied here. Useful geographic narrowing is offered instead via
/// [searchHospitals] and [filterByDistrict], and nearest-first sorting via
/// [getNearestHospitals] when a location is available.
class HospitalService {
  static const List<String> _allDistricts = [
    'anantapuramu',
    'chittoor',
    'east_godavari',
    'guntur',
    'kakinada',
    'krishna',
    'kurnool',
    'nandyal',
    'prakasam',
    'spsr_nellore',
    'srikakulam',
    'tirupati',
    'visakhapatnam',
    'vizianagaram',
    'west_godavari',
    'ysr_kadapa',
  ];

  /// Exposed for display purposes (e.g., to show district names in filters).
  static List<String> get allDistricts => List.unmodifiable(_allDistricts);

  // ── In-memory cache ──

  static List<Hospital>? _cachedAllHospitals;
  static Completer<List<Hospital>>? _cacheCompleter;

  /// Loads & caches all hospitals from every district JSON asset.
  ///
  /// Subsequent calls return the cached list instantly. Concurrent calls
  /// during an in-flight load share the same [Future] so the work is
  /// only done once.
  static Future<List<Hospital>> loadAllHospitals() async {
    final cached = _cachedAllHospitals;
    if (cached != null) return cached;

    final inFlight = _cacheCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<List<Hospital>>();
    _cacheCompleter = completer;

    try {
      final all = <Hospital>[];
      for (final district in _allDistricts) {
        try {
          final jsonString = await rootBundle.loadString(
            'assets/data/hospitals/$district.json',
          );
          final List<dynamic> jsonData =
              json.decode(jsonString) as List<dynamic>;

          for (final item in jsonData) {
            try {
              final hospital =
                  Hospital.fromJson(item as Map<String, dynamic>);
              if (hospital.hasValidCoordinates) {
                all.add(hospital);
              }
            } catch (e) {
              // A single malformed record should not break its district.
              debugPrint('HospitalService: malformed record in '
                  '$district skipped: $e');
            }
          }
        } catch (e) {
          // Log but continue — a single district failure should not
          // prevent showing results from other districts.
          debugPrint('HospitalService: failed to load district '
              '$district: $e');
        }
      }

      _cachedAllHospitals = all;
      completer.complete(all);
      return all;
    } catch (e) {
      // Nothing is cached, so a later call can retry the load.
      completer.completeError(e);
      rethrow;
    } finally {
      _cacheCompleter = null;
    }
  }

  /// Returns all hospitals sorted by distance from [userLat]/[userLng],
  /// nearest first.
  ///
  /// Hospitals are loaded from the in-memory cache (populated on first
  /// call) and distances are computed on every invocation so that the
  /// sort reflects the user's current GPS fix.
  static Future<List<Hospital>> getNearestHospitals(
    double userLat,
    double userLng,
  ) async {
    final hospitals = await loadAllHospitals();

    for (final hospital in hospitals) {
      final distanceInMeters = Geolocator.distanceBetween(
        userLat,
        userLng,
        hospital.latitude,
        hospital.longitude,
      );
      hospital.distanceKm =
          double.parse((distanceInMeters / 1000).toStringAsFixed(1));
    }

    hospitals.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return hospitals;
  }

  // ── Directory search & filtering ──

  /// Case-insensitive text search across the fields the dataset actually
  /// provides: hospital name, district (raw slug and display form) and
  /// address. An empty/blank [query] returns everything.
  ///
  /// Always returns a new list; the input list is never modified.
  static List<Hospital> searchHospitals(
    List<Hospital> hospitals,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.of(hospitals);

    return hospitals.where((hospital) {
      final name = hospital.name.toLowerCase();
      final rawName = hospital.searchName.toLowerCase();
      final district = hospital.district.toLowerCase();
      final districtDisplay = district.replaceAll('_', ' ');
      final address = hospital.address.toLowerCase();
      return name.contains(q) ||
          rawName.contains(q) ||
          district.contains(q) ||
          districtDisplay.contains(q) ||
          address.contains(q);
    }).toList();
  }

  /// Filters hospitals to a single district using the raw slug as stored in
  /// the dataset (e.g. `spsr_nellore`). An empty [district] returns all.
  ///
  /// Always returns a new list; the input list is never modified.
  static List<Hospital> filterByDistrict(
    List<Hospital> hospitals,
    String district,
  ) {
    final d = district.trim().toLowerCase();
    if (d.isEmpty) return List.of(hospitals);
    return hospitals
        .where((h) => h.district.trim().toLowerCase() == d)
        .toList();
  }

  /// Sorted list of unique district slugs present in [hospitals] — used to
  /// build the district filter from whatever the dataset actually contains.
  static List<String> districtsIn(List<Hospital> hospitals) {
    final districts = <String>{};
    for (final hospital in hospitals) {
      final d = hospital.district.trim();
      if (d.isNotEmpty && d != 'Unknown') districts.add(d);
    }
    return districts.toList()..sort();
  }

  /// Formats a raw district slug for display (`spsr_nellore` →
  /// `SPSR Nellore`, `ysr_kadapa` → `YSR Kadapa`, `kurnool` → `Kurnool`).
  static String formatDistrictName(String district) {
    final trimmed = district.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      final upper = word.toUpperCase();
      if (upper == 'YSR' || upper == 'SPSR') return upper;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Formats a distance value in km for display.
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Clears the in-memory cache (useful for testing or data refresh).
  static void clearCache() {
    _cachedAllHospitals = null;
    _cacheCompleter = null;
  }
}
