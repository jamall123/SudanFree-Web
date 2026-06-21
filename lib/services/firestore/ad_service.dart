import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ad_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';

/// Singleton AdService to manage ad fetching, caching, and analytics
/// Uses singleton pattern to share cache across the entire app
class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for ads by category to reduce Firestore reads
  final Map<String, List<AdModel>> _categoryAdCache = {};
  final Map<String, List<AdModel>> _placementAdCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Validate if a category string is valid
  /// Accepts 'all' or 'PostCategoryGroup.{name}' format
  static bool isValidCategory(String category) {
    if (category == 'all') return true;

    // Try to match against PostCategoryGroup names
    for (final group in PostCategoryGroup.values) {
      if ('PostCategoryGroup.${group.name}' == category) {
        return true;
      }
    }
    return false;
  }

  /// Sanitize category string - returns 'all' if invalid
  /// Prevents data corruption from invalid category names
  static String sanitizeCategory(String? category) {
    if (category == null || category.isEmpty) return 'all';
    if (isValidCategory(category)) return category;

    debugPrint('⚠️ Invalid ad category: $category - falling back to "all"');
    return 'all';
  }

  /// Fetches the most relevant ad for a specific placement based on user's region/profession
  Future<AdModel?> getTargetedAd(
    UserModel currentUser, {
    AdPlacement placement = AdPlacement.homeBanner,
    String? targetCategory,
  }) async {
    try {
      // VALIDATE AND SANITIZE TARGET CATEGORY
      final validatedCategory = sanitizeCategory(targetCategory);

      final now = Timestamp.now();

      // Check cache first for category-specific ads
      if (validatedCategory != 'all') {
        final cacheKey = '${placement.name}_$validatedCategory';
        if (_isCacheValid(cacheKey)) {
          final cachedAds = _categoryAdCache[cacheKey];
          if (cachedAds != null && cachedAds.isNotEmpty) {
            // Apply frequency control - avoid showing same ad repeatedly
            final availableAds = _filterByFrequency(cachedAds, currentUser.id);
            if (availableAds.isNotEmpty) {
              availableAds.sort((a, b) => b.priority.compareTo(a.priority));
              return availableAds.first;
            }
          }
        }
      }

      // Query 1: Ads targeted to this user's region AND profession for this placement
      var targetedQuery = _firestore
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .where('placement', isEqualTo: placement.name)
          .where('targetState', isEqualTo: currentUser.state ?? 'all')
          .where('targetRole', isEqualTo: currentUser.role.name)
          .where('expiryDate', isGreaterThan: now)
          .orderBy('expiryDate')
          .limit(10);

      var snap = await targetedQuery.get();

      // If no specific ad, try region-only
      if (snap.docs.isEmpty) {
        var regionQuery = _firestore
            .collection('ads')
            .where('isActive', isEqualTo: true)
            .where('placement', isEqualTo: placement.name)
            .where('targetState', isEqualTo: currentUser.state ?? 'all')
            .where('targetRole', isEqualTo: 'all')
            .where('expiryDate', isGreaterThan: now)
            .orderBy('expiryDate')
            .limit(10);
        snap = await regionQuery.get();
      }

      // If still no ad, get a global ad for this placement
      if (snap.docs.isEmpty) {
        var globalQuery = _firestore
            .collection('ads')
            .where('isActive', isEqualTo: true)
            .where('placement', isEqualTo: placement.name)
            .where('targetState', isEqualTo: 'all')
            .where('targetRole', isEqualTo: 'all')
            .where('expiryDate', isGreaterThan: now)
            .orderBy('expiryDate')
            .limit(10);
        snap = await globalQuery.get();
      }

      // Fallback: any active ad for this placement (ignore targeting)
      if (snap.docs.isEmpty) {
        var fallbackQuery = _firestore
            .collection('ads')
            .where('isActive', isEqualTo: true)
            .where('placement', isEqualTo: placement.name)
            .where('expiryDate', isGreaterThan: now)
            .orderBy('expiryDate')
            .limit(10);
        snap = await fallbackQuery.get();
      }

      // Legacy fallback: any active ad without placement field (old ads)
      if (snap.docs.isEmpty) {
        var legacyQuery = _firestore
            .collection('ads')
            .where('isActive', isEqualTo: true)
            .where('expiryDate', isGreaterThan: now)
            .orderBy('expiryDate')
            .limit(3);
        snap = await legacyQuery.get();
      }

      if (snap.docs.isNotEmpty) {
        final ads = snap.docs.map((d) => AdModel.fromFirestore(d)).toList();

        // Local filtering by category
        if (targetCategory != null) {
          // If a category is selected in the feed, find ads that match it, OR ads meant for "all" categories
          final categoryAds = ads
              .where((ad) =>
                  ad.targetCategory == targetCategory ||
                  ad.targetCategory == 'all')
              .toList();

          if (categoryAds.isNotEmpty) {
            // Cache the results
            final cacheKey = '${placement.name}_$targetCategory';
            _categoryAdCache[cacheKey] = categoryAds;
            _cacheTimestamps[cacheKey] = DateTime.now();

            // Apply frequency control
            final availableAds =
                _filterByFrequency(categoryAds, currentUser.id);
            if (availableAds.isNotEmpty) {
              availableAds.sort((a, b) => b.priority.compareTo(a.priority));
              return availableAds.first;
            }
          }
        }

        ads.sort((a, b) => b.priority.compareTo(a.priority));
        return ads.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching ad: $e');
      return null;
    }
  }

  /// Fetch multiple ads for a placement (e.g., carousel on home)
  Future<List<AdModel>> getAdsForPlacement(
      UserModel currentUser, AdPlacement placement,
      {int limit = 5}) async {
    try {
      final cacheKey = 'placement_${placement.name}';
      if (_isCacheValid(cacheKey)) {
        final cachedAds = _placementAdCache[cacheKey];
        if (cachedAds != null && cachedAds.isNotEmpty) {
          return _filterByFrequency(cachedAds, currentUser.id);
        }
      }

      final now = Timestamp.now();

      final snap = await _firestore
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .where('placement', isEqualTo: placement.name)
          .where('expiryDate', isGreaterThan: now)
          .orderBy('expiryDate')
          .limit(limit)
          .get();

      if (snap.docs.isEmpty) return [];

      final ads = snap.docs.map((d) => AdModel.fromFirestore(d)).toList();
      ads.sort((a, b) => b.priority.compareTo(a.priority));

      _placementAdCache[cacheKey] = ads;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Apply frequency control for multiple ads
      return _filterByFrequency(ads, currentUser.id);
    } catch (e) {
      debugPrint('Error fetching ads for placement: $e');
      return [];
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// Filter ads based on frequency control to avoid showing the same ad repeatedly
  List<AdModel> _filterByFrequency(List<AdModel> ads, String userId) {
    // For now, simple implementation: limit to showing each ad max 3 times per session
    // In production, this could be stored in SharedPreferences or backend
    final shownAds = <String, int>{};

    return ads.where((ad) {
      final count = shownAds[ad.id] ?? 0;
      if (count >= 3) return false;
      shownAds[ad.id] = count + 1;
      return true;
    }).toList();
  }

  /// Clear ad cache (call when user changes location or after long periods)
  void clearAdCache() {
    _categoryAdCache.clear();
    _placementAdCache.clear();
    _cacheTimestamps.clear();
  }

  /// Record an ad impression
  Future<void> recordImpression(String adId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedAds = prefs.getStringList('viewed_ads') ?? [];

      if (viewedAds.contains(adId)) return;
      viewedAds.add(adId);
      await prefs.setStringList('viewed_ads', viewedAds);

      await _firestore.collection('ads').doc(adId).update({
        'impressions': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error recording impression: $e');
    }
  }

  /// Record an ad click
  Future<void> recordClick(String adId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clickedAds = prefs.getStringList('clicked_ads') ?? [];

      if (clickedAds.contains(adId)) return;
      clickedAds.add(adId);
      await prefs.setStringList('clicked_ads', clickedAds);

      await _firestore.collection('ads').doc(adId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error recording click: $e');
    }
  }
}
