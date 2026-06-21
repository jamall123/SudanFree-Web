import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/sudan_locations.dart';
import '../../core/utils/job_titles_utils.dart';
import '../../core/utils/rank_utils.dart';
import '../../core/routes/premium_page_route.dart';
import '../../models/user_model.dart';
import '../../models/contact_log_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../views/profile/profile_screen.dart';
import '../../views/chat/chat_screen.dart';
import '../../providers/chat_provider.dart';
import '../common/verification_badge.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../common/glass_container.dart';
import '../common/premium_animations.dart';

/// Modern Freelancer Card with rectangular design
class FreelancerCard extends StatelessWidget {
  final UserModel freelancer;
  final VoidCallback? onTap;
  final VoidCallback? onWhatsApp;
  final String locale;
  final String? currentUserId;
  final String? currentUserName;
  final bool isPromoted;
  final bool showContactButton;

  const FreelancerCard({
    super.key,
    required this.freelancer,
    this.onTap,
    this.onWhatsApp,
    this.locale = 'ar',
    this.currentUserId,
    this.currentUserName,
    this.isPromoted = false,
    this.showContactButton = true,
  });

  Future<void> _openWhatsApp(BuildContext context) async {
    if (freelancer.phoneNumber == null) return;

    // Smart safety based on rating
    final rating = freelancer.rating;
    final reviewsCount = freelancer.reviewsCount;

    // Trusted users (4.5+ with reviews) - no warning needed
    if (rating >= 4.5 && reviewsCount >= 3) {
      _launchWhatsApp();
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    // Determine warning level
    String title;
    String content;
    Color iconColor;
    IconData icon;

    if (reviewsCount == 0) {
      // New user - extra caution
      title = l10n.newUser;
      content = l10n.newUserWarning;
      iconColor = Colors.orange;
      icon = Icons.fiber_new;
    } else if (rating < 3) {
      // Low rating - strong warning
      title = l10n.warning;
      content = l10n.lowRatingWarning(rating.toStringAsFixed(1));
      iconColor = Colors.red;
      icon = Icons.warning;
    } else {
      // Normal user (3-4.5) - light reminder
      title = l10n.reminder;
      content = l10n.normalUserReminder;
      iconColor = Colors.blue;
      icon = Icons.info;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.chat, size: 18),
            label: Text(l10n.openWhatsApp),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      _launchWhatsApp();
    }
  }

  Future<void> _launchWhatsApp() async {
    if (freelancer.phoneNumber == null) return;

    // تسجيل contactLog قبل فتح واتساب
    if (currentUserId != null && currentUserId != freelancer.id) {
      try {
        final log = ContactLogModel(
          id: '',
          contacterId: currentUserId!,
          contacterName: currentUserName ?? '',
          freelancerId: freelancer.id,
          freelancerName: freelancer.name,
          contactType: 'whatsapp',
          createdAt: DateTime.now(),
        );
        await FirestoreService().createContactLog(log);
      } catch (e) {
        debugPrint('Error creating contact log: $e');
      }
    }

    String cleaned = freelancer.phoneNumber!.replaceAll(RegExp(r'[^\d]'), '');

    // Smart Format for Sudan
    if (cleaned.startsWith('0')) {
      cleaned = '249${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('249') && cleaned.length == 9) {
      cleaned = '249$cleaned';
    }

    final message =
        Uri.encodeComponent('مرحباً، أتواصل معك من خلال منصة سودان فري.');
    final url = 'https://wa.me/$cleaned?text=$message';
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
  }

  void _showContactMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'تواصل مع ${freelancer.name}'
                    : 'Contact ${freelancer.name}',
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
                  if (onWhatsApp != null) {
                    onWhatsApp!();
                  } else {
                    _openWhatsApp(context);
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.call, color: Colors.white)),
                title: Text(Localizations.localeOf(context).languageCode == 'ar'
                    ? 'اتصال مباشر'
                    : 'Direct Call'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final phone =
                      freelancer.phoneNumber ?? freelancer.whatsappNumber;
                  if (phone != null && phone.isNotEmpty) {
                    final uri = Uri.parse('tel:$phone');
                    try {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
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
                  if (currentUserId == null) return;

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
                      currentUserId: currentUserId!,
                      currentUserName: currentUserName ?? '',
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
                  } catch (e) {
                    navigator.pop();
                    if (ctx.mounted) Navigator.pop(ctx);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalStars = RankUtils.calculateTotalStars(
        freelancer.rating, freelancer.reviewsCount);
    final locale = Localizations.localeOf(context).languageCode;
    final rankInfo = RankUtils.getRankInfo(totalStars, locale);
    final bool isRanked = rankInfo != null;
    final rankColor = rankInfo?.color ?? AppColors.sudanGold;

    return PressableCard(
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  PremiumPageRoute(page: ProfileScreen(userId: freelancer.id)),
                ),
        child: GlassContainer(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          blur: 15,
          opacity: (isRanked || isPromoted)
              ? 0.15
              : (Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.25),
          color: (isRanked || isPromoted)
              ? rankColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isPromoted
              ? Border.all(
                  color: AppColors.sudanGold.withValues(alpha: 0.8), width: 2.0)
              : isRanked
                  ? Border.all(
                      color: rankColor.withValues(alpha: 0.4), width: 1.5)
                  : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile Image - Modern rounded rectangle
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                          ),
                          child: freelancer.profileImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: CloudinaryService.getOptimizedUrl(
                                      freelancer.profileImageUrl!,
                                      width: 200,
                                      quality: 'auto'),
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                  placeholder: (_, __) => _buildInitials(),
                                  errorWidget: (_, __, ___) => _buildInitials(),
                                )
                              : _buildInitials(),
                        ),
                      ),
                      // Online indicator
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: freelancer.isAvailable
                                ? AppColors.success
                                : AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      // Rank badge
                      if (isRanked)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: rankColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: rankColor.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(rankInfo.icon,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Info Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Row
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                freelancer.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPromoted)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                child: Icon(Icons.star_rounded,
                                    color: AppColors.sudanGold, size: 20),
                              ),
                            SmartVerificationBadge(user: freelancer, size: 16),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Bio Snippet
                        if (freelancer.bio != null &&
                            freelancer.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              freelancer.bio!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    height: 1.2,
                                    fontSize: 11,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Service Type + Skills Row (inline)
                        Row(
                          children: [
                            // Service type badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: freelancer.isTechService
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : freelancer.isPrivateService
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: freelancer.isTechService
                                      ? Colors.blue.withValues(alpha: 0.3)
                                      : freelancer.isPrivateService
                                          ? Colors.orange.withValues(alpha: 0.3)
                                          : Colors.teal.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                freelancer.getRoleDisplayName(locale),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: freelancer.isTechService
                                      ? Colors.blue
                                      : freelancer.isPrivateService
                                          ? Colors.orange
                                          : Colors.teal,
                                ),
                              ),
                            ),
                            if (freelancer.skills.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    freelancer.skills
                                        .where(
                                            (s) => s.toLowerCase() != 'other')
                                        .take(2)
                                        .map((skill) =>
                                            JobTitlesUtils.getLocalizedTitle(
                                                skill, locale))
                                        .join(' • '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Location Row
                        if (freelancer.state != null)
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 12,
                                  color: Theme.of(context)
                                          .iconTheme
                                          .color
                                          ?.withValues(alpha: 0.7) ??
                                      Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  freelancer.locality != null &&
                                          freelancer.state != null
                                      ? '${SudanLocations.getLocalityName(freelancer.locality!, locale)} - ${SudanLocations.getStateName(freelancer.state!, locale)}'
                                      : (freelancer.state != null
                                          ? SudanLocations.getStateName(
                                              freelancer.state!, locale)
                                          : ''),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  if (showContactButton)
                    // Unified Contact Button
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showContactMenu(context),
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Icon(Icons.support_agent,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildInitials() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.1),
      child: Icon(Icons.person,
          size: 40, color: Colors.grey.withValues(alpha: 0.5)),
    );
  }
}

/// Compact Freelancer Card for grid view
class FreelancerGridCard extends StatelessWidget {
  final UserModel freelancer;
  final VoidCallback? onTap;
  final String locale;

  const FreelancerGridCard({
    super.key,
    required this.freelancer,
    this.onTap,
    this.locale = 'ar',
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 15,
      opacity: Theme.of(context).brightness == Brightness.dark ? 0.08 : 0.25,
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: freelancer.profileImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: CloudinaryService.getOptimizedUrl(
                              freelancer.profileImageUrl!,
                              width: 400,
                              quality: 'auto'),
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (_, __) => _buildGridInitials(),
                          errorWidget: (_, __, ___) => _buildGridInitials(),
                        )
                      : _buildGridInitials(),
                ),
              ),
            ),

            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            freelancer.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SmartVerificationBadge(user: freelancer, size: 14),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: freelancer.isAvailable
                                ? AppColors.success
                                : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Location
                    if (freelancer.state != null)
                      Text(
                        '📍 ${SudanLocations.getStateName(freelancer.state!, locale)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const Spacer(),
                    // Rank/Rating (Hidden Stars)
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          '${freelancer.completedJobs} ${locale == 'ar' ? 'عمل' : 'jobs'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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

  Widget _buildGridInitials() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.1),
      child: Icon(Icons.person,
          size: 50, color: Colors.grey.withValues(alpha: 0.5)),
    );
  }
}
