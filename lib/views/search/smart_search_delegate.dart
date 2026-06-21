import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/search_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/cards/freelancer_card.dart';
import '../../widgets/common/loading_widget.dart';
import '../profile/profile_screen.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/smart_search_service.dart';
import '../freelancers/browse_freelancers_screen.dart';
import '../shops/browse_shops_screen.dart';
import '../../widgets/common/glass_container.dart';
import '../../providers/theme_provider.dart';

class SmartSearchDelegate extends SearchDelegate<UserModel?> {
  final String? initialQuery;
  UserRole? selectedRole;

  // ─── Cache to prevent re-fetch when returning from a profile ───
  List<UserModel>? _cachedResults;
  String? _cachedQuery;
  UserRole? _cachedRole;

  SmartSearchDelegate({this.initialQuery})
      : super(searchFieldLabel: 'ابحث عن مهارات، حرفيين، مواقع...');

  @override
  String get searchFieldLabel =>
      super.searchFieldLabel ?? 'ابحث عن مهارات، حرفيين، مواقع...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _cachedResults = null;
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  bool get _isSameSearch =>
      _cachedResults != null &&
      _cachedQuery == query &&
      _cachedRole == selectedRole;

  @override
  Widget buildResults(BuildContext context) {
    final searchProvider = context.read<SearchProvider>();
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final currentUser = context.read<AuthProvider>().user;

    // ── Use cached results if query/role hasn't changed ──
    if (_isSameSearch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilters(context),
          Expanded(
            child: _buildResultsBody(
              context: context,
              results: _cachedResults!,
              locale: locale,
              currentUserId: currentUser?.id,
              searchProvider: searchProvider,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(context),
        Expanded(
          child: FutureBuilder(
            future: searchProvider
                .searchFreelancers(query: query, role: selectedRole)
                .then((_) {
              _cachedResults = List.from(searchProvider.searchResults);
              _cachedQuery = query;
              _cachedRole = selectedRole;
            }),
            builder: (context, snapshot) {
              return Consumer<SearchProvider>(
                builder: (context, search, _) {
                  if (search.isLoading) return const LoadingIndicator();
                  if (search.errorMessage != null) {
                    return Center(child: Text(search.errorMessage!));
                  }
                  final results = _cachedResults ?? search.searchResults;
                  return _buildResultsBody(
                    context: context,
                    results: results,
                    locale: locale,
                    currentUserId: currentUser?.id,
                    searchProvider: search,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsBody({
    required BuildContext context,
    required List<UserModel> results,
    required String locale,
    required String? currentUserId,
    required SearchProvider searchProvider,
  }) {
    final isAr = locale == 'ar';

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isAr ? 'لا توجد نتائج لـ "$query"' : 'No results for "$query"',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'جرّب كلمات أخرى أو تحقق من الإملاء'
                  : 'Try different keywords or check spelling',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pinned average price card ──
        _MarketPriceCard(results: results, query: query, locale: locale),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            isAr ? '${results.length} نتيجة' : '${results.length} results',
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: _SearchResultsList(
            results: results,
            locale: locale,
            currentUserId: currentUserId,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';
    final isGlassEnabled = context.watch<ThemeProvider>().isGlassmorphismEnabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: GlassContainer(
              borderRadius: BorderRadius.circular(12),
              color: isGlassEnabled ? AppColors.primary : AppColors.primary.withValues(alpha: 0.15),
              opacity: 0.15,
              blur: 15,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BrowseFreelancersScreen())),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handyman,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(isAr ? 'الحرفيين' : 'Freelancers',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassContainer(
              borderRadius: BorderRadius.circular(12),
              color: isGlassEnabled ? AppColors.secondary : AppColors.secondary.withValues(alpha: 0.15),
              opacity: 0.15,
              blur: 15,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BrowseShopsScreen())),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront,
                            size: 18, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text(isAr ? 'المتاجر' : 'Shops',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';

    if (query.isEmpty && selectedRole != null) {
      return buildResults(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilters(context),
        Expanded(
          child: Builder(builder: (context) {
            if (query.isEmpty && selectedRole == null) {
              return _buildEmptyState(context, isAr);
            }
            return _DelayedSuggestionsWidget(
              query: query,
              isAr: isAr,
              onSuggestionTap: (s) {
                query = s;
                showResults(context);
              },
              onSearchSubmitted: (s) {
                query = s;
                showResults(context);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isAr) {
    final quickSearches = [
      {'label': isAr ? 'سباك' : 'Plumber', 'icon': Icons.plumbing},
      {
        'label': isAr ? 'كهربائي' : 'Electrician',
        'icon': Icons.electrical_services
      },
      {'label': isAr ? 'نجار' : 'Carpenter', 'icon': Icons.carpenter},
      {'label': isAr ? 'دهان' : 'Painter', 'icon': Icons.format_paint},
      {'label': isAr ? 'ميكانيكي' : 'Mechanic', 'icon': Icons.build},
      {'label': isAr ? 'مصمم' : 'Designer', 'icon': Icons.design_services},
      {'label': isAr ? 'مبرمج' : 'Developer', 'icon': Icons.code},
      {'label': isAr ? 'مطعم' : 'Restaurant', 'icon': Icons.restaurant},
      {'label': isAr ? 'صيدلية' : 'Pharmacy', 'icon': Icons.local_pharmacy},
      {'label': isAr ? 'ملابس' : 'Clothing', 'icon': Icons.checkroom},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.search, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  isAr
                      ? 'ابحث عن أفضل الحرفيين والخدمات'
                      : 'Find the best professionals & services',
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isAr ? '🔥 بحث سريع' : '🔥 Quick Search',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickSearches.map((item) {
              return ActionChip(
                avatar: Icon(item['icon'] as IconData,
                    size: 18, color: AppColors.primary),
                label: Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                side:
                    BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onPressed: () {
                  query = item['label'] as String;
                  showResults(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isAr ? 'نصائح البحث' : 'Search Tips',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? '• ابحث بالاسم أو المهنة أو الموقع\n• جرّب "سباك في أم درمان" للبحث المركب\n• يمكنك كتابة اسم الحي أو الولاية'
                      : '• Search by name, profession, or location\n• Try "plumber in Omdurman" for combined search\n• You can type a neighborhood or state name',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinned Market Average Price Card
// ─────────────────────────────────────────────────────────────────────────────
class _MarketPriceCard extends StatelessWidget {
  final List<UserModel> results;
  final String query;
  final String locale;

  const _MarketPriceCard({
    required this.results,
    required this.query,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = locale == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Compute stats from fetched results only ──
    final withRate = results
        .where((u) => u.hourlyRate != null && u.hourlyRate! > 0)
        .toList();

    if (withRate.isEmpty) return const SizedBox.shrink();

    final rates = withRate.map((u) => u.hourlyRate!).toList()..sort();
    final avg = rates.reduce((a, b) => a + b) / rates.length;
    final min = rates.first;
    final max = rates.last;

    // Most common locality among results
    final localityCounts = <String, int>{};
    for (final u in withRate) {
      if (u.locality != null) {
        localityCounts[u.locality!] = (localityCounts[u.locality!] ?? 0) + 1;
      }
    }
    String? topLocality;
    if (localityCounts.isNotEmpty) {
      topLocality = localityCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      blur: 15,
      opacity: isDark ? 0.25 : 0.08,
      color: AppColors.primary,
      border: Border.all(
        color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr
                          ? 'متوسط سعر السوق${topLocality != null ? " · $topLocality" : ""}'
                          : 'Market Average${topLocality != null ? " · $topLocality" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      isAr
                          ? 'بناءً على ${withRate.length} حرفي في نتائج البحث'
                          : 'Based on ${withRate.length} professionals in results',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // ── Big average price badge ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${NumberFormat('#,##0').format(avg)} SDG',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Stats row: min / avg / max ──
          Row(
            children: [
              _StatChip(
                label: isAr ? 'الأدنى' : 'Min',
                value: '${NumberFormat('#,##0').format(min)} SDG',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: isAr ? 'المتوسط' : 'Avg',
                value: '${NumberFormat('#,##0').format(avg)} SDG',
                color: AppColors.success,
                highlight: true,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: isAr ? 'الأعلى' : 'Max',
                value: '${NumberFormat('#,##0').format(max)} SDG',
                color: Colors.orange,
              ),
              const Spacer(),
              Text(
                isAr ? 'لكل ساعة' : 'per hour',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            highlight ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delayed Suggestions
// ─────────────────────────────────────────────────────────────────────────────
class _DelayedSuggestionsWidget extends StatefulWidget {
  final String query;
  final bool isAr;
  final Function(String) onSuggestionTap;
  final Function(String) onSearchSubmitted;

  const _DelayedSuggestionsWidget({
    required this.query,
    required this.isAr,
    required this.onSuggestionTap,
    required this.onSearchSubmitted,
  });

  @override
  _DelayedSuggestionsWidgetState createState() =>
      _DelayedSuggestionsWidgetState();
}

class _DelayedSuggestionsWidgetState extends State<_DelayedSuggestionsWidget> {
  List<String> _suggestions = [];
  bool _showEmptyState = false;
  Timer? _emptyStateTimer;

  @override
  void initState() {
    super.initState();
    _updateSuggestions(widget.query, instant: true);
  }

  @override
  void didUpdateWidget(_DelayedSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _updateSuggestions(widget.query, instant: false);
    }
  }

  void _updateSuggestions(String newQuery, {bool instant = false}) {
    final newSuggestions =
        SmartSearchService.getPredefinedSuggestions(newQuery);
    if (newSuggestions.isNotEmpty) {
      _emptyStateTimer?.cancel();
      setState(() {
        _suggestions = newSuggestions;
        _showEmptyState = false;
      });
    } else {
      if (instant) {
        setState(() {
          _suggestions = [];
          _showEmptyState = true;
        });
      } else {
        _emptyStateTimer?.cancel();
        _emptyStateTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _suggestions = [];
              _showEmptyState = true;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _emptyStateTimer?.cancel();
    super.dispose();
  }

  IconData _icon(String s) {
    final l = s.toLowerCase();
    if (l.contains('سباك') || l.contains('plumb')) return Icons.plumbing;
    if (l.contains('كهرب') || l.contains('electr'))
      return Icons.electrical_services;
    if (l.contains('نجار') || l.contains('carpen')) return Icons.carpenter;
    if (l.contains('دهان') || l.contains('paint')) return Icons.format_paint;
    if (l.contains('ميكانيك') || l.contains('mechan')) return Icons.build;
    if (l.contains('مصمم') || l.contains('design'))
      return Icons.design_services;
    if (l.contains('مبرمج') || l.contains('develop')) return Icons.code;
    if (l.contains('مطعم') || l.contains('restau')) return Icons.restaurant;
    if (l.contains('متجر') || l.contains('shop')) return Icons.store;
    return Icons.search;
  }

  @override
  Widget build(BuildContext context) {
    if (_showEmptyState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              widget.isAr
                  ? 'اضغط بحث للعرض الكامل'
                  : 'Press search for full results',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final s = _suggestions[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon(s), color: AppColors.primary, size: 20),
          ),
          title: Text(s,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          trailing: IconButton(
            icon: Icon(Icons.north_west, size: 16, color: Colors.grey[400]),
            onPressed: () => widget.onSuggestionTap(s),
          ),
          onTap: () => widget.onSuggestionTap(s),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Results List — navigates without re-triggering search
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultsList extends StatefulWidget {
  final List<UserModel> results;
  final String locale;
  final String? currentUserId;

  const _SearchResultsList({
    required this.results,
    required this.locale,
    this.currentUserId,
  });

  @override
  State<_SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends State<_SearchResultsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final search = context.read<SearchProvider>();
      if (!search.isLoadingMore && search.hasMore) search.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: widget.results.length + (search.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final freelancer = widget.results[index];
        return FreelancerCard(
          freelancer: freelancer,
          locale: widget.locale,
          currentUserId: widget.currentUserId,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: freelancer.id)),
            // ← No await here intentionally: we don't re-search on pop
          ),
        );
      },
    );
  }
}
