import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'create_portfolio_project_screen.dart';
import 'portfolio_project_detail_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import 'digital_id_card_screen.dart';
import '../../core/routes/premium_page_route.dart';
import '../../models/contact_log_model.dart';
import '../../providers/user_provider.dart';
import '../../models/post_model.dart';
import '../../models/job_model.dart';
import '../../models/review_model.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../../services/firestore_service.dart';
import '../../services/firestore/job_service.dart';
import '../../widgets/common/adaptive_fab_padding.dart';
import '../../widgets/buttons/smart_draggable_fab.dart';
import '../posts/create_post_screen.dart';
import '../map/map_explorer_screen.dart';
import '../auth/profile_setup_screen.dart';
import 'profile_screen.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/cards/post_card.dart';
import '../../widgets/common/linkable_text.dart';

import '../../widgets/reviews/review_widgets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/utils/job_titles_utils.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../core/constants/sudan_locations.dart';
import 'dart:io';
import '../../views/common/image_viewer_screen.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/staggered_animated_widget.dart';
import '../../widgets/common/keep_alive_tab_view.dart';
import '../../widgets/common/verification_badge.dart';
import '../../views/common/report_dialog.dart';
import '../../models/portfolio_project_model.dart';
import '../../core/utils/app_error_handler.dart';
import 'favorites_screen.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/common/glass_container.dart';

class FreelancerProfileScreen extends StatefulWidget {
  final UserModel user;
  final bool isMe;

  final int initialTabIndex;
  final bool showReviewDialog;

  const FreelancerProfileScreen({
    super.key,
    required this.user,
    required this.isMe, // Passed from parent check (currentUser.id == user.id)
    this.initialTabIndex = 0,
    this.showReviewDialog = false,
  });

  @override
  State<FreelancerProfileScreen> createState() =>
      _FreelancerProfileScreenState();
}

class _FreelancerProfileScreenState extends State<FreelancerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploadingImage = false; // loading state for photo upload

  late Stream<UserModel?> _userStream;
  late Stream<List<PostModel>> _postsStream;
  late Stream<List<PortfolioProjectModel>> _portfolioStream;
  late Stream<List<ReviewModel>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      setState(() {});
    });

    _userStream = FirestoreService().getUserStream(widget.user.id);
    _postsStream = FirestoreService().getUserPosts(widget.user.id);
    _portfolioStream = FirestoreService().getUserPortfolio(widget.user.id);
    _reviewsStream = FirestoreService().getFreelancerReviews(widget.user.id);

    if (widget.showReviewDialog && !widget.isMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddReviewDialog();
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
            'ألقِ نظرة على سابقة الأعمال واقرأ تجارب من تعاملوا معه سابقاً ⭐',
        messageEn:
            'Take a look at past work and read experiences of previous clients ⭐',
        tipId: 'profile_first_visit',
        icon: Icons.person_search_rounded,
      );
    } else {
      SmartGuideService.showMicroTip(
        context,
        messageAr: 'معرضك هو واجهتك! أضف صور أعمالك الجديدة لمضاعفة طلباتك 📈',
        messageEn:
            'Your portfolio is your storefront! Add recent work to double your requests 📈',
        tipId: 'portfolio_first_visit',
        icon: Icons.add_photo_alternate_rounded,
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
                      SliverAppBar(
                        expandedHeight: 200,
                        pinned: false,
                        floating: false,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        systemOverlayStyle:
                            Theme.of(context).appBarTheme.systemOverlayStyle,
                        leading: const BackButton(),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            tooltip: l10n.localeName == 'ar'
                                ? 'مشاركة الملف الشخصي'
                                : 'Share Profile',
                            onPressed: () {
                              final url =
                                  'https://sudanfree.com/sudan-free.html?profileId=${user.id}';
                              final text = l10n.localeName == 'ar'
                                  ? 'شاهد الملف الشخصي لـ ${user.name} على تطبيق سودان فري:\n$url'
                                  : 'Check out ${user.name}\'s profile on SudanFree:\n$url';
                              Share.share(text);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.badge, color: Colors.white),
                            tooltip: l10n.localeName == 'ar'
                                ? 'هويتي الرقمية'
                                : 'Digital ID',
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  PremiumPageRoute(
                                      page: DigitalIdCardScreen(user: user)));
                            },
                          ),
                          if (widget.isMe) ...[
                            IconButton(
                              icon: const Icon(Icons.favorite,
                                  color: Colors.white),
                              tooltip: l10n.localeName == 'ar'
                                  ? 'مفضلاتي'
                                  : 'Favorites',
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const FavoritesScreen())),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              tooltip: l10n.editStore,
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ProfileSetupScreen(
                                          existingUser: user))),
                            ),
                          ] else ...[
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white),
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
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: isBlocked
                                                  ? Colors.green
                                                  : Colors.red),
                                          child: Text(
                                              isRtl
                                                  ? (isBlocked
                                                      ? 'إلغاء الحظر'
                                                      : 'حظر')
                                                  : (isBlocked
                                                      ? 'Unblock'
                                                      : 'Block'),
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirestoreService().toggleBlock(
                                        auth.user!.id, user.id, isBlocked);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(isRtl
                                                ? (isBlocked
                                                    ? 'تم إلغاء الحظر'
                                                    : 'تم الحظر')
                                                : (isBlocked
                                                    ? 'Unblocked'
                                                    : 'Blocked'))),
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
                                        Text(
                                            user.isShop
                                                ? l10n.reportStore
                                                : (isRtl
                                                    ? 'الإبلاغ عن الحرفي'
                                                    : 'Report Freelancer'),
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
                        flexibleSpace: LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            final double expandedHeight = 200.0;
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
                                ClipPath(
                                  clipper: ProfileHeaderCurve(),
                                  child: Stack(
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
                                                      AppColors.primary,
                                                      AppColors.secondary
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      // Glass overlay for the cover photo so it keeps the app identity
                                      if (user.coverImageUrl != null)
                                        IgnorePointer(
                                          child: Container(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Avatar
                                Positioned(
                                  bottom: -60,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Opacity(
                                      opacity: opacity,
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.center,
                                        child: GestureDetector(
                                          onTap: opacity > 0
                                              ? () => _handleImageTap(
                                                  user.profileImageUrl, false)
                                              : null,
                                          child: Stack(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .scaffoldBackgroundColor,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.15),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Hero(
                                                  tag: '${user.id}_profile',
                                                  child: CircleAvatar(
                                                    radius: 80,
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .cardColor,
                                                    backgroundImage: user
                                                                .profileImageUrl !=
                                                            null
                                                        ? CachedNetworkImageProvider(
                                                            user.profileImageUrl!)
                                                        : null,
                                                    child:
                                                        user.profileImageUrl ==
                                                                null
                                                            ? const Icon(
                                                                Icons.person,
                                                                size: 60,
                                                                color:
                                                                    Colors.grey)
                                                            : null,
                                                  ),
                                                ),
                                              ),
                                              if (user.isOnline && !widget.isMe)
                                                Positioned(
                                                  bottom: 8,
                                                  right: 8,
                                                  child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Theme.of(
                                                                  context)
                                                              .scaffoldBackgroundColor,
                                                          width: 3),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              const SizedBox(
                                  height:
                                      80), // Space for the overlapping avatar

                              // Name & Skill
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SmartVerificationBadge(user: user, size: 24),
                                ],
                              ),
                              // All Skills as Chips
                              if (user.skills.isNotEmpty)
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: user.skills
                                      .where((s) => s.toLowerCase() != 'other')
                                      .map((skill) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              JobTitlesUtils.getLocalizedTitle(
                                                  skill,
                                                  context
                                                      .read<LocaleProvider>()
                                                      .locale
                                                      .languageCode),
                                              style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                            ),
                                          ))
                                      .toList(),
                                )
                              else
                                Text(
                                  JobTitlesUtils.getLocalizedTitle(
                                      user.jobTitle ?? 'Freelancer',
                                      context
                                          .read<LocaleProvider>()
                                          .locale
                                          .languageCode),
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),

                              const SizedBox(height: 16),

                              // Stats Row
                              GlassContainer(
                                blur: 15,
                                opacity: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.7,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).cardColor,
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: _buildStatItem(
                                            l10n.reviews,
                                            '${user.totalStars.round()}',
                                            Icons.star,
                                            Colors.amber)),
                                    Container(
                                        width: 1,
                                        height: 30,
                                        color:
                                            Colors.grey.withValues(alpha: 0.2)),
                                    Expanded(
                                        child: _buildStatItem(
                                            l10n.completedJobs,
                                            '${user.completedJobs}',
                                            Icons.work_history,
                                            Colors.blue)),
                                    Container(
                                        width: 1,
                                        height: 30,
                                        color:
                                            Colors.grey.withValues(alpha: 0.2)),
                                    Expanded(
                                        child: _buildStatItem(
                                            context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? 'المشاهدات'
                                                : 'Views',
                                            '${user.profileViews}',
                                            Icons.visibility,
                                            Colors.purple)),
                                    Container(
                                        width: 1,
                                        height: 30,
                                        color:
                                            Colors.grey.withValues(alpha: 0.2)),
                                    Expanded(
                                        child: _buildStatItem(
                                            l10n.location,
                                            user.state != null
                                                ? SudanLocations.getStateName(
                                                    user.state!,
                                                    context
                                                        .read<LocaleProvider>()
                                                        .locale
                                                        .languageCode)
                                                : (context
                                                        .read<LocaleProvider>()
                                                        .isArabic
                                                    ? 'غير محدد'
                                                    : 'Not set'),
                                            Icons.location_on,
                                            Colors.red)),

                                    // Partner / Favorite Button
                                    if (!widget.isMe) ...[
                                      Container(
                                          width: 1,
                                          height: 30,
                                          color: Colors.grey
                                              .withValues(alpha: 0.2)),
                                      Expanded(child: Consumer<AuthProvider>(
                                        builder: (context, auth, _) {
                                          final isViewerFreelancer =
                                              auth.user?.role ==
                                                      UserRole.freelancer ||
                                                  auth.user?.role ==
                                                      UserRole.techService ||
                                                  auth.user?.role ==
                                                      UserRole.privateService;

                                          // 1. Client/Shop Logic: Favorites (Hearts)
                                          if (!isViewerFreelancer) {
                                            final isFavorite = auth
                                                    .user?.favoriteUserIds
                                                    .contains(user.id) ??
                                                false;
                                            return _buildStatItem(
                                              context
                                                      .read<LocaleProvider>()
                                                      .isArabic
                                                  ? 'مفضلة'
                                                  : 'Favorite',
                                              isFavorite
                                                  ? (context
                                                          .read<
                                                              LocaleProvider>()
                                                          .isArabic
                                                      ? 'محفوظ'
                                                      : 'Saved')
                                                  : (context
                                                          .read<
                                                              LocaleProvider>()
                                                          .isArabic
                                                      ? 'حفظ'
                                                      : 'Save'),
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              isFavorite
                                                  ? Colors.red
                                                  : Colors.grey,
                                              onTap: () {
                                                auth.toggleFavoriteUser(
                                                    user.id);
                                              },
                                            );
                                          }

                                          // 2. Freelancer Viewer Logic: Partnership (Zamalah)
                                          final isPartner = auth
                                                  .user?.partnerIds
                                                  .contains(user.id) ??
                                              false;
                                          final isPending = user
                                                  .pendingPartnerIds
                                                  .contains(auth.user?.id) ||
                                              (auth.user?.pendingPartnerIds
                                                      .contains(user.id) ??
                                                  false);

                                          String titleText = context
                                                  .read<LocaleProvider>()
                                                  .isArabic
                                              ? 'إضافة'
                                              : 'Connect';
                                          IconData iconData =
                                              Icons.person_add_alt_1;
                                          Color iconColor = Colors.grey;

                                          if (isPartner) {
                                            titleText = context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? 'متصل'
                                                : 'Connected';
                                            iconData = Icons.check_circle;
                                            iconColor = Colors.green;
                                          } else if (isPending) {
                                            titleText = context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? 'مُعلّق'
                                                : 'Pending';
                                            iconData = Icons.schedule;
                                            iconColor = Colors.purple;
                                          }

                                          return _buildStatItem(
                                            context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? 'زميل'
                                                : 'Partner',
                                            titleText,
                                            iconData,
                                            iconColor,
                                            onTap: () {
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);
                                              final isAr = context
                                                  .read<LocaleProvider>()
                                                  .isArabic;
                                              if (isPartner || isPending) {
                                                auth.removePartner(user.id);
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(isAr
                                                        ? 'تم إلغاء العلاقة / الطلب'
                                                        : 'Relationship / Request cancelled'),
                                                    backgroundColor:
                                                        Colors.grey,
                                                  ),
                                                );
                                              } else {
                                                auth.sendPartnerRequest(
                                                    user.id);
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(isAr
                                                        ? 'تم إرسال طلب الزمالة بنجاح!'
                                                        : 'Partner request sent successfully!'),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      )),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Reputation Score & Vouchers
                              if (user.completedJobs > 0 ||
                                  user.reviewsCount > 0 ||
                                  user.vouchedBy.isNotEmpty)
                                GlassContainer(
                                  blur: 15,
                                  opacity: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.3
                                      : 0.7,
                                  borderRadius: BorderRadius.circular(16),
                                  color: Theme.of(context).cardColor,
                                  child: Row(
                                    children: [
                                      // Part 1: Reputation Score
                                      Expanded(
                                        flex: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 16),
                                          child: Row(
                                            children: [
                                              ReputationScoreWidget(
                                                  user: user, size: 48),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      context
                                                              .read<
                                                                  LocaleProvider>()
                                                              .isArabic
                                                          ? 'نقاط السمعة'
                                                          : 'Reputation',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      context
                                                              .read<
                                                                  LocaleProvider>()
                                                              .isArabic
                                                          ? 'مبنية على الأعمال'
                                                          : 'Based on jobs',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .textLight),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Divider
                                      Container(
                                          width: 1,
                                          height: 50,
                                          color: Colors.grey
                                              .withValues(alpha: 0.2)),

                                      // Part 2: Vouchers
                                      Expanded(
                                        flex: 1,
                                        child: InkWell(
                                          onTap: () => _showVouchersBottomSheet(
                                              context, user.vouchedBy),
                                          borderRadius: BorderRadius.horizontal(
                                            right: context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? Radius.zero
                                                : const Radius.circular(16),
                                            left: context
                                                    .read<LocaleProvider>()
                                                    .isArabic
                                                ? const Radius.circular(16)
                                                : Radius.zero,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context
                                                          .read<
                                                              LocaleProvider>()
                                                          .isArabic
                                                      ? 'المُزكّين'
                                                      : 'Vouchers',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13),
                                                ),
                                                const SizedBox(height: 6),
                                                if (user.vouchedBy.isEmpty)
                                                  Text(
                                                    context
                                                            .read<
                                                                LocaleProvider>()
                                                            .isArabic
                                                        ? 'لا توجد تزكيات'
                                                        : 'No vouches yet',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textLight),
                                                  )
                                                else
                                                  SizedBox(
                                                    height: 42,
                                                    child: Stack(
                                                      children: [
                                                        for (int i = 0;
                                                            i <
                                                                (user.vouchedBy
                                                                            .length >
                                                                        3
                                                                    ? 3
                                                                    : user
                                                                        .vouchedBy
                                                                        .length);
                                                            i++)
                                                          Positioned(
                                                            right: context
                                                                    .read<
                                                                        LocaleProvider>()
                                                                    .isArabic
                                                                ? null
                                                                : (i * 26.0),
                                                            left: context
                                                                    .read<
                                                                        LocaleProvider>()
                                                                    .isArabic
                                                                ? (i * 26.0)
                                                                : null,
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .cardColor,
                                                                    width: 2),
                                                              ),
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 19,
                                                                backgroundColor: AppColors
                                                                    .primary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                backgroundImage: user.vouchedBy[i]
                                                                            [
                                                                            'profileImageUrl'] !=
                                                                        null
                                                                    ? NetworkImage(
                                                                        user.vouchedBy[i]
                                                                            [
                                                                            'profileImageUrl'])
                                                                    : null,
                                                                child: user.vouchedBy[i]
                                                                            [
                                                                            'profileImageUrl'] ==
                                                                        null
                                                                    ? const Icon(
                                                                        Icons
                                                                            .person,
                                                                        size:
                                                                            20,
                                                                        color: AppColors
                                                                            .primary)
                                                                    : null,
                                                              ),
                                                            ),
                                                          ),
                                                        if (user.vouchedBy
                                                                .length >
                                                            3)
                                                          Positioned(
                                                            right: context
                                                                    .read<
                                                                        LocaleProvider>()
                                                                    .isArabic
                                                                ? null
                                                                : (3 * 26.0),
                                                            left: context
                                                                    .read<
                                                                        LocaleProvider>()
                                                                    .isArabic
                                                                ? (3 * 26.0)
                                                                : null,
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .cardColor,
                                                                    width: 2),
                                                              ),
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 19,
                                                                backgroundColor:
                                                                    AppColors
                                                                        .sudanGold,
                                                                child: Text(
                                                                  '+${user.vouchedBy.length - 3}',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Bio
                              if (user.bio != null && user.bio!.isNotEmpty)
                                LinkableText(
                                  text: user.bio!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      height: 1.5,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withValues(alpha: 0.9)),
                                ),

                              const SizedBox(height: 16),

                              // Average Price Card
                              _buildAveragePriceCard(user),

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
                            dividerColor:
                                Colors.transparent, // Remove default underline
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
                              Tab(
                                  height: 28,
                                  text: Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? 'المنشورات'
                                      : 'Posts'),
                              Tab(
                                  height: 28,
                                  text: Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? 'المعرض'
                                      : 'Portfolio'),
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
                      // Tab 1: Posts (Grid)
                      KeepAliveTabView(child: _buildPortfolioGrid()),

                      // Tab 2: Professional Portfolio (Detailed)
                      KeepAliveTabView(child: _buildProfessionalPortfolio()),

                      // Tab 3: Reviews (List + Add Button)
                      KeepAliveTabView(child: _buildReviewsSection()),
                    ],
                  ),
                );
              }),
          // Loading overlay while uploading image
          if (_isUploadingImage)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        context.read<LocaleProvider>().isArabic
                            ? 'جاري رفع الصورة...'
                            : 'Uploading image...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.isMe &&
              (_tabController.index == 0 || _tabController.index == 1))
            SmartDraggableFab(
              heroTag: 'add_portfolio_fab',
              icon: _tabController.index == 0
                  ? Icons.add_photo_alternate_outlined
                  : Icons.create_new_folder_outlined,
              locale: Localizations.localeOf(context).languageCode,
              initialBottom: MediaQuery.of(context).padding.bottom + 82.0,
              onPressed: () {
                if (_tabController.index == 0) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreatePostScreen()));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const CreatePortfolioProjectScreen()));
                }
              },
            ),
        ],
      ),
      floatingActionButton: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isGlass = themeProvider.isGlassmorphismEnabled;
          final isAr = Localizations.localeOf(context).languageCode == 'ar';

          if (widget.isMe) {
            return const SizedBox.shrink();
          }

          return AdaptiveFabPadding(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                isGlass
                    ? GlassContainer(
                        borderRadius: BorderRadius.circular(28),
                        blur: 15,
                        opacity: 0.4,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            if (widget.user.latitude == null ||
                                widget.user.longitude == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(isAr
                                        ? 'الموقع غير متوفر لهذا المستخدم'
                                        : 'Location not available for this user'),
                                    backgroundColor: Colors.red),
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
                        heroTag: 'freelancer_location_btn',
                        onPressed: () {
                          if (widget.user.latitude == null ||
                              widget.user.longitude == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(isAr
                                      ? 'الموقع غير متوفر لهذا المستخدم'
                                      : 'Location not available for this user'),
                                  backgroundColor: Colors.red),
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
                        blur: 15,
                        opacity: 0.4,
                        color: AppColors.primary,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
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
                                Text(isAr ? 'تواصل معي' : 'Contact Me',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : FloatingActionButton.extended(
                        heroTag: 'freelancer_contact_btn',
                        onPressed: () => _showContactMenu(context, widget.user),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.support_agent, size: 22),
                        label: Text(isAr ? 'تواصل معي' : 'Contact Me',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showContactMenu(BuildContext context, UserModel freelancer) {
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
                    ? 'تواصل مع الحرفي'
                    : 'Contact Freelancer',
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
                      freelancer.whatsappNumber ?? freelancer.phoneNumber);
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
                  _makePhoneCall(freelancer.phoneNumber);
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
                      otherUserId: freelancer.id,
                      otherUserName: freelancer.name,
                      otherUserImageUrl: freelancer.profileImageUrl,
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
                          logContext: 'FreelancerProfile.createChat');
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

  // --- Helper Widgets & Methods ---

  Widget _buildStatItem(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: onTap != null
                      ? color
                      : null)), // Highlight value if clickable
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPortfolioGrid() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<PostModel>>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading posts: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'خطأ في تحميل الأعمال. قد يحتاج النظام لإنشاء فهرس (Index) في قاعدة البيانات.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: LoadingIndicator());
        final portfolioPosts = snapshot.data!.toList();

        // Sort: Pinned first, then by date (descending)
        portfolioPosts.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        if (portfolioPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  widget.isMe ? l10n.addWork : l10n.noWorkDisplayed,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: portfolioPosts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final post = portfolioPosts[index];
            return StaggeredAnimatedWidget(
              index: index,
              listId: 'freelancer_profile_${widget.user.id}',
              child: PostCard(
                post: post,
                currentUserId: context.read<AuthProvider>().user?.id ?? '',
                locale: Localizations.localeOf(context).languageCode,
                showActions: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewsSection() {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.reviews,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _buildReviewsList(),
      ],
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<List<ReviewModel>>(
      stream: _reviewsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LoadingIndicator();
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return Center(
              child: Text(AppLocalizations.of(context)!.noReviews,
                  style: const TextStyle(color: Colors.grey)));

        return Column(
          children: [
            ReviewStatsWidget(
              reviews: snapshot.data!,
              locale: context.read<LocaleProvider>().locale.languageCode,
            ),
            ...snapshot.data!.map((review) => ReviewCard(
                review: review,
                locale: context.read<LocaleProvider>().locale.languageCode)),
          ],
        );
      },
    );
  }

  void _showAddReviewDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger
          .showSnackBar(SnackBar(content: Text(l10n.loginToReview)));
      return;
    }

    // التحقق من وجود اتفاق مكتمل قبل السماح بالتقييم
    final hasCompletedJob = await FirestoreService().hasCompletedJob(
      currentUser.id,
      widget.user.id,
    );

    if (!hasCompletedJob) {
      if (!mounted) return;
      final isArabic = context.read<LocaleProvider>().isArabic;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(isArabic
                      ? 'يجب إكمال اتفاق أولاً'
                      : 'Complete an Agreement First')),
            ],
          ),
          content: Text(
            isArabic
                ? 'يجب أن يكون هناك اتفاق مكتمل بينك وبين الحرفي قبل إضافة تقييم. هذا يضمن مصداقية التقييمات.'
                : 'You must have a completed agreement with this freelancer before leaving a review. This ensures review credibility.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'حسناً' : 'OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AddReviewDialog(
        freelancerId: widget.user.id,
        targetName: widget.user.name,
        targetImageUrl: widget.user.profileImageUrl,
        onSubmit: (rating, comment, isNegative, isJobCompleted,
            wouldWorkAgain) async {
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(this.context);

          final review = ReviewModel(
            id: '',
            freelancerId: widget.user.id,
            reviewerId: currentUser.id,
            reviewerName: currentUser.name,
            reviewerImageUrl: currentUser.profileImageUrl,
            rating: rating,
            comment: comment,
            isNegative: isNegative,
            wouldWorkAgain: wouldWorkAgain,
            createdAt: DateTime.now(),
          );

          try {
            await FirestoreService()
                .createReview(review, isJobCompleted: isJobCompleted);

            // Log review successfully added
            debugPrint('Review added successfully for job completion check');

            if (!mounted) return;
            messenger.showSnackBar(SnackBar(
                content: Text(l10n.reviewAddedSuccessfully),
                backgroundColor: AppColors.success));
          } catch (e, stack) {
            if (!mounted) return;
            if (context.mounted)
              AppErrorHandler.show(context, e, stack,
                  logContext: 'FreelancerProfile.addReview');
          }
        },
      ),
    );
  }

  Future<void> _openWhatsApp(String? number) async {
    if (number == null || number.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;

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
              context: 'FreelancerProfile.whatsappContactLog');
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

      final message = Uri.encodeComponent(l10n.localeName == 'ar'
          ? 'مرحباً، أتواصل معك من خلال منصة سودان فري.'
          : 'Hello, I am contacting you through the Sudan Free platform.');
      final url = 'https://wa.me/$cleaned?text=$message';
      try {
        await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    } finally {
      // Contact complete
    }
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
          AppErrorHandler.log(e, stack,
              context: 'FreelancerProfile.callContactLog');
        }
      }

      final Uri launchUri = Uri(scheme: 'tel', path: number);
      try {
        await launchUrl(launchUri,
            mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    } finally {
      // Call complete
    }
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
      if (imageUrl != null)
        _openImage(imageUrl,
            isCover ? '${widget.user.id}_cover' : '${widget.user.id}_profile');
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
                isCover ? l10n.coverPhoto : l10n.profilePhoto,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (imageUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(AppLocalizations.of(context)!.viewImage),
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
              title: Text(AppLocalizations.of(context)!.changeImage),
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
    // prevent multiple taps
    if (_isUploadingImage) return;

    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;
    if (!mounted) return;

    // Show loading overlay
    setState(() => _isUploadingImage = true);

    try {
      final file = File(pickedFile.path);
      final url = isCover
          ? await StorageService()
              .uploadImage(file, folder: 'users/${widget.user.id}/cover')
          : await StorageService().uploadProfileImage(widget.user.id, file);

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

        // Force refresh list
        if (mounted)
          context.read<UserProvider>().fetchFreelancers(forceRefresh: true);

        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(context.read<LocaleProvider>().isArabic
                  ? 'تم تحديث الصورة بنجاح ✅'
                  : 'Image updated successfully ✅'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(context.read<LocaleProvider>().isArabic
                  ? 'فشل رفع الصورة، تحقق من اتصالك بالإنترنت'
                  : 'Image upload failed, check your internet connection'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stack) {
      if (mounted)
        AppErrorHandler.show(context, e, stack,
            logContext: 'FreelancerProfile.uploadImage');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Widget _buildProfessionalPortfolio() {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    return StreamBuilder<List<PortfolioProjectModel>>(
      stream: _portfolioStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading portfolio: ${snapshot.error}');
          // Show empty state for permission errors instead of red error text
          final errorStr = snapshot.error.toString();
          if (errorStr.contains('permission-denied') ||
              errorStr.contains('PERMISSION_DENIED')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    locale == 'ar'
                        ? 'لا توجد مشاريع في المعرض بعد'
                        : 'No portfolio projects yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                locale == 'ar'
                    ? 'خطأ في تحميل المعرض المهني.'
                    : 'Error loading portfolio.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: LoadingIndicator());
        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  locale == 'ar'
                      ? 'لا توجد مشاريع في المعرض بعد'
                      : 'No portfolio projects yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _buildProjectCard(project, locale);
          },
        );
      },
    );
  }

  Widget _buildProjectCard(PortfolioProjectModel project, String locale) {
    final isAr = locale == 'ar';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PortfolioProjectDetailScreen(
              project: project,
              providerName: widget.user.name,
              providerImageUrl: widget.user.profileImageUrl,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image Area ───
            if (project.imageUrls.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: project.imageUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          color: Colors.grey.withValues(alpha: 0.1),
                          child:
                              const Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey)),
                    ),
                  ),
                  if (project.imageUrls.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${project.imageUrls.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            // ─── Details Area ───
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Delete Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDeleteProject(project),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (project.category != null)
                        _buildTag(project.category!, AppColors.primary,
                            Icons.category),
                      if (project.status != null)
                        _buildTag(
                          project.status == 'completed'
                              ? (isAr ? 'مكتمل' : 'Completed')
                              : (isAr ? 'قيد التنفيذ' : 'Ongoing'),
                          project.status == 'completed'
                              ? Colors.green
                              : Colors.orange,
                          Icons.task_alt,
                        ),
                      if (project.projectType != null)
                        _buildTag(
                          _getLocalizedType(project.projectType!, isAr),
                          Colors.blue,
                          Icons.work_outline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description Snippet
                  Text(
                    project.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // View Details Button
                  Row(
                    children: [
                      Text(
                        isAr ? 'عرض تفاصيل المشروع' : 'View Project Details',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLocalizedType(String type, bool isAr) {
    if (type == 'personal') return isAr ? 'شخصي' : 'Personal';
    if (type == 'client') return isAr ? 'لعميل' : 'Client';
    if (type == 'startup') return isAr ? 'شركة ناشئة' : 'Startup';
    return isAr ? 'أخرى' : 'Other';
  }

  Widget _buildTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDeleteProject(PortfolioProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشروع'),
        content:
            const Text('هل أنت متأكد أنك تريد حذف هذا المشروع من معرض أعمالك؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              FirestoreService()
                  .deletePortfolioProject(widget.user.id, project.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showVouchersBottomSheet(
      BuildContext context, List<Map<String, dynamic>> vouchedBy) {
    if (vouchedBy.isEmpty) return;
    final isAr = context.read<LocaleProvider>().isArabic;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'قائمة المُزكّين' : 'Vouchers List',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vouchedBy.length,
                  itemBuilder: (ctx, index) {
                    final voucher = vouchedBy[index];
                    return FutureBuilder<UserModel?>(
                      future: FirestoreService().getUser(voucher['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircleAvatar(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            title: Text('...'),
                          );
                        }
                        final user = snapshot.data;
                        if (user == null) return const SizedBox.shrink();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.profileImageUrl != null
                                ? NetworkImage(user.profileImageUrl!)
                                : null,
                            child: user.profileImageUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(user.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${user.jobTitle != null ? JobTitlesUtils.getLocalizedTitle(user.jobTitle!, context.read<LocaleProvider>().locale.languageCode) : ''} • ${user.state != null ? SudanLocations.getStateName(user.state!, context.read<LocaleProvider>().locale.languageCode) : ''}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(userId: user.id)));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAveragePriceCard(UserModel user) {
    if (user.jobTitle == null) return const SizedBox();

    // Try to find the matching JobCategory
    JobCategory? matchingCategory;
    try {
      matchingCategory = JobCategory.values.firstWhere(
          (cat) => cat.name.toLowerCase() == user.jobTitle!.toLowerCase());
    } catch (e) {
      // Not a standard enum category, skip average calculation
      return const SizedBox();
    }

    return FutureBuilder<double?>(
      future: JobFirestoreService().calculateFairPrice(matchingCategory),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          // If no average available, maybe show their own hourly rate if they set one
          if (user.hourlyRate != null && user.hourlyRate! > 0) {
            return _buildPriceContainer(context,
                title: context.read<LocaleProvider>().isArabic
                    ? 'سعري الخاص'
                    : 'My Rate',
                price: user.hourlyRate!,
                icon: Icons.person_outline);
          }
          return const SizedBox();
        }

        return _buildPriceContainer(context,
            title: context.read<LocaleProvider>().isArabic
                ? 'متوسط السعر في السوق'
                : 'Market Average Price',
            price: snapshot.data!,
            icon: Icons.analytics_outlined);
      },
    );
  }

  Widget _buildPriceContainer(BuildContext context,
      {required String title, required double price, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat('#,##0').format(price)} ',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      context.read<LocaleProvider>().isArabic
                          ? 'جنيه سوداني'
                          : 'SDG',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                blur: 20,
                opacity: isDark ? 0.3 : 0.9,
                color: isDark ? Colors.black45 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200),
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
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => true;
}

class ProfileHeaderCurve extends CustomClipper<Path> {
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
