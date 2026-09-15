class Country {
  const Country({
    required this.id,
    required this.isoCode,
    required this.name,
    required this.continent,
  });

  final String id;
  final String isoCode;
  final String name;
  final String continent;

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as String,
      isoCode: json['iso_code'] as String,
      name: json['name'] as String,
      continent: json['continent'] as String,
    );
  }
}
