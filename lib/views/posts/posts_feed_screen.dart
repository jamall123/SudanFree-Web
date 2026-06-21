import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/posts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../models/post_model.dart';
import '../../widgets/common/shimmer_placeholders.dart';
import '../../widgets/cards/post_card.dart';
import '../../widgets/common/staggered_animated_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import 'create_post_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../services/firestore/ad_service.dart';
import '../../models/ad_model.dart';
import '../../views/widgets/ad_widget.dart';
import '../../views/home/ad_details_screen.dart';
import '../../widgets/inputs/smart_search_field.dart';
import '../../services/smart_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'post_details_screen.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/buttons/smart_draggable_fab.dart';
import '../../widgets/common/glass_container.dart';

class PostsFeedScreen extends StatefulWidget {
  const PostsFeedScreen({super.key});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  PostCategoryGroup? _selectedGroup;
  PostCategoryGroup? _pinnedGroup;
  bool _showSearch = false;
  Timer? _heartbeatTimer;
  Timer? _scrollDebounceTimer;

  // ── Smart Ad System ──
  List<AdModel> _ads = []; // جميع الإعلانات النشطة
  bool _isFirstLoad = true; // تحديد موضع الإعلان عند التحميل الأول
  final _random = Random();
  final AdService _adService = AdService();
  final _fs = FirestoreService(); // singleton — لا تُنشئ في كل build

  // ── Cached Mixed Feed (avoid recalculating on every build) ──
  List<dynamic>? _cachedMixedFeed;
  int _lastPostsHashCode = 0;
  int _lastAdsHashCode = 0;

  // ── Category Lookup Map (avoid O(n) firstWhere in filter) ──
  static final Map<String, PostCategory> _categoryLookup = {
    for (final cat in PostCategory.values) cat.name: cat,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPinnedCategory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchPartners();
      _fetchAds();
      _sendHeartbeat();
      _heartbeatTimer =
          Timer.periodic(const Duration(minutes: 15), (_) => _sendHeartbeat());

      final user = context.read<AuthProvider>().user;
      final isClient = user?.role == UserRole.client;

      SmartGuideService.showMicroTip(
        context,
        messageAr: isClient
            ? 'استلهم أفكاراً جديدة من أحدث الأعمال، وتفاعل مع المبدعين ✨'
            : 'اجعل أعمالك تتحدث عنك! شارك إبداعاتك لتلفت انتباه العملاء 🚀',
        messageEn: isClient
            ? 'Get inspired by the latest work and interact with creators ✨'
            : 'Let your work speak for you! Share your creations to attract clients 🚀',
        tipId: 'community_first_visit',
        icon: Icons.forum_rounded,
      );
    });

    // Infinite scroll is now handled via NotificationListener in the build method
  }

  Future<void> _loadPinnedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedGroupStr = prefs.getString('pinned_category_group');
    if (pinnedGroupStr != null) {
      try {
        _selectedGroup = PostCategoryGroup.values
            .firstWhere((e) => e.name == pinnedGroupStr);
        _pinnedGroup = _selectedGroup;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {});
      context.read<PostsProvider>().fetchPosts(categoryGroup: _selectedGroup);
    }
  }

  Future<void> _pinCategory(PostCategoryGroup? group,
      {bool isUnpin = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (group == null) {
      await prefs.remove('pinned_category_group');
      HapticFeedback.lightImpact();
    } else {
      await prefs.setString('pinned_category_group', group.name);
      HapticFeedback.mediumImpact();
    }

    if (!mounted) return;

    final locale = context.read<LocaleProvider>().locale.languageCode;
    setState(() {
      _pinnedGroup = group;
    });

    final msgAr = isUnpin
        ? 'تم إلغاء تثبيت الفئة'
        : 'تم تثبيت هذه الفئة لتكون الافتراضية 📌';
    final msgEn =
        isUnpin ? 'Category unpinned' : 'Category pinned as default 📌';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(locale == 'ar' ? msgAr : msgEn),
        backgroundColor: isUnpin ? Colors.grey[800] : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchAds() async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    try {
      final ads = await _adService.getAdsForPlacement(
        currentUser,
        AdPlacement.communityFeed,
        limit: 8, // جلب حتى 8 إعلانات لتوزيعها في التغذية
      );
      if (mounted) {
        setState(() {
          _ads = ads;
        });
        // تسجيل الظهور لكل إعلان
        for (final ad in ads) {
          _adService.recordImpression(ad.id);
        }
      }
    } catch (e) {
      debugPrint('PostsFeed: Error fetching ads: $e');
    }
  }

  /// يبني قائمة مدمجة من المنشورات والإعلانات بشكل ذكي (مع تخزين مؤقت)
  List<dynamic> _buildMixedFeed(
      List<PostModel> originalPosts, List<String> promotedIds) {
    // 1. Reorder posts: 70% promoted, 30% normal
    final List<PostModel> posts = [];
    final promoted =
        originalPosts.where((p) => promotedIds.contains(p.userId)).toList();
    final normal =
        originalPosts.where((p) => !promotedIds.contains(p.userId)).toList();

    int pIdx = 0;
    int nIdx = 0;
    while (pIdx < promoted.length || nIdx < normal.length) {
      // Take up to 7 promoted
      for (int i = 0; i < 7 && pIdx < promoted.length; i++) {
        posts.add(promoted[pIdx++]);
      }
      // Take up to 3 normal
      for (int i = 0; i < 3 && nIdx < normal.length; i++) {
        posts.add(normal[nIdx++]);
      }
    }

    if (_ads.isEmpty || _searchQuery.isNotEmpty) return posts;

    // Check if we can reuse cached result
    final postsHash = posts.length.hashCode ^
        (posts.isNotEmpty ? posts.first.id.hashCode : 0);
    final adsHash = _ads.length.hashCode;
    if (_cachedMixedFeed != null &&
        postsHash == _lastPostsHashCode &&
        adsHash == _lastAdsHashCode) {
      return _cachedMixedFeed!;
    }

    final List<dynamic> mixed = [];
    int adIndex = 0;

    // ─ التحميل الأول: الإعلان في الأعلى مباشرة (index 0)
    if (_isFirstLoad && adIndex < _ads.length) {
      mixed.add(_ads[adIndex++]);
    }

    // ─ باقي المنشورات مع توزيع الإعلانات بشكل عشوائي (4–8 منشورات)
    int nextAdAfter =
        _isFirstLoad ? (4 + _random.nextInt(5)) : (2 + _random.nextInt(3));
    int postsSinceLastAd = 0;

    for (final post in posts) {
      mixed.add(post);
      postsSinceLastAd++;

      if (adIndex < _ads.length && postsSinceLastAd >= nextAdAfter) {
        mixed.add(_ads[adIndex++]);
        postsSinceLastAd = 0;
        nextAdAfter = 4 + _random.nextInt(5);
      }
    }

    // تأكد من ظهور إعلان واحد على الأقل إذا كانت المنشورات قليلة جداً
    if (adIndex == 0 && _ads.isNotEmpty && posts.isNotEmpty) {
      mixed.add(_ads[adIndex++]);
    }

    // Cache the result
    _cachedMixedFeed = mixed;
    _lastPostsHashCode = postsHash;
    _lastAdsHashCode = adsHash;

    return mixed;
  }

  void _sendHeartbeat() {
    final uid = context.read<AuthProvider>().user?.id;
    if (uid != null) _fs.updateLastActive(uid);
  }

  /// Freshness + Engagement score: كل تفاعل يضيف ساعتين افتراضيتين
  static int _sortScore(PostModel p) =>
      p.createdAt.millisecondsSinceEpoch +
      ((p.totalReactions + p.commentsCount) * 7200000);

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<PostModel> _filterPosts(List<PostModel> posts) {
    final blockedUsers = context.read<AuthProvider>().user?.blockedUsers ?? [];

    final filtered = posts.where((post) {
      if (blockedUsers.contains(post.userId)) return false;
      if (_searchQuery.isNotEmpty) {
        final query =
            SmartSearchService.normalizeArabic(_searchQuery.toLowerCase());
        final postCaption = post.caption != null
            ? SmartSearchService.normalizeArabic(post.caption!.toLowerCase())
            : '';
        final postUser =
            SmartSearchService.normalizeArabic(post.userName.toLowerCase());
        if (!postCaption.contains(query) && !postUser.contains(query))
          return false;
      }
      if (_selectedGroup != null) {
        if (post.category == null) return false;
        // O(1) lookup instead of O(n) firstWhere
        final postCat = _categoryLookup[post.category];
        if (postCat != null) {
          if (postCat.group != _selectedGroup) return false;
        } else {
          // Fallback: Check if the raw string matches the group name directly
          if (post.category != _selectedGroup!.name) return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => _sortScore(b).compareTo(_sortScore(a)));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final postsProvider = context.watch<PostsProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final allPosts = postsProvider.posts;
    final posts = _filterPosts(allPosts);

    // Restrict clients from posting
    final bool canPost =
        currentUser != null && currentUser.role != UserRole.client;

    return Scaffold(
      body: Stack(
        children: [
          // 1. المحتوى الرئيسي
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // App Bar (Match reference image exactly for RTL)
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    elevation: 0,
                    centerTitle: false,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: Text(
                      locale == 'ar' ? 'المجتمع' : 'Community',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.search,
                            color: Theme.of(context).iconTheme.color),
                        onPressed: () {
                          setState(() {
                            _showSearch = !_showSearch;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Search Bar (expandable)
                  if (_showSearch)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            // Smart Search Input with autocomplete
                            SmartSearchField(
                              controller: _searchController,
                              hintText: locale == 'ar'
                                  ? 'ابحث في المنشورات...'
                                  : 'Search posts...',
                              searchContext: SearchContext.community,
                              accentColor: AppColors.primary,
                              onSearch: (val) =>
                                  setState(() => _searchQuery = val),
                            ),
                            const SizedBox(height: 6),
                            // Category Group Chips
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildCategoryChip(
                                    locale == 'ar' ? 'الكل' : 'All',
                                    _selectedGroup == null,
                                    () {
                                      setState(() => _selectedGroup = null);
                                      _fetchAds();
                                      context
                                          .read<PostsProvider>()
                                          .fetchPosts(categoryGroup: null);
                                    },
                                    onLongPress: () {
                                      if (_pinnedGroup == null) return;
                                      _pinCategory(null, isUnpin: true);
                                      setState(() => _selectedGroup = null);
                                      context
                                          .read<PostsProvider>()
                                          .fetchPosts(categoryGroup: null);
                                    },
                                    isPinned: _pinnedGroup == null,
                                  ),
                                  ...PostCategoryGroup.values.map((group) {
                                    return _buildCategoryChip(
                                      group.getName(locale),
                                      _selectedGroup == group,
                                      () {
                                        setState(() => _selectedGroup = group);
                                        _fetchAds();
                                        context
                                            .read<PostsProvider>()
                                            .fetchPosts(categoryGroup: group);
                                      },
                                      onLongPress: () {
                                        if (_pinnedGroup == group) {
                                          _pinCategory(null, isUnpin: true);
                                          setState(() => _selectedGroup = null);
                                          context
                                              .read<PostsProvider>()
                                              .fetchPosts(categoryGroup: null);
                                        } else {
                                          _pinCategory(group);
                                          setState(
                                              () => _selectedGroup = group);
                                          context
                                              .read<PostsProvider>()
                                              .fetchPosts(categoryGroup: group);
                                        }
                                      },
                                      isPinned: _pinnedGroup == group,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Trending Posts Section
                  if (postsProvider.trendingPosts.isNotEmpty &&
                      _selectedGroup == null &&
                      _searchQuery.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildTrendingSection(
                          context, postsProvider.trendingPosts, locale),
                    ),
                ],
                body: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    // ── التحميل المبكر: يبدأ قبل 800px من النهاية ──
                    // يضمن أن البيانات تكون جاهزة قبل أن يصل المستخدم للحافة
                    if (scrollInfo.metrics.pixels >=
                        scrollInfo.metrics.maxScrollExtent - 800) {
                      _scrollDebounceTimer?.cancel();
                      _scrollDebounceTimer =
                          Timer(const Duration(milliseconds: 200), () {
                        if (mounted &&
                            !context.read<PostsProvider>().isLoadingMore &&
                            context.read<PostsProvider>().hasMore) {
                          context.read<PostsProvider>().fetchMorePosts();
                        }
                      });
                    }
                    return false;
                  },
                  child: (postsProvider.isLoading && !postsProvider.hasPosts)
                      ? ListView.builder(
                          itemCount: 4,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (_, __) => const PostCardShimmer(),
                        )
                      : posts.isEmpty && !postsProvider.isLoading
                          ? _searchQuery.isNotEmpty || _selectedGroup != null
                              ? _buildNoSearchResults(context, locale)
                              : _buildEmptyState(context, locale, canPost)
                          : RefreshIndicator(
                              onRefresh: () async {
                                setState(() => _isFirstLoad = false);
                                _fetchAds();
                                return postsProvider.fetchPosts(
                                    forceRefresh: true);
                              },
                              child: Builder(builder: (context) {
                                final promotedIds = context
                                    .read<UserProvider>()
                                    .promotedUserIds;
                                final mixedFeed =
                                    _buildMixedFeed(posts, promotedIds);
                                final bottomInset =
                                    MediaQuery.of(context).padding.bottom;
                                final navBarMargin = bottomInset > 30
                                    ? bottomInset + 8
                                    : bottomInset + 14;
                                const navBarHeight = 62.0;
                                final navBarTop = navBarMargin + navBarHeight;

                                return ListView.builder(
                                  key: const PageStorageKey('posts_feed_list'),
                                  padding: EdgeInsets.only(
                                      top: 6, bottom: navBarTop + 80),
                                  cacheExtent:
                                      1200, // زيادة العمق المخزَّن للتمرير السلس
                                  itemCount:
                                      mixedFeed.length + 1, // +1 للـ footer
                                  itemBuilder: (context, index) {
                                    // ── Footer: مؤشر التحميل في الأسفل فقط ──
                                    // يظهر تحت آخر منشور بدون أي layout shift
                                    if (index == mixedFeed.length) {
                                      return postsProvider.isLoadingMore
                                          ? const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 24),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2.5),
                                                ),
                                              ),
                                            )
                                          : postsProvider.hasMore
                                              ? const SizedBox(height: 8)
                                              : Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 20),
                                                  child: Center(
                                                    child: Text(
                                                      '',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 12),
                                                    ),
                                                  ),
                                                );
                                    }

                                    final item = mixedFeed[index];

                                    if (item is AdModel) {
                                      return ClipRect(
                                        key: ValueKey('ad_${item.id}'),
                                        child: AdWidget(
                                          ad: item,
                                          onTap: () {
                                            _adService.recordClick(item.id);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      AdDetailsScreen(
                                                          ad: item)),
                                            );
                                          },
                                        ),
                                      );
                                    }

                                    final post = item as PostModel;
                                    final postIndex = mixedFeed
                                        .sublist(0, index)
                                        .whereType<PostModel>()
                                        .length;

                                    return Column(
                                      key: ValueKey('post_${post.id}'),
                                      children: [
                                        StaggeredAnimatedWidget(
                                          index: postIndex,
                                          listId: 'posts_feed',
                                          child: PostCard(
                                            post: post,
                                            currentUserId:
                                                currentUser?.id ?? '',
                                            locale: locale,
                                            isPromoted: promotedIds
                                                .contains(post.userId),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  },
                                );
                              }),
                            ),
                ),
              ),
            ),
          ),

          // 2. زر النشر الذكي والمتحرك
          if (canPost)
            SmartDraggableFab(
              heroTag: 'create_post_fab',
              icon: Icons.add_photo_alternate_outlined,
              locale: locale,
              initialBottom: MediaQuery.of(context).padding.bottom +
                  82.0, // navBar + safe area
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePostScreen(
                      showInCommunity: true,
                      showInProfile: false,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap,
      {VoidCallback? onLongPress, bool isPinned = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          borderRadius: BorderRadius.circular(20),
          blur: 15,
          opacity: isSelected
              ? (Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.4)
              : (Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.2),
          color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
          border: Border.all(
              color:
                  AppColors.primary.withValues(alpha: isSelected ? 0.5 : 0.1)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutBack,
                child: isPinned
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      )
                    : const SizedBox(width: 0),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : AppColors.textSecondary),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(BuildContext context, String locale) {
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

  Widget _buildEmptyState(BuildContext context, String locale, bool canPost) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyStateWidget(
      icon: Icons.photo_library_rounded,
      title: l10n.noPosts,
      subtitle: canPost ? l10n.beFirstToShare : l10n.followToSeePosts,
      actionLabel: canPost ? l10n.createPost : null,
      onAction: canPost
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
            }
          : null,
    );
  }

  Widget _buildTrendingSection(
      BuildContext context, List<PostModel> trendingPosts, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trendingPosts.length,
            itemBuilder: (context, index) {
              final post = trendingPosts[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primary.withValues(alpha: 0.1),
                  image: post.allImageUrls.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                              post.allImageUrls.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PostDetailsScreen(post: post)));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: post.userImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      post.userImageUrl!)
                                  : null,
                              child: post.userImageUrl == null
                                  ? const Icon(Icons.person,
                                      size: 14, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (post.caption != null &&
                                  post.caption!.isNotEmpty)
                                Text(
                                  post.caption!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                post.userName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
}
