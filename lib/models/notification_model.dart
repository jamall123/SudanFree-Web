import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  rating,
  message,
  follow,
  mention,
  fraudWarning,
  reviewRequest,
  system,
  offer,
  partnerRequest,
  assignment
}

class NotificationModel {
  final String id;
  final String userId; // Receiver
  final NotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final Timestamp createdAt;
  final Timestamp?
      sendAfter; // For delayed push notifications (e.g. 5 mins delay)
  final String? relatedId; // e.g. reviewId, postId

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.sendAfter,
    this.relatedId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.message,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      sendAfter: data['sendAfter'],
      relatedId: data['relatedId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'isRead': isRead,
      'createdAt': createdAt,
      if (sendAfter != null) 'sendAfter': sendAfter,
      'relatedId': relatedId,
    };
  }
}
