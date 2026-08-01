class ProductModel {
  final String id;
  final String name;
  final String category;
  final double price;     // Selling price
  final double costPrice; // Purchase / wholesale price
  final int units;
  final String shopId;
  final String location;
  final bool hasWarranty;
  final int warrantyPeriod;
  final String warrantyType; // "Days", "Months", "Years"

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.units,
    required this.shopId,
    this.costPrice = 0.0,
    this.location = '',
    this.hasWarranty = false,
    this.warrantyPeriod = 0,
    this.warrantyType = 'Months',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'costPrice': costPrice,
      'units': units,
      'shopId': shopId,
      'location': location,
      'hasWarranty': hasWarranty,
      'warrantyPeriod': warrantyPeriod,
      'warrantyType': warrantyType,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      units: map['units'] ?? 0,
      shopId: map['shopId'] ?? '1',
      location: map['location'] ?? '',
      hasWarranty: map['hasWarranty'] ?? false,
      warrantyPeriod: map['warrantyPeriod'] ?? 0,
      warrantyType: map['warrantyType'] ?? 'Months',
    );
  }

  ProductModel copyWith({
    String? name,
    double? price,
    double? costPrice,
    int? units,
    String? location,
    bool? hasWarranty,
    int? warrantyPeriod,
    String? warrantyType,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      category: category,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      units: units ?? this.units,
      shopId: shopId,
      location: location ?? this.location,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
      warrantyType: warrantyType ?? this.warrantyType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          shopId == other.shopId;

  @override
  int get hashCode => id.hashCode ^ shopId.hashCode;
}
