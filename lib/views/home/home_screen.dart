import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_provider.dart';

import '../../providers/posts_provider.dart';
import '../../providers/job_provider.dart';
import '../requests/requests_screen.dart';
import '../posts/posts_feed_screen.dart';
import '../squads/squads_explorer_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/glass_container.dart';
import '../profile/profile_screen.dart';
import 'dashboard_screen.dart';

class BottomBarVisibilityProvider extends ChangeNotifier {
  bool _isVisible = true;
  bool get isVisible => _isVisible;

  void setVisible(bool value) {
    if (_isVisible != value) {
      _isVisible = value;
      notifyListeners();
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0; // Dashboard is home now
  final List<int> _history = [0];
  final BottomBarVisibilityProvider _visibilityProvider =
      BottomBarVisibilityProvider();

  // Track which tabs have been visited to lazy-load them and save memory
  final List<bool> _initializedTabs = [true, false, false, false];

  // Keys for refreshing tabs
  Key _dashboardKey = UniqueKey();
  Key _squadsKey = UniqueKey();
  Key _requestsKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return;

    final userProvider = context.read<UserProvider>();
    userProvider.setUserState(user.state); // Region-priority: 75% local
    
    // ✅ FIX #9: Sequential loading instead of parallel to improve cold start
    // Load most important data first (Posts & Chats)
    await context.read<PostsProvider>().fetchPosts();
    if (!mounted) return;
    
    await context.read<ChatProvider>().fetchChats(user.id);
    if (!mounted) return;
    
    // Load secondary data
    await userProvider.fetchFreelancers();
    if (!mounted) return;
    
    await userProvider.fetchShops();
    if (!mounted) return;
    
    context.read<JobProvider>().fetchJobs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final info = await FirestoreService().getAppVersionInfo();
      if (info.isEmpty) return;

      final latestVersion = info['version'] as String?;
      if (latestVersion == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (latestVersion != currentVersion) {
        if (!mounted) return;
        _showUpdateDialog(
          context,
          latestVersion,
          info['force_update'] as bool? ?? false,
          info['url'] as String? ?? 'https://sudanfree.com/sudan-free.html',
          info['message_ar'] as String?,
          info['message_en'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, String version, bool force,
      String url, String? messageAr, String? messageEn) {
    final isArabic = context.read<LocaleProvider>().isArabic;

    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(isArabic ? 'تحديث جديد متوفر!' : 'New Update Available!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update,
                  size: 60, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                context.read<LocaleProvider>().isArabic
                    ? (messageAr ??
                        'يتوفر إصدار جديد ($version). يرجى التحديث للحصول على أفضل تجربة.')
                    : (messageEn ??
                        'A new version ($version) is available. Please update for the best experience.'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
            ElevatedButton(
              onPressed: () {
                _launchURL(url);
                if (!force) Navigator.pop(ctx);
              },
              child: Text(context.read<LocaleProvider>().isArabic
                  ? 'تحديث الآن'
                  : 'Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  /// Navigate to a specific tab — used by DashboardScreen
  void _navigateToTab(int index) {
    if (index >= 0 && index <= 3) {
      setState(() {
        _currentIndex = index;
        _history.remove(index);
        _history.add(index);
        _initializedTabs[index] = true; // Mark as initialized
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    final screens = [
      DashboardScreen(
          key: _dashboardKey, onNavigateToTab: _navigateToTab), // 0 - الرئيسية
      const PostsFeedScreen(), // 1 - المجتمع (يحدث عبر الـ Provider)
      SquadsExplorerScreen(key: _squadsKey), // 2 - المجموعات
      RequestsScreen(key: _requestsKey), // 3 - الطلبات
      // 4 - الملف الشخصي
      // We will create the Profile screen directly inline or import it
    ];

    // Lazy initialization logic needs 5 elements now
    if (_initializedTabs.length == 4) {
      _initializedTabs.add(false);
    }

    return PopScope(
      canPop: _currentIndex == 0 && _history.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_history.length > 1) {
          setState(() {
            _history.removeLast();
            _currentIndex = _history.last;
          });
        } else if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
            _history.clear();
            _history.add(0);
          });
        }
      },
      child: Scaffold(
        body: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (notification.scrollDelta != null) {
              if (notification.scrollDelta! > 5 &&
                  _visibilityProvider.isVisible) {
                _visibilityProvider.setVisible(false);
              } else if (notification.scrollDelta! < -5 &&
                  !_visibilityProvider.isVisible) {
                _visibilityProvider.setVisible(true);
              }
            }
            return false;
          },
          child: IndexedStack(
            index: _currentIndex,
            children: [
              screens[0],
              screens[1],
              screens[2],
              screens[3],
              // Late binding for ProfileScreen to pass user.id
              _initializedTabs.length > 4 && _initializedTabs[4]
                  ? _buildProfileScreen(user.id)
                  : const SizedBox(),
            ],
          ),
        ),
        // Add Request FAB removed by user request
        extendBody: true, // Crucial for floating nav bar
        bottomNavigationBar: AnimatedBuilder(
          animation: _visibilityProvider,
          builder: (context, child) {
            return AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              offset: _visibilityProvider.isVisible
                  ? Offset.zero
                  : const Offset(0, 2.0),
              child: Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom > 20
                        ? MediaQuery.of(context).padding.bottom
                        : 20),
                child: GlassContainer(
                  height: 64,
                  borderRadius: BorderRadius.circular(32),
                  opacity: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.45,
                  blur: 20,
                  enableBlur: true,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home,
                          locale == 'ar' ? 'الرئيسية' : 'Home'),
                      _buildNavItem(
                          1, Icons.forum_outlined, Icons.forum, l10n.community,
                          hasBadge: context.watch<PostsProvider>().hasNewPosts),
                      _buildNavItem(2, Icons.groups_outlined, Icons.groups,
                          locale == 'ar' ? 'المجموعات' : 'Squads'),
                      _buildNavItem(
                          3,
                          Icons.assignment_outlined,
                          Icons.assignment,
                          locale == 'ar' ? 'الطلبات' : 'Requests'),
                      _buildNavItem(4, Icons.person_outline, Icons.person,
                          locale == 'ar' ? 'ملفي' : 'Profile'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label,
      {bool hasBadge = false}) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
            _history.remove(index);
            _history.add(index);
            if (index < _initializedTabs.length) {
              _initializedTabs[index] = true;
            }
          });
        } else {
          // Double tap refresh
          setState(() {
            if (index == 0) _dashboardKey = UniqueKey();
            if (index == 1)
              context.read<PostsProvider>().fetchPosts(forceRefresh: true);
            if (index == 2) _squadsKey = UniqueKey();
            if (index == 3) _requestsKey = UniqueKey();
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding:
            EdgeInsets.symmetric(horizontal: isActive ? 16 : 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: hasBadge,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen(String userId) {
    return ProfileScreen(userId: userId);
  }
}
