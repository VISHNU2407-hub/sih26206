import 'dart:convert';
import 'package:flutter/services.dart';

class MandalDataService {
  static List<String>? _cachedMandals;
  static List<String>? _cachedDistricts;

  /// Loads and caches the full list of district names from the AP dataset.
  static Future<List<String>> loadDistricts() async {
    if (_cachedDistricts != null) return _cachedDistricts!;

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/andhra_pradesh.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final List<String> districts = [];

      if (data.containsKey('districts')) {
        final List<dynamic> districtList = data['districts'];
        for (var district in districtList) {
          if (district.containsKey('district')) {
            districts.add(district['district'].toString());
          }
        }
      }

      // Sort alphabetically
      districts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _cachedDistricts = districts;
      return districts;
    } catch (e) {
      throw Exception('Failed to load district data: $e');
    }
  }

  /// Filters districts by query (case-insensitive contains).
  static List<String> filterDistricts(String query, List<String> districts) {
    if (query.isEmpty) return districts;
    final lowerQuery = query.toLowerCase();
    return districts
        .where((d) => d.toLowerCase().contains(lowerQuery))
        .toList();
  }

  static Future<List<String>> loadMandals() async {
    if (_cachedMandals != null) {
      return _cachedMandals!;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/andhra_pradesh.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final List<String> mandals = [];

      if (data.containsKey('districts')) {
        final List<dynamic> districts = data['districts'];
        
        for (var district in districts) {
          if (district.containsKey('subDistricts')) {
            final List<dynamic> subDistricts = district['subDistricts'];
            
            for (var subDistrict in subDistricts) {
              if (subDistrict.containsKey('subDistrict')) {
                mandals.add(subDistrict['subDistrict'].toString());
              }
            }
          }
        }
      }

      // Remove duplicates and sort alphabetically
      final uniqueMandals = mandals.toSet().toList();
      uniqueMandals.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _cachedMandals = uniqueMandals;
      return uniqueMandals;
    } catch (e) {
      throw Exception('Failed to load mandal data: $e');
    }
  }

  static List<String> filterMandals(String query, List<String> mandals) {
    if (query.isEmpty) {
      return mandals;
    }

    final lowerQuery = query.toLowerCase();
    return mandals
        .where((mandal) => mandal.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Loads and caches the complete raw JSON data for village lookups.
  static List<Map<String, dynamic>>? _cachedRawDistricts;

  /// Loads and caches the full raw district list from the JSON asset.
  /// Used internally for village lookups by mandal.
  static Future<List<Map<String, dynamic>>> _loadRawDistricts() async {
    if (_cachedRawDistricts != null) return _cachedRawDistricts!;

    final String jsonString =
        await rootBundle.loadString('assets/data/andhra_pradesh.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    final List<dynamic> districts = data['districts'];
    _cachedRawDistricts =
        districts.map((d) => Map<String, dynamic>.from(d)).toList();
    return _cachedRawDistricts!;
  }

  /// Loads all village names for the given [mandalName] (case-insensitive match).
  /// Returns an empty list if the mandal is not found or has no villages.
  static Future<List<String>> loadVillagesForMandal(String mandalName) async {
    if (mandalName.trim().isEmpty) return [];

    try {
      final districts = await _loadRawDistricts();
      final lowerMandal = mandalName.trim().toLowerCase();

      for (final district in districts) {
        final subDistricts = district['subDistricts'] as List<dynamic>? ?? [];
        for (final sub in subDistricts) {
          final subMap = Map<String, dynamic>.from(sub);
          final subName = (subMap['subDistrict'] as String? ?? '').toLowerCase();
          if (subName == lowerMandal) {
            final villages = subMap['villages'] as List<dynamic>? ?? [];
            final villageNames = villages.map((v) => v.toString()).toList();
            villageNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            return villageNames;
          }
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load villages for mandal: $e');
    }
  }

  /// Filters a village list by query (case-insensitive contains).
  static List<String> filterVillages(String query, List<String> villages) {
    if (query.isEmpty) return villages;
    final lowerQuery = query.toLowerCase();
    return villages
        .where((v) => v.toLowerCase().contains(lowerQuery))
        .toList();
  }

  static void clearCache() {
    _cachedMandals = null;
    _cachedDistricts = null;
    _cachedRawDistricts = null;
  }
}
