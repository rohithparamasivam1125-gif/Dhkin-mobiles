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

const int kCurrentVersionCode = 22;
const String kCurrentVersionName = '1.0.3';

// Developer update Build 2 (Features & Bugfixes)
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
    
    // Initialize notifications in the background to prevent blocking app startup pp
    NotificationService().init().catchError((e) {
      debugPrint('Error initializing notifications: $e');
    });
  } catch (e, stackTrace) {
    debugPrint('CRITICAL STARTUP ERROR: $e');
    debugPrint(stackTrace.toString());
  }

  // TEMPORARY RECONSTRUCTION SCRIPT: Clears and rebuilds database up to Test D3 state
  // (Disabled after running once to prevent future erasures)
  /*
  debugPrint('[DatabaseService] Reconstructing test database up to Test D3...');
  try {
    await reconstructTestDatabaseState();
    debugPrint('[DatabaseService] Database reconstructed up to Test D3 successfully!');
  } catch (e) {
    debugPrint('[DatabaseService] Error during reconstruction: $e');
  }
  */

  runApp(const MyApp());
}

Future<void> reconstructTestDatabaseState() async {
  debugPrint('[Reconstruct] Starting database reconstruction...');
  try {
    final db = FirebaseFirestore.instance;

    // 1. Find the active shopId from settings
    final settingsSnap = await db.collection('settings').get();
    String shopId = '';
    for (var doc in settingsSnap.docs) {
      if (doc.id.startsWith('gst_')) {
        shopId = doc.id.replaceFirst('gst_', '');
        break;
      }
    }
    if (shopId.isEmpty) {
      shopId = 'dhkin_mobiles'; // fallback
    }
    debugPrint('[Reconstruct] Found shopId: $shopId');

    // 2. Clear all transaction collections
    final collections = [
      'sales',
      'services',
      'expenses',
      'specialistFeeRequests',
      'replacements',
      'enquiries',
      'notifications',
      'product_orders'
    ];
    for (final col in collections) {
      final snap = await db.collection(col).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
    debugPrint('[Reconstruct] Wiped all transaction collections.');

    // 3. Write GstSettings (Opening Cash: 1000)
    await db.collection('settings').doc('gst_$shopId').set({
      'shopId': shopId,
      'cgstRate': 9.0,
      'sgstRate': 9.0,
      'openingDrawerAmount': 1000.0,
      'groupLink': 'https://chat.whatsapp.com/test',
    });
    debugPrint('[Reconstruct] Wrote GST Settings with opening drawer cash: 1000.0');

    // 4. Write Test Tempered Glass product (Stock: 1 unit)
    await db.collection('products').doc('test_tempered_glass').set({
      'id': 'test_tempered_glass',
      'name': 'Test Tempered Glass',
      'costPrice': 50.0,
      'price': 150.0,
      'units': 1,
      'shopId': shopId,
      'category': 'Tempered Glass',
    });
    debugPrint('[Reconstruct] Wrote test product with remaining stock: 1 unit.');

    // 5. Write Sales
    final sales = [
      {
        'id': 'sale_s1_reconstruct',
        'customerName': 'S1 Cash Customer',
        'customerNameLower': 's1 cash customer',
        'customerPhone': '',
        'totalPrice': 300.0,
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 10))),
        'employeeId': 'Owner',
        'shopId': shopId,
        'isGstBill': false,
        'taxableAmount': 300.0,
        'cgstAmount': 0.0,
        'sgstAmount': 0.0,
        'paymentMode': 'Cash',
        'cashAmount': 300.0,
        'onlineAmount': 0.0,
        'exchangeAmount': 0.0,
        'items': [
          {
            'productId': 'test_tempered_glass',
            'productName': 'Test Tempered Glass',
            'costPrice': 50.0,
            'price': 150.0,
            'quantity': 2,
          }
        ],
      },
      {
        'id': 'sale_s3_reconstruct',
        'customerName': 'S3 Split Customer',
        'customerNameLower': 's3 split customer',
        'customerPhone': '',
        'totalPrice': 150.0,
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 8))),
        'employeeId': 'Owner',
        'shopId': shopId,
        'isGstBill': false,
        'taxableAmount': 150.0,
        'cgstAmount': 0.0,
        'sgstAmount': 0.0,
        'paymentMode': 'Split',
        'cashAmount': 80.0,
        'onlineAmount': 70.0,
        'exchangeAmount': 0.0,
        'items': [
          {
            'productId': 'test_tempered_glass',
            'productName': 'Test Tempered Glass',
            'costPrice': 50.0,
            'price': 150.0,
            'quantity': 1,
          }
        ],
      },
      {
        'id': 'sale_s4_reconstruct',
        'customerName': 'S4 GST Customer',
        'customerNameLower': 's4 gst customer',
        'customerPhone': '',
        'totalPrice': 150.0,
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 6))),
        'employeeId': 'Owner',
        'shopId': shopId,
        'isGstBill': true,
        'taxableAmount': 127.12,
        'cgstAmount': 11.44,
        'sgstAmount': 11.44,
        'paymentMode': 'Cash',
        'cashAmount': 150.0,
        'onlineAmount': 0.0,
        'exchangeAmount': 0.0,
        'items': [
          {
            'productId': 'test_tempered_glass',
            'productName': 'Test Tempered Glass',
            'costPrice': 50.0,
            'price': 150.0,
            'quantity': 1,
          }
        ],
      }
    ];
    for (var sale in sales) {
      await db.collection('sales').doc(sale['id'] as String).set(sale);
    }
    debugPrint('[Reconstruct] Recreated all Sales.');

    // 6. Write Services
    final services = [
      {
        'id': 'service_a',
        'customerName': 'Service A Customer',
        'customerNameLower': 'service a customer',
        'customerPhone': '',
        'mobileModel': 'Model A',
        'mobileDetails': 'Screen replacement A',
        'totalAmount': 400.0,
        'advanceAmount': 400.0, // Updated to 400.0 to reflect Delivered state
        'remainingAmount': 0.0,
        'status': 'Delivered',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 5))),
        'shopId': shopId,
        'employeeName': 'Owner',
        'isGstBill': false,
        'taxableAmount': 400.0,
        'cgstAmount': 0.0,
        'sgstAmount': 0.0,
        'partsCost': 60.0,
        'technicianFee': 40.0,
        'reRepairCost': 0.0,
        'discountAmount': 0.0,
        'isExpenseRecorded': true,
        'cashAmount': 150.0,
        'onlineAmount': 250.0,
        'partsPaymentMode': 'Cash',
        'technicianPaymentMode': 'Cash',
      },
      {
        'id': 'service_b',
        'customerName': 'Service B Customer',
        'customerNameLower': 'service b customer',
        'customerPhone': '',
        'mobileModel': 'Model B',
        'mobileDetails': 'Screen replacement B',
        'totalAmount': 400.0,
        'advanceAmount': 400.0, // Updated to 400.0 to reflect Delivered state
        'remainingAmount': 0.0,
        'status': 'Delivered',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
        'shopId': shopId,
        'employeeName': 'Owner',
        'isGstBill': false,
        'taxableAmount': 400.0,
        'cgstAmount': 0.0,
        'sgstAmount': 0.0,
        'partsCost': 60.0,
        'technicianFee': 40.0,
        'reRepairCost': 0.0,
        'discountAmount': 0.0,
        'isExpenseRecorded': true,
        'cashAmount': 150.0,
        'onlineAmount': 250.0,
        'partsPaymentMode': 'Cash',
        'technicianPaymentMode': 'Cash',
      }
    ];
    for (var service in services) {
      await db.collection('services').doc(service['id'] as String).set(service);
    }
    debugPrint('[Reconstruct] Recreated all Services.');

    // 7. Write Expenses
    final expenses = [
      {
        'id': 'exp_service_a_parts',
        'category': 'Parts Cost',
        'amount': 60.0,
        'paymentMode': 'Cash',
        'description': 'Parts cost for Service A',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 5))),
        'shopId': shopId,
      },
      {
        'id': 'exp_service_a_tech',
        'category': 'Specialist Fee',
        'amount': 40.0,
        'paymentMode': 'Cash',
        'description': 'Specialist Fee for Service A',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 5))),
        'shopId': shopId,
      },
      {
        'id': 'exp_service_b_parts',
        'category': 'Parts Cost',
        'amount': 60.0,
        'paymentMode': 'Cash',
        'description': 'Parts cost for Service B',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
        'shopId': shopId,
      },
      {
        'id': 'exp_service_b_tech',
        'category': 'Specialist Fee',
        'amount': 40.0,
        'paymentMode': 'Cash',
        'description': 'Specialist Fee for Service B',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
        'shopId': shopId,
      },
      {
        'id': 'exp_e1',
        'category': 'General',
        'amount': 80.0,
        'paymentMode': 'Cash',
        'description': 'Shop expense E1',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 3))),
        'shopId': shopId,
      },
      {
        'id': 'exp_e2',
        'category': 'General',
        'amount': 120.0,
        'paymentMode': 'Online',
        'description': 'Shop expense E2',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 3))),
        'shopId': shopId,
      },
      {
        'id': 'exp_w1',
        'category': 'Replacement Loss',
        'amount': 100.0,
        'paymentMode': 'Stock',
        'description': 'Wastage write-off (Test W1)',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
        'shopId': shopId,
      },
      {
        'id': 'exp_w2',
        'category': 'Service Re-Repair Loss',
        'amount': 150.0,
        'paymentMode': 'Cash',
        'description': 'Service re-repair loss (Test W2)',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
        'shopId': shopId,
      },
      {
        'id': 'exp_sv3_gift',
        'category': 'Complementary Gift',
        'amount': 50.0,
        'paymentMode': 'Stock',
        'description': 'Complementary Gift for Service B',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
        'shopId': shopId,
      },
      {
        'id': 'exp_w3_replace',
        'category': 'Replacement Loss',
        'amount': 50.0,
        'paymentMode': 'Stock',
        'description': 'Warranty replacement for S3 (Test W3)',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
        'shopId': shopId,
      },
      {
        'id': 'exp_w3_refund',
        'category': 'Replacement Loss',
        'amount': -50.0,
        'paymentMode': 'Online',
        'description': '[Dealer Refunded] Offset for claim on Test Tempered Glass | Ref: N/A',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 30))),
        'shopId': shopId,
      },
      {
        'id': 'exp_w4_replace',
        'category': 'Replacement Loss',
        'amount': 50.0,
        'paymentMode': 'Stock',
        'description': 'Warranty replacement for S4 (Test W4)',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 45))),
        'shopId': shopId,
      }
    ];
    for (var exp in expenses) {
      await db.collection('expenses').doc(exp['id'] as String).set(exp);
    }
    debugPrint('[Reconstruct] Recreated all Expenses.');

    // 8. Write Replacements
    final replacements = [
      {
        'id': 'replacement_w3',
        'productId': 'test_tempered_glass',
        'productName': 'Test Tempered Glass',
        'employeeName': 'Owner',
        'shopId': shopId,
        'reason': '[Warranty] Defective',
        'status': 'accepted',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
        'costPrice': 50.0,
        'saleId': 'sale_s3_reconstruct',
        'customerName': 'S3 Split Customer',
        'returnAction': 'replace',
        'dealerStatus': 'resolved_refunded',
        'dealerName': 'Test Dealer',
        'dealerDocketNo': '',
        'dealerSentDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 40))),
        'dealerResolvedDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 30))),
      },
      {
        'id': 'replacement_w4',
        'productId': 'test_tempered_glass',
        'productName': 'Test Tempered Glass',
        'employeeName': 'Owner',
        'shopId': shopId,
        'reason': '[Warranty] Defective',
        'status': 'accepted',
        'timestamp': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 45))),
        'costPrice': 50.0,
        'saleId': 'sale_s4_reconstruct',
        'customerName': 'S4 GST Customer',
        'returnAction': 'replace',
        'dealerStatus': 'dealer_rejected',
        'dealerName': 'Test Dealer',
        'dealerDocketNo': '',
        'dealerSentDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 20))),
        'dealerResolvedDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 10))),
      }
    ];
    for (var rep in replacements) {
      await db.collection('replacements').doc(rep['id'] as String).set(rep);
    }
    debugPrint('[Reconstruct] Recreated all Replacements / Dealer Claims.');
    debugPrint('[Reconstruct] DATABASE STATE RECONSTRUCTED SUCCESSFULLY!');
  } catch (e, st) {
    debugPrint('[Reconstruct] ERROR: $e');
    debugPrint(st.toString());
  }
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

        final dynamic rawMinCode = data['minVersionCode'];
        final int minVersionCode = (rawMinCode is int)
            ? rawMinCode
            : (int.tryParse(rawMinCode?.toString() ?? '1') ?? 1);

        // 1. Check if the app version is outdated (INSTANT BLOCK)
        if (kCurrentVersionCode < minVersionCode) {
          return BlockedScreen(
            title: 'UPDATE REQUIRED',
            message: 'Your installed app (Build $kCurrentVersionCode) is no longer supported.\n\nPlease contact the owner for the new app version to continue.',
            icon: Icons.system_update_alt,
            color: Colors.red.shade700,
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
