import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import 'product_detail_screen.dart';
import '../../widgets/common/linkable_text.dart';

// ignore: unused_import
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/contact_log_model.dart';
import '../../providers/user_provider.dart';
import '../../models/post_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/adaptive_fab_padding.dart';
import '../../widgets/buttons/smart_draggable_fab.dart';
import '../../widgets/common/full_screen_image_viewer.dart';
import '../../core/routes/premium_page_route.dart';
import 'digital_id_card_screen.dart';
import '../map/map_explorer_screen.dart';

import 'create_product_screen.dart';
import 'shop_dashboard_screen.dart';
// To show comments/details
import '../auth/profile_setup_screen.dart'; // For editing
import '../../views/common/report_dialog.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../views/common/image_viewer_screen.dart';
import '../../widgets/common/keep_alive_tab_view.dart';
import '../../core/constants/sudan_locations.dart';
import '../../widgets/common/verification_badge.dart';
import '../chat/chat_screen.dart';
import '../../providers/chat_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../models/review_model.dart';
import '../../core/utils/app_error_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';
import 'favorites_screen.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/common/glass_container.dart';
import 'shop_components/shop_products_tab.dart';
import 'shop_components/shop_gallery_tab.dart';
import 'shop_components/shop_reviews_tab.dart';
class ShopProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool isMe;
  final int initialTabIndex;
  final bool showReviewDialog;

  const ShopProfileScreen({
    super.key,
    required this.user,
    required this.isMe,
    this.initialTabIndex = 0,
    this.showReviewDialog = false,
  });

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Stream<UserModel?> _userStream;
  late Stream<List<PostModel>> _postsStream;
  late Stream<List<ReviewModel>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTabIndex);

    _userStream = FirestoreService().getUserStream(widget.user.id);
    _postsStream = FirestoreService().getUserPosts(widget.user.id);
    _reviewsStream = FirestoreService().getFreelancerReviews(widget.user.id);

    if (widget.showReviewDialog && !widget.isMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ShopReviewsTab.showAddReviewDialog(context, widget.user);
        }
      });
    }

    // Increment profile views if not me
    if (!widget.isMe) {
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).user?.id;
      if (currentUserId != null) {
        FirestoreService()
            .incrementProfileViews(widget.user.id, currentUserId)
            .catchError(
                (_) {}); // Non-critical: silently ignore permission errors
      }

      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'تصفح المنتجات المميزة هنا واطلع على آراء وتقييمات المتسوقين 🛒',
        messageEn:
            'Browse featured products here and check out shopper reviews 🛒',
        tipId: 'shop_profile_visit',
        icon: Icons.storefront_rounded,
      );
    } else {
      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'أدر متجرك بذكاء! أضف منتجاتك وراقب إحصائيات المشاهدات لحظة بلحظة 📊',
        messageEn:
            'Manage your shop smartly! Add products and track views in real-time 📊',
        tipId: 'shop_owner_visit',
        icon: Icons.dashboard_customize_rounded,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          StreamBuilder<UserModel?>(
              stream: _userStream,
              initialData: widget.user,
              builder: (context, snapshot) {
                final user = snapshot.data ?? widget.user;

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      // 1. Store Header
                      SliverAppBar(
                        expandedHeight: 220, // Taller cover as requested
                        pinned: false,
                        floating: false,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        systemOverlayStyle:
                            Theme.of(context).appBarTheme.systemOverlayStyle,
                        leading: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        flexibleSpace: LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            final double expandedHeight = 180.0;
                            final double collapsedHeight = kToolbarHeight +
                                MediaQuery.of(context).padding.top;
                            final double currentHeight =
                                constraints.biggest.height;

                            double progress =
                                (currentHeight - collapsedHeight) /
                                    (expandedHeight - collapsedHeight);
                            progress = progress.clamp(0.0, 1.0);

                            final double opacity = progress > 0.4
                                ? ((progress - 0.4) / 0.6).clamp(0.0, 1.0)
                                : 0.0;
                            final double scale =
                                Curves.easeOut.transform(progress);

                            return Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.none,
                              children: [
                                // Cover Image with Curve
                                // Cover Image without Curve
                                Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _handleImageTap(
                                          user.coverImageUrl, true),
                                      child: user.coverImageUrl != null
                                          ? Hero(
                                              tag: '${user.id}_cover',
                                              child: CachedNetworkImage(
                                                imageUrl: user.coverImageUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    Container(
                                                        color:
                                                            Colors.grey[300]),
                                              ),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.secondary,
                                                    AppColors.primary
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),
                                    ),
                                    // Dark gradient overlay to make top buttons visible
                                    IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withValues(alpha: 0.5),
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.3),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ),

                                  ],
                                ),
                                // Avatar
                                // Avatar
                                Positioned.directional(
                                  textDirection: Directionality.of(context),
                                  bottom: -50,
                                  start: 24, // Shifted to start edge
                                  end: 16,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Transform.scale(
                                      scale: scale,
                                      alignment: AlignmentDirectional.centerStart,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: opacity > 0
                                                ? () => _handleImageTap(
                                                    user.profileImageUrl, false)
                                                : null,
                                            child: Stack(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6), // Thicker border
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).scaffoldBackgroundColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.15),
                                                        blurRadius: 12,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Hero(
                                                    tag: '${user.id}_profile',
                                                    child: CircleAvatar(
                                                      radius: 65,
                                                      backgroundColor: Theme.of(context).cardColor,
                                                      backgroundImage: user.profileImageUrl != null
                                                          ? CachedNetworkImageProvider(user.profileImageUrl!)
                                                          : null,
                                                      child: user.profileImageUrl == null
                                                          ? const Icon(Icons.store, size: 50, color: Colors.grey)
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                // Verified Badge / Online indicator
                                                Positioned.directional(
                                                  textDirection: Directionality.of(context),
                                                  bottom: 12,
                                                  end: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                                                    ),
                                                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 60), // Push down to overlap cover edge
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      user.name,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 24,
                                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                                        height: 1.2,
                                                        shadows: [
                                                          Shadow(
                                                            color: Theme.of(context).scaffoldBackgroundColor,
                                                            blurRadius: 12,
                                                          ),
                                                          Shadow(
                                                            color: Theme.of(context).scaffoldBackgroundColor,
                                                            blurRadius: 24,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  SmartVerificationBadge(user: user, size: 24),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white, size: 24),
                            tooltip: l10n.localeName == 'ar'
                                ? 'مشاركة الملف الشخصي'
                                : 'Share Profile',
                            onPressed: () {
                              final url =
                                  'https://sudanfree.com/sudan-free.html?profileId=${user.id}';
                              final text = l10n.localeName == 'ar'
                                  ? 'تفضل بزيارة متجر ${user.name} على تطبيق سودان فري:\n$url'
                                  : 'Visit ${user.name}\'s store on SudanFree:\n$url';
                              Share.share(text);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                            tooltip: l10n.localeName == 'ar' ? 'الهوية الرقمية' : 'Digital ID',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  PremiumPageRoute(
                                      page: DigitalIdCardScreen(user: user)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.contact_phone, color: Colors.white, size: 24),
                            tooltip: l10n.localeName == 'ar' ? 'تواصل معنا' : 'Contact Shop',
                            onPressed: () => _showContactMenu(context, user),
                          ),
                          // OWNER ACTIONS: Edit & Settings
                          if (widget.isMe) ...[
                            IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.white, size: 24),
                              tooltip: l10n.localeName == 'ar' ? 'مفضلاتي' : 'Favorites',
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                              tooltip: l10n.editStore,
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen(existingUser: user))),
                            ),
                          ] else ...[
                            // VISITOR ACTIONS: Report & Block
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                              onSelected: (value) async {
                                if (value == 'report') {
                                  showDialog(
                                      context: context,
                                      builder: (_) =>
                                          ReportDialog(reportedUser: user));
                                } else if (value == 'block') {
                                  final auth = context.read<AuthProvider>();
                                  if (auth.user == null) return;
                                  final isBlocked =
                                      auth.user!.blockedUsers.contains(user.id);

                                  final isRtl = Localizations.localeOf(context)
                                          .languageCode ==
                                      'ar';
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(isRtl
                                          ? (isBlocked
                                              ? 'إلغاء حظر المستخدم؟'
                                              : 'حظر المستخدم؟')
                                          : (isBlocked
                                              ? 'Unblock User?'
                                              : 'Block User?')),
                                      content: Text(isRtl
                                          ? (isBlocked
                                              ? 'هل أنت متأكد من إلغاء حظر هذا المستخدم؟'
                                              : 'لن تتمكن من رؤية منشورات أو التعليقات من هذا المستخدم. وسيتم إلغاء متابعتك له إذا كنت تتابعه.')
                                          : (isBlocked
                                              ? 'Are you sure you want to unblock this user?'
                                              : 'You will no longer see posts or comments from this user. You will also unfollow them.')),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(
                                                isRtl ? 'إلغاء' : 'Cancel')),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                              isRtl
                                                  ? (isBlocked
                                                      ? 'إلغاء الحظر'
                                                      : 'حظر')
                                                  : (isBlocked
                                                      ? 'Unblock'
                                                      : 'Block'),
                                              style: const TextStyle(
                                                  color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );

                                    if (confirm == true) {
                                      if (isBlocked) {
                                        await FirestoreService().toggleBlock(auth.user!.id, user.id, true);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text(isRtl
                                                  ? 'تم إلغاء الحظر بنجاح'
                                                  : 'User unblocked successfully')),
                                        );
                                        auth.refreshUserProfile();
                                      } else {
                                        await FirestoreService().toggleBlock(auth.user!.id, user.id, false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text(isRtl
                                                  ? 'تم حظر المستخدم بنجاح'
                                                  : 'User blocked successfully')),
                                        );
                                        auth.refreshUserProfile();
                                        if (!isBlocked) {
                                          Navigator.pop(
                                              context); // Leave profile if blocked
                                        }
                                      }
                                    }
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                final auth = context.read<AuthProvider>();
                                final isBlocked =
                                    auth.user?.blockedUsers.contains(user.id) ??
                                        false;
                                final isRtl = Localizations.localeOf(context)
                                        .languageCode ==
                                    'ar';

                                return [
                                  PopupMenuItem<String>(
                                    value: 'report',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.flag_outlined,
                                            color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(l10n.reportStore,
                                            style: const TextStyle(
                                                color: Colors.orange)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'block',
                                    child: Row(
                                      children: [
                                        Icon(
                                            isBlocked
                                                ? Icons.check_circle_outline
                                                : Icons.block,
                                            color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text(
                                            isRtl
                                                ? (isBlocked
                                                    ? 'إلغاء الحظر'
                                                    : 'حظر')
                                                : (isBlocked
                                                    ? 'Unblock'
                                                    : 'Block'),
                                            style: const TextStyle(
                                                color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ]
                        ],
                      ),

                      // 2. Info & Action Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              const SizedBox(
                                  height:
                                      60), // Space for the overlapping avatar

                              // Name was moved up to the cover

                              // Category
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  user.getShopCategoryName(
                                      Localizations.localeOf(context)
                                          .languageCode),
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Glass Stats Container
                              GlassContainer(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                borderRadius: BorderRadius.circular(16),
                                child: widget.isMe
                                    ? // Owner View: Dashboard Button
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          ShopDashboardScreen(
                                                              shop:
                                                                  widget.user)),
                                                );
                                              },
                                              icon: const Icon(
                                                  Icons.dashboard_rounded),
                                              label: Text(
                                                l10n.localeName == 'ar'
                                                    ? 'لوحة التحكم'
                                                    : 'Dashboard',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.purple.shade600,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : // Visitor View: Stats
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Details Button
                                          _buildContactButton(
                                              Icons.info_outline,
                                              l10n.details,
                                              Colors.grey,
                                              () => _showShopDetailsDialog(
                                                  context)),
                                          Container(
                                              width: 1,
                                              height: 30,
                                              color: Colors.grey
                                                  .withValues(alpha: 0.2)),
                                          // Rating
                                          GestureDetector(
                                            onTap: () =>
                                                _tabController.animateTo(2),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons.star_rounded,
                                                          color: Colors.amber,
                                                          size: 18),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        widget.user.rating > 0
                                                            ? widget.user.rating
                                                                .toStringAsFixed(
                                                                    1)
                                                            : '--',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                    ]),
                                                Text(
                                                  l10n.localeName == 'ar'
                                                      ? 'تقييم'
                                                      : 'Rating',
                                                  style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                              width: 1,
                                              height: 30,
                                              color: Colors.grey
                                                  .withValues(alpha: 0.2)),
                                          // Followers
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${user.followers.length}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              Text(
                                                l10n.localeName == 'ar'
                                                    ? 'متابع'
                                                    : 'Followers',
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          Container(
                                              width: 1,
                                              height: 30,
                                              color: Colors.grey
                                                  .withValues(alpha: 0.2)),
                                          // Follow Button
                                          Consumer<AuthProvider>(
                                            builder: (context, auth, _) {
                                              final isFollowing = user.followers
                                                  .contains(auth.user?.id);
                                              return _buildContactButton(
                                                isFollowing
                                                    ? Icons.check
                                                    : Icons.person_add_alt_1,
                                                isFollowing
                                                    ? (l10n.localeName == 'ar'
                                                        ? 'أُتابع'
                                                        : 'Following')
                                                    : (l10n.localeName == 'ar'
                                                        ? 'متابعة'
                                                        : 'Follow'),
                                                isFollowing
                                                    ? Colors.green
                                                    : AppColors.primary,
                                                () async {
                                                  if (auth.user == null) return;
                                                  try {
                                                    await FirestoreService()
                                                        .toggleFollow(
                                                            auth.user!.id,
                                                            user.id,
                                                            isFollowing,
                                                            auth.user!.name);
                                                    setState(() {
                                                      if (isFollowing) {
                                                        user.followers.remove(
                                                            auth.user!.id);
                                                      } else {
                                                        user.followers
                                                            .add(auth.user!.id);
                                                      }
                                                    });
                                                  } catch (_) {}
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      // 3. Tab Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabBarDelegate(
                          topPadding: MediaQuery.of(context).padding.top,
                          TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelPadding: EdgeInsets.zero,
                            indicatorPadding: const EdgeInsets.all(2),
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey.shade600,
                            labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            splashBorderRadius: BorderRadius.circular(20),
                            tabs: [
                              Tab(height: 28, text: l10n.products),
                              Tab(
                                  height: 28,
                                  text: l10n.localeName == 'ar'
                                      ? 'المعرض'
                                      : 'Gallery'),
                              Tab(height: 28, text: l10n.reviews),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      KeepAliveTabView(child: ShopProductsTab(postsStream: _postsStream, isMe: widget.isMe)),
                      KeepAliveTabView(child: ShopGalleryTab(user: user, isMe: widget.isMe)),
                      KeepAliveTabView(child: ShopReviewsTab(user: user, isMe: widget.isMe, reviewsStream: _reviewsStream)),
                    ],
                  ),
                );
              }),
          if (widget.isMe)
            SmartDraggableFab(
              heroTag: 'add_product_fab',
              icon: Icons.shopping_bag_outlined,
              locale: Localizations.localeOf(context).languageCode,
              initialBottom: MediaQuery.of(context).padding.bottom + 82.0,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateProductScreen()),
              ),
            ),
        ],
      ),
      floatingActionButton: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isGlass = themeProvider.isGlassmorphismEnabled;

          if (widget.isMe) {
            return const SizedBox.shrink();
          }

          if (widget.user.role == UserRole.shop ||
              widget.user.role == UserRole.techService ||
              widget.user.role == UserRole.privateService) {
            return AdaptiveFabPadding(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  isGlass
                      ? GlassContainer(
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () {
                              if (widget.user.latitude == null ||
                                  widget.user.longitude == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(Localizations.localeOf(
                                                    context)
                                                .languageCode ==
                                            'ar'
                                        ? 'الموقع غير متوفر لهذا المستخدم'
                                        : 'Location not available for this user'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => MapExplorerScreen(
                                          targetUser: widget.user)));
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.location_on_outlined,
                                  color: AppColors.primary),
                            ),
                          ),
                        )
                      : FloatingActionButton.small(
                          heroTag: 'shop_location_btn',
                          onPressed: () {
                            if (widget.user.latitude == null ||
                                widget.user.longitude == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? 'الموقع غير متوفر لهذا المستخدم'
                                      : 'Location not available for this user'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => MapExplorerScreen(
                                        targetUser: widget.user)));
                          },
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          child: const Icon(Icons.location_on_outlined),
                        ),
                  const SizedBox(height: 12),
                  isGlass
                      ? GlassContainer(
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => _showContactMenu(context, widget.user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.support_agent,
                                      size: 22, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    Localizations.localeOf(context)
                                                .languageCode ==
                                            'ar'
                                        ? 'تواصل معنا'
                                        : 'Contact Us',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : FloatingActionButton.extended(
                          heroTag: 'shop_contact_btn',
                          onPressed: () =>
                              _showContactMenu(context, widget.user),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.support_agent, size: 22),
                          label: Text(
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'تواصل معنا'
                                : 'Contact Us',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showContactMenu(BuildContext context, UserModel shopUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        blur: 20,
        opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'تواصل مع المتجر'
                    : 'Contact Shop',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.chat, color: Colors.white)),
                title: Text(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'واتساب'
                    : 'WhatsApp'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsApp(
                      shopUser.whatsappNumber ?? shopUser.phoneNumber);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.call, color: Colors.white)),
                title: Text(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'اتصال مباشر'
                    : 'Direct Call'),
                onTap: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(shopUser.phoneNumber);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.handshake, color: Colors.white)),
                title: Text(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'إنشاء اتفاق (دردشة)'
                    : 'Create Agreement (Chat)'),
                onTap: () async {
                  final authProvider = context.read<AuthProvider>();
                  final currentUser = authProvider.user;
                  if (currentUser == null) return;

                  // Capture before async gap
                  final chatProvider = context.read<ChatProvider>();
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final locale = Localizations.localeOf(context).languageCode;

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final chat = await chatProvider.getOrCreateChat(
                      currentUserId: currentUser.id,
                      currentUserName: currentUser.name,
                      currentUserImageUrl: currentUser.profileImageUrl,
                      otherUserId: shopUser.id,
                      otherUserName: shopUser.name,
                      otherUserImageUrl: shopUser.profileImageUrl,
                    );

                    // Pop loading dialog
                    navigator.pop();
                    // Pop bottom sheet
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (chat != null) {
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              chat: chat, autoOpenContractDialog: true),
                        ),
                      );
                    } else {
                      final errorMsg = chatProvider.errorMessage ??
                          (locale == 'ar'
                              ? 'حدث خطأ أثناء إنشاء المحادثة'
                              : 'Error creating chat');
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red),
                      );
                    }
                  } catch (e, stack) {
                    navigator.pop();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted)
                      AppErrorHandler.show(context, e, stack,
                          logContext: 'ShopProfile.createChat');
                  }
                },
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactButton(
      IconData icon, String label, Color color, VoidCallback? onTap,
      {bool isLoading = false}) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
        child: Column(
          children: [
            isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(icon, color: color, size: 24),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String? number) async {
    if (number == null || number.isEmpty) return;

    final isArabic = context.read<LocaleProvider>().isArabic;

    try {
      // تسجيل contactLog قبل فتح واتساب
      final currentUser = context.read<AuthProvider>().user;
      if (currentUser != null && currentUser.id != widget.user.id) {
        try {
          final log = ContactLogModel(
            id: '',
            contacterId: currentUser.id,
            contacterName: currentUser.name,
            freelancerId: widget.user.id,
            freelancerName: widget.user.name,
            contactType: 'whatsapp',
            createdAt: DateTime.now(),
          );
          await FirestoreService().createContactLog(log);
        } catch (e, stack) {
          AppErrorHandler.log(e, stack,
              context: 'ShopProfile.whatsappContactLog');
        }
      }

      String cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleaned.startsWith('00')) {
        cleaned = cleaned.substring(2);
      } else if (cleaned.startsWith('+')) {
        cleaned = cleaned.substring(1);
      } else if (cleaned.startsWith('0')) {
        cleaned = '249${cleaned.substring(1)}';
      } else if (!cleaned.startsWith('249') && cleaned.length == 9) {
        cleaned = '249$cleaned';
      }

      final message = Uri.encodeComponent(isArabic
          ? 'مرحباً، أتواصل معك من خلال منصة سودان فري.'
          : 'Hello, I am contacting you through the Sudan Free platform.');
      final url = 'https://wa.me/$cleaned?text=$message';
      final uri = Uri.parse(url);

      try {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    } catch (e, stack) {
      AppErrorHandler.log(e, stack, context: 'ShopProfile.launchWhatsApp');
    } finally {}
  }

  void _showShopDetailsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = context.read<LocaleProvider>().locale.languageCode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.store, color: AppColors.secondary),
            const SizedBox(width: 8),
            Text(
              widget.user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem(
                Icons.category_outlined,
                l10n.storeCategory,
                widget.user.getShopCategoryName(locale),
              ),
              const Divider(height: 24),
              _buildDetailItem(
                Icons.info_outline,
                l10n.aboutStore,
                widget.user.bio ?? l10n.noData,
              ),
              const Divider(height: 24),
              _buildDetailItem(
                Icons.location_on_outlined,
                l10n.location,
                '${widget.user.locality != null ? "${SudanLocations.getLocalityName(widget.user.locality!, locale)} - " : ''}${widget.user.state != null ? SudanLocations.getStateName(widget.user.state!, locale) : ''}',
              ),
              const Divider(height: 24),
              _buildDetailItem(
                Icons.access_time,
                l10n.workingHours,
                (widget.user.openingHours != null &&
                        widget.user.closingHours != null)
                    ? '${l10n.from} ${widget.user.openingHours} ${l10n.to} ${widget.user.closingHours}'
                    : l10n.undefined,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: LinkableText(
              text: value,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String? number) async {
    if (number == null) return;

    try {
      // تسجيل contactLog قبل الاتصال
      final currentUser = context.read<AuthProvider>().user;
      if (currentUser != null && currentUser.id != widget.user.id) {
        try {
          final log = ContactLogModel(
            id: '',
            contacterId: currentUser.id,
            contacterName: currentUser.name,
            freelancerId: widget.user.id,
            freelancerName: widget.user.name,
            contactType: 'call',
            createdAt: DateTime.now(),
          );
          await FirestoreService().createContactLog(log);
        } catch (e, stack) {
          AppErrorHandler.log(e, stack, context: 'ShopProfile.callContactLog');
        }
      }

      final Uri launchUri = Uri(scheme: 'tel', path: number);
      try {
        await launchUrl(launchUri,
            mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    } catch (e, stack) {
      AppErrorHandler.log(e, stack, context: 'ShopProfile.launchCall');
    } finally {}
  }

  void _openImage(String url, String tag) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ImageViewerScreen(imageUrl: url, heroTag: tag)));
  }

  void _handleImageTap(String? imageUrl, bool isCover) {
    final l10n = AppLocalizations.of(context)!;
    // If not me, just view image (if exists)
    if (!widget.isMe) {
      if (imageUrl != null) {
        _openImage(imageUrl,
            isCover ? '${widget.user.id}_cover' : '${widget.user.id}_profile');
      }
      return;
    }

    // If me, show options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isCover ? l10n.coverPhoto : l10n.storePhoto,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (imageUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(l10n.viewImage),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImage(
                      imageUrl,
                      isCover
                          ? '${widget.user.id}_cover'
                          : '${widget.user.id}_profile');
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.changeImage),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(isCover: isCover);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage({required bool isCover}) async {
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
          content: Text(l10n.uploadingImage),
          duration: const Duration(seconds: 2)),
    );

    final file = File(pickedFile.path);
    final storage = StorageService();

    // Upload
    final url = isCover
        ? await storage.uploadImage(file,
            folder: 'users/${widget.user.id}/cover')
        : await storage.uploadProfileImage(widget.user.id, file);

    if (url != null) {
      // Update Firestore
      final updates =
          isCover ? {'coverImageUrl': url} : {'profileImageUrl': url};

      await FirestoreService().updateUserProfile(widget.user.id, updates);

      // Update ALL User posts and comments with new image if profile image changed
      if (!isCover) {
        await FirestoreService()
            .updateUserProfileImages(widget.user.id, url, null);
      }

      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(l10n.imageUpdated),
            backgroundColor: AppColors.success),
      );

      // Force refresh shops data in provider
      context
          .read<UserProvider>()
          .fetchShops(category: null, forceRefresh: true);

      // Reload screen
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ShopProfileScreen(
                  user: widget.user.copyWith(
                      coverImageUrl: isCover ? url : widget.user.coverImageUrl,
                      profileImageUrl:
                          !isCover ? url : widget.user.profileImageUrl),
                  isMe: true)));
    } else {
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(l10n.imageUploadFailed), backgroundColor: Colors.red),
      );
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final double topPadding;
  _SliverTabBarDelegate(this._tabBar, {this.topPadding = 0});

  @override
  double get minExtent => 40 + topPadding;
  @override
  double get maxExtent => 40 + topPadding;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPadding + 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 32,
              child: GlassContainer(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _tabBar,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate._tabBar != _tabBar ||
        oldDelegate.topPadding != topPadding;
  }
}

class ShopProfileHeaderCurve extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 2, size.height + 20, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
