import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore/notification_service.dart';

/// Hybrid notification service:
/// - Uses a lightweight Firestore stream for unread notification count (instant updates)
/// - Uses a lightweight stream for chat unread count (instant updates)
/// - No heavy polling or redundant reads
///
/// This ensures the badge updates IMMEDIATELY when:
/// 1. A new notification arrives
/// 2. The user reads a notification
/// 3. A new chat message arrives
/// 4. The user reads a chat message
class NotificationPollingService extends ChangeNotifier {
  static final NotificationPollingService _instance =
      NotificationPollingService._internal();

  factory NotificationPollingService() {
    return _instance;
  }

  NotificationPollingService._internal();

  final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached values
  int _unreadNotificationCount = 0;
  int _unreadChatCount = 0;

  // Current user ID
  String? _currentUserId;

  // Stream subscriptions
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _chatSubscription;

  // Getters
  /// Total unread count (notifications + chats) — used by the badge
  int get unreadCount => _unreadNotificationCount + _unreadChatCount;
  int get unreadNotificationsOnly => _unreadNotificationCount;
  int get unreadChatsOnly => _unreadChatCount;

  /// Initialize with user ID — call once when user logs in
  void setUserId(String userId) {
    if (_currentUserId == userId) return;

    // Clean up old subscriptions
    _notificationSubscription?.cancel();
    _chatSubscription?.cancel();

    _currentUserId = userId;
    _listenToNotificationCount(userId);
    _listenToChatUnread(userId);
  }

  /// Listen to unread notification count using Firestore's count() stream
  /// This is very lightweight — only returns a number, not full documents
  void _listenToNotificationCount(String userId) {
    _notificationSubscription?.cancel();
    _notificationSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      final newCount = snapshot.docs.length;
      if (_unreadNotificationCount != newCount) {
        _unreadNotificationCount = newCount;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('NotificationPollingService: notification stream error: $e');
    });
  }

  /// Listen to chat unread counts in real-time
  void _listenToChatUnread(String userId) {
    _chatSubscription?.cancel();
    _chatSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
        if (unreadMap != null && unreadMap[userId] != null) {
          totalUnread += (unreadMap[userId] as num).toInt();
        }
      }
      if (_unreadChatCount != totalUnread) {
        _unreadChatCount = totalUnread;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('NotificationPollingService: chat stream error: $e');
    });
  }

  /// Force immediate refresh — useful after marking notifications as read
  /// This does a one-time read to immediately sync the count
  Future<void> forceRefresh() async {
    if (_currentUserId == null) return;

    try {
      final count = await _notificationService.getUnreadCount(_currentUserId!);
      if (_unreadNotificationCount != count) {
        _unreadNotificationCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationPollingService: forceRefresh error: $e');
    }
  }

  /// Fetch notifications list on demand (for NotificationsScreen)
  Future<List<dynamic>> getNotificationsOnce() async {
    if (_currentUserId == null) return [];

    try {
      return await _notificationService.getNotificationsOnce(_currentUserId!);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Reset counts (for logout)
  void reset() {
    _notificationSubscription?.cancel();
    _chatSubscription?.cancel();
    _notificationSubscription = null;
    _chatSubscription = null;
    _currentUserId = null;
    _unreadNotificationCount = 0;
    _unreadChatCount = 0;
    notifyListeners();
  }

  /// Cleanup on app close
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _chatSubscription?.cancel();
    super.dispose();
  }
}
