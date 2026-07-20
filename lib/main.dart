import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/blocked_screen.dart';
import 'utils/app_theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

import 'services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

const int kCurrentVersionCode = 1;
const String kCurrentVersionName = '1.0.0';

void main() async {
  try {
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
  } catch (e, stackTrace) {
    debugPrint('CRITICAL STARTUP ERROR: $e');
    debugPrint(stackTrace.toString());
  }

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
      builder: (context, child) {
        return AppStatusWrapper(child: child!);
      },
    );
  }
}

class AppStatusWrapper extends StatelessWidget {
  final Widget child;
  const AppStatusWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_status')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading app status: ${snapshot.error}');
          return child;
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return child;
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return child;
        }

        final bool isBlocked = data['isBlocked'] ?? false;
        final String blockedMessage = data['blockedMessage'] ??
            'Access suspended. Please contact the developer to resolve payment and restore service.';

        final bool isUnderMaintenance = data['isUnderMaintenance'] ?? false;
        final String maintenanceMessage = data['maintenanceMessage'] ??
            'D&H Mobiles is currently undergoing scheduled maintenance. Please check back later.';

        final int minVersionCode = data['minVersionCode'] ?? 1;
        final String minVersionName = data['minVersionName'] ?? '1.0.0';
        final String updateUrl = data['updateUrl'] ?? 'https://example.com/update';

        // 1. Check if the app version is outdated
        if (kCurrentVersionCode < minVersionCode) {
          return BlockedScreen(
            title: 'UPDATE REQUIRED',
            message: 'Your installed app version ($kCurrentVersionName) is no longer supported.\n\nPlease install the latest version ($minVersionName) to continue.',
            icon: Icons.system_update_alt,
            color: Colors.blue.shade400,
            actionButtonText: 'Download Update',
            onActionButtonPressed: () async {
              try {
                final uri = Uri.parse(updateUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('Could not launch update URL: $updateUrl');
                }
              } catch (e) {
                debugPrint('Error launching update URL: $e');
              }
            },
          );
        }

        if (isBlocked) {
          return BlockedScreen(
            title: 'ACCESS SUSPENDED',
            message: blockedMessage,
            icon: Icons.block,
            color: Colors.red.shade400,
          );
        }

        if (isUnderMaintenance) {
          return BlockedScreen(
            title: 'UNDER MAINTENANCE',
            message: maintenanceMessage,
            icon: Icons.construction,
            color: Colors.orange.shade400,
          );
        }

        return child;
      },
    );
  }
}
