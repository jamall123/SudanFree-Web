import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/sudan_locations.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/common/shimmer_placeholders.dart';
import '../../services/cloudinary_service.dart';
import '../profile/profile_screen.dart';
import '../../services/smart_search_service.dart';
import '../../widgets/inputs/smart_search_field.dart';
import '../../services/smart_guide_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/common/premium_animations.dart';

class BrowseShopsScreen extends StatefulWidget {
  const BrowseShopsScreen({super.key});

  @override
  State<BrowseShopsScreen> createState() => _BrowseShopsScreenState();
}

class _BrowseShopsScreenState extends State<BrowseShopsScreen>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String? _selectedState;
  ShopCategory? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'recommended';
  bool _showFilters = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // الحفاظ على حالة الشاشة

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().fetchShops();
      SmartGuideService.showMicroTip(
        context,
        messageAr: 'اكتشف أفضل المتاجر المحلية وتصفح أحدث عروضها ومنتجاتها 🛍️',
        messageEn:
            'Discover local shops and browse their latest products and offers 🛍️',
        tipId: 'shops_first_visit',
        icon: Icons.storefront_rounded,
      );
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<UserProvider>().fetchMoreShops();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<UserModel> _filterShops(List<UserModel> shops) {
    final filtered = shops.where((s) {
      // Hide scammers
      if (s.rating < 2.0 && s.reviewsCount >= 3) return false;

      // Smart search filter
      if (_searchQuery.isNotEmpty) {
        final matches = SmartSearchService.matchesSmartSearch(
          _searchQuery,
          name: s.name,
          skills: [],
          jobTitle: s.shopCategory?.name,
          bio: s.bio,
          state: s.state,
          locality: s.locality,
        );
        if (!matches) return false;
      }

      // Location filter
      if (_selectedState != null && s.state != _selectedState) return false;

      // Category filter
      if (_selectedCategory != null && s.shopCategory != _selectedCategory)
        return false;

      return true;
    }).toList();

    final currentUser = context.read<AuthProvider>().user;

    if (_sortBy == 'top_rated') {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'nearest' &&
        currentUser != null &&
        currentUser.latitude != null &&
        currentUser.longitude != null) {
      filtered.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;
        final distA = Geolocator.distanceBetween(currentUser.latitude!,
            currentUser.longitude!, a.latitude!, a.longitude!);
        final distB = Geolocator.distanceBetween(currentUser.latitude!,
            currentUser.longitude!, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });
    } else {
      // Sort by client interest match (matching interests appear first)
      if (currentUser != null &&
          currentUser.shopInterests.isNotEmpty &&
          _searchQuery.isEmpty &&
          _selectedCategory == null) {
        filtered.sort((a, b) {
          final aMatch = a.shopCategory != null &&
              currentUser.shopInterests.contains(a.shopCategory!.name);
          final bMatch = b.shopCategory != null &&
              currentUser.shopInterests.contains(b.shopCategory!.name);
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;
          return 0;
        });
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـ Mixin
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final userProvider = context.watch<UserProvider>();
    final shops = _filterShops(userProvider.shops);
    final hasData = userProvider.hasShops;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Smart Search Bar with autocomplete
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SmartSearchField(
                      controller: _searchController,
                      hintText: locale == 'ar'
                          ? 'ابحث عن متجر، معرض، مطعم...'
                          : 'Search for shop, showroom...',
                      searchContext: SearchContext.shops,
                      accentColor: AppColors.secondary,
                      onSearch: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: Icon(
                      Icons.tune,
                      size: 24,
                      color:
                          (_selectedState != null || _selectedCategory != null)
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Filters
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 260 : 0,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedState,
                            isExpanded: true,
                            hint: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(locale == 'ar'
                                    ? 'اختر الولاية'
                                    : 'Select Location'),
                              ],
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(locale == 'ar'
                                    ? 'كل الولايات'
                                    : 'All States'),
                              ),
                              ...SudanLocations.states.map((s) =>
                                  DropdownMenuItem(
                                      value: s,
                                      child: Text(SudanLocations.getStateName(
                                          s, locale)))),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedState = v),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Sort By Chips
                      Text(locale == 'ar' ? 'ترتيب حسب' : 'Sort by',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label:
                                  locale == 'ar' ? 'مقترح لك' : 'Recommended',
                              isSelected: _sortBy == 'recommended',
                              onTap: () =>
                                  setState(() => _sortBy = 'recommended'),
                            ),
                            _FilterChip(
                              label: locale == 'ar'
                                  ? 'الأعلى تقييماً'
                                  : 'Top Rated',
                              isSelected: _sortBy == 'top_rated',
                              onTap: () =>
                                  setState(() => _sortBy = 'top_rated'),
                            ),
                            _FilterChip(
                              label:
                                  locale == 'ar' ? 'الأقرب مسافة' : 'Nearest',
                              isSelected: _sortBy == 'nearest',
                              onTap: () {
                                final user = context.read<AuthProvider>().user;
                                if (user?.latitude == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(locale == 'ar'
                                          ? 'يجب تفعيل موقعك في ملفك الشخصي أولاً'
                                          : 'Enable location in your profile first'),
                                      backgroundColor: Colors.orange));
                                  return;
                                }
                                setState(() => _sortBy = 'nearest');
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Category Chips
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label: locale == 'ar' ? 'الكل' : 'All',
                              isSelected: _selectedCategory == null,
                              onTap: () =>
                                  setState(() => _selectedCategory = null),
                            ),
                            ...ShopCategory.values.map((cat) => _FilterChip(
                                  label: _getCategoryName(cat, locale),
                                  isSelected: _selectedCategory == cat,
                                  onTap: () =>
                                      setState(() => _selectedCategory = cat),
                                )),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_selectedState != null ||
                          _selectedCategory != null ||
                          _sortBy != 'recommended')
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _selectedState = null;
                            _selectedCategory = null;
                            _sortBy = 'recommended';
                          }),
                          icon: const Icon(Icons.clear, size: 16),
                          label: Text(locale == 'ar' ? 'مسح الفلاتر' : 'Clear'),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Results - Grid View for Shops
            Expanded(
              child: userProvider.shopError != null
                  ? _buildErrorState(context, locale, userProvider.shopError!)
                  : (!hasData && userProvider.isLoading)
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.77,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 6,
                          itemBuilder: (_, __) => const ShopCardShimmer(),
                        )
                      : shops.isEmpty && !userProvider.isLoading
                          ? _buildEmptyState(context, locale)
                          : RefreshIndicator(
                              onRefresh: () async =>
                                  userProvider.fetchShops(forceRefresh: true),
                              child: GridView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 96),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio:
                                      0.77, // More height for stability across screens
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: shops.length +
                                    (userProvider.isLoadingMoreShops ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == shops.length) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  final shop = shops[index];
                                  return ShopCard(
                                    shop: shop,
                                    locale: locale,
                                    isPromoted: userProvider.promotedUserIds
                                        .contains(shop.id),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProfileScreen(userId: shop.id),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String locale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            locale == 'ar'
                ? (_searchQuery.isNotEmpty
                    ? 'لا توجد نتائج لـ "$_searchQuery"'
                    : 'لا توجد نتائج')
                : (_searchQuery.isNotEmpty
                    ? 'No results for "$_searchQuery"'
                    : 'No results found'),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            locale == 'ar'
                ? 'جرّب كلمات أخرى أو تحقق من الإملاء'
                : 'Try different keywords or check spelling',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String locale, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              locale == 'ar'
                  ? 'حدث خطأ في جلب البيانات'
                  : 'Error fetching data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.read<UserProvider>().fetchShops(forceRefresh: true),
              child: Text(locale == 'ar' ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(ShopCategory category, String locale) {
    final names = {
      'ar': {
        ShopCategory.electronics: 'إلكترونيات',
        ShopCategory.clothing: 'ملابس',
        ShopCategory.furniture: 'أثاث',
        ShopCategory.food: 'غذائية',
        ShopCategory.restaurant: 'مطعم',
        ShopCategory.supermarket: 'سوبرماركت',
        ShopCategory.pharmacy: 'صيدلية',
        ShopCategory.beauty: 'تجميل',
        ShopCategory.automotive: 'سيارات',
        ShopCategory.building: 'بناء',
        ShopCategory.jewelry: 'مجوهرات',
        ShopCategory.mobile: 'جوالات',
        ShopCategory.bookstore: 'مكتبة',
        ShopCategory.sports: 'رياضة',
        ShopCategory.toys: 'ألعاب',
        ShopCategory.home: 'منزلية',
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
        ShopCategory.beauty: 'Beauty',
        ShopCategory.automotive: 'Auto',
        ShopCategory.building: 'Building',
        ShopCategory.jewelry: 'Jewelry',
        ShopCategory.mobile: 'Mobile',
        ShopCategory.bookstore: 'Books',
        ShopCategory.sports: 'Sports',
        ShopCategory.toys: 'Toys',
        ShopCategory.home: 'Home',
        ShopCategory.other: 'Other',
      },
    };
    return names[locale]?[category] ?? category.name;
  }
}

// Shop Card - Different design from Freelancer Card
class ShopCard extends StatelessWidget {
  final UserModel shop;
  final String locale;
  final VoidCallback onTap;
  final bool isPromoted;

  const ShopCard({
    super.key,
    required this.shop,
    required this.locale,
    required this.onTap,
    this.isPromoted = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isPromoted
              ? Border.all(
                  color: AppColors.sudanGold.withValues(alpha: 0.8), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isPromoted
                  ? AppColors.sudanGold.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Image/Cover
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: shop.coverImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: CloudinaryService.getOptimizedUrl(
                                shop.coverImageUrl!,
                                width: 400,
                                quality: 'auto'),
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            placeholder: (_, __) => Container(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              child: const Icon(Icons.store,
                                  size: 40, color: AppColors.secondary),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              child: const Icon(Icons.store,
                                  size: 40, color: AppColors.secondary),
                            ),
                          )
                        : Container(
                            color: AppColors.secondary.withValues(alpha: 0.2),
                            child: const Center(
                              child: Icon(Icons.store,
                                  size: 40, color: AppColors.secondary),
                            ),
                          ),
                  ),
                  // Category Badge
                  if (shop.shopCategory != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shop.getShopCategoryName(locale),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Open/Closed Status (only show if hours are set)
                  if (shop.openingHours != null &&
                      shop.closingHours != null &&
                      shop.openingHours!.isNotEmpty &&
                      shop.closingHours!.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: shop.isShopCurrentlyOpen
                              ? AppColors.success
                              : AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shop.isShopCurrentlyOpen
                              ? (locale == 'ar' ? 'مفتوح' : 'Open')
                              : (locale == 'ar' ? 'مغلق' : 'Closed'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Shop Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image + Name
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppColors.secondary.withValues(alpha: 0.2),
                          backgroundImage: shop.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                  CloudinaryService.getOptimizedUrl(
                                      shop.profileImageUrl!,
                                      width: 100,
                                      quality: 'auto'))
                              : null,
                          child: shop.profileImageUrl == null
                              ? const Icon(Icons.store,
                                  size: 14, color: AppColors.secondary)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            shop.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPromoted)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.star_rounded,
                                color: AppColors.sudanGold, size: 16),
                          ),
                      ],
                    ),

                    // Bio
                    if (shop.bio != null && shop.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          shop.bio!,
                          maxLines:
                              1, // Reduced to 1 to leave room for location/rating
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    height: 1.1,
                                    fontSize: 10,
                                  ),
                        ),
                      ),

                    const Spacer(), // Pushes location and rating to the bottom

                    // Location
                    if (shop.state != null)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 10,
                              color: Theme.of(context)
                                  .iconTheme
                                  .color
                                  ?.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              SudanLocations.getStateName(shop.state!, locale),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    // Rating
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 12, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text(
                          shop.ratingDisplay,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        Text(
                          ' (${shop.reviewsCount})',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.textSecondary),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
