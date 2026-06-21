import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../services/firestore_service.dart';
import '../views/chat/chat_screen.dart';
import '../views/posts/post_details_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/profile/freelancer_profile_screen.dart';
import '../views/profile/shop_profile_screen.dart';
import '../views/requests/request_details_screen.dart';
import '../views/jobs/active_job_tracking_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:universal_io/io.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications
  Future<void> initialize() async {
    // 1. Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // 2. Setup Local Notifications (for Foreground)
    const androidInit = AndroidInitializationSettings('sudan1');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
        if (details.payload != null) {
          try {
            // Simple payload format: "type:relatedId"
            final parts = details.payload!.split(':');
            if (parts.length >= 2) {
              final type = parts[0];
              final relatedId = parts.sublist(1).join(':');
              _navigateBasedOnData({'type': type, 'relatedId': relatedId});
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // 3. Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Foreground message received: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 4. Handle background messages (when app is opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

    // 5. Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageNavigation(initialMessage);
    }

    // 6. Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token Refreshed: $newToken');
      // Token update logic is usually handled in AuthProvider/UserService
    });

    // 7. Subscribe to global announcements topic
    try {
      await subscribeToTopic('all_users');
      debugPrint('Successfully subscribed to all_users topic');
    } catch (e) {
      debugPrint('Failed to subscribe to all_users topic: $e');
    }
  }

  // Get FCM token
  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) return null;
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      final isChat = data['type'] == 'chat_message';

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isChat ? 'sudan_free_chat_channel' : 'sudan_free_channel',
            isChat ? 'الدردشة والرسائل' : 'SudanFree Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'sudan1',
            channelDescription: isChat
                ? 'إشعارات الرسائل والدردشة الخاصة'
                : 'الإشعارات العامة للتطبيق',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleMessageNavigation(RemoteMessage message) {
    debugPrint('Notification message opened: ${message.notification?.title}');
    _navigateBasedOnData(message.data);
  }

  Future<void> _navigateBasedOnData(Map<String, dynamic> data) async {
    final relatedId = data['relatedId'];
    final type = data['type'];
    if (relatedId == null) return;

    // Use a small delay to ensure navigator key is attached
    await Future.delayed(const Duration(milliseconds: 500));
    final context = SudanFreeApp.navigatorKey.currentContext;
    if (context == null) return;

    final firestore = FirestoreService();

    try {
      if (type == 'message' || type == 'contract') {
        final chat = await firestore.getChatById(relatedId);
        if (chat != null && context.mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
        }
      } else if (type == 'comment' || type == 'like' || type == 'mention') {
        final post = await firestore.getPost(relatedId);
        if (post != null && context.mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post)));
        }
      } else if (type == 'partnerRequest' || type == 'follow') {
        final user = await firestore.getUser(relatedId);
        if (user != null && context.mounted) {
          if (user.isFreelancer) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FreelancerProfileScreen(user: user, isMe: false)));
          } else if (user.isShop) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ShopProfileScreen(user: user, isMe: false)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: user.id)));
          }
        }
      } else if (type == 'offer') {
        final req = await firestore.getRequestById(relatedId);
        if (req != null && context.mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RequestDetailsScreen(request: req)));
        }
      } else if (type == 'system' || type == 'assignment') {
        // Try user first, if not found, try job
        final user = await firestore.getUser(relatedId);
        if (user != null && context.mounted) {
          if (user.isFreelancer) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FreelancerProfileScreen(user: user, isMe: false)));
          } else if (user.isShop) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ShopProfileScreen(user: user, isMe: false)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: user.id)));
          }
        } else {
          final job = await firestore.getJob(relatedId);
          if (job != null && context.mounted) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ActiveJobTrackingScreen(jobId: job.id)));
          }
        }
      }
    } catch (e) {
      debugPrint('Navigation error from notification: $e');
    }
  }

  /// Show a local push notification immediately (for in-app events like likes, comments, mentions)
  Future<void> showLocalPush({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sudan_free_interactions',
            'التفاعلات',
            channelDescription: 'إشعارات التفاعلات مثل الإعجابات والتعليقات',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'sudan1',
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local push: $e');
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
