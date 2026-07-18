class EnquiryModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String productName;
  final int quantity;
  final String status; // 'pending', 'ordered', 'received', 'completed'
  final DateTime createdAt;
  final String shopId;
  final String? note;

  EnquiryModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.productName,
    required this.quantity,
    this.status = 'pending',
    required this.createdAt,
    required this.shopId,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'productName': productName,
      'quantity': quantity,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'shopId': shopId,
      'note': note,
    };
  }

  factory EnquiryModel.fromMap(Map<String, dynamic> map) {
    return EnquiryModel(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 1,
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      shopId: map['shopId'] ?? 'Shop 1',
      note: map['note'],
    );
  }

  EnquiryModel copyWith({
    String? status,
    String? note,
  }) {
    return EnquiryModel(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      productName: productName,
      quantity: quantity,
      status: status ?? this.status,
      createdAt: createdAt,
      shopId: shopId,
      note: note ?? this.note,
    );
  }
}
