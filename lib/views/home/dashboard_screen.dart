import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/posts_provider.dart';
import '../../models/user_model.dart';
import '../../models/ad_model.dart';
import '../../services/firestore/ad_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/notification_polling_service.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../core/routes/premium_page_route.dart';
import '../search/smart_search_delegate.dart';
import '../settings/settings_screen.dart';
import 'ad_details_screen.dart';
import 'filtered_providers_screen.dart';
import '../map/map_explorer_screen.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../core/utils/job_titles_utils.dart';
import '../../widgets/common/glass_container.dart';
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AdModel> _homeBannerAds = [];
  List<AdModel> _stripAds = [];
  int _currentBannerAdIndex = 0;
  bool _isLoadingAds = true;
  final AdService _adService = AdService();
  PageController? _bannerPageController;
  Timer? _bannerAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAds();
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        NotificationPollingService().setUserId(authProvider.user!.id);
        authProvider.fetchPartners();
      }
    });
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    if (_homeBannerAds.length <= 1) return;
    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _homeBannerAds.isEmpty || _bannerPageController == null)
        return;
      final nextPage = (_currentBannerAdIndex + 1) % _homeBannerAds.length;
      _bannerPageController!.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _fetchAds() async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;
    setState(() => _isLoadingAds = true);
    final homeBannerAds = await _adService
        .getAdsForPlacement(currentUser, AdPlacement.homeBanner, limit: 4);
    final stripAds = await _adService
        .getAdsForPlacement(currentUser, AdPlacement.strip, limit: 1);
    if (!mounted) return;
    setState(() {
      _homeBannerAds = homeBannerAds;
      _stripAds = stripAds;
      _currentBannerAdIndex = 0;
      _isLoadingAds = false;
    });
    if (_homeBannerAds.isNotEmpty) {
      _adService.recordImpression(_homeBannerAds[0].id);
    }
    if (_stripAds.isNotEmpty) {
      _adService.recordImpression(_stripAds[0].id);
    }
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerAutoScrollTimer?.cancel();
    _bannerPageController?.dispose();
    super.dispose();
  }

  String _getStoreTypeDisplay(UserModel u, String locale) {
    if (u.shopCategory == ShopCategory.beauty)
      return locale == 'ar' ? 'تجميل' : 'Beauty';
    // Since we don't have an explicit 'online'/'local' field in UserModel, we assume local by default,
    // or maybe based on if they have a physical address? Let's just use local unless online is specified in their bio/title
    final isOnline = u.bio?.toLowerCase().contains('online') == true ||
        u.jobTitle?.toLowerCase().contains('online') == true;
    if (isOnline) return locale == 'ar' ? 'متجر إلكتروني' : 'Online Store';
    return locale == 'ar' ? 'متجر محلي' : 'Local Store';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUser = authProvider.user;
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allPartners = authProvider.partners.take(15).toList();
    final storyUsers = [
      ...allPartners.where((u) => u.isOnline),
      ...allPartners.where((u) => !u.isOnline),
    ];

    final nearbyShops = userProvider.shops
        .where((s) => currentUser.state == null || s.state == currentUser.state)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final nearbyFreelancers = userProvider.freelancers
        .where((f) => currentUser.state == null || f.state == currentUser.state)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    Theme.of(context).primaryColor.withValues(alpha: 0.15)
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            _fetchAds();
            userProvider.fetchFreelancers(forceRefresh: true);
            userProvider.fetchShops(forceRefresh: true);
            authProvider.fetchPartners(forceRefresh: true);
          },
          child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.3),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    builder: (_) => const SettingsScreen(asBottomSheet: true),
                  );
                },
              ),
              title: Text(
                locale == 'ar' ? 'سودان فري' : 'SudanFree',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MapExplorerScreen()));
                  },
                  icon: const Icon(Icons.map_outlined),
                ),
                Consumer<NotificationPollingService>(
                  builder: (context, pollingService, _) {
                    final count = pollingService.unreadCount;
                    return IconButton(
                      onPressed: () => Navigator.push(context,
                          PremiumPageRoute(page: const NotificationsScreen())),
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : count.toString()),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      PremiumPageRoute(
                          page: ProfileScreen(userId: currentUser.id))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      backgroundImage: currentUser.profileImageUrl != null
                          ? CachedNetworkImageProvider(
                              CloudinaryService.getOptimizedUrl(
                                  currentUser.profileImageUrl!,
                                  width: 100,
                                  quality: 'auto'))
                          : null,
                      child: currentUser.profileImageUrl == null
                          ? const Icon(Icons.person,
                              size: 18) // ✅ Changed back to person
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(30),
                  padding: EdgeInsets.zero,
                  child: TextField(
                    readOnly: true,
                    onTap: () => showSearch(
                        context: context, delegate: SmartSearchDelegate()),
                    decoration: InputDecoration(
                      hintText: locale == 'ar'
                          ? 'ابحث في سودان فري...'
                          : 'Search SudanFree...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoadingAds)
              const SliverToBoxAdapter(
                child: SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator())),
              )
            else if (_homeBannerAds.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _bannerPageController,
                    onPageChanged: (index) =>
                        setState(() => _currentBannerAdIndex = index),
                    itemCount: _homeBannerAds.length,
                    itemBuilder: (context, index) {
                      final ad = _homeBannerAds[index];
                      return GestureDetector(
                        onTap: () {
                          _adService.recordImpression(ad.id);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AdDetailsScreen(ad: ad)));
                        },
                        child: GlassCard(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          borderRadius: 16,
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                OptimizedNetworkImage(
                                  imageUrl: ad.mediaUrl,
                                  quality: ImageQuality.medium,
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.7),
                                        Colors.transparent
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ad.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GlassContainer(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                          locale == 'ar'
                                              ? 'إعلان ممول'
                                              : 'Sponsored',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
                ),
              ),


            // ✅ Improved Quick Access Buttons (Horizontal scroll, small cards)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 74,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCompactActionCard(
                            context,
                            locale == 'ar' ? 'خدمات' : 'Services',
                            Icons.handyman,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredProvidersScreen(
                                        filterType: FilterType.freelancersNearYou,
                                        title: locale == 'ar'
                                            ? 'خدمات'
                                            : 'Services')))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactActionCard(
                            context,
                            locale == 'ar' ? 'متاجر' : 'Shops',
                            Icons.storefront,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredProvidersScreen(
                                        filterType: FilterType.shops,
                                        title: locale == 'ar' ? 'متاجر' : 'Shops')))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactActionCard(
                            context,
                            locale == 'ar' ? 'الجديد' : 'New',
                            Icons.fiber_new,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredProvidersScreen(
                                        filterType: FilterType.newest,
                                        title: locale == 'ar' ? 'الجديد' : 'New')))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactActionCard(
                            context,
                            locale == 'ar' ? 'الأعلى' : 'Top',
                            Icons.star,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredProvidersScreen(
                                        filterType: FilterType.topRated,
                                        title: locale == 'ar'
                                            ? 'الأعلى تقييماً'
                                            : 'Top Rated')))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactActionCard(
                            context,
                            locale == 'ar' ? 'الأقرب' : 'Nearest',
                            Icons.location_on,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredProvidersScreen(
                                        filterType: FilterType.nearYou,
                                        title: locale == 'ar'
                                            ? 'الأقرب'
                                            : 'Nearest')))),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            _buildSectionHeader(
                locale == 'ar' ? 'خدمات في منطقتك' : 'Services Near You',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FilteredProvidersScreen(
                            filterType: FilterType.freelancersNearYou,
                            title: locale == 'ar'
                                ? 'خدمات في منطقتك'
                                : 'Services Near You')))),
            SliverToBoxAdapter(
              child: userProvider.isLoading
                  ? _buildShimmerList()
                  : _buildHorizontalUserList(
                      context, nearbyFreelancers.take(10).toList(), locale),
            ),
            _buildSectionHeader(
                locale == 'ar' ? 'متاجر في منطقتك' : 'Shops Near You',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FilteredProvidersScreen(
                            filterType: FilterType.shopsNearYou,
                            title: locale == 'ar'
                                ? 'متاجر في منطقتك'
                                : 'Shops Near You')))),
            SliverToBoxAdapter(
              child: userProvider.isLoading
                  ? _buildShimmerList()
                  : _buildHorizontalUserList(
                      context, nearbyShops.take(10).toList(), locale),
            ),
            if (_stripAds.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      _adService.recordClick(_stripAds[0].id);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdDetailsScreen(ad: _stripAds[0])));
                    },
                    child: GlassContainer(
                      blur: 10,
                      opacity: 0.8,
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: _stripAds[0].mediaUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // ✅ Removed Community Section completely from DashboardScreen
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      ),
    );
  }

  // ✅ New Compact Action Card (70x70)
  Widget _buildCompactActionCard(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        height: 70,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                  context.read<LocaleProvider>().locale.languageCode == 'ar'
                      ? 'عرض الكل'
                      : 'See All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, __) => GlassContainer(
          width: 140,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildHorizontalUserList(
      BuildContext context, List<UserModel> users, String locale) {
    if (users.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(
                locale == 'ar' ? 'لا توجد بيانات حالياً' : 'No data available',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 170, // ✅ Increased height slightly to accommodate the distinctive layout
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final u = users[index];
          final String translatedJobTitle =
              (u.jobTitle != null && u.jobTitle!.isNotEmpty)
                  ? JobTitlesUtils.getLocalizedTitle(u.jobTitle!, locale)
                  : (u.skills.isNotEmpty
                      ? JobTitlesUtils.getLocalizedTitle(u.skills.first, locale)
                      : '');

          // ✅ FIX #4: RepaintBoundary isolates each card's GPU layer
          return RepaintBoundary(
            child: GestureDetector(
            onTap: () => Navigator.push(
                context, PremiumPageRoute(page: ProfileScreen(userId: u.id))),
            child: GlassCard(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              borderRadius: 16,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: u.isShop ? 150 : 130, // Shops are slightly wider
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: u.profileImageUrl != null
                                ? OptimizedNetworkImage(
                                    imageUrl: u.profileImageUrl!,
                                    quality: ImageQuality.thumbnail,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    child: Icon(
                                      u.isShop ? Icons.storefront : Icons.person,
                                      size: 40,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                          // Badge Overlay
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              borderRadius: BorderRadius.circular(8),
                              color: u.isShop ? Colors.blue.withValues(alpha: 0.8) : Colors.green.withValues(alpha: 0.8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(u.isShop ? Icons.store : Icons.handyman, size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    u.isShop ? (locale == 'ar' ? 'متجر' : 'Shop') : (locale == 'ar' ? 'حرفي' : 'Artisan'),
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              u.isShop
                                  ? u.getShopCategoryName(locale)
                                  : translatedJobTitle,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (u.isShop)
                              Text(
                                _getStoreTypeDisplay(u, locale),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.7),
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                              ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 12, color: Colors.orange),
                                    const SizedBox(width: 2),
                                    Text(u.rating.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ), // Close GestureDetector
          ); // Close RepaintBoundary
        },
      ),
    );
  }
}
