import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import 'database_service.dart';
import 'demo_setup_service.dart';

class AuthService {
  // Simple PIN verification for demo
  Future<UserModel?> verifyOwnerPin(String pin) async {
    if (pin == '1111') {
      return UserModel(
        uid: 'owner_demo',
        email: 'admin@demo.com',
        name: 'Owner Ragul',
        role: 'owner',
      );
    }
    return null;
  }

  // Direct access for employees
  UserModel getEmployeeUser(String shopId) {
    return UserModel(
      uid: 'employee_${shopId.replaceAll(' ', '').toLowerCase()}',
      email: 'staff@${shopId.toLowerCase()}.com',
      name: 'Staff $shopId',
      role: 'employee',
      shopId: shopId,
    );
  }
}
