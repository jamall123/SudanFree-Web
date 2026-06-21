import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/sudan_locations.dart';
import '../../models/user_model.dart';
import '../../models/job_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/cards/freelancer_card.dart';
import '../../widgets/common/shimmer_placeholders.dart';
import '../profile/profile_screen.dart';
import '../../widgets/common/staggered_animated_widget.dart';
import '../../services/smart_search_service.dart';
import '../../widgets/inputs/smart_search_field.dart';
import '../../services/smart_guide_service.dart';
import 'package:geolocator/geolocator.dart';

class BrowseFreelancersScreen extends StatefulWidget {
  const BrowseFreelancersScreen({super.key});

  @override
  State<BrowseFreelancersScreen> createState() =>
      _BrowseFreelancersScreenState();
}

class _BrowseFreelancersScreenState extends State<BrowseFreelancersScreen>
    with AutomaticKeepAliveClientMixin {
  String? _selectedState;
  JobCategory? _selectedCategory;
  bool _showFilters = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recommended';

  @override
  bool get wantKeepAlive => true; // الحفاظ على الحالة عند التنقل

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().fetchFreelancers();
      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'استكشف نخبة الحرفيين واضغط على أي ملف لبدء التواصل فوراً 📱',
        messageEn:
            'Explore top professionals and tap any profile to connect instantly 📱',
        tipId: 'freelancers_first_visit',
        icon: Icons.touch_app_rounded,
      );
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<UserProvider>().fetchMoreFreelancers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterFreelancers(List<UserModel> freelancers) {
    final filtered = freelancers.where((f) {
      // Hide scammers
      if (f.rating < 2.0 && f.reviewsCount >= 3) return false;
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final matches = SmartSearchService.matchesSmartSearch(
          _searchQuery,
          name: f.name,
          skills: f.skills,
          jobTitle: f.jobTitle,
          bio: f.bio,
          state: f.state,
          locality: f.locality,
        );
        if (!matches) return false;
      }
      // Location filter (Tech Services are remote and should appear anywhere)
      if (_selectedState != null) {
        if (f.role != UserRole.techService && f.state != _selectedState) {
          return false;
        }
      }
      // Category filter
      if (_selectedCategory != null &&
          !f.skills.contains(_selectedCategory!.name)) return false;
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
          currentUser.serviceInterests.isNotEmpty &&
          _searchQuery.isEmpty &&
          _selectedCategory == null) {
        filtered.sort((a, b) {
          final aMatch =
              a.skills.any((s) => currentUser.serviceInterests.contains(s));
          final bMatch =
              b.skills.any((s) => currentUser.serviceInterests.contains(s));
          if (aMatch && !bMatch) return -1;
          if (!aMatch && bMatch) return 1;
          return 0;
        });
      }
    }
    return filtered;
  }

  Widget _buildAverageCostBanner(
      List<UserModel> filteredFreelancers, String locale) {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();

    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return const SizedBox.shrink();

    final withRates = filteredFreelancers
        .where((f) => f.hourlyRate != null && f.hourlyRate! > 0)
        .toList();
    if (withRates.isEmpty) return const SizedBox.shrink();

    // 1. Try Locality
    var localRates =
        withRates.where((f) => f.locality == currentUser.locality).toList();
    String locationText = locale == 'ar'
        ? 'في منطقتك (${currentUser.locality ?? ''})'
        : 'in your locality (${currentUser.locality ?? ''})';

    // 2. Try State if Locality is empty
    if (localRates.isEmpty && currentUser.state != null) {
      localRates =
          withRates.where((f) => f.state == currentUser.state).toList();
      locationText = locale == 'ar'
          ? 'في ولايتك (${currentUser.state})'
          : 'in your state (${currentUser.state})';
    }

    // 3. Fallback to all
    if (localRates.isEmpty) {
      localRates = withRates;
      locationText = locale == 'ar' ? 'بشكل عام' : 'in general';
    }

    final average =
        localRates.map((f) => f.hourlyRate!).reduce((a, b) => a + b) /
            localRates.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locale == 'ar'
                  ? 'سيكلفك طلب هذه الخدمة بالتقريب ${average.toStringAsFixed(0)} SDG للساعة $locationText.'
                  : 'Requesting this service will cost you approximately ${average.toStringAsFixed(0)} SDG/hr $locationText.',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 13,
                  height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب لـ AutomaticKeepAliveClientMixin
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final userProvider = context.watch<UserProvider>();
    final freelancers = _filterFreelancers(userProvider.freelancers);
    // عرض البيانات فوراً إذا كانت موجودة
    final hasData = userProvider.hasFreelancers;

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
                          ? 'ابحث عن فني، كهربائي، مدرس...'
                          : 'Search freelancer...',
                      searchContext: SearchContext.freelancers,
                      accentColor: AppColors.primary,
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
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            _buildAverageCostBanner(freelancers, locale),

            // Expandable Filters
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
                            ...JobCategory.values.map((cat) => _FilterChip(
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

            // Results
            Expanded(
              child: userProvider.freelancerError != null
                  ? _buildErrorState(
                      context, locale, userProvider.freelancerError!)
                  : (!hasData && userProvider.isLoading)
                      ? ListView.builder(
                          itemCount: 6,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (_, __) => const FreelancerCardShimmer(),
                        )
                      : freelancers.isEmpty && !userProvider.isLoading
                          ? _buildEmptyState(context, locale)
                          : RefreshIndicator(
                              onRefresh: () async => userProvider
                                  .fetchFreelancers(forceRefresh: true),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 96),
                                itemCount: freelancers.length +
                                    (userProvider.isLoadingMoreFreelancers
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index == freelancers.length) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  final freelancer = freelancers[index];
                                  final currentUser =
                                      context.read<AuthProvider>().user;
                                  return StaggeredAnimatedWidget(
                                    key:
                                        ValueKey('freelancer_${freelancer.id}'),
                                    index: index,
                                    listId: 'freelancers_list',
                                    child: FreelancerCard(
                                      freelancer: freelancer,
                                      locale: locale,
                                      currentUserId: currentUser?.id,
                                      currentUserName: currentUser?.name,
                                      isPromoted: userProvider.promotedUserIds
                                          .contains(freelancer.id),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                              userId: freelancer.id),
                                        ),
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
              onPressed: () => context
                  .read<UserProvider>()
                  .fetchFreelancers(forceRefresh: true),
              child: Text(locale == 'ar' ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(JobCategory category, String locale) {
    // Create a dummy job model to access the helper method
    final job = JobModel(
      id: '',
      clientId: '',
      clientName: '',
      title: '',
      description: '',
      category: category,
      budgetMin: 0,
      budgetMax: 0,
      deadline: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return job.getCategoryDisplayName(locale);
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
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
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
