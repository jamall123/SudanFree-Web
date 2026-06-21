import 'package:cloud_firestore/cloud_firestore.dart';

class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String contentUrl;
  final String? caption;
  final DateTime createdAt;
  final bool isVideo;
  final List<String> viewers;

  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.contentUrl,
    this.caption,
    required this.createdAt,
    this.isVideo = false,
    this.viewers = const [],
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'contentUrl': contentUrl,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVideo': isVideo,
      'viewers': viewers,
    };
  }

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImageUrl: data['userImageUrl'],
      contentUrl: data['contentUrl'] ?? '',
      caption: data['caption'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVideo: data['isVideo'] ?? false,
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  bool get isExpired => DateTime.now().difference(createdAt).inHours >= 24;
}
