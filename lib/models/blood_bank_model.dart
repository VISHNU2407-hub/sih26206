class BloodBank {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String hospitalType;
  final double latitude;
  final double longitude;
  double distanceKm;

  BloodBank({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.hospitalType,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0.0,
  });

  factory BloodBank.fromJson(Map<String, dynamic> json) {
    return BloodBank(
      name: (json['name'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      hospitalType: (json['hospitalType'] as String?)?.trim() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'hospitalType': hospitalType,
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
    };
  }

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  bool get hasPhone => phone.isNotEmpty;
}
