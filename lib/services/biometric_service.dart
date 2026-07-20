import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricEnabledKey = 'owner_biometric_login_enabled';

  /// Check if the device has biometric hardware and if the user has enrolled any biometrics
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      if (!canAuthenticateWithBiometrics || !isDeviceSupported) {
        return false;
      }
      
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Trigger the biometric authentication dialog
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access Owner Dashboard',
        biometricOnly: true,
        persistAcrossBackgrounding: true, // Allows retrying automatically on app resume
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Get the state of biometric login for owner on this device
  Future<bool> isBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Set the state of biometric login for owner on this device
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }
}
