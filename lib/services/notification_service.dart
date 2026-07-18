import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';


// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Listener subscription to close when not needed
  StreamSubscription? _notifSubscription;

  Future<void> init() async {
    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // 2. Initialize Local Notifications (for Foreground/Background Alerts)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(initializationSettings);
    
    // Create Android High Importance Channel
    await _createNotificationChannel();

    // 3. Initialize OneSignal (for Free Background Push)
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("34a90b51-5593-438d-8372-42299c97e4f0");
    OneSignal.Notifications.requestPermission(true);

    // 4. Register External User ID (Owner's UID) for targeting
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      OneSignal.login(user.uid);
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important shop alerts.', // description
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Real-time listener for Spark (Free) plan
  void startListeningToNotifications(List<String> shopIds) {
    if (_notifSubscription != null) return; // Already listening
    if (shopIds.isEmpty) return;

    debugPrint('Starting Firestore notification listener for shops: $shopIds');
    
    // Only listen for notifications created AFTER the app was opened (with 1 min buffer for clock drift)
    final DateTime startTime = DateTime.now().subtract(const Duration(minutes: 1));

    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startTime))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp?;
          final shopId = data['shopId'] as String?;
          
          if (timestamp != null && 
              timestamp.toDate().isAfter(startTime) && 
              shopId != null && 
              shopIds.contains(shopId)) {
            _showLocalNotification(
              data['title'] ?? 'New Notification',
              data['body'] ?? '',
            );
          }
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to notifications: $error');
    });
  }

  void stopListening() {
    _notifSubscription?.cancel();
    _notifSubscription = null;
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> saveTokenToFirestore() async {
    String? token = await _fcm.getToken();
    User? user = FirebaseAuth.instance.currentUser;

    if (token != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token saved to Firestore');
      
      // Also register with OneSignal
      OneSignal.login(user.uid);
    }
  }

  // Send a push notification via OneSignal REST API (No Blaze required)
  Future<void> sendOneSignalNotification(String title, String body) async {
    const String appId = "34a90b51-5593-438d-8372-42299c97e4f0";
    const String apiKey = "qxhvdqq5zuirvcvda2jyv6i1h";

    try {
      // Fetch all owner UIDs from Firestore to target them specifically
      final ownersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'owner')
          .get();
      
      List<String> ownerUids = ownersSnapshot.docs
          .map((doc) => doc.id)
          .toList();

      if (ownerUids.isEmpty) {
        debugPrint('No owner UIDs found to notify.');
        return;
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $apiKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'headings': {'en': title},
          'contents': {'en': body},
          // Target owners directly by their UIDs
          'include_external_user_ids': ownerUids,
          // Optimization: High priority for background delivery
          'priority': 10,
          'android_channel_id': 'high_importance_channel',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('OneSignal notification sent successfully to ${ownerUids.length} owners');
      } else {
        debugPrint('Failed to send OneSignal notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending OneSignal notification: $e');
    }
  }
}
