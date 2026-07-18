import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityService {
  static const String _lockTypeKey = 'owner_lock_type';
  static const String _lockSecretKey = 'owner_lock_secret';

  // Default values
  static const String defaultType = 'pin';
  static const String defaultSecret = '1111';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSettings(String type, String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lockTypeKey, type);
    await prefs.setString(_lockSecretKey, secret);

    // Sync to Firestore for persistence across installs
    await _firestore.collection('settings').doc('owner_auth').set({
      'lockType': type,
      'secret': secret,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, String>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try to read from local cache first for instant response
    String? localType = prefs.getString(_lockTypeKey);
    String? localSecret = prefs.getString(_lockSecretKey);

    if (localType != null && localSecret != null) {
      // Sync from Firestore in the background so local cache remains updated on subsequent runs
      _syncSettingsFromFirestoreInBackground();
      return {'type': localType, 'secret': localSecret};
    }

    // 2. Fetch from Firestore if cache is empty
    try {
      final doc = await _firestore.collection('settings').doc('owner_auth').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final type = data['lockType'] as String;
        final secret = data['secret'] as String;
        
        await prefs.setString(_lockTypeKey, type);
        await prefs.setString(_lockSecretKey, secret);
        
        return {'type': type, 'secret': secret};
      }
    } catch (_) {
      // Network offline or error, fallback to default
    }

    // 3. Fallback to default
    return {'type': defaultType, 'secret': defaultSecret};
  }

  // Background helper to fetch from Firestore and update cache without blocking
  void _syncSettingsFromFirestoreInBackground() async {
    try {
      final doc = await _firestore.collection('settings').doc('owner_auth').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final type = data['lockType'] as String;
        final secret = data['secret'] as String;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lockTypeKey, type);
        await prefs.setString(_lockSecretKey, secret);
      }
    } catch (_) {}
  }

  Future<bool> verify(String input) async {
    final settings = await getSettings();
    return settings['secret'] == input;
  }
}
