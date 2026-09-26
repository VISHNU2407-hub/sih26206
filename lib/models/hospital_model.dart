class Hospital {
  final String name;

  /// Original (raw) name from the dataset, preserved for search.
  ///
  /// Many legacy records name the village rather than the facility
  /// (e.g. "Owk"), and [name] may show a generated fallback instead.
  /// Keeping the raw value here lets text search find records by their
  /// original name without changing what is displayed.
  final String searchName;

  final String district;
  final String address;
  final String phone;
  final double latitude;
  final double longitude;
  double distanceKm;

  Hospital({
    required this.name,
    String? searchName,
    required this.district,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0.0,
  }) : searchName = searchName ?? name;

  factory Hospital.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    final address = json['address'] as String? ?? '';
    final district = json['district'] as String? ?? 'Unknown';

    final bool needsFallback = rawName.isEmpty ||
        rawName == 'nan' ||
        rawName == 'Hospital' ||
        rawName == 'Medical Center' ||
        rawName == 'Clinic' ||
        rawName == 'PHC' ||
        rawName == 'CHC' ||
        rawName.length < 5 ||
        _isLikelyVillageName(rawName);

    String displayName = rawName;

    // Check if name is null, empty, generic, or invalid
    if (needsFallback) {
      // Generate better fallback name using address/village/locality
      final locationInfo = _extractLocationInfo(address);
      if (locationInfo.isNotEmpty) {
        // Use different prefixes based on location type
        displayName = _generateFallbackName(locationInfo);
      } else {
        // Last resort: use a generic name with district
        displayName = 'Health Center';
      }
    }

    return Hospital(
      name: displayName,
      // Preserve the raw dataset name for search (never 'nan').
      searchName: (rawName.isEmpty || rawName == 'nan') ? null : rawName,
      district: district,
      address: address == 'nan' ? 'Address not available' : address,
      phone: json['phone'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static bool _isLikelyVillageName(String name) {
    // Common village name patterns - single words without hospital/clinic/medical terms
    final hospitalKeywords = [
      'hospital',
      'clinic',
      'medical',
      'health',
      'care',
      'center',
      'centre',
      'nursing',
      'phc',
      'chc',
    ];
    final lowerName = name.toLowerCase();

    // If it doesn't contain any hospital-related keywords, it's likely a village name
    return !hospitalKeywords.any((keyword) => lowerName.contains(keyword));
  }

  static String _extractLocationInfo(String address) {
    if (address.isEmpty || address == 'nan') return '';

    // Try to extract a meaningful location name from address
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';

    // Priority order: village/locality name > address first part > nearby area name
    // Filter out district names and generic terms
    for (final part in parts) {
      final lowerPart = part.toLowerCase();

      // Skip if it's a district name (contains "district" or is a known district)
      if (lowerPart.contains('district')) continue;

      // Skip generic terms
      if (lowerPart == 'andhra pradesh' ||
          lowerPart == 'ap' ||
          lowerPart == 'india') {
        continue;
      }

      // Return the first meaningful location (village/locality)
      return part;
    }

    return '';
  }

  static String _generateFallbackName(String locationInfo) {
    // Always use PHC prefix with village/locality name
    return 'PHC - $locationInfo';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'district': district,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
    };
  }

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
  bool get hasPhone => phone.isNotEmpty;
}
