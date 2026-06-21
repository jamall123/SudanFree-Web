import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Navigator observer for automatic screen tracking
  NavigatorObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ==================== SCREEN & NAVIGATION ====================

  // Track page views
  Future<void> logScreenView(
      {required String screenName, String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== AUTH ====================

  // Track login/signup
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  Future<void> logSignUp(String method) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== JOBS & OFFERS ====================

  // Track job/offer actions
  Future<void> logJobCreated(String jobId, String category) async {
    try {
      await _analytics.logEvent(
        name: 'job_created',
        parameters: {
          'job_id': jobId,
          'category': category,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  Future<void> logOfferSubmitted(String jobId, double amount) async {
    try {
      await _analytics.logEvent(
        name: 'offer_submitted',
        parameters: {
          'job_id': jobId,
          'amount': amount,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== SEARCH ====================

  /// Track search queries with result count for search quality analysis
  Future<void> logSearchQuery(String query, int resultCount) async {
    try {
      await _analytics.logEvent(
        name: 'search',
        parameters: {
          'search_term': query,
          'result_count': resultCount,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== PROFILE ====================

  /// Track profile views for engagement metrics
  Future<void> logProfileView(String profileId, String profileRole) async {
    try {
      await _analytics.logEvent(
        name: 'profile_view',
        parameters: {
          'profile_id': profileId,
          'profile_role': profileRole,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== CONTRACTS ====================

  /// Track contract creation for conversion funnel analysis
  Future<void> logContractCreated(String chatId, double? price) async {
    try {
      await _analytics.logEvent(
        name: 'contract_created',
        parameters: {
          'chat_id': chatId,
          if (price != null) 'price': price,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// Track contract acceptance
  Future<void> logContractAccepted(String chatId) async {
    try {
      await _analytics.logEvent(
        name: 'contract_accepted',
        parameters: {'chat_id': chatId},
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== CHAT ====================

  /// Track chat initiation for social engagement metrics
  Future<void> logChatStarted(String targetUserId) async {
    try {
      await _analytics.logEvent(
        name: 'chat_started',
        parameters: {'target_user_id': targetUserId},
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== ADS ====================

  /// Track ad impressions for monetization analytics
  Future<void> logAdImpression(String adId, String adType) async {
    try {
      await _analytics.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_id': adId,
          'ad_type': adType,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// Track ad clicks for CTR analysis
  Future<void> logAdClick(String adId, String adType) async {
    try {
      await _analytics.logEvent(
        name: 'ad_click',
        parameters: {
          'ad_id': adId,
          'ad_type': adType,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== REVIEWS ====================

  /// Track review submissions for quality metrics
  Future<void> logReviewSubmitted(String freelancerId, double rating) async {
    try {
      await _analytics.logEvent(
        name: 'review_submitted',
        parameters: {
          'freelancer_id': freelancerId,
          'rating': rating,
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== POSTS ====================

  /// Track post creation for content engagement
  Future<void> logPostCreated(
      String postId, String? category, bool hasImage) async {
    try {
      await _analytics.logEvent(
        name: 'post_created',
        parameters: {
          'post_id': postId,
          if (category != null) 'category': category,
          'has_image': hasImage.toString(),
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// Track post shares for viral metrics
  Future<void> logPostShared(String postId) async {
    try {
      await _analytics.logShare(
        contentType: 'post',
        itemId: postId,
        method: 'in_app',
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== PARTNER REQUESTS ====================

  /// Track partner request actions
  Future<void> logPartnerRequest(String targetId, String action) async {
    try {
      await _analytics.logEvent(
        name: 'partner_request',
        parameters: {
          'target_id': targetId,
          'action': action, // 'sent', 'accepted', 'rejected'
        },
      );
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ==================== USER PROPERTIES ====================

  // Set user properties
  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// Set multiple user properties at once (role, region, etc.)
  Future<void> setUserProperties({
    required String userId,
    String? role,
    String? region,
    String? jobTitle,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      if (role != null)
        await _analytics.setUserProperty(name: 'user_role', value: role);
      if (region != null)
        await _analytics.setUserProperty(name: 'user_region', value: region);
      if (jobTitle != null)
        await _analytics.setUserProperty(name: 'job_title', value: jobTitle);
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }
}
