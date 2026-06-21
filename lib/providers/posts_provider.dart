import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/network_service.dart';

class PostsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService();
  final AnalyticsService _analytics = AnalyticsService();

  List<PostModel> _posts = [];
  StreamSubscription? _postsSubscription;
  bool _isLoading = false; // for feed loading only
  bool _isCreating = false; // for createPost
  bool _isUpdating = false; // for updatePost/deletePost
  String? _errorMessage;

  // Pagination & New Posts State
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _hasNewPosts = false;
  StreamSubscription? _newPostsSubscription;

  // Caching
  bool _postsLoaded = false;

  // Rate Limiting: prevent flooding notifications
  // Key: "${postId}_${notifType}" → last sent time
  final Map<String, DateTime> _notifCooldown = {};
  static const Duration _notifCooldownDuration = Duration(minutes: 5);

  bool _canSendNotif(String key) {
    final last = _notifCooldown[key];
    if (last == null) return true;
    return DateTime.now().difference(last) > _notifCooldownDuration;
  }

  void _markNotifSent(String key) {
    _notifCooldown[key] = DateTime.now();
  }

  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get hasPosts => _posts.isNotEmpty;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNewPosts => _hasNewPosts;

  /// Returns up to 5 trending posts (last 7 days, sorted by engagement)
  List<PostModel> get trendingPosts {
    if (_posts.isEmpty) return [];
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recent =
        _posts.where((p) => p.createdAt.isAfter(sevenDaysAgo)).toList();

    // Engagement Score = (Reactions * 2) + Comments
    recent.sort((a, b) {
      final scoreA = (a.reactions.length * 2) + a.commentsCount;
      final scoreB = (b.reactions.length * 2) + b.commentsCount;
      return scoreB.compareTo(scoreA); // Descending
    });

    return recent.take(5).toList();
  }

  PostCategoryGroup? _currentCategoryGroup;

  Future<void> fetchPosts(
      {bool forceRefresh = false, PostCategoryGroup? categoryGroup}) async {
    final bool isChangingCategory = _currentCategoryGroup != categoryGroup;
    _currentCategoryGroup = categoryGroup;

    if (_posts.isEmpty &&
        !forceRefresh &&
        categoryGroup == null &&
        !isChangingCategory) {
      // Intentionally removed _cacheService.getCachedPosts() to rely purely on Firestore offline persistence
    }

    if (_postsLoaded &&
        !forceRefresh &&
        _posts.isNotEmpty &&
        !isChangingCategory) {
      return;
    }

    if (forceRefresh || _posts.isEmpty || isChangingCategory) {
      _isLoading = true;
      _posts = []; // clear to load new category or full feed
      _lastDoc = null;
      notifyListeners();
    }

    debugPrint('PostsProvider: Fetching paginated posts...');
    try {
      final result = await _firestoreService.getFeedPostsPaginated(
        limit: 15,
        categoryGroup: categoryGroup,
      );

      final fetchedPosts = result['posts'];
      if (fetchedPosts is! List<PostModel>) {
        throw TypeError();
      }

      _posts = fetchedPosts;
      _lastDoc = result['lastDoc'] as DocumentSnapshot?;

      final hasMore = result['hasMore'];
      if (hasMore is! bool) {
        throw TypeError();
      }
      _hasMore = hasMore;

      _hasNewPosts = false;
      _isLoading = false;
      _postsLoaded = true;

      // Intentionally removed _cacheService.cachePosts() to rely purely on Firestore offline persistence

      notifyListeners();
    } catch (e) {
      debugPrint('PostsProvider: Error: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchMorePosts() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _firestoreService.getFeedPostsPaginated(
        startAfterDoc: _lastDoc,
        limit: 15,
        categoryGroup: _currentCategoryGroup,
      );

      final morePosts = result['posts'];
      if (morePosts is! List<PostModel>) {
        throw TypeError();
      }

      if (morePosts.isNotEmpty) {
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniquePosts =
            morePosts.where((p) => !existingIds.contains(p.id)).toList();
        _posts.addAll(uniquePosts);
        _lastDoc = result['lastDoc'] as DocumentSnapshot?;

        final hasMore = result['hasMore'];
        if (hasMore is! bool) {
          throw TypeError();
        }
        _hasMore = hasMore;

        // Intentionally removed _cacheService.cachePosts() to rely purely on Firestore offline persistence
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('PostsProvider: Load More Error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<String?> uploadPostImage(File imageFile, String userId) async {
    return await StorageService().uploadImage(imageFile, folder: 'posts/$userId');
  }

  Future<void> createPostInBackground({
    required String userId,
    required String userName,
    String? userRole,
    String? userJobTitle,
    String? userImageUrl,
    List<File>? imageFiles,
    String? caption,
    String? category,
    List<String>? mentionedUsers,
    bool showInCommunity = true,
    bool showInProfile = true,
    double? price,
    String? linkedProductId,
    String? linkedProductName,
    String? linkedProductImage,
    double? linkedProductPrice,
    PollModel? poll,
  }) async {
    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Optimistic Update (Show in UI instantly)
    final pendingPost = PostModel(
      id: pendingId,
      userId: userId,
      userName: userName,
      userRole: userRole,
      userJobTitle: userJobTitle,
      userImageUrl: userImageUrl,
      imageUrl: imageFiles?.isNotEmpty == true
          ? imageFiles!.first.path
          : null, // local path for preview
      imageUrls: imageFiles?.map((f) => f.path).toList() ??
          [], // local paths for carousel
      caption: caption,
      category: category,
      mentionedUsers: mentionedUsers ?? [],
      showInCommunity: showInCommunity,
      showInProfile: showInProfile,
      createdAt: DateTime.now(),
      price: price,
      linkedProductId: linkedProductId,
      linkedProductName: linkedProductName,
      linkedProductImage: linkedProductImage,
      linkedProductPrice: linkedProductPrice,
      poll: poll,
    );

    _posts.insert(0, pendingPost);
    notifyListeners();

    // 2. Background Upload Loop
    bool success = false;
    while (!success) {
      try {
        if (!NetworkService().isConnected) {
          await Future.delayed(const Duration(seconds: 5));
          continue; // wait and retry
        }

        List<String> imageUrls = [];
        if (imageFiles != null && imageFiles.isNotEmpty) {
          final futures = imageFiles.map((f) => uploadPostImage(f, userId));
          final results = await Future.wait(futures);
          for (final url in results) {
            if (url == null) throw Exception("Upload failed");
            imageUrls.add(url);
          }
        }

        final postToSave = pendingPost.copyWith(
          id: '', // let Firestore generate real ID
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
        );

        await _firestoreService.createPost(postToSave);
        success = true;

        // Remove pending and fetch latest to get real ID
        _posts.removeWhere((p) => p.id == pendingId);
        fetchPosts(forceRefresh: true);
      } catch (e) {
        debugPrint('Background post failed, retrying: $e');
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<bool> createPost({
    required String userId,
    required String userName,
    String? userRole,
    String? userJobTitle,
    String? userImageUrl,
    File? imageFile,
    List<File>? imageFiles,
    String? caption,
    String? category,
    List<String>? mentionedUsers,
    bool showInCommunity = true,
    bool showInProfile = true,
    double? price,
    List<String>? productSizes,
    String? productCondition,
    String? productAgeGroup,
    List<String>? productColors,
    int? quantity,
    bool hasShipping = false,
    String? linkedProductId,
    String? linkedProductName,
    String? linkedProductImage,
    double? linkedProductPrice,
    PollModel? poll,
  }) async {
    try {
      _isCreating = true;
      _errorMessage = null;
      notifyListeners();

      String? imageUrl;
      List<String> imageUrls = [];

      // Support both single imageFile (legacy) and multiple imageFiles
      final filesToUpload = <File>[];
      if (imageFiles != null && imageFiles.isNotEmpty) {
        filesToUpload.addAll(imageFiles);
      } else if (imageFile != null) {
        filesToUpload.add(imageFile);
      }

      if (filesToUpload.isNotEmpty) {
        if (!NetworkService().isConnected) {
          throw Exception("لا يوجد اتصال بالإنترنت، لا يمكن رفع الصورة الآن");
        }
        // Upload all images in parallel
        final futures = filesToUpload.map((f) => uploadPostImage(f, userId));
        final results = await Future.wait(futures);
        for (final url in results) {
          if (url == null) {
            throw Exception("فشل رفع الصورة برجاء التحقق من اتصالك بالإنترنت");
          }
          imageUrls.add(url);
        }
        // Keep first image as imageUrl for backward compatibility
        imageUrl = imageUrls.first;
      }

      final post = PostModel(
        id: '',
        userId: userId,
        userName: userName,
        userRole: userRole,
        userJobTitle: userJobTitle,
        userImageUrl: userImageUrl,
        imageUrl: imageUrl,
        imageUrls: imageUrls,
        caption: caption,
        category: category,
        mentionedUsers: mentionedUsers ?? [],
        showInCommunity: showInCommunity,
        showInProfile: showInProfile,
        price: price,
        productSizes: productSizes ?? [],
        productCondition: productCondition,
        productAgeGroup: productAgeGroup,
        productColors: productColors ?? [],
        quantity: quantity,
        hasShipping: hasShipping,
        linkedProductId: linkedProductId,
        linkedProductName: linkedProductName,
        linkedProductImage: linkedProductImage,
        linkedProductPrice: linkedProductPrice,
        poll: poll,
        createdAt: DateTime.now(),
      );

      final newPostId = await _firestoreService.createPost(post);

      // Notify mentioned users
      if (mentionedUsers != null && mentionedUsers.isNotEmpty) {
        for (final mentionedId in mentionedUsers) {
          final notification = NotificationModel(
            id: '',
            userId: mentionedId,
            type: NotificationType.mention,
            title: 'إشارة جديدة 📢',
            message: 'قام $userName بالإشارة إليك في منشور',
            createdAt: Timestamp.now(),
            relatedId: newPostId,
          );

          await _firestoreService.sendNotification(notification);
        }
      }

      // Notify Followers if it's a Shop (parallel, fire-and-forget)
      if (userRole == 'shop') {
        final userDoc = await _firestoreService.getUser(userId);
        if (userDoc != null && userDoc.followers.isNotEmpty) {
          final futures = userDoc.followers.map((followerId) {
            final notification = NotificationModel(
              id: '',
              userId: followerId,
              type: NotificationType.follow,
              title: 'منتج جديد من $userName 🛍️',
              message: 'قام $userName بإضافة منتج جديد، تفقد المتجر الآن!',
              createdAt: Timestamp.now(),
              relatedId: userId,
            );
            return _firestoreService.sendNotification(notification);
          });
          // Send all notifications in parallel
          Future.wait(futures).catchError((e) {
            debugPrint('PostsProvider: Error notifying followers: $e');
            return <void>[];
          });
        }
      }

      _isCreating = false;
      notifyListeners();

      // Track post creation analytics
      _analytics.logPostCreated(newPostId, category, imageUrl != null);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> addComment({
    required String postId,
    required String postOwnerId,
    required String userId,
    required String userName,
    String? userImageUrl,
    required String content,
    String? parentId,
    String? parentUserName,
    String? parentUserId,
    List<String> mentionedNames = const [],
  }) async {
    final comment = CommentModel(
      id: '',
      postId: postId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
      content: content,
      createdAt: DateTime.now(),
      parentId: parentId,
      parentUserName: parentUserName,
      isReply: parentId != null,
      mentionedNames: mentionedNames,
    );

    // Optimistic Update Locally
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(commentsCount: post.commentsCount + 1);
      notifyListeners();
    }

    await _firestoreService.addComment(comment,
        postOwnerId: postOwnerId, parentUserId: parentUserId);
  }

  /// Optimistic decrement of comment count when deleting a comment
  void decrementCommentCount(String postId) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(
          commentsCount: (post.commentsCount - 1).clamp(0, 999999));
      notifyListeners();
    }
  }

  Future<void> reactToPost(String postId, String userId, String userName,
      String postOwnerId, String reactionType) async {
    // Optimistic Update Locally
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      if (reactionType == 'unlike') {
        post.reactions.remove(userId);
      } else {
        post.reactions[userId] = reactionType;
      }
      // notifyListeners removed to prevent full list rebuild.
      // UI is already optimistically updated via local state in PostCard.
    }

    if (reactionType == 'unlike') {
      await _firestoreService.removeReaction(postId, userId);
    } else {
      await _firestoreService.reactToPost(postId, userId, reactionType);
    }

    // Send notification to post owner (only on like, not unlike) with rate limiting
    if (reactionType != 'unlike' && userId != postOwnerId) {
      final rateLimitKey = '${postId}_like_$userId';
      if (_canSendNotif(rateLimitKey)) {
        _markNotifSent(rateLimitKey);
        final notification = NotificationModel(
          id: '',
          userId: postOwnerId,
          type: NotificationType.like,
          title: 'تفاعل جديد',
          message: 'أعجب $userName بمنشورك',
          createdAt: Timestamp.now(),
          relatedId: postId,
        );
        await _firestoreService.sendNotification(notification);
      }
    }
  }

  Future<void> removeReaction(String postId, String userId) async {
    await _firestoreService.removeReaction(postId, userId);
  }

  Future<void> toggleReaction(String postId, String userId, String userName,
      String reactionType, String postOwnerId, String? currentReaction) async {
    // 1. Check if post exists locally
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final oldReactions = Map<String, String>.from(post.reactions);

    // 2. Optimistic Update (Immediate Feedback)
    if (currentReaction == reactionType) {
      // Remove reaction
      post.reactions.remove(userId);
    } else {
      // Add/Update reaction
      post.reactions[userId] = reactionType;
    }

    // notifyListeners removed to prevent full list rebuild.
    // UI is already optimistically updated via local state in PostCard.

    // 3. Perform Network Request (no extra notifyListeners)
    try {
      if (currentReaction == reactionType) {
        await _firestoreService.removeReaction(postId, userId);
      } else {
        await _firestoreService.reactToPost(postId, userId, reactionType);
        // Send notification to post owner (only on like, not unlike) with rate limiting
        if (userId != postOwnerId) {
          final rateLimitKey = '${postId}_like_$userId';
          if (_canSendNotif(rateLimitKey)) {
            _markNotifSent(rateLimitKey);
            final notification = NotificationModel(
              id: '',
              userId: postOwnerId,
              type: NotificationType.like,
              title: 'تفاعل جديد',
              message: 'أعجب $userName بمنشورك',
              createdAt: Timestamp.now(),
              relatedId: postId,
            );
            _firestoreService.sendNotification(notification); // fire-and-forget
          }
        }
      }
    } catch (e) {
      // 4. Rollback on Error
      post.reactions.clear();
      post.reactions.addAll(oldReactions);
      _errorMessage = 'Failed to update reaction: $e';
      notifyListeners();
    }
  }

  Future<void> voteInPoll(String postId, int optionIndex, String userId) async {
    // 1. Check if post exists locally
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    if (post.poll == null) return;

    // Make a deep copy of the poll options to rollback if needed
    final oldOptions = post.poll!.options
        .map((o) => o.copyWith(voterIds: List.from(o.voterIds)))
        .toList();
    final oldPoll = PollModel(
      question: post.poll!.question,
      options: oldOptions,
      expiresAt: post.poll!.expiresAt,
      isMultipleChoice: post.poll!.isMultipleChoice,
    );

    // 2. Optimistic Update (Immediate Feedback)
    final newOptions = post.poll!.options
        .map((o) => o.copyWith(voterIds: List.from(o.voterIds)))
        .toList();

    // Remove user from all other options if not multiple choice
    if (!post.poll!.isMultipleChoice) {
      for (var option in newOptions) {
        option.voterIds.remove(userId);
      }
    }

    // Add or remove user from the selected option
    final selectedOption = newOptions[optionIndex];
    if (selectedOption.voterIds.contains(userId)) {
      selectedOption.voterIds.remove(userId);
    } else {
      selectedOption.voterIds.add(userId);
    }

    final newPoll = PollModel(
      question: post.poll!.question,
      options: newOptions,
      expiresAt: post.poll!.expiresAt,
      isMultipleChoice: post.poll!.isMultipleChoice,
    );

    _posts[index] = post.copyWith(poll: newPoll);
    notifyListeners();

    // 3. Perform Network Request
    try {
      await _firestoreService.voteInPoll(postId, newPoll.toMap());
    } catch (e) {
      // 4. Rollback on Error
      _posts[index] = post.copyWith(poll: oldPoll);
      _errorMessage = 'Failed to vote: $e';
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      _isUpdating = true;
      notifyListeners();

      await _firestoreService.deletePost(postId);
      _posts.removeWhere((p) => p.id == postId);

      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isUpdating = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePin(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final oldStatus = post.isPinned;

    // Optimistic Update
    _posts[index] = post.copyWith(isPinned: !oldStatus);
    notifyListeners();

    try {
      await _firestoreService.togglePin(postId, !oldStatus);
    } catch (e) {
      // Rollback
      _posts[index] = post.copyWith(isPinned: oldStatus);
      notifyListeners();
      _errorMessage = 'Failed to update pin status: $e';
      notifyListeners();
    }
  }

  Future<bool> updatePost({
    required String postId,
    File? imageFile,
    List<File>? imageFiles,
    String? caption,
    String? category,
    List<String>? mentionedUsers,
    bool? showInCommunity,
    bool? showInProfile,
    double? price,
    List<String>? productSizes,
    String? productCondition,
    String? productAgeGroup,
    List<String>? productColors,
    int? quantity,
    bool? hasShipping,
  }) async {
    try {
      _isUpdating = true;
      notifyListeners();

      final updates = <String, dynamic>{};
      if (caption != null) updates['caption'] = caption;
      if (category != null) updates['category'] = category;
      if (mentionedUsers != null) updates['mentionedUsers'] = mentionedUsers;
      if (showInCommunity != null) updates['showInCommunity'] = showInCommunity;
      if (showInProfile != null) updates['showInProfile'] = showInProfile;
      if (price != null) updates['price'] = price;
      if (productSizes != null) updates['productSizes'] = productSizes;
      if (productCondition != null)
        updates['productCondition'] = productCondition;
      if (productAgeGroup != null) updates['productAgeGroup'] = productAgeGroup;
      if (productColors != null) updates['productColors'] = productColors;
      if (quantity != null) updates['quantity'] = quantity;
      if (hasShipping != null) updates['hasShipping'] = hasShipping;

      // Handle multiple images
      final filesToUpload = <File>[];
      if (imageFiles != null && imageFiles.isNotEmpty) {
        filesToUpload.addAll(imageFiles);
      } else if (imageFile != null) {
        filesToUpload.add(imageFile);
      }

      if (filesToUpload.isNotEmpty) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index == -1) throw Exception("Could not determine post owner for image upload");
        final postUserId = _posts[index].userId;

        final futures = filesToUpload.map((f) => uploadPostImage(f, postUserId));
        final results = await Future.wait(futures);
        final uploadedUrls = <String>[];
        for (final url in results) {
          if (url != null) uploadedUrls.add(url);
        }
        if (uploadedUrls.isNotEmpty) {
          updates['imageUrl'] = uploadedUrls.first;
          updates['imageUrls'] = uploadedUrls;
        }
      }

      await _firestoreService.updatePost(postId, updates);

      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> incrementPostShares(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];

    // Optimistic Update
    _posts[index] = post.copyWith(sharesCount: post.sharesCount + 1);
    notifyListeners();

    try {
      await _firestoreService.incrementPostShares(postId);
      // Track share analytics
      _analytics.logPostShared(postId);
    } catch (e) {
      // Rollback
      _posts[index] = post;
      notifyListeners();
      debugPrint('Error incrementing shares: $e');
    }
  }

  void clear() {
    _postsSubscription?.cancel();
    _newPostsSubscription?.cancel();
    _posts = [];
    _isLoading = false;
    _isCreating = false;
    _isUpdating = false;
    _errorMessage = null;
    _postsLoaded = false;
    _lastDoc = null;
    _hasMore = true;
    _hasNewPosts = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _newPostsSubscription?.cancel();
    super.dispose();
  }
}
