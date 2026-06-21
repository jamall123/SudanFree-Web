import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String content;
  final DateTime createdAt;
  final String? parentId; // For replies
  final String? parentUserName; // Optional: for "@User" display
  final bool isReply;
  final List<String> likedBy; // User IDs who liked this comment
  final List<String> mentionedNames; // Full names mentioned with @

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.parentUserName,
    this.isReply = false,
    this.likedBy = const [],
    this.mentionedNames = const [],
  });

  int get likesCount => likedBy.length;

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userImageUrl: data['userImageUrl'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentId: data['parentId'],
      parentUserName: data['parentUserName'],
      isReply: data['isReply'] ?? false,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      mentionedNames: List<String>.from(data['mentionedNames'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentId': parentId,
      'parentUserName': parentUserName,
      'isReply': isReply,
      'likedBy': likedBy,
      'mentionedNames': mentionedNames,
    };
  }
}
