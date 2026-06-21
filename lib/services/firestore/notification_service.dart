import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/notification_model.dart';

class NotificationFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream notifications
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  // Stream unread count
  Stream<int> getUnreadNotificationsCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Add Notification
  Future<void> addNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .add(notification.toFirestore());
  }

  // Delete Notification
  Future<void> deleteNotification(String notifId) async {
    await _firestore.collection('notifications').doc(notifId).delete();
  }

  // Get unread count as single read (for polling service) instead of stream
  // Reduces reads from 60/min to 1/min when used with polling
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // Get notifications as single read (for polling) instead of stream
  Future<List<NotificationModel>> getNotificationsOnce(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromFirestore(doc))
        .toList();
  }
}
