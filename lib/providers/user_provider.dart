import 'package:universal_io/io.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../services/firestore/promotion_service.dart';

import '../services/storage_service.dart';
import '../services/image_compress_service.dart';
import '../services/cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService();
  final PromotionService _promotionService = PromotionService();

  List<String> _promotedUserIds = [];
  List<String> get promotedUserIds => _promotedUserIds;

  String? _currentUserState; // ولاية المستخدم الحالي

  UserModel? _viewedUser;
  List<UserModel> _freelancers = [];
  List<UserModel> _shops = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _freelancerError; // خطأ جلب المستقلين
  String? _shopError; // خطأ جلب المتاجر
  String _uploadStatus = ''; // حالة الرفع للعرض

  // Listeners
  StreamSubscription? _freelancerSub;
  StreamSubscription? _shopSub;

  // Caching flags - تجنب إعادة التحميل
  bool _freelancersLoaded = false;
  bool _shopsLoaded = false;
  DateTime? _lastFreelancersRefresh;
  DateTime? _lastShopsRefresh;
  static const _refreshInterval = Duration(minutes: 5); // تحديث كل 5 دقائق

  UserModel? get viewedUser => _viewedUser;
  List<UserModel> get freelancers => _freelancers;
  List<UserModel> get shops => _shops;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get freelancerError => _freelancerError;
  String? get shopError => _shopError;
  String get uploadStatus => _uploadStatus;
  bool get hasFreelancers => _freelancers.isNotEmpty;
  bool get hasShops => _shops.isNotEmpty;

  /// Set current user's state/region for region-priority fetching
  void setUserState(String? state) {
    _currentUserState = state;
  }

  // Pagination State
  DocumentSnapshot? _lastFreelancerDoc;
  bool _hasMoreFreelancers = true;
  bool _isLoadingMoreFreelancers = false;

  DocumentSnapshot? _lastShopDoc;
  bool _hasMoreShops = true;
  bool _isLoadingMoreShops = false;

  bool get hasMoreFreelancers => _hasMoreFreelancers;
  bool get isLoadingMoreFreelancers => _isLoadingMoreFreelancers;
  bool get hasMoreShops => _hasMoreShops;
  bool get isLoadingMoreShops => _isLoadingMoreShops;

  // Calculate Rank
  int? getRank(String userId, {String? state, String? locality}) {
    // 1. Filter
    var filtered = _freelancers.where((u) {
      if (state != null && u.state != state) return false;
      if (locality != null && u.locality != locality) return false;
      return true;
    }).toList();

    // 2. Sort by Total Stars (Sum of all ratings) as requested
    filtered.sort((a, b) {
      return b.totalStars.compareTo(a.totalStars);
    });

    // 3. Find Index
    int index = filtered.indexWhere((u) => u.id == userId);

    // 4. Return rank (1-based) if in top 10, else null
    if (index != -1 && index < 10) {
      return index + 1;
    }
    return null;
  }

  // Get user by ID
  Future<void> fetchUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _viewedUser = await _firestoreService.getUser(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// حذف مستخدم من القائمة المحلية (عندما يفشل تحميل بياناته أو حسابه غير متاح)
  void removeStaleUser(String userId) {
    final beforeCount = _freelancers.length + _shops.length;
    _freelancers.removeWhere((u) => u.id == userId);
    _shops.removeWhere((u) => u.id == userId);
    if (_freelancers.length + _shops.length < beforeCount) {
      // تحديث الكاش بعد الحذف
      try {
        _cacheService
            .cacheFreelancers(_freelancers.map((e) => e.toJsonMap()).toList());
      } catch (_) {}
      notifyListeners();
      debugPrint('UserProvider: removed stale user $userId from local list');
    }
  }

  // Stream user updates
  void streamUser(String userId) {
    _firestoreService.getUserStream(userId).listen((user) {
      _viewedUser = user;
      notifyListeners();
    });
  }

  // Get freelancers with region priority (75% local, 25% discovery)
  Future<void> fetchFreelancers(
      {String? skill, bool forceRefresh = false}) async {
    // 1. Try Load from Cache First (Instant Display)
    if (_freelancers.isEmpty && !forceRefresh) {
      final cached = _cacheService.getCachedFreelancers();
      if (cached != null && cached.isNotEmpty) {
        // تصفية الحسابات التالفة بصمت — لا نوقف تحميل كل القائمة بسبب حساب واحد
        _freelancers = cached
            .map((e) {
              try {
                return UserModel.fromMap(e);
              } catch (err) {
                debugPrint(
                    'UserProvider: Skipped corrupted cache entry ${e['id']}: $err');
                return null;
              }
            })
            .whereType<UserModel>()
            .toList();
        _freelancersLoaded = true;
        notifyListeners(); // Show cached data immediately
      }
    }

    // إذا تم التحميل مسبقاً (سواء من الكاش او النت) ولم يمض وقت كافٍ، لا تعيد التحميل من النت
    if (_freelancersLoaded && !forceRefresh && _freelancers.isNotEmpty) {
      final now = DateTime.now();
      if (_lastFreelancersRefresh != null &&
          now.difference(_lastFreelancersRefresh!) < _refreshInterval) {
        return;
      }
    }

    if (_freelancers.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    debugPrint('UserProvider: Fetching freelancers (region-priority)...');
    _freelancerError = null;

    try {
      if (_promotedUserIds.isEmpty) {
        final promos = await _promotionService.getActivePromotions();
        _promotedUserIds = promos.map((p) => p.userId).toList();
      }

      final result =
          await _firestoreService.getFreelancersPaginated(limit: 100);
      List<UserModel> combined = result['users'] as List<UserModel>;
      _lastFreelancerDoc = result['lastDoc'] as DocumentSnapshot?;
      _hasMoreFreelancers = result['hasMore'] as bool;

      _freelancers = combined;
      _isLoading = false;
      _freelancersLoaded = true;
      _lastFreelancersRefresh = DateTime.now();

      try {
        _cacheService
            .cacheFreelancers(_freelancers.map((e) => e.toJsonMap()).toList());
      } catch (e) {
        debugPrint('UserProvider: Cache freelancers error: $e');
      }

      _shuffleWithPriority(_freelancers);
      notifyListeners();
    } catch (e) {
      debugPrint('UserProvider: Firestore Error (Freelancers): $e');
      _freelancerError = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreFreelancers({String? skill}) async {
    if (!_hasMoreFreelancers || _isLoadingMoreFreelancers || _isLoading) return;

    _isLoadingMoreFreelancers = true;
    notifyListeners();

    try {
      final result = await _firestoreService.getFreelancersPaginated(
        startAfterDoc: _lastFreelancerDoc,
        limit: 15,
      );

      final moreUsers = result['users'] as List<UserModel>;
      if (moreUsers.isNotEmpty) {
        _freelancers.addAll(moreUsers);
        _lastFreelancerDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMoreFreelancers = result['hasMore'] as bool;

        try {
          _cacheService.cacheFreelancers(
              _freelancers.map((e) => e.toJsonMap()).toList());
        } catch (e) {
          debugPrint('UserProvider: Cache freelancers error: $e');
        }
      } else {
        _hasMoreFreelancers = false;
      }
    } catch (e) {
      debugPrint('UserProvider: Load More Error: $e');
    } finally {
      _isLoadingMoreFreelancers = false;
      notifyListeners();
    }
  }

  // Get shops with region priority (75% local, 25% discovery)
  Future<void> fetchShops(
      {ShopCategory? category, bool forceRefresh = false}) async {
    // 1. Try Load from Cache First
    if (_shops.isEmpty && !forceRefresh) {
      final cached = _cacheService.getCachedShops();
      if (cached != null && cached.isNotEmpty) {
        _shops = cached.map((e) => UserModel.fromMap(e)).toList();
        _shopsLoaded = true;
        notifyListeners();
      }
    }

    // Check refresh interval
    if (_shopsLoaded && !forceRefresh && _shops.isNotEmpty) {
      final now = DateTime.now();
      if (_lastShopsRefresh != null &&
          now.difference(_lastShopsRefresh!) < _refreshInterval) {
        return;
      }
    }

    if (_shops.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    debugPrint('UserProvider: Fetching shops (region-priority)...');
    _shopError = null;

    try {
      if (_promotedUserIds.isEmpty) {
        final promos = await _promotionService.getActivePromotions();
        _promotedUserIds = promos.map((p) => p.userId).toList();
      }

      final result = await _firestoreService.getShopsPaginated(limit: 100);
      List<UserModel> combined = result['users'] as List<UserModel>;
      _lastShopDoc = result['lastDoc'] as DocumentSnapshot?;
      _hasMoreShops = result['hasMore'] as bool;

      _shops = combined;
      _isLoading = false;
      _shopsLoaded = true;
      _lastShopsRefresh = DateTime.now();

      try {
        _cacheService.cacheShops(_shops.map((e) => e.toJsonMap()).toList());
      } catch (e) {
        debugPrint('UserProvider: Cache shops error: $e');
      }

      _shuffleWithPriority(_shops);
      notifyListeners();
    } catch (e) {
      debugPrint('UserProvider: Firestore Error (Shops): $e');
      _shopError = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreShops({ShopCategory? category}) async {
    if (!_hasMoreShops || _isLoadingMoreShops || _isLoading) return;

    _isLoadingMoreShops = true;
    notifyListeners();

    try {
      final result = await _firestoreService.getShopsPaginated(
        startAfterDoc: _lastShopDoc,
        limit: 15,
      );

      final moreUsers = result['users'] as List<UserModel>;
      if (moreUsers.isNotEmpty) {
        _shops.addAll(moreUsers);
        _lastShopDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMoreShops = result['hasMore'] as bool;

        try {
          _cacheService.cacheShops(_shops.map((e) => e.toJsonMap()).toList());
        } catch (e) {
          debugPrint('UserProvider: Cache shops error: $e');
        }
      } else {
        _hasMoreShops = false;
      }
    } catch (e) {
      debugPrint('UserProvider: Load More Error: $e');
    } finally {
      _isLoadingMoreShops = false;
      notifyListeners();
    }
  }

  // Shuffle list prioritizing promoted, local state, high-rated, and randomness
  void _shuffleWithPriority(List<UserModel> list) {
    if (list.isEmpty) return;

    final promotedList =
        list.where((u) => _promotedUserIds.contains(u.id)).toList()..shuffle();
    final nonPromotedList =
        list.where((u) => !_promotedUserIds.contains(u.id)).toList();

    // تقسيم القائمة غير المروجة إلى: محليين وغير محليين
    final localList = nonPromotedList
        .where((u) =>
            u.state == _currentUserState || u.role == UserRole.techService)
        .toList();
    final otherList = nonPromotedList
        .where((u) =>
            u.state != _currentUserState && u.role != UserRole.techService)
        .toList();

    void sortAndShuffle(List<UserModel> sublist) {
      final highRated = sublist.where((u) => u.rating >= 4.0).toList()
        ..shuffle();
      final midRated = sublist
          .where((u) => u.rating >= 2.0 && u.rating < 4.0)
          .toList()
        ..shuffle();
      final lowRated = sublist
          .where((u) => u.rating < 2.0 || u.reviewsCount == 0)
          .toList()
        ..shuffle();
      sublist.clear();
      sublist.addAll(highRated);
      sublist.addAll(midRated);
      sublist.addAll(lowRated);
    }

    sortAndShuffle(localList);
    sortAndShuffle(otherList);

    list.clear();
    // 1. المروجين دائماً في البداية (Promoted)
    list.addAll(promotedList);
    // 2. أبناء المنطقة
    list.addAll(localList);
    // 3. البقية
    list.addAll(otherList);
  }

  // Upload profile image with compression
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    _isLoading = true;
    _uploadStatus = 'جاري ضغط ورفع الصورة...';
    notifyListeners();

    try {
      File compressedFile = imageFile;
      if (await ImageCompressService.needsCompression(imageFile)) {
        compressedFile = await ImageCompressService.compressImage(imageFile);
      }

      final url =
          await StorageService().uploadProfileImage(userId, compressedFile);

      await _firestoreService
          .updateUserProfile(userId, {'profileImageUrl': url});
      await _firestoreService.updateUserProfileImages(userId, url, null);

      if (_viewedUser?.id == userId) {
        _viewedUser = _viewedUser?.copyWith(profileImageUrl: url);
      }
      _uploadStatus = 'تم بنجاح ✓';

      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _uploadStatus = 'حدث خطأ';
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadCoverImage(String userId, File imageFile) async {
    _isLoading = true;
    _uploadStatus = 'جاري ضغط ورفع الغلاف...';
    notifyListeners();

    try {
      File compressedFile = imageFile;
      if (await ImageCompressService.needsCompression(imageFile)) {
        compressedFile = await ImageCompressService.compressImage(imageFile);
      }

      final url = await StorageService()
          .uploadImage(compressedFile, folder: 'users/$userId/cover');

      if (url != null) {
        _uploadStatus = 'تم التحديث بنجاح';
        await _firestoreService
            .updateUserProfile(userId, {'coverImageUrl': url});
        if (_viewedUser?.id == userId) {
          _viewedUser = _viewedUser?.copyWith(coverImageUrl: url);
        }
      } else {
        _uploadStatus = 'فشل الرفع';
      }

      _isLoading = false;
      notifyListeners();
      return url;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      _uploadStatus = 'حدث خطأ في الرفع';
      notifyListeners();
      return null;
    }
  }

  // Upload portfolio image
  Future<String?> uploadPortfolioImage(String userId, File imageFile) async {
    try {
      final url =
          await StorageService().uploadPortfolioImage(userId, imageFile);
      return url;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Upload portfolio video
  Future<String?> uploadPortfolioVideo(String userId, File videoFile) async {
    try {
      final url =
          await StorageService().uploadPortfolioVideo(userId, videoFile);
      return url;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear viewed user
  void clearViewedUser() {
    _viewedUser = null;
    notifyListeners();
  }

  // Clear all data (on logout)
  void clear() {
    _viewedUser = null;
    _freelancers = [];
    _shops = [];
    _isLoading = false;
    _errorMessage = null;
    _freelancerError = null;
    _shopError = null;
    _freelancersLoaded = false;
    _shopsLoaded = false;
    _lastFreelancersRefresh = null;
    _lastShopsRefresh = null;
    _freelancerSub?.cancel();
    _shopSub?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _freelancerSub?.cancel();
    _shopSub?.cancel();
    super.dispose();
  }

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestoreService.getNotifications(userId);
  }
}
