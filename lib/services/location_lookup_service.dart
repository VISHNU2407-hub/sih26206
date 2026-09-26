import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a location lookup against the Andhra Pradesh dataset.
class LocationLookupResult {
  /// The matched district name.
  final String district;

  /// The matched mandal (subDistrict) name, if found.
  final String? mandal;

  /// The matched village name, if found.
  final String? village;

  /// Description of how the match was made (e.g. 'village_exact', 'mandal_fuzzy').
  final String matchType;

  /// Other possible matches that were found but not selected.
  final List<String> alternatives;

  LocationLookupResult({
    required this.district,
    this.mandal,
    this.village,
    required this.matchType,
    this.alternatives = const [],
  });

  @override
  String toString() =>
      'LocationLookupResult(district: $district, mandal: $mandal, village: $village, matchType: $matchType, alternatives: $alternatives)';
}

/// Service that cross-references reverse geocoding text output against the
/// Andhra Pradesh district → mandal → village dataset (andhra_pradesh.json).
///
/// This acts as an enhancement layer on top of platform geocoding: when the
/// device geocoder returns only a state name or a fragmentary address, this
/// service can determine the full district/mandal/village hierarchy by matching
/// the returned text against the known dataset.
class LocationLookupService {
  static List<Map<String, dynamic>>? _cachedDistricts;

  /// Loads and caches the full district list from the JSON asset.
  static Future<List<Map<String, dynamic>>> _loadDistricts() async {
    if (_cachedDistricts != null) return _cachedDistricts!;

    final String jsonString =
        await rootBundle.loadString('assets/data/andhra_pradesh.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    final List<dynamic> districts = data['districts'];
    _cachedDistricts =
        districts.map((d) => Map<String, dynamic>.from(d)).toList();
    return _cachedDistricts!;
  }

  /// Clears the in-memory cache (useful for testing or hot reload).
  static void clearCache() {
    _cachedDistricts = null;
  }

  /// Common suffixes/prefixes that may appear in geocoding output but should
  /// be stripped before matching against the dataset village/mandal names.
  static final List<RegExp> _noisePatterns = [
    RegExp(r'\bvillage\b', caseSensitive: false),
    RegExp(r'\btown\b', caseSensitive: false),
    RegExp(r'\bmanda[l|r]\b', caseSensitive: false),
    RegExp(r'\bpeta\b', caseSensitive: false),
    RegExp(r'\bpost\b', caseSensitive: false),
    RegExp(r'\p{So}+',) // remove pictographic/emoji characters
  ];

  /// Cleans a candidate string by stripping common noise words and extra
  /// whitespace, so that e.g. "Rangampeta Village" becomes "Rangampeta".
  static String _cleanCandidate(String raw) {
    var cleaned = raw.trim();
    for (final pattern in _noisePatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Builds a deduplicated list of candidate search strings from the available
  /// geocoding fields, ordered by reliability (name first, then locality, etc.).
  ///
  /// Each field is:
  /// 1. Trimmed
  /// 2. Cleaned of common noise words ("Village", "Town", "Mandal", etc.)
  /// 3. Split on commas / semicolons so that "Kadiri, Anantapur" produces
  ///    two candidates ["Kadiri", "Anantapur"]
  static List<String> _buildCandidates({
    required String? name,
    required String? locality,
    required String? subLocality,
    required String? thoroughfare,
    required String? subThoroughfare,
  }) {
    final rawValues = [
      name,
      locality,
      subLocality,
      thoroughfare,
      subThoroughfare,
    ];

    final candidates = <String>[];

    for (final value in rawValues) {
      if (value == null || value.trim().isEmpty) continue;

      final trimmed = value.trim();
      // Split on common separators
      final parts = trimmed.split(RegExp(r'[,;:]'));

      for (var part in parts) {
        part = _cleanCandidate(part);
        if (part.isEmpty) continue;
        if (!candidates.contains(part)) {
          candidates.add(part);
        }
      }
    }

    debugPrint('[LocationLookup] Built candidates: $candidates (from raw values: '
        'name=$name, locality=$locality, subLocality=$subLocality, '
        'thoroughfare=$thoroughfare, subThoroughfare=$subThoroughfare)');

    return candidates;
  }

  /// Attempts to match [searchText] against the dataset using multiple strategies.
  ///
  /// Returns the best [`LocationLookupResult`] across all candidates, or `null`
  /// if no match is found.
  static Future<LocationLookupResult?> lookup({
    required String? name,
    required String? locality,
    required String? subLocality,
    required String? thoroughfare,
    String? subThoroughfare,
  }) async {
    final candidates = _buildCandidates(
      name: name,
      locality: locality,
      subLocality: subLocality,
      thoroughfare: thoroughfare,
      subThoroughfare: subThoroughfare,
    );

    if (candidates.isEmpty) {
      debugPrint('[LocationLookup] No candidates from geocoding response');
      return null;
    }

    final districts = await _loadDistricts();
    debugPrint('[LocationLookup] Loaded ${districts.length} districts, '
        'candidates: $candidates');

    LocationLookupResult? bestResult;
    int bestScore = -1;

    // Try each candidate against each matching strategy, keeping the best score.
    for (final candidate in candidates) {
      final lowerCandidate = candidate.toLowerCase();
      final result = _searchInDataset(
        districts,
        candidate,
        lowerCandidate,
      );
      if (result != null && result.score > bestScore) {
        bestScore = result.score;
        bestResult = result.result;
      }
    }

    if (bestResult != null) {
      debugPrint('[LocationLookup] Match found: $bestResult');
    } else {
      debugPrint('[LocationLookup] No match for any candidate');
    }

    return bestResult;
  }

  /// Searches the full dataset for [candidate] (and its lowercase form
  /// [lowerCandidate]) and returns a scored result.
  static _ScoredResult? _searchInDataset(
    List<Map<String, dynamic>> districts,
    String candidate,
    String lowerCandidate,
  ) {
    // Collect all matches for alternative logging
    final allVillageMatches = <String>[];
    final allMandalMatches = <String>[];

    for (final district in districts) {
      final districtName = district['district'] as String? ?? '';
      final subDistricts = district['subDistricts'] as List<dynamic>? ?? [];

      for (final sub in subDistricts) {
        final subMap = Map<String, dynamic>.from(sub);
        final mandalName = subMap['subDistrict'] as String? ?? '';
        final villages = subMap['villages'] as List<dynamic>? ?? [];
        final villageNames =
            villages.map((v) => v.toString()).toList();

        final lowerMandal = mandalName.toLowerCase();

        // ── Village exact match (score 100) ──
        for (final village in villageNames) {
          if (village == candidate) {
            return _ScoredResult(
              LocationLookupResult(
                district: districtName,
                mandal: mandalName,
                village: village,
                matchType: 'village_exact',
              ),
              score: 100,
            );
          }
        }

        // ── Mandal exact match (score 90) ──
        if (mandalName == candidate) {
          return _ScoredResult(
            LocationLookupResult(
              district: districtName,
              mandal: mandalName,
              matchType: 'mandal_exact',
            ),
            score: 90,
          );
        }

        // ── Village case-insensitive exact match (score 85) ──
        for (final village in villageNames) {
          if (village.toLowerCase() == lowerCandidate) {
            allVillageMatches
                .add('$districtName → $mandalName → $village');
          }
        }

        // ── Mandal case-insensitive exact match (score 80) ──
        if (lowerMandal == lowerCandidate) {
          allMandalMatches.add('$districtName → $mandalName');
        }

        // ── Village reverse-contains match (score 75) ──
        // Check if ANY village name is contained WITHIN the candidate.
        // Handles cases like geocoder returning "Rangampeta Village"
        // while the dataset has "Rangampeta".
        for (final village in villageNames) {
          final lowerVillage = village.toLowerCase();
          if (lowerVillage.isNotEmpty &&
              lowerCandidate.contains(lowerVillage) &&
              lowerVillage.length >= 3) {
            // Filter: need at least 3 chars to avoid trivial matches like "a"
            allVillageMatches
                .add('$districtName → $mandalName → $village');
          }
        }

        // ── Village prefix match (score 73) ──
        // Handles cases where candidate is a prefix of a village name.
        for (final village in villageNames) {
          final lowerVillage = village.toLowerCase();
          if (lowerVillage.isNotEmpty &&
              lowerVillage.startsWith(lowerCandidate) &&
              lowerVillage.length >= 3 &&
              lowerCandidate.length >= 3) {
            allVillageMatches
                .add('$districtName → $mandalName → $village');
          }
        }

        // ── Mandal reverse-contains match (score 70) ──
        if (lowerMandal.isNotEmpty &&
            lowerCandidate.contains(lowerMandal) &&
            lowerMandal.length >= 3) {
          allMandalMatches.add('$districtName → $mandalName');
        }

        // ── Mandal prefix match (score 68) ──
        if (lowerMandal.isNotEmpty &&
            lowerMandal.startsWith(lowerCandidate) &&
            lowerMandal.length >= 3 &&
            lowerCandidate.length >= 3) {
          allMandalMatches.add('$districtName → $mandalName');
        }

        // ── Village forward-contains match (score 65) ──
        for (final village in villageNames) {
          final lowerVillage = village.toLowerCase();
          if (lowerVillage.isNotEmpty &&
              lowerVillage.contains(lowerCandidate) &&
              lowerCandidate.length >= 3) {
            allVillageMatches
                .add('$districtName → $mandalName → $village');
          }
        }

        // ── Mandal forward-contains match (score 60) ──
        if (lowerMandal.isNotEmpty &&
            lowerMandal.contains(lowerCandidate) &&
            lowerCandidate.length >= 3) {
          allMandalMatches.add('$districtName → $mandalName');
        }
      }
    }

    // ── Score and select the best among non-exact matches ──

    // Village case-insensitive: score 85
    if (allVillageMatches.isNotEmpty) {
      final seen = <String>{};
      final unique = <String>[];
      for (final m in allVillageMatches) {
        if (seen.add(m)) unique.add(m);
      }

      final parts = unique.first.split(' → ');
      return _ScoredResult(
        LocationLookupResult(
          district: parts[0],
          mandal: parts[1],
          village: parts[2],
          matchType: unique.length == 1 ? 'village_fuzzy' : 'village_fuzzy',
          alternatives: unique.length > 1 ? unique.sublist(1) : [],
        ),
        score: 85,
      );
    }

    // Mandal case-insensitive: score 80 -> dropped down because
    // village reverse-contains (75) and prefix (73) are higher priority.
    if (allMandalMatches.isNotEmpty) {
      final seen = <String>{};
      final unique = <String>[];
      for (final m in allMandalMatches) {
        if (seen.add(m)) unique.add(m);
      }

      final parts = unique.first.split(' → ');
      return _ScoredResult(
        LocationLookupResult(
          district: parts[0],
          mandal: parts[1],
          matchType: 'mandal_fuzzy',
          alternatives: unique.length > 1 ? unique.sublist(1) : [],
        ),
        score: 80,
      );
    }

    return null;
  }
}

/// Internal helper to pair a result with its match score.
class _ScoredResult {
  final LocationLookupResult result;
  final int score;
  _ScoredResult(this.result, {required this.score});
}
