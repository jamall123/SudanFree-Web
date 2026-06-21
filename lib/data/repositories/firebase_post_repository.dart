import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/notification_model.dart';
import '../../domain/repositories/post_repository.dart';

class FirebasePostRepository implements PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create post
  Future<String> createPost(PostModel post) async {
    final docRef = _firestore.collection('posts').doc();
    final data = post.toFirestore();
    data['id'] = docRef.id;
    await docRef.set(data);
    return docRef.id;
  }

  // Get paginated posts
  Future<Map<String, dynamic>> getFeedPostsPaginated({
    DocumentSnapshot? startAfterDoc,
    int limit = 15,
    PostCategoryGroup? categoryGroup,
  }) async {
    Query query = _firestore
        .collection('posts')
        .where('showInCommunity', isEqualTo: true);

    if (categoryGroup != null) {
      final groupCats = PostCategory.getCategoriesForGroup(categoryGroup);
      final Set<String> categoriesSet = groupCats.map((c) => c.name).toSet();

      // Support legacy posts that saved the group name
      categoriesSet.add(categoryGroup.name);
      categoriesSet.add(categoryGroup.getName('ar'));
      categoriesSet.add(categoryGroup.getName('en'));

      // Support legacy localized subcategory names
      for (final cat in groupCats) {
        categoriesSet.add(cat.getName('ar'));
        categoriesSet.add(cat.getName('en'));
      }

      // Firestore whereIn has a strict limit of 30 items
      final categories = categoriesSet.take(30).toList();

      query = query.where('category', whereIn: categories);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.get();
    final posts = snapshot.docs
        .map((doc) {
          try {
            return PostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing post ${doc.id}: $e');
            return null;
          }
        })
        .whereType<PostModel>()
        .toList();

    return {
      'posts': posts,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      'hasMore': snapshot.docs.length == limit,
    };
  }

  // Get user posts
  Stream<List<PostModel>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs
          .map((doc) {
            try {
              return PostModel.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .whereType<PostModel>()
          .where((post) => post.showInProfile)
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  // Get user posts including hidden ones (for dashboard)
  Stream<List<PostModel>> getDashboardUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs
          .map((doc) {
            try {
              return PostModel.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .whereType<PostModel>()
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromFirestore(doc);
  }

  // React to post
  Future<void> reactToPost(
      String postId, String userId, String reactionType) async {
    await _firestore.collection('posts').doc(postId).update({
      'reactions.$userId': reactionType,
    });
  }

  // Remove reaction
  Future<void> removeReaction(String postId, String userId) async {
    await _firestore.collection('posts').doc(postId).update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  // Toggle Pin
  Future<void> togglePin(String postId, bool isPinned) async {
    await _firestore.collection('posts').doc(postId).update({
      'isPinned': isPinned,
    });
  }

  // Increment Shares
  Future<void> incrementPostShares(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  // Increment Post Views with rate limiting
  Future<void> incrementPostViews(String postId, [String? viewerId]) async {
    if (viewerId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final viewsRef = postRef.collection('views').doc(viewerId);
    final viewsSnap = await viewsRef.get();

    const int rateWindowMinutes = 60;
    final now = Timestamp.now();

    if (viewsSnap.exists) {
      final last = viewsSnap.data()?['lastViewed'] as Timestamp?;
      if (last != null) {
        final diff = now.toDate().difference(last.toDate());
        if (diff.inMinutes < rateWindowMinutes) {
          return;
        }
      }
    }

    await _firestore.runTransaction((tx) async {
      final freshDoc = await tx.get(postRef);
      if (!freshDoc.exists) return;

      tx.update(postRef, {
        'viewsCount': FieldValue.increment(1),
      });

      tx.set(viewsRef, {'lastViewed': now}, SetOptions(merge: true));
    });
  }

  // ==================== COMMENTS ====================

  // Add Comment
  Future<void> addComment(CommentModel comment,
      {String? postOwnerId, String? parentUserId}) async {
    final batch = _firestore.batch();
    final commentRef = _firestore
        .collection('posts')
        .doc(comment.postId)
        .collection('comments')
        .doc();

    final commentWithId = CommentModel(
      id: commentRef.id,
      postId: comment.postId,
      userId: comment.userId,
      userName: comment.userName,
      userImageUrl: comment.userImageUrl,
      content: comment.content,
      createdAt: comment.createdAt,
      parentId: comment.parentId,
      parentUserName: comment.parentUserName,
      isReply: comment.isReply,
      mentionedNames: comment.mentionedNames,
    );

    batch.set(commentRef, commentWithId.toFirestore());
    batch.update(_firestore.collection('posts').doc(comment.postId), {
      'commentsCount': FieldValue.increment(1),
    });

    // Notify post owner about a new top-level comment
    if (!comment.isReply &&
        postOwnerId != null &&
        postOwnerId != comment.userId) {
      final notifRef = _firestore.collection('notifications').doc();
      final notification = NotificationModel(
        id: notifRef.id,
        userId: postOwnerId,
        type: NotificationType.comment,
        title: 'تعليق جديد',
        message:
            'علق ${comment.userName} على منشورك: "${comment.content.length > 40 ? '${comment.content.substring(0, 40)}...' : comment.content}"',
        createdAt: Timestamp.now(),
        relatedId: comment.postId,
      );
      batch.set(notifRef, notification.toFirestore());
    }

    // Notify the user being replied to
    if (comment.isReply &&
        parentUserId != null &&
        parentUserId != comment.userId) {
      final notifRef = _firestore.collection('notifications').doc();
      final notification = NotificationModel(
        id: notifRef.id,
        userId: parentUserId,
        type: NotificationType.comment, // Can be comment type for replies
        title: 'رد جديد',
        message:
            'رد ${comment.userName} على تعليقك: "${comment.content.length > 40 ? '${comment.content.substring(0, 40)}...' : comment.content}"',
        createdAt: Timestamp.now(),
        relatedId: comment.postId,
      );
      batch.set(notifRef, notification.toFirestore());
    }

    await batch.commit();
  }

  // Get Comments Stream
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromFirestore(doc))
            .toList());
  }

  // Toggle Comment Like
  Future<void> toggleCommentLike(
      String postId, String commentId, String userId, bool isLiked) async {
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    await commentRef.update({
      'likedBy': isLiked
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId])
    });
  }

  // Delete Comment
  Future<void> deleteComment(String postId, String commentId) async {
    final batch = _firestore.batch();
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    batch.delete(commentRef);
    batch.update(_firestore.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }
}
