import 'package:cloud_firestore/cloud_firestore.dart';

class DiscountRequestModel {
  final String id;
  final String serviceId;
  final String shopId;
  final String customerName;
  final String mobileModel;
  final String employeeName;
  final double discountAmount;
  final double amountToCollect; // remaining - discountAmount
  final String reason;
  final String status; // 'pending' | 'rejected'
  final DateTime timestamp;

  DiscountRequestModel({
    required this.id,
    required this.serviceId,
    required this.shopId,
    required this.customerName,
    required this.mobileModel,
    required this.employeeName,
    required this.discountAmount,
    required this.amountToCollect,
    required this.reason,
    this.status = 'pending',
    required this.timestamp,
  });

  DiscountRequestModel copyWith({
    String? id,
    String? serviceId,
    String? shopId,
    String? customerName,
    String? mobileModel,
    String? employeeName,
    double? discountAmount,
    double? amountToCollect,
    String? reason,
    String? status,
    DateTime? timestamp,
  }) {
    return DiscountRequestModel(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      shopId: shopId ?? this.shopId,
      customerName: customerName ?? this.customerName,
      mobileModel: mobileModel ?? this.mobileModel,
      employeeName: employeeName ?? this.employeeName,
      discountAmount: discountAmount ?? this.discountAmount,
      amountToCollect: amountToCollect ?? this.amountToCollect,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceId': serviceId,
      'shopId': shopId,
      'customerName': customerName,
      'mobileModel': mobileModel,
      'employeeName': employeeName,
      'discountAmount': discountAmount,
      'amountToCollect': amountToCollect,
      'reason': reason,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory DiscountRequestModel.fromMap(Map<String, dynamic> map) {
    return DiscountRequestModel(
      id: map['id'] ?? '',
      serviceId: map['serviceId'] ?? '',
      shopId: map['shopId'] ?? '',
      customerName: map['customerName'] ?? '',
      mobileModel: map['mobileModel'] ?? '',
      employeeName: map['employeeName'] ?? '',
      discountAmount: (map['discountAmount'] ?? 0.0).toDouble(),
      amountToCollect: (map['amountToCollect'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
