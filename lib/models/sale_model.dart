import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String productId;
  final String productName;
  final String category;
  final int quantity;
  final double price;     // Selling price per unit at time of sale
  final double costPrice; // Purchase/cost price per unit at time of sale
  final bool hasWarranty;
  final int warrantyPeriod;
  final String warrantyType;

  CartItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.price,
    this.costPrice = 0.0,
    this.hasWarranty = false,
    this.warrantyPeriod = 0,
    this.warrantyType = 'Months',
  });

  CartItem copyWith({
    String? productId,
    String? productName,
    String? category,
    int? quantity,
    double? price,
    double? costPrice,
    bool? hasWarranty,
    int? warrantyPeriod,
    String? warrantyType,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      warrantyPeriod: warrantyPeriod ?? this.warrantyPeriod,
      warrantyType: warrantyType ?? this.warrantyType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'category': category,
      'quantity': quantity,
      'price': price,
      'costPrice': costPrice,
      'hasWarranty': hasWarranty,
      'warrantyPeriod': warrantyPeriod,
      'warrantyType': warrantyType,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      category: map['category'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      costPrice: (map['costPrice'] ?? 0.0).toDouble(),
      hasWarranty: map['hasWarranty'] ?? false,
      warrantyPeriod: map['warrantyPeriod'] ?? 0,
      warrantyType: map['warrantyType'] ?? 'Months',
    );
  }
}

class SaleModel {
  final String id;
  final List<CartItem> items;
  final double totalPrice;
  final DateTime timestamp;
  final String employeeId;
  final String shopId;
  final String customerName;
  final String customerNameLower;
  final String customerPhone;
  final bool isGstBill;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final String paymentMode;
  final double cashAmount;
  final double onlineAmount;
  final double exchangeAmount;
  final String? returnedReplacementId;
  final double discountAmount;

  SaleModel({
    required this.id,
    required this.items,
    required this.totalPrice,
    required this.timestamp,
    required this.employeeId,
    required this.shopId,
    required this.customerName,
    required this.customerNameLower,
    required this.customerPhone,
    this.isGstBill = false,
    this.taxableAmount = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.paymentMode = 'Cash',
    this.cashAmount = 0.0,
    this.onlineAmount = 0.0,
    this.exchangeAmount = 0.0,
    this.returnedReplacementId,
    this.discountAmount = 0.0,
  });

  SaleModel copyWith({
    String? id,
    List<CartItem>? items,
    double? totalPrice,
    DateTime? timestamp,
    String? employeeId,
    String? shopId,
    String? customerName,
    String? customerNameLower,
    String? customerPhone,
    bool? isGstBill,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    String? paymentMode,
    double? cashAmount,
    double? onlineAmount,
    double? exchangeAmount,
    String? returnedReplacementId,
    double? discountAmount,
  }) {
    return SaleModel(
      id: id ?? this.id,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      timestamp: timestamp ?? this.timestamp,
      employeeId: employeeId ?? this.employeeId,
      shopId: shopId ?? this.shopId,
      customerName: customerName ?? this.customerName,
      customerNameLower: customerNameLower ?? this.customerNameLower,
      customerPhone: customerPhone ?? this.customerPhone,
      isGstBill: isGstBill ?? this.isGstBill,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      cashAmount: cashAmount ?? this.cashAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      exchangeAmount: exchangeAmount ?? this.exchangeAmount,
      returnedReplacementId: returnedReplacementId ?? this.returnedReplacementId,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'totalPrice': totalPrice,
      'timestamp': Timestamp.fromDate(timestamp),
      'employeeId': employeeId,
      'shopId': shopId,
      'customerName': customerName,
      'customerNameLower': customerNameLower,
      'customerPhone': customerPhone,
      'isGstBill': isGstBill,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'paymentMode': paymentMode,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'exchangeAmount': exchangeAmount,
      'returnedReplacementId': returnedReplacementId,
      'discountAmount': discountAmount,
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    // Handle backwards compatibility for old single-item sales
    List<CartItem> items = [];
    if (map['items'] != null) {
      items = (map['items'] as List).map((i) => CartItem.fromMap(i)).toList();
    } else if (map['productId'] != null) {
      // Convert old format to new format on the fly
      items = [
        CartItem(
          productId: map['productId'],
          productName: map['productName'],
          category: map['category'] ?? '',
          quantity: map['quantity'] ?? 1,
          price: (map['totalPrice'] / (map['quantity'] ?? 1)).toDouble(),
          costPrice: (map['costPrice'] ?? 0.0).toDouble() / (map['quantity'] ?? 1),
        )
      ];
    }

    final double totalP = (map['totalPrice'] ?? 0.0).toDouble();
    final String mode = map['paymentMode'] ?? 'Cash';
    final double cashAmt = (map['cashAmount'] ?? (mode == 'Cash' ? totalP : 0.0)).toDouble();
    final double onlineAmt = (map['onlineAmount'] ?? (mode == 'Online' ? totalP : 0.0)).toDouble();
    final double exchangeAmt = (map['exchangeAmount'] ?? 0.0).toDouble();
    final double discountAmt = (map['discountAmount'] ?? 0.0).toDouble();

    return SaleModel(
      id: map['id'] ?? '',
      items: items,
      totalPrice: totalP,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
      employeeId: map['employeeId'] ?? '',
      shopId: map['shopId'] ?? 'Shop 1',
      customerName: map['customerName'] ?? 'Unknown',
      customerNameLower: map['customerNameLower'] ?? (map['customerName'] ?? 'Unknown').toString().toLowerCase(),
      customerPhone: map['customerPhone'] ?? 'N/A',
      isGstBill: map['isGstBill'] ?? false,
      taxableAmount: (map['taxableAmount'] ?? totalP).toDouble(),
      cgstAmount: (map['cgstAmount'] ?? 0.0).toDouble(),
      sgstAmount: (map['sgstAmount'] ?? 0.0).toDouble(),
      paymentMode: mode,
      cashAmount: cashAmt,
      onlineAmount: onlineAmt,
      exchangeAmount: exchangeAmt,
      returnedReplacementId: map['returnedReplacementId'],
      discountAmount: discountAmt,
    );
  }
}
