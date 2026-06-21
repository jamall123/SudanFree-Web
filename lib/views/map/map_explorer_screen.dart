import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/locale_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/smart_guide_service.dart';
import '../../models/job_model.dart';
import '../profile/profile_screen.dart';
import '../../core/utils/job_titles_utils.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/premium_animations.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {
        'User-Agent': 'com.sudan.free',
      },
    );
  }
}

class MapExplorerScreen extends StatefulWidget {
  final UserModel? targetUser;
  const MapExplorerScreen({super.key, this.targetUser});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allMapUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  String _selectedRoleFilter = 'all'; // 'all', 'shop', 'freelancer'
  ShopCategory? _selectedShopCategoryFilter;
  JobCategory? _selectedFreelancerCategoryFilter;

  // حدود السودان التقريبية (وسعناها قليلاً لتجنب الأخطاء)
  final LatLngBounds _sudanBounds = LatLngBounds(
    const LatLng(8.0, 21.0),
    const LatLng(23.0, 39.0),
  );

  final LatLng _defaultCenter =
      const LatLng(15.5007, 32.5599); // الخرطوم كموقع افتراضي

  Timer? _debounceTimer;

  bool _isValidSudanCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= 8.0 && lat <= 23.0 && lng >= 21.0 && lng <= 39.0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.targetUser != null) {
      // If a specific target user is provided, only show this user
      // Check privacy setting
      final user = widget.targetUser!;
      double? lat = user.latitude;
      double? lng = user.longitude;

      if (lat != null && lng != null) {
        if (user.showOnMap != true) {
          // Add a random offset for privacy (approx 2-3km)
          // 0.02 degrees is approx 2km
          lat += (DateTime.now().millisecond % 4 - 2) * 0.01;
          lng += (DateTime.now().microsecond % 4 - 2) * 0.01;
          // Set a flag to indicate it's approximate (we can use a custom property or just standard)
        }

        // Ensure it's valid
        if (_isValidSudanCoordinate(lat, lng)) {
          // create a copy of the user with modified coords
          final displayUser = user.copyWith(latitude: lat, longitude: lng);
          _allMapUsers = [displayUser];
          _filteredUsers = [displayUser];
          _isLoading = false;
        }
      } else {
        _isLoading = false;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (lat != null && lng != null) {
          _animatedMapMove(LatLng(lat, lng), 14.5);
        }

        if (user.showOnMap != true) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                context.read<LocaleProvider>().isArabic
                    ? 'الموقع تقريبي لحماية خصوصية المستخدم'
                    : 'Location is approximate to protect user privacy',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    } else {
      _fetchUsersInBounds(_sudanBounds);

      // تحريك الخريطة لموقع المستخدم الفعلي بعد بناء الواجهة
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateUser();

        SmartGuideService.showMicroTip(
          context,
          messageAr: 'اضغط على أي نقطة لرؤية تفاصيل مقدم الخدمة 📍',
          messageEn: 'Tap any point to see provider details 📍',
          tipId: 'map_first_use',
          icon: Icons.map_rounded,
        );
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // الحصول على موقع المستخدم الحالي وتحريك الكاميرا إليه
  Future<void> _locateUser() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      // Try to get last known position first for instant response
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _animatedMapMove(LatLng(position.latitude, position.longitude), 14.5);
      }

      // Then get current with high accuracy for precise location
      position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ));

      // التوجه إلى موقع المستخدم الفعلي بزووم قريب
      _animatedMapMove(LatLng(position.latitude, position.longitude), 15.5);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // حركة سينمائية ناعمة للكاميرا
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!mounted) return;

    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);

    final Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _fetchUsersInBounds(LatLngBounds bounds) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final users = await FirestoreService().getUsersInMapBounds(
        bounds.south - 0.1,
        bounds.north + 0.1,
        bounds.west - 0.1,
        bounds.east + 0.1,
      );
      if (mounted) {
        setState(() {
          final seen = <String>{};
          _allMapUsers = users.where((user) => seen.add(user.id)).toList();
          _applyFilters(setStateOnly: false);
          _rebuildMarkerCache();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching map users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    if (!hasGesture) return;
    if (position.bounds == null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchUsersInBounds(position.bounds!);
    });
  }

  void _applyFilters({bool setStateOnly = true}) {
    final filtered = _allMapUsers.where((user) {
      if (_selectedRoleFilter == 'shop' && user.role != UserRole.shop)
        return false;
      if (_selectedRoleFilter == 'freelancer' &&
          user.role != UserRole.freelancer) return false;
      if (_selectedShopCategoryFilter != null) {
        if (user.role != UserRole.shop) return false;
        if (user.shopCategory != _selectedShopCategoryFilter) return false;
      }
      if (_selectedFreelancerCategoryFilter != null) {
        if (user.role != UserRole.freelancer &&
            user.role != UserRole.techService &&
            user.role != UserRole.privateService) return false;
        if (user.jobTitle == null) return false;
        if (user.jobTitle!.toLowerCase() !=
            _selectedFreelancerCategoryFilter!.name.toLowerCase()) return false;
      }
      return true;
    }).toList();

    if (setStateOnly) {
      setState(() {
        _filteredUsers = filtered;
        _rebuildMarkerCache();
      });
    } else {
      _filteredUsers = filtered;
    }
  }

  // Pre-computed valid markers list for performance
  List<UserModel> _validMarkerUsers = [];

  void _rebuildMarkerCache() {
    _validMarkerUsers = _filteredUsers
        .where((user) => _isValidSudanCoordinate(user.latitude, user.longitude))
        .where((user) => widget.targetUser != null || user.showOnMap == true)
        .toList();
  }

  // ترجمة المسمى الوظيفي إذا كان من قائمة النظام، أو إرجاعه كما هو إذا كان مخصصاً
  String _getTranslatedSkill(String skill, bool isAr) {
    return JobTitlesUtils.getLocalizedTitle(skill, isAr ? 'ar' : 'en');
  }

  // تحديد المهنة أو تصنيف المتجر - المسمى الوظيفي الفعلي فقط
  String? _getUserProfession(UserModel user, bool isAr) {
    if (user.isShop) {
      final category = user.getShopCategoryName(isAr ? 'ar' : 'en');
      if (category.isNotEmpty) return category;
      return null;
    }
    // حرفي / تقني / خاص - المسمى الوظيفي الحقيقي فقط
    if (user.jobTitle != null && user.jobTitle!.isNotEmpty)
      return JobTitlesUtils.getLocalizedTitle(
          user.jobTitle!, isAr ? 'ar' : 'en');
    if (user.skills.isNotEmpty)
      return _getTranslatedSkill(user.skills.first,
          isAr); // أخذ المسمى الذي اختاره عند التسجيل وترجمته
    return null;
  }

  // تحديد حالة التوفر أو الفتح/الإغلاق
  bool _getUserIsActive(UserModel user) {
    if (user.isShop) return user.isShopCurrentlyOpen;
    return user.isAvailable;
  }

  String _getUserStatusText(UserModel user, bool isAr, bool isActive) {
    if (user.isShop) {
      return isActive
          ? (isAr ? 'مفتوح الآن' : 'Open Now')
          : (isAr ? 'مغلق الآن' : 'Closed Now');
    }
    return isActive
        ? (isAr ? 'متوفر' : 'Available')
        : (isAr ? 'غير متوفر' : 'Unavailable');
  }

  void _showUserPopup(UserModel user) {
    final isAr = context.read<LocaleProvider>().locale.languageCode == 'ar';
    final profession = _getUserProfession(user, isAr);
    final hasProfession = profession != null;
    final isActive = _getUserIsActive(user);
    final statusText = _getUserStatusText(user, isAr, isActive);
    final statusColor = isActive ? Colors.green : Colors.red;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GlassContainer(
        padding: const EdgeInsets.all(24),
        blur: 20,
        opacity: Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.85,
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: [
                  // صورة المستخدم
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: ClipOval(
                      child: user.profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user.profileImageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 140,
                              placeholder: (_, __) => Container(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: Icon(
                                    user.isShop ? Icons.store : Icons.person,
                                    size: 35,
                                    color: AppColors.primary),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                  user.isShop ? Icons.store : Icons.person,
                                  size: 35,
                                  color: AppColors.primary),
                            )
                          : Icon(user.isShop ? Icons.store : Icons.person,
                              size: 35, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // الاسم
                        Text(
                          user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profession != null) ...[
                          const SizedBox(height: 4),
                          // المسمى الوظيفي أو تصنيف المتجر
                          Row(
                            children: [
                              Icon(
                                user.isShop
                                    ? Icons.storefront
                                    : Icons.work_outline,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  profession,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        // حالة التوفر/الفتح (دائماً يظهر)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // التقييم
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 18, color: Colors.amber[600]),
                            const SizedBox(width: 3),
                            Text(
                              user.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              ' (${user.completedJobs} ${isAr ? 'عمل' : 'jobs'})',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bio
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                Text(
                  user.bio!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 12),
              ],

              // Skills / Tags
              if (user.skills.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.skills.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getTranslatedSkill(skill, isAr),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Location & Work Hours
              if ((user.state != null && user.state!.isNotEmpty) ||
                  (user.locality != null && user.locality!.isNotEmpty) ||
                  (user.openingHours != null && user.openingHours!.isNotEmpty))
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      // Location
                      if ((user.state != null && user.state!.isNotEmpty) ||
                          (user.locality != null && user.locality!.isNotEmpty))
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [user.state, user.locality]
                                    .where((e) => e != null && e.isNotEmpty)
                                    .join(' - '),
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),

                      // Work Hours
                      if (user.openingHours != null &&
                          user.openingHours!.isNotEmpty) ...[
                        if ((user.state != null && user.state!.isNotEmpty) ||
                            (user.locality != null &&
                                user.locality!.isNotEmpty))
                          const Divider(height: 16),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAr
                                    ? 'زمن العمل: من ${user.openingHours} إلى ${user.closingHours ?? ''}'
                                    : 'Working hours: ${user.openingHours} to ${user.closingHours ?? ''}',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              else if (user.bio != null || user.skills.isNotEmpty)
                const SizedBox(height: 8)
              else
                const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: PressableCard(
                  onTap: () {
                    if (context.mounted) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: user.id)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(isAr ? 'زيارة الملف الشخصي' : 'View Profile',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء شريط البحث
  Widget _buildSearchBar(bool isAr) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                    _isSearching = _searchQuery.isNotEmpty;
                  });
                },
                decoration: InputDecoration(
                  hintText: isAr
                      ? 'ابحث عن متجر أو حرفي...'
                      : 'Search shops or freelancers...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                            });
                            FocusScope.of(context).unfocus();
                          })
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),

            // قائمة النتائج
            if (_isSearching)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10)
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 280),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: _allMapUsers
                        .where(
                            (u) => u.name.toLowerCase().contains(_searchQuery))
                        .map((user) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: user.profileImageUrl == null
                              ? Icon(
                                  user.role == UserRole.shop
                                      ? Icons.store
                                      : Icons.person,
                                  color: AppColors.primary)
                              : null,
                        ),
                        title: Text(user.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          user.jobTitle != null && user.jobTitle!.isNotEmpty
                              ? JobTitlesUtils.getLocalizedTitle(
                                  user.jobTitle!, isAr ? 'ar' : 'en')
                              : (user.role == UserRole.shop
                                  ? (isAr ? 'متجر' : 'Shop')
                                  : (isAr ? 'حرفي' : 'Freelancer')),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _searchQuery = '';
                            _isSearching = false;
                            _searchController.clear();
                          });
                          if (user.latitude != null && user.longitude != null) {
                            // الذهاب فوراً لمكان الشخص في الخريطة وفتح بطاقته
                            _animatedMapMove(
                                LatLng(user.latitude!, user.longitude!), 16.0);
                            Future.delayed(const Duration(milliseconds: 1000),
                                () {
                              _showUserPopup(user);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isAr ? 'تصفية الخريطة' : 'Filter Map',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Text(isAr ? 'عرض:' : 'Show:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    FilterChip(
                      label: Text(isAr ? 'الكل' : 'All'),
                      selected: _selectedRoleFilter == 'all',
                      onSelected: (val) {
                        if (val)
                          setSheetState(() {
                            _selectedRoleFilter = 'all';
                            _selectedShopCategoryFilter = null;
                            _selectedFreelancerCategoryFilter = null;
                          });
                      },
                    ),
                    FilterChip(
                      label: Text(isAr ? 'المتاجر' : 'Shops'),
                      selected: _selectedRoleFilter == 'shop',
                      onSelected: (val) {
                        if (val)
                          setSheetState(() {
                            _selectedRoleFilter = 'shop';
                            _selectedFreelancerCategoryFilter = null;
                          });
                      },
                    ),
                    FilterChip(
                      label: Text(isAr ? 'الحرفيين' : 'Freelancers'),
                      selected: _selectedRoleFilter == 'freelancer',
                      onSelected: (val) {
                        if (val)
                          setSheetState(() {
                            _selectedRoleFilter = 'freelancer';
                            _selectedShopCategoryFilter = null;
                          });
                      },
                    ),
                  ],
                ),
                if (_selectedRoleFilter == 'shop') ...[
                  const SizedBox(height: 16),
                  Text(isAr ? 'تصنيف المتجر:' : 'Shop Category:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 45,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ShopCategory.values.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(UserModel.getLocalizedShopCategory(
                                cat, isAr ? 'ar' : 'en')),
                            selected: _selectedShopCategoryFilter == cat,
                            onSelected: (val) {
                              setSheetState(() {
                                _selectedShopCategoryFilter = val ? cat : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                if (_selectedRoleFilter == 'freelancer') ...[
                  const SizedBox(height: 16),
                  Text(isAr ? 'التخصص:' : 'Profession:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 45,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: JobCategory.values.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(JobTitlesUtils.getLocalizedTitle(
                                cat.name, isAr ? 'ar' : 'en')),
                            selected: _selectedFreelancerCategoryFilter == cat,
                            onSelected: (val) {
                              setSheetState(() {
                                _selectedFreelancerCategoryFilter =
                                    val ? cat : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (context.mounted) Navigator.pop(context);
                      _applyFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isAr ? 'تطبيق' : 'Apply',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.read<LocaleProvider>().locale.languageCode == 'ar';

    return Scaffold(
      extendBodyBehindAppBar:
          true, // يجعل التطبيق يغطي الشاشة بالكامل تحت الـ AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(
            color: Colors.white), // لون الأزرار أبيض ليناسب الستايل الداكن
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, left: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilterSheet,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 5.5,
              minZoom: 5.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(bounds: _sudanBounds),
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sudan.free',
                tileProvider: CachedTileProvider(),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _validMarkerUsers.map((user) {
                    final isShop = user.isShop;
                    final isPrivacyProtected = user.showOnMap != true;
                    final markerColor = isPrivacyProtected
                        ? Colors.yellow
                        : (isShop ? Colors.amber : Colors.cyanAccent);
                    return Marker(
                      key: ValueKey('marker_${user.id}'),
                      point: LatLng(user.latitude!, user.longitude!),
                      width: 50,
                      height: 50,
                      child: RepaintBoundary(
                        child: GestureDetector(
                          onTap: () {
                            _animatedMapMove(
                                LatLng(user.latitude!, user.longitude!), 16.0);
                            _showUserPopup(user);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: markerColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: markerColor.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: user.profileImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: user.profileImageUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 100,
                                      fadeInDuration:
                                          const Duration(milliseconds: 150),
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey[900],
                                        child: Icon(
                                            isShop ? Icons.store : Icons.work,
                                            color: Colors.white,
                                            size: 22),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.grey[900],
                                        child: Icon(
                                            isShop ? Icons.store : Icons.work,
                                            color: Colors.white,
                                            size: 22),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[900],
                                      child: Icon(
                                          isShop ? Icons.store : Icons.work,
                                          color: Colors.white,
                                          size: 22),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // شريط البحث المخصص
          _buildSearchBar(isAr),

          // زر "تحديد موقعي"
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'myLocationBtn',
              backgroundColor: Theme.of(context).cardColor,
              onPressed: _locateUser,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          if (_isLoading)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('جاري تحميل البيانات...',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
