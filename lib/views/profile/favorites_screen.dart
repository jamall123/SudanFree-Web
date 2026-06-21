import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../core/utils/job_titles_utils.dart';
import '../../services/firestore_service.dart';
import 'profile_screen.dart';
import 'product_detail_screen.dart';
import '../posts/post_details_screen.dart';
import '../../models/post_model.dart';
import 'apprentices_dashboard_screen.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../services/smart_guide_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/firestore/user_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? _mySquadId;

  @override
  void initState() {
    super.initState();
    _checkSquadLeaderStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'مساحتك الخاصة! هنا تُحفظ الحسابات والمنشورات التي لفتت انتباهك للرجوع إليها 🔖',
        messageEn:
            'Your personal space! Saved accounts and posts live here for quick access 🔖',
        tipId: 'favorites_tip',
        icon: Icons.favorite_rounded,
      );
    });
  }

  Future<void> _checkSquadLeaderStatus() async {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('squads')
            .where('leaderId', isEqualTo: user.id)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty && mounted) {
          setState(() {
            _mySquadId = snap.docs.first.id;
          });
        }
      } catch (e) {
        debugPrint('Error fetching squad leader status: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(locale == 'ar' ? 'المفضلة' : 'Favorites')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isFreelancer = user.role == UserRole.freelancer ||
        user.role == UserRole.techService ||
        user.role == UserRole.privateService;
    final title = locale == 'ar'
        ? (!isFreelancer ? 'مفضلاتي' : 'الزملاء والمفضلة')
        : (!isFreelancer ? 'My Favorites' : 'Partners & Favorites');

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            isScrollable: true,
            tabs: [
              Tab(text: locale == 'ar' ? 'الزملاء' : 'Partners'),
              Tab(
                  text:
                      locale == 'ar' ? 'الحسابات المحفوظة' : 'Saved Accounts'),
              Tab(text: locale == 'ar' ? 'المجموعات' : 'Squads'),
              Tab(text: locale == 'ar' ? 'المنشورات المحفوظة' : 'Saved Posts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersTab(
                user: user,
                userIds: user.partnerIds,
                locale: locale,
                isPartnerList: true,
                mySquadId: _mySquadId),
            _UsersTab(
                user: user,
                userIds: user.favoriteUserIds,
                locale: locale,
                isPartnerList: false,
                mySquadId: _mySquadId),
            _SquadsTab(
                user: user,
                favoriteSquadIds: user.favoriteSquadIds,
                locale: locale),
            _ProductsTab(
                user: user,
                favoriteProductIds: user.favoriteProductIds,
                locale: locale),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  final UserModel user;
  final List<String> userIds;
  final String locale;
  final bool isPartnerList;
  final String? mySquadId;

  const _UsersTab(
      {required this.user,
      required this.userIds,
      required this.locale,
      required this.isPartnerList,
      this.mySquadId});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<UserModel>> _usersFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _usersFuture = FirestoreService().getUsersByIds(widget.userIds);
  }

  @override
  void didUpdateWidget(_UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userIds.length != oldWidget.userIds.length ||
        !widget.userIds.every((e) => oldWidget.userIds.contains(e))) {
      _usersFuture = FirestoreService().getUsersByIds(widget.userIds);
    }
  }

  Widget _buildShimmer(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action, UserModel targetUser,
      UserModel currentUser, String locale) async {
    final isAr = locale == 'ar';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (action == 'remove_partner') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isAr ? 'إلغاء الزمالة' : 'Remove Partner'),
          content: Text(isAr
              ? 'هل أنت متأكد من إلغاء زمالة ${targetUser.name}؟'
              : 'Are you sure you want to remove ${targetUser.name}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isAr ? 'تراجع' : 'Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isAr ? 'حذف' : 'Remove',
                    style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true) {
        await context.read<AuthProvider>().removePartner(targetUser.id);
        if (!mounted) return;
        context.read<AuthProvider>().fetchPartners(forceRefresh: true);
      }
    } else if (action == 'vouch') {
      try {
        await UserFirestoreService().vouchForUser(targetUser.id, currentUser);
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(isAr
                ? 'تم إرسال التزكية بنجاح!'
                : 'Recommendation sent successfully!'),
            backgroundColor: Colors.green));
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(isAr
                ? 'حدث خطأ أثناء التزكية، قد تكون زكيته مسبقاً.'
                : 'Error sending recommendation, you may have already vouched.'),
            backgroundColor: Colors.red));
      }
    } else if (action == 'request_apprenticeship') {
      try {
        await UserFirestoreService()
            .sendApprenticeshipRequest(currentUser.id, targetUser.id);
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(isAr
                ? 'تم إرسال طلب التتلمذ بنجاح!'
                : 'Apprenticeship request sent!'),
            backgroundColor: Colors.green));
      } catch (e) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text(
                isAr ? 'حدث خطأ أثناء إرسال الطلب' : 'Error sending request'),
            backgroundColor: Colors.red));
      }
    } else if (action == 'cancel_apprenticeship') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isAr ? 'إلغاء التتلمذ' : 'Cancel Apprenticeship'),
          content: Text(isAr
              ? 'هل أنت متأكد من فك الارتباط؟ إذا كنت الصبي، سيتم إرسال طلب للموافقة.'
              : 'Are you sure you want to cancel? If you are the apprentice, a request will be sent for approval.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(isAr ? 'تراجع' : 'Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isAr ? 'تأكيد' : 'Confirm',
                    style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true) {
        try {
          if (currentUser.apprenticesIds.contains(targetUser.id)) {
            await UserFirestoreService()
                .terminateApprentice(currentUser.id, targetUser.id);
            scaffoldMessenger.showSnackBar(SnackBar(
                content: Text(isAr
                    ? 'تم إلغاء التتلمذ بنجاح'
                    : 'Apprenticeship canceled'),
                backgroundColor: Colors.green));
          } else if (currentUser.masterId == targetUser.id) {
            await UserFirestoreService()
                .sendLeaveRequest(currentUser.id, targetUser.id);
            scaffoldMessenger.showSnackBar(SnackBar(
                content: Text(isAr
                    ? 'تم إرسال طلب الموافقة على ترك التتلمذ'
                    : 'Leave request sent to master'),
                backgroundColor: Colors.green));
          }
        } catch (e) {
          scaffoldMessenger.showSnackBar(SnackBar(
              content: Text(isAr ? 'حدث خطأ' : 'Error occurred'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildExpressiveActionButton(String label, IconData icon, Color color,
      VoidCallback onTap, bool isDark) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    if (widget.userIds.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle),
              child: Icon(
                  widget.isPartnerList
                      ? Icons.group_off
                      : Icons.favorite_border,
                  size: 60,
                  color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.locale == 'ar'
                  ? (widget.isPartnerList
                      ? 'لا يوجد زملاء حالياً'
                      : 'لا توجد حسابات مفضلة بعد')
                  : (widget.isPartnerList
                      ? 'No partners yet'
                      : 'No favorite accounts yet'),
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
                widget.locale == 'ar'
                    ? 'قم بإضافة حسابات من ملفاتهم الشخصية'
                    : 'Add accounts from their profiles',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    } else {
      content = FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildShimmer(isDark);
          if (snapshot.hasError)
            return Center(
                child: Text(
                    widget.locale == 'ar' ? 'حدث خطأ' : 'An error occurred'));

          final users = snapshot.data ?? [];
          if (users.isEmpty) return const SizedBox.shrink();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final targetUser = users[index];
              final isFavorite =
                  widget.user.favoriteUserIds.contains(targetUser.id);
              final isPartner = widget.user.partnerIds.contains(targetUser.id);

              final bool canCancelApprenticeship =
                  widget.user.masterId == targetUser.id ||
                      widget.user.apprenticesIds.contains(targetUser.id);
              final bool canRequestApprenticeship = !canCancelApprenticeship &&
                  widget.user.masterId == null &&
                  widget.user.role != UserRole.shop &&
                  widget.user.role != UserRole.client &&
                  targetUser.role != UserRole.shop &&
                  targetUser.role != UserRole.client;

              return Card(
                elevation: 0,
                color: isDark ? Colors.grey[900] : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                          left: 16, right: 16, top: 12, bottom: 4),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(userId: targetUser.id))),
                      leading: Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                width: 2)),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: targetUser.profileImageUrl != null
                              ? NetworkImage(targetUser.profileImageUrl!)
                              : null,
                          child: targetUser.profileImageUrl == null
                              ? Icon(
                                  targetUser.role == UserRole.shop
                                      ? Icons.store
                                      : Icons.person,
                                  color: AppColors.primary)
                              : null,
                        ),
                      ),
                      title: Text(targetUser.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(
                          targetUser.jobTitle != null ? JobTitlesUtils.getLocalizedTitle(targetUser.jobTitle!, widget.locale) :
                              (widget.locale == 'ar'
                                  ? 'حساب في سودان فري'
                                  : 'SudanFree Account'),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13)),
                      trailing: !widget.isPartnerList
                          ? IconButton(
                              icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.red
                                      : Colors.grey[400]),
                              onPressed: () {
                                context
                                    .read<AuthProvider>()
                                    .toggleFavoriteUser(targetUser.id);
                              },
                            )
                          : null,
                    ),
                    Divider(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.start,
                          children: [
                            _buildExpressiveActionButton(
                                widget.locale == 'ar' ? 'تزكية' : 'Vouch',
                                Icons.verified,
                                AppColors.sudanGold,
                                () => _handleMenuAction('vouch', targetUser,
                                    widget.user, widget.locale),
                                isDark),
                            if (canRequestApprenticeship)
                              _buildExpressiveActionButton(
                                  widget.locale == 'ar'
                                      ? 'طلب تتلمذ'
                                      : 'Request Apprenticeship',
                                  Icons.engineering,
                                  Colors.teal,
                                  () => _handleMenuAction(
                                      'request_apprenticeship',
                                      targetUser,
                                      widget.user,
                                      widget.locale),
                                  isDark),
                            if (canCancelApprenticeship)
                              _buildExpressiveActionButton(
                                  widget.locale == 'ar'
                                      ? 'إلغاء التتلمذ'
                                      : 'Cancel Apprenticeship',
                                  Icons.handshake_rounded,
                                  Colors.redAccent,
                                  () => _handleMenuAction(
                                      'cancel_apprenticeship',
                                      targetUser,
                                      widget.user,
                                      widget.locale),
                                  isDark),
                            if (widget.isPartnerList)
                              _buildExpressiveActionButton(
                                  widget.locale == 'ar'
                                      ? 'إلغاء الزمالة'
                                      : 'Remove Partner',
                                  Icons.person_remove_rounded,
                                  Colors.redAccent,
                                  () => _handleMenuAction('remove_partner',
                                      targetUser, widget.user, widget.locale),
                                  isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      children: [
        if (widget.isPartnerList && widget.user.apprenticesIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ApprenticesDashboardScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.admin_panel_settings,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.locale == 'ar'
                                  ? 'لوحة تحكم المعلم'
                                  : 'Master Dashboard',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                              widget.locale == 'ar'
                                  ? 'إدارة فريقك والصبيان (${widget.user.apprenticesIds.length})'
                                  : 'Manage your team & apprentices (${widget.user.apprenticesIds.length})',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: content),
      ],
    );
  }
}

class _SquadsTab extends StatefulWidget {
  final UserModel user;
  final List<String> favoriteSquadIds;
  final String locale;
  const _SquadsTab(
      {required this.user,
      required this.favoriteSquadIds,
      required this.locale});
  @override
  State<_SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends State<_SquadsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<DocumentSnapshot>> _squadsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchSquads();
  }

  void _fetchSquads() {
    _squadsFuture = _getCombinedSquads();
  }

  Future<List<DocumentSnapshot>> _getCombinedSquads() async {
    final futures = <Future<QuerySnapshot>>[];

    // 1. Favorited Squads
    if (widget.favoriteSquadIds.isNotEmpty) {
      // Split into chunks of 10 for whereIn limit
      for (var i = 0; i < widget.favoriteSquadIds.length; i += 10) {
        final end = (i + 10 < widget.favoriteSquadIds.length) ? i + 10 : widget.favoriteSquadIds.length;
        final chunk = widget.favoriteSquadIds.sublist(i, end);
        futures.add(FirebaseFirestore.instance
            .collection('squads')
            .where(FieldPath.documentId, whereIn: chunk)
            .get());
      }
    }

    // 2. Leader Squads
    futures.add(FirebaseFirestore.instance
        .collection('squads')
        .where('leaderId', isEqualTo: widget.user.id)
        .get());

    // 3. Member Squads
    futures.add(FirebaseFirestore.instance
        .collection('squads')
        .where('memberIds', arrayContains: widget.user.id)
        .get());

    final results = await Future.wait(futures);
    
    // Combine and deduplicate
    final Map<String, DocumentSnapshot> uniqueDocs = {};
    for (var snapshot in results) {
      for (var doc in snapshot.docs) {
        uniqueDocs[doc.id] = doc;
      }
    }
    
    return uniqueDocs.values.toList();
  }

  @override
  void didUpdateWidget(_SquadsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favoriteSquadIds.length != oldWidget.favoriteSquadIds.length ||
        !widget.favoriteSquadIds
            .every((e) => oldWidget.favoriteSquadIds.contains(e))) {
      _fetchSquads();
    }
  }

  Widget _buildShimmer(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
            height: 80,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: _squadsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return _buildShimmer(isDark);
        if (snapshot.hasError)
          return Center(
              child: Text(
                  widget.locale == 'ar' ? 'حدث خطأ' : 'An error occurred'));

        final docs = snapshot.data ?? [];
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.groups, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                    widget.locale == 'ar'
                        ? 'لا توجد مجموعات مفضلة بعد'
                        : 'No favorite squads yet',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final squadName = data['squadName'] ?? '';
            final bio = data['bio'] ?? '';

            return Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () {},
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.groups, color: AppColors.primary),
                ),
                title: Text(squadName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(bio,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: Icon(
                    widget.favoriteSquadIds.contains(doc.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.favoriteSquadIds.contains(doc.id)
                        ? Colors.red
                        : Colors.grey,
                  ),
                  onPressed: () =>
                      context.read<AuthProvider>().toggleFavoriteSquad(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductsTab extends StatefulWidget {
  final UserModel user;
  final List<String> favoriteProductIds;
  final String locale;
  const _ProductsTab(
      {required this.user,
      required this.favoriteProductIds,
      required this.locale});
  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<PostModel?>> _productsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  void _fetchProducts() {
    if (widget.favoriteProductIds.isEmpty) {
      _productsFuture = Future.value([]);
      return;
    }
    _productsFuture = Future.wait(widget.favoriteProductIds.map((id) async {
      try {
        final post = await FirestoreService().getPost(id);
        if (post == null)
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.read<AuthProvider>().toggleFavoriteProduct(id));
        return post;
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.read<AuthProvider>().toggleFavoriteProduct(id));
        return null;
      }
    }));
  }

  @override
  void didUpdateWidget(_ProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favoriteProductIds.length !=
            oldWidget.favoriteProductIds.length ||
        !widget.favoriteProductIds
            .every((e) => oldWidget.favoriteProductIds.contains(e))) {
      _fetchProducts();
    }
  }

  Widget _buildShimmer(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16),
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.favoriteProductIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
                widget.locale == 'ar'
                    ? 'لا توجد منشورات أو منتجات محفوظة'
                    : 'No saved posts or products',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return FutureBuilder<List<PostModel?>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return _buildShimmer(isDark);
        if (snapshot.hasError)
          return Center(
              child: Text(
                  widget.locale == 'ar' ? 'حدث خطأ' : 'An error occurred'));

        final products = snapshot.data
                ?.whereType<PostModel>()
                .where((p) => p.showInProfile)
                .toList() ??
            [];
        if (products.isEmpty) {
          return Center(
              child: Text(
                  widget.locale == 'ar'
                      ? 'لا توجد منشورات أو منتجات محفوظة'
                      : 'No saved posts or products',
                  style: TextStyle(color: Colors.grey[600])));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final imageUrl = product.allImageUrls.isNotEmpty
                ? product.allImageUrls.first
                : null;

            return GestureDetector(
              onTap: () {
                if (product.price != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(product: product)));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PostDetailsScreen(post: product)));
                }
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null)
                            CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey[200]),
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.broken_image))
                          else
                            Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.image,
                                    color: Colors.grey)),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.favorite,
                                      color: Colors.red, size: 20),
                                  onPressed: () => context
                                      .read<AuthProvider>()
                                      .toggleFavoriteProduct(product.id)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(product.caption ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            if (product.price != null && product.price! > 0)
                              Text(
                                  '${product.price} ${widget.locale == 'ar' ? 'ج.س' : 'SDG'}',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
