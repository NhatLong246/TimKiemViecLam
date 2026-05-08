class AddressModel {
  final String id;
  final String city;
  final String ward;
  final String street;
  final String number;
  final bool isDefault;
  final double latitude;
  final double longitude;

  AddressModel({
    required this.id,
    required this.city,
    required this.ward,
    required this.street,
    required this.number,
    required this.isDefault,
    required this.latitude,
    required this.longitude,
  });

  factory AddressModel.fromMap(String id, Map<String, dynamic> map) {
    return AddressModel(
      id: id,
      city: map['city'] ?? '',
      ward: map['ward'] ?? '',
      street: map['street'] ?? '',
      number: map['number'] ?? '',
      isDefault: map['isDefault'] ?? false,
      latitude: 0.0,
      longitude: 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'ward': ward,
      'street': street,
      'number': number,
      'isDefault': isDefault,
      'createdAt': DateTime.now(),
    };
  }

  String get fullAddress => '$number, $street, $ward, $city';
}
