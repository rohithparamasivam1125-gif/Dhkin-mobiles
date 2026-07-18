class GstSettingsModel {
  final String shopId;
  final String shopName;
  final String gstNumber;
  final String address;
  final String contactNumber;
  final String email;
  final String? logoBase64;
  final double cgstRate; // Editable CGST percentage (e.g. 9.0)
  final double sgstRate; // Editable SGST percentage (e.g. 9.0)
  final String? groupLink; // WhatsApp group invite link
  final double openingDrawerAmount; // Opening cash in drawer before sales start

  GstSettingsModel({
    required this.shopId,
    required this.shopName,
    required this.gstNumber,
    required this.address,
    required this.contactNumber,
    required this.email,
    this.logoBase64,
    required this.cgstRate,
    required this.sgstRate,
    this.groupLink,
    this.openingDrawerAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'gstNumber': gstNumber,
      'address': address,
      'contactNumber': contactNumber,
      'email': email,
      'logoBase64': logoBase64,
      'cgstRate': cgstRate,
      'sgstRate': sgstRate,
      'groupLink': groupLink,
      'openingDrawerAmount': openingDrawerAmount,
    };
  }

  factory GstSettingsModel.fromMap(Map<String, dynamic> map, String shopId) {
    return GstSettingsModel(
      shopId: shopId,
      shopName: map['shopName'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
      address: map['address'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      email: map['email'] ?? '',
      logoBase64: map['logoBase64'],
      cgstRate: (map['cgstRate'] ?? 9.0).toDouble(),
      sgstRate: (map['sgstRate'] ?? 9.0).toDouble(),
      groupLink: map['groupLink'],
      openingDrawerAmount: (map['openingDrawerAmount'] ?? 0.0).toDouble(),
    );
  }
}
