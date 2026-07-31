import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_model.dart';

class PendingSaleModel {
  final String id;
  final SaleModel sale;
  final String status; // 'pending' | 'rejected'
  final String reason;
  final DateTime timestamp; // Request time

  PendingSaleModel({
    required this.id,
    required this.sale,
    this.status = 'pending',
    this.reason = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale': sale.toMap(),
      'status': status,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory PendingSaleModel.fromMap(Map<String, dynamic> map) {
    return PendingSaleModel(
      id: map['id'] ?? '',
      sale: SaleModel.fromMap(map['sale'] ?? {}),
      status: map['status'] ?? 'pending',
      reason: map['reason'] ?? '',
      timestamp: map['timestamp'] is Timestamp 
          ? (map['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
