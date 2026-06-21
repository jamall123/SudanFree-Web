import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../models/squad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../posts/post_details_screen.dart';
import '../posts/comments_sheet.dart';
import '../profile/freelancer_profile_screen.dart';
import '../profile/shop_profile_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../safety/safety_tips_screen.dart';
import '../requests/request_details_screen.dart';
import '../jobs/active_job_tracking_screen.dart';
import '../chat/chats_list_screen.dart';
import '../../providers/chat_provider.dart';
import '../../core/routes/premium_page_route.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/common/glass_container.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmartGuideService.showMicroTip(
        context,
        messageAr:
            'ابقَ على اطلاع دائم! هنا تجد أحدث التنبيهات لطلباتك ورسائلك المهمة 🔔',
        messageEn:
            'Stay in the loop! Find the latest updates on your requests and messages here 🔔',
        tipId: 'notifications_tip',
        icon: Icons.notifications_active_rounded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'ar' ? 'التنبيهات' : 'Notifications'),
        centerTitle: true,
        actions: [
          // Chat List Button (For ALL users)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.support_agent),
                onPressed: () {
                  Navigator.push(
                    context,
                    PremiumPageRoute(page: const ChatsListScreen()),
                  );
                },
              ),
              if (context.watch<ChatProvider>().getTotalUnreadCount(user.id) >
                  0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${context.watch<ChatProvider>().getTotalUnreadCount(user.id)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),

          // Icon for Pending Partner Requests
          if (user.role == UserRole.freelancer ||
              user.role == UserRole.shop ||
              user.role == UserRole.techService)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () =>
                      _showPendingRequestsSheet(context, user, locale),
                ),
                if (user.pendingPartnerIds.isNotEmpty ||
                    user.pendingSquadInvites.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${user.pendingPartnerIds.length + user.pendingSquadInvites.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
          StreamBuilder<List<NotificationModel>>(
            stream:
                context.read<UserProvider>().getNotificationsStream(user.id),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final hasUnread = notifications.any((n) => !n.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await FirestoreService().markAllNotificationsAsRead(user.id);
                },
                child: Text(
                  locale == 'ar' ? 'قراءة الكل' : 'Read all',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: context.read<UserProvider>().getNotificationsStream(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.notifications_off_rounded,
              title: locale == 'ar' ? 'لا توجد تنبيهات' : 'No notifications',
              subtitle: locale == 'ar'
                  ? 'ابق على اطلاع! تصفح المجتمع وتفاعل الآن.'
                  : 'Stay updated! Browse the community now.',
              actionLabel:
                  locale == 'ar' ? 'تصفح المجتمع' : 'Explore Community',
              actionIcon: Icons.explore_rounded,
              onAction: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return TweenAnimationBuilder<double>(
                  key: ValueKey(notif.id),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration:
                      Duration(milliseconds: 300 + (index.clamp(0, 10) * 50)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset((1 - value) * 30, 0),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _SimpleNotificationTile(
                    notification: notif,
                    locale: locale,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showPendingRequestsSheet(
      BuildContext context, UserModel currentUser, String locale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PendingRequestsSheet(locale: locale),
    );
  }
}

class _SimpleNotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final String locale;

  const _SimpleNotificationTile({
    required this.notification,
    required this.locale,
  });

  @override
  State<_SimpleNotificationTile> createState() =>
      _SimpleNotificationTileState();
}

class _SimpleNotificationTileState extends State<_SimpleNotificationTile> {
  bool _isNavigating = false;

  NotificationModel get notification => widget.notification;
  String get locale => widget.locale;

  // ── Icon per type ──
  IconData get _icon {
    switch (notification.type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.mention:
        return Icons.alternate_email_rounded;
      case NotificationType.rating:
        return Icons.star_rounded;
      case NotificationType.offer:
        return Icons.local_offer_rounded;
      case NotificationType.partnerRequest:
        return Icons.people_alt_rounded;
      case NotificationType.message:
        return Icons.mail_rounded;
      case NotificationType.follow:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.fraudWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.reviewRequest:
        return Icons.rate_review_rounded;
      case NotificationType.system:
        return Icons.campaign_rounded;
      case NotificationType.assignment:
        return Icons.assignment_ind_rounded;
    }
  }

  // ── Color per type ──
  Color get _color {
    switch (notification.type) {
      case NotificationType.like:
        return Colors.redAccent;
      case NotificationType.comment:
        return Colors.blueAccent;
      case NotificationType.mention:
        return Colors.orangeAccent;
      case NotificationType.rating:
        return Colors.amber;
      case NotificationType.offer:
        return Colors.teal;
      case NotificationType.partnerRequest:
        return Colors.deepPurpleAccent;
      case NotificationType.message:
        return AppColors.primary;
      case NotificationType.follow:
        return Colors.green;
      case NotificationType.fraudWarning:
        return AppColors.error;
      case NotificationType.reviewRequest:
        return Colors.amber.shade700;
      case NotificationType.system:
        return AppColors.primary;
      case NotificationType.assignment:
        return Colors.indigoAccent;
    }
  }

  // ── Readable title per type ──
  String get _title {
    if (notification.title.isNotEmpty) return notification.title;

    switch (notification.type) {
      case NotificationType.like:
        return locale == 'ar' ? 'تفاعل جديد' : 'New Reaction';
      case NotificationType.comment:
        return locale == 'ar' ? 'تعليق جديد 💬' : 'New Comment';
      case NotificationType.mention:
        return locale == 'ar' ? 'تم ذكرك 📢' : 'You were mentioned';
      case NotificationType.rating:
        return locale == 'ar' ? 'تقييم جديد ⭐' : 'New Rating';
      case NotificationType.offer:
        return locale == 'ar' ? 'عرض جديد 📩' : 'New Offer';
      case NotificationType.partnerRequest:
        return locale == 'ar' ? 'طلب زمالة 🤝' : 'Partner Request';
      case NotificationType.message:
        return locale == 'ar' ? 'رسالة جديدة' : 'New Message';
      case NotificationType.follow:
        return locale == 'ar' ? 'متابعة جديدة' : 'New Follower';
      case NotificationType.fraudWarning:
        return locale == 'ar' ? 'تحذير ⚠️' : 'Warning';
      case NotificationType.reviewRequest:
        return locale == 'ar' ? 'كيف كانت تجربتك؟' : 'Rate your experience';
      case NotificationType.system:
        return locale == 'ar' ? 'سودان فري' : 'SudanFree';
      case NotificationType.assignment:
        return locale == 'ar' ? 'مهمة جديدة' : 'New Assignment';
    }
  }

  // ── Time ago ──
  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return locale == 'ar' ? 'الآن' : 'now';
    } else if (diff.inMinutes < 60) {
      return locale == 'ar' ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return locale == 'ar' ? 'منذ ${diff.inHours} س' : '${diff.inHours}h';
    } else {
      return locale == 'ar' ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isFraud = notification.type == NotificationType.fraudWarning;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: notification.isRead
          ? theme.cardColor
          : (isFraud
              ? Colors.red.withValues(alpha: isDark ? 0.15 : 0.06)
              : AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)),
      borderRadius: BorderRadius.circular(14),
      blur: 15,
      opacity: isDark ? 0.3 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isNavigating ? null : () => _onTap(context),
          onLongPress: () => _onLongPress(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _color, size: 22),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, right: 6),
                              decoration: BoxDecoration(
                                color: _color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _timeAgo(notification.createdAt.toDate()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      Text(
                        notification.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                              alpha: notification.isRead ? 0.6 : 0.85),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tap action ──
  Future<void> _onTap(BuildContext context) async {
    if (_isNavigating) return; // Prevent double tap
    setState(() => _isNavigating = true);

    final firestore = FirestoreService();

    // Mark as read (fire-and-forget, don't block navigation)
    if (!notification.isRead) {
      firestore.markNotificationAsRead(notification.id);
    }

    try {
      switch (notification.type) {
        case NotificationType.like:
          if (notification.relatedId != null) {
            await _navigateToPost(context, notification.relatedId!,
                openComments: false);
          }
          break;
        case NotificationType.comment:
        case NotificationType.mention:
          if (notification.relatedId != null) {
            await _navigateToPost(context, notification.relatedId!,
                openComments: true);
          }
          break;
        case NotificationType.rating:
          if (notification.relatedId != null) {
            await _navigateToProfile(context, notification.userId);
          }
          break;
        case NotificationType.fraudWarning:
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SafetyTipsScreen()));
          break;
        case NotificationType.reviewRequest:
          if (notification.relatedId != null) {
            await _handleReviewRequestTap(context, notification);
          }
          break;
        case NotificationType.offer:
          if (notification.relatedId != null) {
            await _navigateToRequest(context, notification.relatedId!);
          }
          break;
        case NotificationType.partnerRequest:
          if (notification.relatedId != null) {
            await _navigateToProfile(context, notification.relatedId!);
          } else {
            if (!context.mounted) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _PendingRequestsSheet(locale: locale),
            );
          }
          break;
        case NotificationType.message:
          if (notification.relatedId != null) {
            final chat = await firestore.getChatById(notification.relatedId!);
            if (chat != null && mounted) {
              Navigator.push(
                  context, PremiumPageRoute(page: ChatScreen(chat: chat)));
            }
          }
          break;
        case NotificationType.follow:
          // Navigate to the shop/freelancer profile
          if (notification.relatedId != null) {
            await _navigateToProfile(context, notification.relatedId!);
          }
          break;
        case NotificationType.system:
          // Try user first, if not found, try job
          if (notification.relatedId != null) {
            final user = await firestore.getUser(notification.relatedId!);
            if (user != null) {
              await _navigateToProfile(context, notification.relatedId!);
            } else {
              final job = await firestore.getJob(notification.relatedId!);
              if (job != null && mounted) {
                Navigator.push(
                    context,
                    PremiumPageRoute(
                        page: ActiveJobTrackingScreen(jobId: job.id)));
              }
            }
          }
          break;
        case NotificationType.assignment:
          if (notification.relatedId != null) {
            await _navigateToRequest(context, notification.relatedId!);
          }
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  // ── Long press to delete ──
  Future<void> _onLongPress(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale == 'ar' ? 'حذف الإشعار' : 'Delete Notification'),
        content: Text(locale == 'ar'
            ? 'هل أنت متأكد من حذف هذا الإشعار؟'
            : 'Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(locale == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(locale == 'ar' ? 'حذف' : 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirestoreService().deleteNotification(notification.id);
    }
  }

  Future<void> _navigateToPost(BuildContext context, String postId,
      {bool openComments = false}) async {
    final post = await FirestoreService().getPost(postId);
    if (!context.mounted) return;

    if (post != null) {
      final route =
          MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post));
      Navigator.push(context, route);
      if (openComments) {
        // Wait for the push animation to finish before showing comments
        Future.delayed(const Duration(milliseconds: 400), () {
          if (context.mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => CommentsSheet(
                postId: post.id,
                postOwnerId: post.userId,
              ),
            );
          }
        });
      }
    } else {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('عذراً، هذا المنشور لم يعد موجوداً')),
      );
    }
  }

  Future<void> _navigateToProfile(BuildContext context, String userId) async {
    final user = await FirestoreService().getUser(userId);
    if (!context.mounted) return;

    if (user != null) {
      if (user.isFreelancer) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FreelancerProfileScreen(user: user, isMe: false)));
      } else if (user.isShop) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ShopProfileScreen(user: user, isMe: false)));
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
      }
    }
  }

  Future<void> _navigateToRequest(
      BuildContext context, String requestId) async {
    final request = await FirestoreService().getRequestById(requestId);
    if (!context.mounted) return;

    if (request != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RequestDetailsScreen(request: request)));
    } else {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('عذراً، هذا الطلب لم يعد موجوداً')),
      );
    }
  }

  Future<void> _handleReviewRequestTap(
      BuildContext context, NotificationModel notification) async {
    final freelancerId = notification.relatedId!;
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    final contactLog =
        await FirestoreService().getContactLog(currentUser.id, freelancerId);
    if (contactLog != null && contactLog.hasReviewed) {
      if (!context.mounted) return;
      final isArabic = context.read<LocaleProvider>().isArabic;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content:
              Text(isArabic ? 'تم التقييم مسبقاً ✅' : 'Already reviewed ✅'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final freelancer = await FirestoreService().getUser(freelancerId);
    if (freelancer == null || !context.mounted) return;

    if (freelancer.isShop) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopProfileScreen(
            user: freelancer,
            isMe: currentUser.id == freelancer.id,
            initialTabIndex: 1,
            showReviewDialog: true,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FreelancerProfileScreen(
            user: freelancer,
            isMe: currentUser.id == freelancer.id,
            initialTabIndex: 1,
            showReviewDialog: true,
          ),
        ),
      );
    }
  }
}

class _PendingRequestsSheet extends StatefulWidget {
  final String locale;

  const _PendingRequestsSheet({
    required this.locale,
  });

  @override
  State<_PendingRequestsSheet> createState() => _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends State<_PendingRequestsSheet> {
  List<UserModel> _requesters = [];
  List<SquadModel> _squads = [];
  bool _isLoading = true;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequesters();
  }

  Future<void> _loadRequesters() async {
    final user = context.read<AuthProvider>().user;
    if (user == null ||
        (user.pendingPartnerIds.isEmpty && user.pendingSquadInvites.isEmpty)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final futures = <Future<dynamic>>[];

      if (user.pendingPartnerIds.isNotEmpty) {
        futures.add(FirestoreService().getUsersByIds(user.pendingPartnerIds));
      } else {
        futures.add(Future.value(<UserModel>[]));
      }

      if (user.pendingSquadInvites.isNotEmpty) {
        futures.add(FirebaseFirestore.instance
            .collection('squads')
            .where(FieldPath.documentId, whereIn: user.pendingSquadInvites)
            .get()
            .then((snap) => snap.docs
                .map((doc) => SquadModel.fromFirestore(doc))
                .toList()));
      } else {
        futures.add(Future.value(<SquadModel>[]));
      }

      final results = await Future.wait(futures);
      final users = results[0] as List<UserModel>;
      final squadsList = results[1] as List<SquadModel>;

      if (mounted) {
        setState(() {
          _requesters = users;
          _squads = squadsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSquadRequest(String squadId, bool accept) async {
    if (_processingIds.contains(squadId)) return;

    final squadIndex = _squads.indexWhere((s) => s.id == squadId);
    if (squadIndex == -1) return;
    final squad = _squads[squadIndex];

    setState(() {
      _processingIds.add(squadId);
      _squads.removeAt(squadIndex);
    });

    try {
      final user = context.read<AuthProvider>().user!;
      final batch = FirebaseFirestore.instance.batch();

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.id);
      batch.update(userRef, {
        'pendingSquadInvites': FieldValue.arrayRemove([squadId]),
      });

      if (accept) {
        final squadRef =
            FirebaseFirestore.instance.collection('squads').doc(squadId);
        batch.update(squadRef, {
          'memberIds': FieldValue.arrayUnion([user.id])
        });
      }

      await batch.commit();

      // Refresh local user state
      context.read<AuthProvider>().refreshUserProfile();

      if (mounted) {
        setState(() => _processingIds.remove(squadId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept
                ? (widget.locale == 'ar'
                    ? 'تم الانضمام للمجموعة بنجاح ✅'
                    : 'Joined squad successfully ✅')
                : (widget.locale == 'ar'
                    ? 'تم رفض دعوة المجموعة ❌'
                    : 'Squad invite declined ❌')),
            backgroundColor: accept ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingIds.remove(squadId);
          _squads.insert(squadIndex, squad);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.locale == 'ar'
                  ? 'حدث خطأ، يرجى المحاولة'
                  : 'An error occurred'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRequest(String requesterId, bool accept) async {
    if (_processingIds.contains(requesterId)) return;

    final requesterIndex = _requesters.indexWhere((u) => u.id == requesterId);
    if (requesterIndex == -1) return;
    final requester = _requesters[requesterIndex];

    setState(() {
      _processingIds.add(requesterId);
      _requesters.removeAt(requesterIndex);
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.handlePartnerRequest(requesterId, accept,
          requester: requester);

      if (mounted) {
        setState(() {
          _processingIds.remove(requesterId);
        });

        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(accept
                ? (widget.locale == 'ar'
                    ? 'تم قبول طلب الزمالة ✅'
                    : 'Partner request accepted ✅')
                : (widget.locale == 'ar'
                    ? 'تم رفض طلب الزمالة ❌'
                    : 'Partner request declined ❌')),
            backgroundColor: accept ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingIds.remove(requesterId);
          _requesters.insert(requesterIndex, requester);
        });
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(widget.locale == 'ar'
                ? 'حدث خطأ، يرجى المحاولة'
                : 'An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProfile(UserModel user) {
    if (context.mounted) Navigator.pop(context);
    if (user.isFreelancer) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  FreelancerProfileScreen(user: user, isMe: false)));
    } else if (user.isShop) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ShopProfileScreen(user: user, isMe: false)));
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = widget.locale == 'ar';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
        minHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isArabic ? 'الطلبات والدعوات' : 'Requests & Invites',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_requesters.isNotEmpty || _squads.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_requesters.length + _squads.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha: 0.1)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requesters.isEmpty && _squads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_add_disabled_rounded,
                                size: 72,
                                color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              isArabic
                                  ? 'لا توجد طلبات معلقة'
                                  : 'No pending requests',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isArabic
                                  ? 'ستظهر هنا طلبات الزمالة ودعوات المجموعات'
                                  : 'Partner requests and squad invites will appear here',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_requesters.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 8, left: 4, right: 4),
                              child: Text(
                                isArabic ? 'طلبات الزمالة' : 'Partner Requests',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary),
                              ),
                            ),
                            ..._requesters.map((requester) =>
                                _buildUserRequestCard(
                                    requester, isDark, isArabic)),
                          ],
                          if (_requesters.isNotEmpty && _squads.isNotEmpty)
                            const SizedBox(height: 24),
                          if (_squads.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 8, left: 4, right: 4),
                              child: Text(
                                isArabic ? 'دعوات المجموعات' : 'Squad Invites',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.primary),
                              ),
                            ),
                            ..._squads.map((squad) =>
                                _buildSquadInviteCard(squad, isDark, isArabic)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRequestCard(
      UserModel requester, bool isDark, bool isArabic) {
    final isProcessing = _processingIds.contains(requester.id);
    final roleText = requester.role == UserRole.freelancer ||
            requester.role == UserRole.techService
        ? (isArabic ? 'حرفي' : 'Freelancer')
        : (requester.role == UserRole.shop
            ? (isArabic ? 'معرض / متجر' : 'Shop')
            : '');

    return GestureDetector(
      onTap: () => _navigateToProfile(requester),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: requester.profileImageUrl != null
                  ? CachedNetworkImageProvider(requester.profileImageUrl!)
                  : null,
              child: requester.profileImageUrl == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 30)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requester.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.work_outline,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        roleText,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _handleRequest(requester.id, true),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.green, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleRequest(requester.id, false),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.red, size: 22),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquadInviteCard(SquadModel squad, bool isDark, bool isArabic) {
    final isProcessing = _processingIds.contains(squad.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: squad.squadImageUrl != null
                ? CachedNetworkImageProvider(squad.squadImageUrl!)
                : null,
            child: squad.squadImageUrl == null
                ? const Icon(Icons.groups, color: AppColors.primary, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  squad.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        squad.category.getName(widget.locale),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _handleSquadRequest(squad.id, true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.green, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _handleSquadRequest(squad.id, false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.red, size: 22),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
