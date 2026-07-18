class ProductOrderModel {
  final String id;
  final String? orderId;
  final String productName;
  final int quantity;
  final String status; // 'pending', 'ordered', 'completed'
  final DateTime createdAt;
  final DateTime? orderedAt;
  final String shopId;
  final String? note;

  ProductOrderModel({
    required this.id,
    this.orderId,
    required this.productName,
    required this.quantity,
    this.status = 'pending',
    required this.createdAt,
    this.orderedAt,
    required this.shopId,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productName': productName,
      'quantity': quantity,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'orderedAt': orderedAt?.toIso8601String(),
      'shopId': shopId,
      'note': note,
    };
  }

  factory ProductOrderModel.fromMap(Map<String, dynamic> map) {
    return ProductOrderModel(
      id: map['id'] ?? '',
      orderId: map['orderId'],
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 1,
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      orderedAt: map['orderedAt'] != null ? DateTime.tryParse(map['orderedAt']) : null,
      shopId: map['shopId'] ?? 'Shop 1',
      note: map['note'],
    );
  }

  ProductOrderModel copyWith({
    String? orderId,
    String? productName,
    int? quantity,
    String? status,
    DateTime? orderedAt,
    String? note,
  }) {
    return ProductOrderModel(
      id: id,
      orderId: orderId ?? this.orderId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      createdAt: createdAt,
      orderedAt: orderedAt ?? this.orderedAt,
      shopId: shopId,
      note: note ?? this.note,
    );
  }
}
