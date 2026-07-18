import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'utils/app_theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

import 'services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable offline persistence explicitly with unlimited cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Initialize notifications in the background to prevent blocking app startup
  NotificationService().init().catchError((e) {
    debugPrint('Error initializing notifications: $e');
  });

  // TEMPORARY WIPE SCRIPT: Clears sales, services, wastage, replacements, enquiries, and notifications for both shops
  // (Disabled after running once to prevent future data erasure)
  /*
  debugPrint('[DatabaseService] Clearing all transaction/test data for both shops...');
  try {
    await DatabaseService().clearAllTransactionData();
    debugPrint('[DatabaseService] Wiped all transactions, sales, services, enquiries, replacements, and notifications successfully!');
  } catch (e) {
    debugPrint('[DatabaseService] Error during wipe: $e');
  }
  */



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D&H mobiles',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
