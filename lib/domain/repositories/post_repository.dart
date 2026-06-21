import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';

abstract class PostRepository {
  Future<String> createPost(PostModel post);

  Future<Map<String, dynamic>> getFeedPostsPaginated({
    DocumentSnapshot? startAfterDoc,
    int limit = 15,
    PostCategoryGroup? categoryGroup,
  });

  Stream<List<PostModel>> getUserPosts(String userId);

  Stream<List<PostModel>> getDashboardUserPosts(String userId);

  Future<PostModel?> getPost(String postId);

  Future<void> reactToPost(String postId, String userId, String reactionType);

  Future<void> removeReaction(String postId, String userId);

  Future<void> deletePost(String postId);

  Future<void> togglePin(String postId, bool isPinned);

  Future<void> incrementPostShares(String postId);

  Future<void> incrementPostViews(String postId, [String? viewerId]);

  Future<void> addComment(CommentModel comment,
      {String? postOwnerId, String? parentUserId});

  Stream<List<CommentModel>> getComments(String postId);

  Future<void> toggleCommentLike(
      String postId, String commentId, String userId, bool isLiked);

  Future<void> deleteComment(String postId, String commentId);
}
