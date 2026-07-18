import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String shopId;
  final String category;
  final double amount;
  final String description;
  final DateTime timestamp;
  final String paymentMode; // 'Cash' or 'Online'

  ExpenseModel({
    required this.id,
    required this.shopId,
    required this.category,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.paymentMode = 'Cash',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'category': category,
      'amount': amount,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'paymentMode': paymentMode,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] ?? '',
      shopId: map['shopId'] ?? 'Shop 1',
      category: map['category'] ?? 'General',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
      paymentMode: map['paymentMode'] ?? 'Cash',
    );
  }
}
