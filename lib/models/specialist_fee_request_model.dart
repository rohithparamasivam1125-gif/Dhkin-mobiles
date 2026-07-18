import 'package:cloud_firestore/cloud_firestore.dart';

class SpecialistFeeRequestModel {
  final String id;
  final String serviceId;
  final String customerName;
  final String mobileModel;
  final String shopId;
  final String deliveredBy; // staff name who delivered
  final DateTime timestamp;
  final String status; // 'pending' | 'recorded'

  SpecialistFeeRequestModel({
    required this.id,
    required this.serviceId,
    required this.customerName,
    required this.mobileModel,
    required this.shopId,
    required this.deliveredBy,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceId': serviceId,
      'customerName': customerName,
      'mobileModel': mobileModel,
      'shopId': shopId,
      'deliveredBy': deliveredBy,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory SpecialistFeeRequestModel.fromMap(Map<String, dynamic> map) {
    return SpecialistFeeRequestModel(
      id: map['id'] ?? '',
      serviceId: map['serviceId'] ?? '',
      customerName: map['customerName'] ?? '',
      mobileModel: map['mobileModel'] ?? '',
      shopId: map['shopId'] ?? '',
      deliveredBy: map['deliveredBy'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
      status: map['status'] ?? 'pending',
    );
  }
}
