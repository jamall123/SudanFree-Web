import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

// New specialized services
import 'firestore/user_service.dart';
import 'firestore/post_service.dart';
import 'firestore/job_service.dart';
import 'firestore/chat_service.dart';
import 'firestore/notification_service.dart';
import 'firestore/payment_service.dart';
import 'firestore/report_service.dart';
import 'firestore/app_service.dart';
import 'firestore/request_service.dart';
import 'firestore/portfolio_service.dart';
import 'firestore/story_service.dart';
import 'firestore/review_service.dart';
import '../models/portfolio_project_model.dart';
import '../models/story_model.dart';
import '../models/review_model.dart';

// Models
import '../models/job_model.dart';
import '../models/proposal_model.dart';
import '../models/message_model.dart';
import '../models/offer_model.dart';
import '../models/payment_model.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/notification_model.dart';
import '../models/comment_model.dart';
import '../models/report_model.dart';
import '../models/request_model.dart';
import '../models/contact_log_model.dart';

/// Facade for all Firestore operations.
/// This class delegates to specialized services for better maintainability.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Service Instances
  final _users = UserFirestoreService();
  final _posts = PostsFirestoreService();
  final _jobs = JobFirestoreService();
  final _chat = ChatFirestoreService();
  final _notifications = NotificationFirestoreService();
  final _payments = PaymentFirestoreService();
  final _reports = ReportFirestoreService();
  final _app = AppFirestoreService();
  final _requests = RequestFirestoreService();
  final _portfolio = PortfolioFirestoreService();
  final _story = StoryFirestoreService();

  final _reviews = ReviewFirestoreService();

  Future<Map<String, dynamic>> callFunction(
      String name, Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call(data);
    final payload = result.data;
    if (payload is Map<String, dynamic>) return payload;
    return Map<String, dynamic>.from(payload as Map);
  }

  // ==================== STORIES ====================
  Future<String> addStory(StoryModel story) => _story.addStory(story);
  Stream<List<StoryModel>> getActiveStories() => _story.getActiveStories();
  Future<void> addStoryViewer(String storyId, String userId) =>
      _story.addViewer(storyId, userId);
  Future<void> deleteStory(String storyId) => _story.deleteStory(storyId);

  // ==================== PORTFOLIO ====================
  Future<String> addPortfolioProject(PortfolioProjectModel project) =>
      _portfolio.addProject(project);
  Stream<List<PortfolioProjectModel>> getUserPortfolio(String userId) =>
      _portfolio.getUserProjects(userId);
  Future<void> deletePortfolioProject(String userId, String projectId) =>
      _portfolio.deleteProject(userId, projectId);
  Future<void> updatePortfolioProject(
          String userId, String projectId, Map<String, dynamic> data) =>
      _portfolio.updateProject(userId, projectId, data);

  // ==================== USERS ====================
  Future<UserModel?> getUser(String userId) => _users.getUser(userId);
  Stream<UserModel?> getUserStream(String userId) =>
      _users.getUserStream(userId);
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) =>
      _users.updateUserProfile(userId, data);
  Future<void> updateLastActive(String userId) =>
      _users.updateLastActive(userId);
  Future<void> sendPartnerRequest(
          String requesterId, String requesterName, String targetId) =>
      _users.sendPartnerRequest(requesterId, requesterName, targetId);
  Future<void> handlePartnerRequest(String userId, String responderName,
          String requesterId, bool accept) =>
      _users.handlePartnerRequest(userId, responderName, requesterId, accept);
  Future<void> removePartner(String userId, String targetId) =>
      _users.removePartner(userId, targetId);
  Future<List<UserModel>> getUsersByIds(List<String> ids) =>
      _users.getUsersByIds(ids);
  Future<List<UserModel>> getUsersForMap() => _users.getUsersForMap();
  Future<List<UserModel>> getUsersInMapBounds(
          double minLat, double maxLat, double minLng, double maxLng) =>
      _users.getUsersInMapBounds(minLat, maxLat, minLng, maxLng);
  Future<void> toggleFollow(
          String followerId, String targetId, bool isFollowing,
          [String? followerName]) =>
      _users.toggleFollow(followerId, targetId, isFollowing, followerName);
  Future<void> toggleBlock(
          String currentUserId, String targetUserId, bool isBlocked) =>
      _users.toggleBlock(currentUserId, targetUserId, isBlocked);
  Future<void> incrementProfileViews(String userId, [String? viewerId]) =>
      _users.incrementProfileViews(userId, viewerId);

  Future<Map<String, dynamic>> getFreelancersPaginated(
          {DocumentSnapshot? startAfterDoc, int limit = 15, String? state}) =>
      _users.getFreelancersPaginated(
          startAfterDoc: startAfterDoc, limit: limit, state: state);

  Future<Map<String, dynamic>> getShopsPaginated(
          {DocumentSnapshot? startAfterDoc, int limit = 15, String? state}) =>
      _users.getShopsPaginated(
          startAfterDoc: startAfterDoc, limit: limit, state: state);

  Future<Map<String, dynamic>> getProvidersPaginated(
          {DocumentSnapshot? startAfterDoc, int limit = 50}) =>
      _users.getProvidersPaginated(startAfterDoc: startAfterDoc, limit: limit);

  // ==================== POSTS ====================
  Future<String> createPost(PostModel post) => _posts.createPost(post);
  Future<PostModel?> getPost(String postId) => _posts.getPost(postId);
  Future<Map<String, dynamic>> getFeedPostsPaginated(
          {DocumentSnapshot? startAfterDoc,
          int limit = 15,
          PostCategoryGroup? categoryGroup}) =>
      _posts.getFeedPostsPaginated(
          startAfterDoc: startAfterDoc,
          limit: limit,
          categoryGroup: categoryGroup);
  Stream<List<PostModel>> getUserPosts(String userId) =>
      _posts.getUserPosts(userId);
  Stream<List<PostModel>> getDashboardUserPosts(String userId) =>
      _posts.getDashboardUserPosts(userId);
  Future<void> reactToPost(String postId, String userId, String reactionType) =>
      _posts.reactToPost(postId, userId, reactionType);
  Future<void> removeReaction(String postId, String userId) =>
      _posts.removeReaction(postId, userId);
  Future<void> deletePost(String postId) => _posts.deletePost(postId);
  Future<void> togglePin(String postId, bool isPinned) =>
      _posts.togglePin(postId, isPinned);
  Future<void> incrementPostShares(String postId) =>
      _posts.incrementPostShares(postId);
  Future<void> incrementPostViews(String postId, [String? viewerId]) =>
      _posts.incrementPostViews(postId, viewerId);
  Future<void> updatePost(String postId, Map<String, dynamic> data) =>
      _firestore
          .collection('posts')
          .doc(postId)
          .update({...data, 'updatedAt': Timestamp.now()});

  Future<void> voteInPoll(String postId, Map<String, dynamic> pollMap) async {
    final docRef = _firestore.collection('posts').doc(postId);
    await docRef.update({'poll': pollMap});
  }

  // ==================== COMMENTS ====================
  Future<void> addComment(CommentModel comment,
          {String? postOwnerId, String? parentUserId}) =>
      _posts.addComment(comment,
          postOwnerId: postOwnerId, parentUserId: parentUserId);
  Stream<List<CommentModel>> getPostComments(String postId, {int limit = 50}) =>
      _posts.getComments(postId);
  Future<void> toggleCommentLike(
          String postId, String commentId, String userId, bool isLiked) =>
      _posts.toggleCommentLike(postId, commentId, userId, isLiked);
  Future<void> deleteComment(String postId, String commentId) =>
      _posts.deleteComment(postId, commentId);

  // ==================== REVIEWS ====================
  Future<String> createReview(ReviewModel review,
          {bool isJobCompleted = false}) =>
      _reviews.createReview(review, isJobCompleted: isJobCompleted);
  Stream<List<ReviewModel>> getFreelancerReviews(String freelancerId) =>
      _reviews.getFreelancerReviews(freelancerId);

  // ==================== JOBS ====================
  Future<String> createJob(JobModel job) => _jobs.createJob(job);
  Future<JobModel?> getJob(String jobId) => _jobs.getJob(jobId);
  Stream<JobModel?> getJobStream(String jobId) => _jobs.getJobStream(jobId);
  Stream<List<JobModel>> getJobs(
          {String? category,
          String? state,
          String? locality,
          String? status,
          int limit = 50}) =>
      _jobs.getJobs(
          category: category,
          state: state,
          locality: locality,
          status: status,
          limit: limit);
  Stream<List<JobModel>> getFreelancerJobs(String freelancerId) =>
      _jobs.getFreelancerJobs(freelancerId);
  Stream<List<JobModel>> getClientJobs(String clientId) =>
      _jobs.getClientJobs(clientId);
  Future<void> updateJob(String jobId, Map<String, dynamic> data) =>
      _jobs.updateJob(jobId, data);
  Future<void> deleteJob(String jobId) => _jobs.deleteJob(jobId);
  Future<void> completeJob(String jobId, String freelancerId) =>
      _jobs.completeJob(jobId, freelancerId);
  Future<void> updateMilestones(
          String jobId, List<MilestoneModel> milestones) =>
      _jobs.updateMilestones(jobId, milestones);
  Future<bool> hasCompletedJob(String clientId, String freelancerId) =>
      _jobs.hasCompletedJob(clientId, freelancerId);

  // ==================== PROPOSALS ====================
  Stream<List<ProposalModel>> getJobProposals(String jobId) =>
      _jobs.getJobProposals(jobId);
  Stream<List<ProposalModel>> getFreelancerProposals(String freelancerId) =>
      _jobs.getFreelancerProposals(freelancerId);
  Future<String> createProposal(ProposalModel proposal) =>
      _jobs.createProposal(proposal);
  Future<void> acceptProposal(ProposalModel proposal) =>
      _jobs.acceptProposal(proposal);
  Future<void> updateProposalStatus(String proposalId, String status) =>
      _jobs.updateProposalStatus(proposalId, status);

  // ==================== OFFERS ====================
  Future<void> createOffer(OfferModel offer) => _jobs.createOffer(offer);
  Stream<List<OfferModel>> getOffers(String requestId) =>
      _jobs.getOffers(requestId);
  Future<int> getUserOfferCount(String requestId, String userId) =>
      _jobs.getUserOfferCount(requestId, userId);

  // ==================== CHAT ====================
  Future<void> sendMessage(MessageModel message) => _chat.sendMessage(message);
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) =>
      _chat.getMessages(chatId);
  Future<ChatModel?> getChatById(String chatId) => _chat.getChatById(chatId);
  Future<void> updateMessage(String messageId, Map<String, dynamic> data,
          {String? chatId}) =>
      _chat.updateMessage(messageId, data, chatId: chatId);
  Future<void> deleteMessage(String messageId, {String? chatId}) =>
      _chat.deleteMessage(messageId, chatId: chatId);
  Stream<List<ChatModel>> getUserChats(String userId) =>
      _chat.getUserChats(userId);
  Future<List<ChatModel>> getUserChatsOnce(String userId) =>
      _chat.getUserChatsOnce(userId);
  Future<ChatModel> getOrCreateChat({
    required String user1Id,
    required String user1Name,
    String? user1ImageUrl,
    required String user2Id,
    required String user2Name,
    String? user2ImageUrl,
    String? jobId,
    String? jobTitle,
  }) =>
      _chat.getOrCreateChat(
        user1Id: user1Id,
        user1Name: user1Name,
        user1ImageUrl: user1ImageUrl,
        user2Id: user2Id,
        user2Name: user2Name,
        user2ImageUrl: user2ImageUrl,
        jobId: jobId,
        jobTitle: jobTitle,
      );
  Future<void> markMessagesAsRead(String chatId, String userId) =>
      _chat.markAsRead(chatId, userId);
  Future<void> updateTypingStatus(
          String chatId, String userId, bool isTyping) =>
      _chat.updateTypingStatus(chatId, userId, isTyping);

  // ==================== NOTIFICATIONS ====================
  Stream<List<NotificationModel>> getNotifications(String userId) =>
      _notifications.getNotifications(userId);
  Stream<int> getUnreadNotificationsCount(String userId) =>
      _notifications.getUnreadNotificationsCount(userId);
  Future<void> sendNotification(NotificationModel notification) =>
      _notifications.addNotification(notification);
  Future<void> markNotificationAsRead(String notifId) => _firestore
      .collection('notifications')
      .doc(notifId)
      .update({'isRead': true});
  Future<void> markAllNotificationsAsRead(String userId) =>
      _notifications.markAllAsRead(userId);
  Future<void> deleteNotification(String notifId) =>
      _notifications.deleteNotification(notifId);

  // ==================== PAYMENTS ====================
  Future<String> createPayment(PaymentModel payment) =>
      _payments.createPayment(payment);
  Future<PaymentModel?> getPayment(String paymentId) =>
      _payments.getPayment(paymentId);
  Stream<List<PaymentModel>> getJobPayments(String jobId) =>
      _payments.getJobPayments(jobId);
  Stream<List<PaymentModel>> getUserPayments(String userId,
          {bool isClient = true}) =>
      _payments.getUserPayments(userId, isClient: isClient);
  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status) =>
      _payments.updatePaymentStatus(paymentId, status);

  // ==================== REPORTS ====================
  Future<void> submitReport(ReportModel report) =>
      _reports.submitReport(report);

  // ==================== APP CONFIG & LOGS ====================
  Future<Map<String, dynamic>> getAppVersionInfo() => _app.getAppVersionInfo();
  Future<String> createContactLog(ContactLogModel log) =>
      _app.createContactLog(log);
  Future<ContactLogModel?> getContactLog(
          String contacterId, String freelancerId) =>
      _app.getContactLog(contacterId, freelancerId);
  Future<bool> hasContactLog(String contacterId, String freelancerId) =>
      _app.hasContactLog(contacterId, freelancerId);
  Future<void> markContactAsReviewed(String logId) =>
      _app.markContactAsReviewed(logId);

  // Legacy / Batch / Special
  Future<void> updateUserProfileImages(
          String userId, String? imageUrl, String? userName) =>
      _users.updateUserProfileImages(userId, imageUrl, userName);

  // Requests
  Future<void> createRequest(RequestModel request) =>
      _requests.createRequest(request);
  Stream<List<RequestModel>> getRequests() => _requests.getGlobalRequests();
  Future<RequestModel?> getRequestById(String requestId) =>
      _requests.getRequest(requestId);
  Future<void> deleteRequest(String requestId) =>
      _requests.deleteRequest(requestId);

  // Cleanup
  Future<void> deleteAllUserData(String userId) =>
      _users.deleteAllUserData(userId);
}
