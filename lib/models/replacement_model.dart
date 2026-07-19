import 'package:cloud_firestore/cloud_firestore.dart';

class ReplacementModel {
  final String id;
  final String productId;
  final String productName;
  final String employeeName;
  final String shopId;
  final String reason;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;
  final double? costPrice; // Will be set by owner on approval
  final String? saleId; // Optional: Link to the original purchase for warranty
  final bool isService; // To distinguish between sale replacement and service re-repair
  final String? stockProductId; // Optional: Link to a specific product from inventory used for re-repair
  final String customerName; // Permanent record of the customer for auditing
  final int quantity; // Added to support bulk wastage

  // Dealer claim tracking fields
  final String? returnAction; // 'replace', 'refund', 'exchange'
  final String? dealerStatus; // 'collected', 'sent_to_dealer', 'resolved_replaced', 'resolved_refunded', 'dealer_rejected'
  final String? dealerName;
  final String? dealerDocketNo;
  final DateTime? dealerSentDate;
  final DateTime? dealerResolvedDate;
  final String paymentMode; // 'Cash' or 'Online'

  ReplacementModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.employeeName,
    required this.shopId,
    required this.reason,
    required this.status,
    required this.timestamp,
    this.costPrice,
    this.saleId,
    this.isService = false,
    this.stockProductId,
    this.customerName = '',
    this.quantity = 1,
    this.returnAction,
    this.dealerStatus,
    this.dealerName,
    this.dealerDocketNo,
    this.dealerSentDate,
    this.dealerResolvedDate,
    this.paymentMode = 'Stock',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'employeeName': employeeName,
      'shopId': shopId,
      'reason': reason,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'costPrice': costPrice,
      'saleId': saleId,
      'isService': isService,
      'stockProductId': stockProductId,
      'customerName': customerName,
      'quantity': quantity,
      'returnAction': returnAction,
      'dealerStatus': dealerStatus,
      'dealerName': dealerName,
      'dealerDocketNo': dealerDocketNo,
      'dealerSentDate': dealerSentDate != null ? Timestamp.fromDate(dealerSentDate!) : null,
      'dealerResolvedDate': dealerResolvedDate != null ? Timestamp.fromDate(dealerResolvedDate!) : null,
      'paymentMode': paymentMode,
    };
  }

  factory ReplacementModel.fromMap(Map<String, dynamic> map) {
    return ReplacementModel(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      employeeName: map['employeeName'] ?? '',
      shopId: map['shopId'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
      costPrice: map['costPrice']?.toDouble(),
      saleId: map['saleId'],
      isService: map['isService'] ?? false,
      stockProductId: map['stockProductId'],
      customerName: map['customerName'] ?? '',
      quantity: map['quantity'] ?? 1,
      returnAction: map['returnAction'],
      dealerStatus: map['dealerStatus'],
      dealerName: map['dealerName'],
      dealerDocketNo: map['dealerDocketNo'],
      dealerSentDate: map['dealerSentDate'] is Timestamp
          ? (map['dealerSentDate'] as Timestamp).toDate()
          : (map['dealerSentDate'] is String
              ? DateTime.tryParse(map['dealerSentDate'] as String)
              : null),
      dealerResolvedDate: map['dealerResolvedDate'] is Timestamp
          ? (map['dealerResolvedDate'] as Timestamp).toDate()
          : (map['dealerResolvedDate'] is String
              ? DateTime.tryParse(map['dealerResolvedDate'] as String)
              : null),
      paymentMode: map['paymentMode'] ?? 'Stock',
    );
  }
}
