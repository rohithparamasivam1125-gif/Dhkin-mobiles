class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'owner' or 'employee'
  final String? shopId; // '1' or '2'

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.shopId,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'shopId': shopId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'employee',
      shopId: map['shopId'],
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? shopId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
    );
  }
}
