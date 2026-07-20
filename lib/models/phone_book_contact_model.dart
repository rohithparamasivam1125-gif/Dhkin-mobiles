import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneBookContact {
  final String id;
  final String name;
  final String phone;
  final String notes;
  final DateTime timestamp;

  PhoneBookContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory PhoneBookContact.fromMap(Map<String, dynamic> map) {
    return PhoneBookContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      notes: map['notes'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : (map['timestamp'] is String
              ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
              : DateTime.now()),
    );
  }

  PhoneBookContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? notes,
    DateTime? timestamp,
  }) {
    return PhoneBookContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
