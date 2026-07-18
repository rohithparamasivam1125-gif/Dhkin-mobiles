import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerNameLower;
  final String mobileModel;
  final String mobileDetails;
  final double totalAmount;
  final double advanceAmount;
  final double remainingAmount;
  final String status;
  final DateTime timestamp;
  final String shopId;
  final String employeeName;
  final bool isGstBill;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double partsCost;
  final double technicianFee;
  final double reRepairCost;
  final bool isExpenseRecorded;
  final double discountAmount;
  final double cashAmount;
  final double onlineAmount;
  final String partsPaymentMode; // 'Cash' or 'Online'
  final String technicianPaymentMode; // 'Cash' or 'Online'

  ServiceModel({
    required this.id,
    required this.customerName,
    required this.customerNameLower,
    required this.customerPhone,
    required this.mobileModel,
    required this.mobileDetails,
    required this.totalAmount,
    required this.advanceAmount,
    required this.remainingAmount,
    required this.status,
    required this.timestamp,
    required this.shopId,
    required this.employeeName,
    this.isGstBill = false,
    this.taxableAmount = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.partsCost = 0.0,
    this.technicianFee = 0.0,
    this.reRepairCost = 0.0,
    this.isExpenseRecorded = false,
    this.discountAmount = 0.0,
    this.cashAmount = 0.0,
    this.onlineAmount = 0.0,
    this.partsPaymentMode = 'Cash',
    this.technicianPaymentMode = 'Cash',
  });

  ServiceModel copyWith({
    String? id,
    String? customerName,
    String? customerNameLower,
    String? customerPhone,
    String? mobileModel,
    String? mobileDetails,
    double? totalAmount,
    double? advanceAmount,
    double? remainingAmount,
    String? status,
    DateTime? timestamp,
    String? shopId,
    String? employeeName,
    bool? isGstBill,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? partsCost,
    double? technicianFee,
    double? reRepairCost,
    bool? isExpenseRecorded,
    double? discountAmount,
    double? cashAmount,
    double? onlineAmount,
    String? partsPaymentMode,
    String? technicianPaymentMode,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerNameLower: customerNameLower ?? this.customerNameLower,
      customerPhone: customerPhone ?? this.customerPhone,
      mobileModel: mobileModel ?? this.mobileModel,
      mobileDetails: mobileDetails ?? this.mobileDetails,
      totalAmount: totalAmount ?? this.totalAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      shopId: shopId ?? this.shopId,
      employeeName: employeeName ?? this.employeeName,
      isGstBill: isGstBill ?? this.isGstBill,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      partsCost: partsCost ?? this.partsCost,
      technicianFee: technicianFee ?? this.technicianFee,
      reRepairCost: reRepairCost ?? this.reRepairCost,
      isExpenseRecorded: isExpenseRecorded ?? this.isExpenseRecorded,
      discountAmount: discountAmount ?? this.discountAmount,
      cashAmount: cashAmount ?? this.cashAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      partsPaymentMode: partsPaymentMode ?? this.partsPaymentMode,
      technicianPaymentMode: technicianPaymentMode ?? this.technicianPaymentMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'customerNameLower': customerNameLower.toLowerCase(),
      'customerPhone': customerPhone,
      'mobileModel': mobileModel,
      'mobileDetails': mobileDetails,
      'totalAmount': totalAmount,
      'advanceAmount': advanceAmount,
      'remainingAmount': remainingAmount,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'shopId': shopId,
      'employeeName': employeeName,
      'isGstBill': isGstBill,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'partsCost': partsCost,
      'technicianFee': technicianFee,
      'reRepairCost': reRepairCost,
      'isExpenseRecorded': isExpenseRecorded,
      'discountAmount': discountAmount,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'partsPaymentMode': partsPaymentMode,
      'technicianPaymentMode': technicianPaymentMode,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final double totalAmt = (map['totalAmount'] ?? 0.0).toDouble();
    final double advanceAmt = (map['advanceAmount'] ?? 0.0).toDouble();
    return ServiceModel(
      id: map['id'] ?? '',
      customerName: map['customerName'] ?? '',
      customerNameLower: map['customerNameLower'] ?? (map['customerName'] ?? '').toString().toLowerCase(),
      customerPhone: map['customerPhone'] ?? '',
      mobileModel: map['mobileModel'] ?? '',
      mobileDetails: map['mobileDetails'] ?? '',
      totalAmount: totalAmt,
      advanceAmount: advanceAmt,
      remainingAmount: (map['remainingAmount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Pending',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
      shopId: map['shopId'] ?? 'Shop 1',
      employeeName: map['employeeName'] ?? 'Unknown',
      isGstBill: map['isGstBill'] ?? false,
      taxableAmount: (map['taxableAmount'] ?? totalAmt).toDouble(),
      cgstAmount: (map['cgstAmount'] ?? 0.0).toDouble(),
      sgstAmount: (map['sgstAmount'] ?? 0.0).toDouble(),
      partsCost: (map['partsCost'] ?? 0.0).toDouble(),
      technicianFee: (map['technicianFee'] ?? 0.0).toDouble(),
      reRepairCost: (map['reRepairCost'] ?? 0.0).toDouble(),
      isExpenseRecorded: map['isExpenseRecorded'] ?? false,
      discountAmount: (map['discountAmount'] ?? 0.0).toDouble(),
      cashAmount: (map['cashAmount'] ?? advanceAmt).toDouble(),
      onlineAmount: (map['onlineAmount'] ?? 0.0).toDouble(),
      partsPaymentMode: map['partsPaymentMode'] ?? 'Cash',
      technicianPaymentMode: map['technicianPaymentMode'] ?? 'Cash',
    );
  }
}
