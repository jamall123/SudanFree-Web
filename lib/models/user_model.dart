import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

enum UserRole { freelancer, techService, privateService, client, shop, admin }

enum ShopCategory {
  electronics, // إلكترونيات
  clothing, // ملابس
  furniture, // أثاث
  food, // مواد غذائية
  restaurant, // مطعم
  supermarket, // سوبرماركت
  pharmacy, // صيدلية
  beauty, // تجميل ومستحضرات
  automotive, // قطع غيار سيارات
  building, // مواد بناء
  jewelry, // مجوهرات
  mobile, // جوالات وإكسسوارات
  bookstore, // مكتبة
  sports, // رياضة
  toys, // ألعاب أطفال
  home, // أدوات منزلية
  other, // أخرى
}

enum VerificationStatus { none, pending, verified, rejected }

class UserModel {
  final String id;
  final String email;
  final String? username; // @username للإشارات (اختياري)
  final String? phoneNumber;
  final bool isVerified;
  final bool isPremium;
  final DateTime? verifiedAt;
  final VerificationStatus verificationStatus;
  final String? idCardUrl;
  final String? verificationSelfieUrl;
  final int profileViews;
  final int dailyProfileViews;
  final DateTime? lastViewReset;
  final String name;
  final UserRole role;
  final String? bio;
  final String? jobTitle; // نوع العمل المخصص
  final String? profileImageUrl;
  final String? coverImageUrl;
  final List<String> skills;
  final List<String> portfolioImages;
  final List<String> portfolioVideos; // معرض الفيديوهات
  final double? hourlyRate;
  // Location fields
  final String? state; // الولاية
  final String? locality; // المحلية
  final String? neighborhood; // المنطقة / الحي
  // Shop fields (for role == shop)
  final ShopCategory? shopCategory; // تصنيف المتجر
  final List<String> shopImages; // صور المنتجات
  final String? openingHours; // أوقات الفتح
  final String? closingHours; // أوقات الإغلاق
  final String? whatsappNumber; // رقم الواتساب للتواصل
  // Rating fields
  final double rating;
  final int reviewsCount;
  final Map<String, int> ratingCounts; // Key: '1', '2', '3', '4', '5'
  final int negativeReports; // Reports for fraud/scam
  final int totalJobs;
  final int completedJobs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fcmToken;
  final String preferredLanguage;
  final bool isAvailable;
  final bool isBanned; // To block user from platform
  final String? banReason; // The reason why the user was banned
  final double walletBalance;
  final List<String> partnerIds; // Accepted colleagues
  final List<String> pendingPartnerIds; // Pending colleague requests
  final List<String> pendingSquadInvites; // Pending squad join requests
  final List<String> followers; // Users who follow this shop/user
  final List<String> following; // Users/shops this user follows
  final List<String> blockedUsers; // Users that this user has blocked
  final DateTime? lastActive; // For online status tracking
  final Map<String, bool> notificationSettings; // Notification preferences
  final List<String> searchKeywords; // Auto-generated keywords for search
  // Client Interests
  final List<String> shopInterests; // أنواع المتاجر التي يهتم بها العميل
  final List<String> serviceInterests; // أنواع الخدمات التي يحتاجها العميل
  final List<String> favoriteUserIds; // المفضلة: حرفيون أو متاجر
  final List<String> favoriteProductIds;
  final List<String> favoriteSquadIds; // المفضلة: المنتجات
  final bool showOnMap; // إظهار أو إخفاء من الخريطة
  final double? latitude; // خط العرض
  final double? longitude; // خط الطول

  // Guarantor / Vouching System (نظام الضامن)
  final List<Map<String, dynamic>> vouchedBy; // [{id, name, level, timestamp}]

  // Master-Apprentice System (نظام الأسطى والصبي)
  final String? masterId; // الخبير المسؤول عن هذا المتدرب
  final List<String> apprenticesIds; // قائمة المتدربين تحت إشراف هذا الخبير
  final List<String>
      pendingApprenticeRequests; // طلبات من صبيان للانضمام لهذا الأسطى
  final List<String>
      pendingMasterRequests; // دعوات من أسطوات لهذا المستخدم ليكون صبياً لهم
  final List<String> pendingLeaveRequests; // طلبات من صبيان لترك هذا الأسطى

  UserModel({
    required this.id,
    required this.email,
    this.username,
    this.phoneNumber,
    this.profileViews = 0,
    this.dailyProfileViews = 0,
    this.lastViewReset,
    required this.name,
    required this.role,
    this.bio,
    this.jobTitle,
    this.profileImageUrl,
    this.coverImageUrl,
    this.skills = const [],
    this.portfolioImages = const [],
    this.portfolioVideos = const [],
    this.hourlyRate,
    this.state,
    this.locality,
    this.neighborhood,
    this.shopCategory,
    this.shopImages = const [],
    this.openingHours,
    this.closingHours,
    this.whatsappNumber,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.ratingCounts = const {},
    this.negativeReports = 0,
    this.totalJobs = 0,
    this.completedJobs = 0,
    required this.createdAt,
    required this.updatedAt,
    this.fcmToken,
    this.preferredLanguage = 'ar',
    this.isAvailable = true,
    this.isBanned = false,
    this.banReason,
    this.walletBalance = 0.0,
    this.partnerIds = const [],
    this.pendingPartnerIds = const [],
    this.pendingSquadInvites = const [],
    this.followers = const [],
    this.following = const [],
    this.blockedUsers = const [],
    this.lastActive,
    this.isVerified = false,
    this.isPremium = false,
    this.verifiedAt,
    this.verificationStatus = VerificationStatus.none,
    this.idCardUrl,
    this.verificationSelfieUrl,
    this.notificationSettings = const {
      'chat': true,
      'mentions': true,
      'milestones': true,
      'marketing': false,
    },
    this.searchKeywords = const [],
    this.shopInterests = const [],
    this.serviceInterests = const [],
    this.favoriteUserIds = const [],
    this.favoriteProductIds = const [],
    this.favoriteSquadIds = const [],
    this.showOnMap = true,
    this.latitude,
    this.longitude,
    this.vouchedBy = const [],
    this.masterId,
    this.apprenticesIds = const [],
    this.pendingApprenticeRequests = const [],
    this.pendingMasterRequests = const [],
    this.pendingLeaveRequests = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id; // Ensure ID is in data map
    return UserModel.fromMap(data);
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString(),
      phoneNumber: data['phoneNumber']?.toString(),
      profileViews: (data['profileViews'] as num?)?.toInt() ?? 0,
      dailyProfileViews: (data['dailyProfileViews'] as num?)?.toInt() ?? 0,
      lastViewReset: data['lastViewReset'] is Timestamp
          ? (data['lastViewReset'] as Timestamp).toDate()
          : data['lastViewReset'] is String
              ? DateTime.parse(data['lastViewReset'])
              : null,
      name: data['name'] ?? '',
      role: UserModel._parseRole(data['role']),
      bio: data['bio'],
      jobTitle: data['jobTitle'],
      profileImageUrl: data['profileImageUrl'],
      coverImageUrl: data['coverImageUrl'],
      skills: _safeStringList(data['skills']),
      portfolioImages: _safeStringList(data['portfolioImages']),
      portfolioVideos: _safeStringList(data['portfolioVideos']),
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      state: SafeParse.nullableString(data['state']),
      locality: SafeParse.nullableString(data['locality']),
      neighborhood: SafeParse.nullableString(data['neighborhood']),
      shopCategory: data['shopCategory'] != null
          ? ShopCategory.values.firstWhere(
              (e) => e.name == data['shopCategory'],
              orElse: () => ShopCategory.other,
            )
          : null,
      shopImages: _safeStringList(data['shopImages']),
      openingHours: data['openingHours'],
      closingHours: data['closingHours'],
      whatsappNumber: data['whatsappNumber'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (data['reviewsCount'] as num?)?.toInt() ?? 0,
      // إصلاح جذري: Map.from يرمي CastException إذا كانت القيم double بدل int
      ratingCounts: (() {
        try {
          final raw = data['ratingCounts'];
          if (raw == null) return <String, int>{};
          return (raw as Map)
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        } catch (_) {
          return <String, int>{};
        }
      })(),
      negativeReports: (data['negativeReports'] as num?)?.toInt() ?? 0,
      totalJobs: (data['totalJobs'] as num?)?.toInt() ?? 0,
      completedJobs: (data['completedJobs'] as num?)?.toInt() ?? 0,
      // Handle both Timestamp (Firestore) and String/int (JSON Cache)
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is String
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(), // Fallback
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : data['updatedAt'] is String
              ? DateTime.parse(data['updatedAt'])
              : DateTime.now(),
      fcmToken: data['fcmToken'],
      preferredLanguage: data['preferredLanguage'] ?? 'ar',
      isAvailable: data['isAvailable'] ?? true,
      isBanned: data['isBanned'] ?? false,
      banReason: data['banReason'],
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      partnerIds: _safeStringList(data['partnerIds']),
      pendingPartnerIds: _safeStringList(data['pendingPartnerIds']),
      pendingSquadInvites: _safeStringList(data['pendingSquadInvites']),
      followers: _safeStringList(data['followers']),
      following: _safeStringList(data['following']),
      blockedUsers: _safeStringList(data['blockedUsers']),
      lastActive: data['lastActive'] is Timestamp
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
      isVerified: data['isVerified'] ?? false,
      isPremium: data['isPremium'] ?? false,
      verifiedAt: data['verifiedAt'] is Timestamp
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == (data['verificationStatus'] ?? 'none'),
        orElse: () => VerificationStatus.none,
      ),
      idCardUrl: data['idCardUrl'],
      verificationSelfieUrl: data['verificationSelfieUrl'],
      // إصلاح جذري: Map.from يرمي CastException إذا كانت القيم ليست bool صريحة
      notificationSettings: (() {
        try {
          final raw = data['notificationSettings'];
          if (raw == null)
            return {
              'chat': true,
              'mentions': true,
              'milestones': true,
              'marketing': false
            };
          return (raw as Map).map((k, v) => MapEntry(k.toString(), v == true));
        } catch (_) {
          return {
            'chat': true,
            'mentions': true,
            'milestones': true,
            'marketing': false
          };
        }
      })(),
      searchKeywords: _safeStringList(data['searchKeywords']),
      shopInterests: _safeStringList(data['shopInterests']),
      serviceInterests: _safeStringList(data['serviceInterests']),
      favoriteUserIds: _safeStringList(data['favoriteUserIds']),
      favoriteProductIds: _safeStringList(data['favoriteProductIds']),
      favoriteSquadIds: _safeStringList(data['favoriteSquadIds']),
      showOnMap: data['showOnMap'] ?? true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      // إصلاح جذري: List.from يرمي CastException إذا كانت القوائم الداخلية Map<dynamic,dynamic>
      vouchedBy: (() {
        try {
          final raw = data['vouchedBy'];
          if (raw == null) return <Map<String, dynamic>>[];
          return (raw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      })(),
      masterId: data['masterId'],
      apprenticesIds: _safeStringList(data['apprenticesIds']),
      pendingApprenticeRequests:
          _safeStringList(data['pendingApprenticeRequests']),
      pendingMasterRequests: _safeStringList(data['pendingMasterRequests']),
      pendingLeaveRequests: _safeStringList(data['pendingLeaveRequests']),
    );
  }

  static List<String> _safeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  static UserRole _parseRole(dynamic rawRole) {
    final normalized = rawRole?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'freelancer':
      case 'craftsman':
      case 'worker':
      case 'artisan':
      case 'service provider':
      case 'provider':
        return UserRole.freelancer;
      case 'techservice':
      case 'tech_service':
      case 'tech service':
      case 'technician':
        return UserRole.techService;
      case 'privateservice':
      case 'private_service':
      case 'private service':
      case 'provider_private':
        return UserRole.privateService;
      case 'shop':
      case 'store':
      case 'gallery':
      case 'معرض':
        return UserRole.shop;
      case 'client':
        return UserRole.client;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.values.firstWhere(
          (e) => e.name.toLowerCase() == normalized,
          orElse: () => UserRole.client,
        );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'profileViews': profileViews,
      'dailyProfileViews': dailyProfileViews,
      if (lastViewReset != null)
        'lastViewReset': Timestamp.fromDate(lastViewReset!),
      'name': name,
      'role': role.name,
      'bio': bio,
      'jobTitle': jobTitle,
      'profileImageUrl': profileImageUrl,
      'coverImageUrl': coverImageUrl,
      'skills': skills,
      'portfolioImages': portfolioImages,
      'portfolioVideos': portfolioVideos,
      'hourlyRate': hourlyRate,
      'state': state,
      'locality': locality,
      'neighborhood': neighborhood,
      'shopCategory': shopCategory?.name,
      'shopImages': shopImages,
      'openingHours': openingHours,
      'closingHours': closingHours,
      'whatsappNumber': whatsappNumber,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'ratingCounts': ratingCounts,
      'totalJobs': totalJobs,
      'completedJobs': completedJobs,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'fcmToken': fcmToken,
      'preferredLanguage': preferredLanguage,
      'isAvailable': isAvailable,
      'isBanned': isBanned,
      if (banReason != null) 'banReason': banReason,
      'walletBalance': walletBalance,
      'negativeReports': negativeReports,
      'partnerIds': partnerIds,
      'pendingPartnerIds': pendingPartnerIds,
      'pendingSquadInvites': pendingSquadInvites,
      'followers': followers,
      'following': following,
      'blockedUsers': blockedUsers,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isVerified': isVerified,
      'isPremium': isPremium,
      'verificationStatus': verificationStatus.name,
      'idCardUrl': idCardUrl,
      if (verificationSelfieUrl != null)
        'verificationSelfieUrl': verificationSelfieUrl,
      'notificationSettings': notificationSettings,
      'shopInterests': shopInterests,
      'serviceInterests': serviceInterests,
      'favoriteUserIds': favoriteUserIds,
      'favoriteProductIds': favoriteProductIds,
      'favoriteSquadIds': favoriteSquadIds,
      'showOnMap': showOnMap,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'vouchedBy': vouchedBy,
      'masterId': masterId,
      'apprenticesIds': apprenticesIds,
      'pendingApprenticeRequests': pendingApprenticeRequests,
      'pendingMasterRequests': pendingMasterRequests,
      'pendingLeaveRequests': pendingLeaveRequests,
      'searchKeywords': generateSearchKeywords(
        name: name,
        jobTitle: jobTitle,
        skills: skills,
        bio: bio,
        state: state,
        locality: locality,
        neighborhood: neighborhood,
        shopCategory: shopCategory,
        role: role,
      ),
    };
  }

  // JSON Map for Hive Cache (Strings instead of Timestamps)
  Map<String, dynamic> toJsonMap() {
    final map = toFirestore();
    map['id'] = id;
    // SafeParse.sanitizeForCache recursively converts ALL Timestamps → ISO strings
    return SafeParse.sanitizeForCache(map);
  }

  // Calculated getter for total stars (Ranking Score)
  double get totalStars => rating * reviewsCount;

  // Calculated getter for Reputation Points System (نظام السمعة)
  int get reputationScore {
    int score = (totalStars * 10).toInt() + 
                (completedJobs * 50) + 
                (profileViews ~/ 10) - 
                (negativeReports * 100);
    if (effectivelyVerified) score += 500;
    if (isPremium) score += 200;
    return score < 0 ? 0 : score;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? phoneNumber,
    int? profileViews,
    int? dailyProfileViews,
    DateTime? lastViewReset,
    String? name,
    UserRole? role,
    String? bio,
    String? jobTitle,
    String? profileImageUrl,
    String? coverImageUrl,
    List<String>? skills,
    List<String>? portfolioImages,
    List<String>? portfolioVideos,
    double? hourlyRate,
    String? state,
    String? locality,
    String? neighborhood,
    ShopCategory? shopCategory,
    List<String>? shopImages,
    String? openingHours,
    String? closingHours,
    String? whatsappNumber,
    double? rating,
    int? reviewsCount,
    Map<String, int>? ratingCounts,
    int? negativeReports,
    int? totalJobs,
    int? completedJobs,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fcmToken,
    String? preferredLanguage,
    bool? isAvailable,
    bool? isBanned,
    String? banReason,
    double? walletBalance,
    List<String>? partnerIds,
    List<String>? pendingPartnerIds,
    List<String>? pendingSquadInvites,
    List<String>? followers,
    List<String>? following,
    List<String>? blockedUsers,
    DateTime? lastActive,
    bool? isVerified,
    bool? isPremium,
    DateTime? verifiedAt,
    VerificationStatus? verificationStatus,
    String? idCardUrl,
    String? verificationSelfieUrl,
    Map<String, bool>? notificationSettings,
    List<String>? shopInterests,
    List<String>? serviceInterests,
    List<String>? favoriteUserIds,
    List<String>? favoriteProductIds,
    List<String>? favoriteSquadIds,
    bool? showOnMap,
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>>? vouchedBy,
    String? masterId,
    List<String>? apprenticesIds,
    List<String>? pendingApprenticeRequests,
    List<String>? pendingMasterRequests,
    List<String>? pendingLeaveRequests,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileViews: profileViews ?? this.profileViews,
      dailyProfileViews: dailyProfileViews ?? this.dailyProfileViews,
      lastViewReset: lastViewReset ?? this.lastViewReset,
      name: name ?? this.name,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      jobTitle: jobTitle ?? this.jobTitle,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      skills: skills ?? this.skills,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      portfolioVideos: portfolioVideos ?? this.portfolioVideos,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      state: state ?? this.state,
      locality: locality ?? this.locality,
      neighborhood: neighborhood ?? this.neighborhood,
      shopCategory: shopCategory ?? this.shopCategory,
      shopImages: shopImages ?? this.shopImages,
      openingHours: openingHours ?? this.openingHours,
      closingHours: closingHours ?? this.closingHours,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      negativeReports: negativeReports ?? this.negativeReports,
      totalJobs: totalJobs ?? this.totalJobs,
      completedJobs: completedJobs ?? this.completedJobs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isAvailable: isAvailable ?? this.isAvailable,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      walletBalance: walletBalance ?? this.walletBalance,
      partnerIds: partnerIds ?? this.partnerIds,
      pendingPartnerIds: pendingPartnerIds ?? this.pendingPartnerIds,
      pendingSquadInvites: pendingSquadInvites ?? this.pendingSquadInvites,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      lastActive: lastActive ?? this.lastActive,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      verificationSelfieUrl:
          verificationSelfieUrl ?? this.verificationSelfieUrl,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      searchKeywords: searchKeywords,
      shopInterests: shopInterests ?? this.shopInterests,
      serviceInterests: serviceInterests ?? this.serviceInterests,
      favoriteUserIds: favoriteUserIds ?? this.favoriteUserIds,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      favoriteSquadIds: favoriteSquadIds ?? this.favoriteSquadIds,
      showOnMap: showOnMap ?? this.showOnMap,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vouchedBy: vouchedBy ?? this.vouchedBy,
      masterId: masterId ?? this.masterId,
      apprenticesIds: apprenticesIds ?? this.apprenticesIds,
      pendingApprenticeRequests:
          pendingApprenticeRequests ?? this.pendingApprenticeRequests,
      pendingMasterRequests:
          pendingMasterRequests ?? this.pendingMasterRequests,
      pendingLeaveRequests: pendingLeaveRequests ?? this.pendingLeaveRequests,
    );
  }

  bool get isFreelancer => role == UserRole.freelancer;
  bool get isTechService => role == UserRole.techService;
  bool get isPrivateService => role == UserRole.privateService;
  bool get isClient => role == UserRole.client;
  bool get isShop => role == UserRole.shop;
  bool get isAdmin => role == UserRole.admin;

  /// Admins/moderators are automatically verified without the verification process
  bool get effectivelyVerified => isVerified || isAdmin;

  /// Dynamically checks if shop is currently open based on openingHours/closingHours.
  /// Falls back to isAvailable if hours are not set.
  bool get isShopCurrentlyOpen {
    if (openingHours == null ||
        closingHours == null ||
        openingHours!.isEmpty ||
        closingHours!.isEmpty) {
      return isAvailable; // Fallback to static field
    }

    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final openParts = openingHours!.split(':');
      final closeParts = closingHours!.split(':');

      final openMinutes =
          int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMinutes =
          int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      // Handle overnight hours (e.g., 22:00 - 06:00)
      if (closeMinutes <= openMinutes) {
        return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
      }

      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } catch (_) {
      return isAvailable; // Fallback on parse error
    }
  }

  String get locationDisplay {
    if (state == null) return '';
    final parts = <String>[];
    if (neighborhood != null) parts.add(neighborhood!);
    if (locality != null) parts.add(locality!);
    parts.add(state!);
    return parts.join('، ');
  }

  String get ratingDisplay => rating.toStringAsFixed(1);

  /// True if user was active within the last 5 minutes
  bool get isOnline {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inMinutes < 5;
  }

  static String getLocalizedShopCategory(ShopCategory cat, String locale) {
    final names = {
      'ar': {
        ShopCategory.electronics: 'إلكترونيات',
        ShopCategory.clothing: 'ملابس',
        ShopCategory.furniture: 'أثاث',
        ShopCategory.food: 'مواد غذائية',
        ShopCategory.restaurant: 'مطعم',
        ShopCategory.supermarket: 'سوبرماركت',
        ShopCategory.pharmacy: 'صيدلية',
        ShopCategory.beauty: 'تجميل ومستحضرات',
        ShopCategory.automotive: 'قطع غيار سيارات',
        ShopCategory.building: 'مواد بناء',
        ShopCategory.jewelry: 'مجوهرات',
        ShopCategory.mobile: 'جوالات وإكسسوارات',
        ShopCategory.bookstore: 'مكتبة',
        ShopCategory.sports: 'رياضة',
        ShopCategory.toys: 'ألعاب أطفال',
        ShopCategory.home: 'أدوات منزلية',
        ShopCategory.other: 'أخرى',
      },
      'en': {
        ShopCategory.electronics: 'Electronics',
        ShopCategory.clothing: 'Clothing',
        ShopCategory.furniture: 'Furniture',
        ShopCategory.food: 'Food',
        ShopCategory.restaurant: 'Restaurant',
        ShopCategory.supermarket: 'Supermarket',
        ShopCategory.pharmacy: 'Pharmacy',
        ShopCategory.beauty: 'Beauty & Cosmetics',
        ShopCategory.automotive: 'Auto Parts',
        ShopCategory.building: 'Building Materials',
        ShopCategory.jewelry: 'Jewelry',
        ShopCategory.mobile: 'Mobiles & Accessories',
        ShopCategory.bookstore: 'Bookstore',
        ShopCategory.sports: 'Sports',
        ShopCategory.toys: 'Toys',
        ShopCategory.home: 'Home Appliances',
        ShopCategory.other: 'Other',
      }
    };
    return names[locale]?[cat] ?? cat.name;
  }

  // Helper to get shop category display name
  String getShopCategoryName(String locale) {
    if (shopCategory == null) return '';
    if (shopCategory == ShopCategory.other &&
        jobTitle != null &&
        jobTitle!.isNotEmpty) {
      return jobTitle!;
    }
    return getLocalizedShopCategory(shopCategory!, locale);
  }

  String getRoleDisplayName(String locale) {
    if (locale == 'ar') {
      switch (role) {
        case UserRole.freelancer:
          return 'مقدم خدمات فنية';
        case UserRole.techService:
          return 'مقدم خدمات تقنية';
        case UserRole.privateService:
          return 'مقدم خدمات خاصة';
        case UserRole.shop:
          return 'معرض / متجر';
        case UserRole.client:
          return 'عميل';
        case UserRole.admin:
          return 'مدير';
      }
    } else {
      switch (role) {
        case UserRole.freelancer:
          return 'Craft Service';
        case UserRole.techService:
          return 'Tech Service';
        case UserRole.privateService:
          return 'Private Service';
        case UserRole.shop:
          return 'Shop / Gallery';
        case UserRole.client:
          return 'Client';
        case UserRole.admin:
          return 'Admin';
      }
    }
  }

  /// Generates normalized search keywords from user profile fields.
  /// These are stored in Firestore for efficient array-contains search.
  static List<String> generateSearchKeywords({
    required String name,
    String? jobTitle,
    List<String> skills = const [],
    String? bio,
    String? state,
    String? locality,
    String? neighborhood,
    ShopCategory? shopCategory,
    UserRole? role,
  }) {
    final keywords = <String>{};

    // Helper to add normalized words
    void addWords(String? text) {
      if (text == null || text.isEmpty) return;
      final normalized = _normalize(text);
      // Add whole phrase
      if (normalized.length >= 2) keywords.add(normalized);
      // Add individual words
      for (final word in normalized.split(RegExp(r'\s+'))) {
        if (word.length >= 2) keywords.add(word);
      }
    }

    // Name (full + parts)
    addWords(name);

    // Job Title
    addWords(jobTitle);

    // Skills
    for (final skill in skills) {
      addWords(skill);
    }

    // Bio (extract meaningful words, skip very short ones)
    if (bio != null && bio.isNotEmpty) {
      final normalized = _normalize(bio);
      for (final word in normalized.split(RegExp(r'\s+'))) {
        if (word.length >= 3) keywords.add(word);
      }
    }

    // Location
    addWords(state);
    addWords(locality);
    addWords(neighborhood);

    // Shop Category (Arabic names)
    if (shopCategory != null) {
      const categoryKeywords = {
        ShopCategory.electronics: ['الكترونيات', 'electronics'],
        ShopCategory.clothing: ['ملابس', 'clothing'],
        ShopCategory.furniture: ['اثاث', 'furniture'],
        ShopCategory.food: ['مواد غذائيه', 'food'],
        ShopCategory.restaurant: ['مطعم', 'restaurant'],
        ShopCategory.supermarket: ['سوبرماركت', 'supermarket'],
        ShopCategory.pharmacy: ['صيدليه', 'pharmacy'],
        ShopCategory.beauty: ['تجميل', 'beauty'],
        ShopCategory.automotive: ['سيارات', 'automotive'],
        ShopCategory.building: ['مواد بناء', 'building'],
        ShopCategory.jewelry: ['مجوهرات', 'jewelry'],
        ShopCategory.mobile: ['جوالات', 'mobile'],
        ShopCategory.bookstore: ['مكتبه', 'bookstore'],
        ShopCategory.sports: ['رياضه', 'sports'],
        ShopCategory.toys: ['العاب اطفال', 'toys'],
        ShopCategory.home: ['ادوات منزليه', 'home'],
        ShopCategory.other: ['اخري', 'other'],
      };
      for (final kw in categoryKeywords[shopCategory] ?? []) {
        addWords(kw);
      }
    }

    // Role keywords
    if (role != null) {
      const roleKeywords = {
        UserRole.freelancer: ['حرفي', 'فني', 'مقدم خدمات'],
        UserRole.techService: ['تقني', 'تكنولوجيا', 'فني'],
        UserRole.privateService: ['خدمات خاصه', 'خاص'],
        UserRole.shop: ['متجر', 'معرض', 'محل'],
        UserRole.client: ['عميل'],
        UserRole.admin: ['مدير'],
      };
      for (final kw in roleKeywords[role] ?? []) {
        addWords(kw);
      }
    }

    return keywords.toList();
  }

  /// Normalize Arabic text for keyword generation (matches SmartSearchService normalization)
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // Remove tashkeel
        .trim();
  }
}
