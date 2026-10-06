class CompanyLocation {
  const CompanyLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.address,
  });

  factory CompanyLocation.fromJson(Map<String, dynamic> json) {
    double number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.parse(value.toString().replaceAll(',', '.'));
    }

    final radius = json['radiusMeters'] ?? json['radius_meters'];
    return CompanyLocation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Lokasi kantor',
      address: json['address']?.toString(),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      radiusMeters: radius == null ? 100 : number(radius),
    );
  }

  final int id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}
