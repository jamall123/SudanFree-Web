import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/post_model.dart';
import '../../providers/posts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../views/posts/comments_sheet.dart';
import '../../views/posts/create_post_screen.dart';
import '../../services/cloudinary_service.dart';
import '../../views/profile/profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user_model.dart';
import '../common/linkable_text.dart';
import '../common/poll_widget.dart';
import '../../views/posts/post_details_screen.dart';
import '../../views/search/search_screen.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../common/internal_link_preview.dart';
import '../common/glass_container.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final String locale;
  final bool enableHero;
  final bool showActions;
  final bool isPromoted;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.locale,
    this.enableHero = true,
    this.showActions = true,
    this.isPromoted = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  bool _isSharing = false;
  int _currentImageIndex = 0;
  bool? _localIsLiked;
  int? _localTotalReactions;

  // Like animation
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;

  // Heart overlay animation
  bool _showHeartOverlay = false;
  late AnimationController _heartOverlayController;
  late Animation<double> _heartOverlayScale;

  // Track precached URLs to avoid redundant calls
  static final Set<String> _precachedUrls = {};

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut));

    _heartOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _heartOverlayScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
        parent: _heartOverlayController, curve: Curves.easeInOut));

    _heartOverlayController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartOverlay = false);
        _heartOverlayController.reset();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.totalReactions != widget.post.totalReactions) {
      _localIsLiked = null;
      _localTotalReactions = null;
    }
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _heartOverlayController.dispose();
    super.dispose();
  }

  void _toggleLike({bool forceLike = false}) {
    final isLiked = _localIsLiked ??
        widget.post.reactions.containsKey(widget.currentUserId);
    final totalReactions = _localTotalReactions ?? widget.post.totalReactions;

    if (forceLike && isLiked) return; // Already liked

    HapticFeedback.lightImpact();
    _likeAnimController.forward(from: 0);

    if (forceLike) {
      setState(() {
        _showHeartOverlay = true;
        _localIsLiked = true;
        _localTotalReactions = totalReactions + 1;
      });
      _heartOverlayController.forward(from: 0);
    } else {
      setState(() {
        _localIsLiked = !isLiked;
        _localTotalReactions = isLiked
            ? (totalReactions > 0 ? totalReactions - 1 : 0)
            : totalReactions + 1;
      });
    }

    final type = (forceLike || !isLiked) ? 'like' : 'unlike';
    context.read<PostsProvider>().reactToPost(
          widget.post.id,
          widget.currentUserId,
          context.read<AuthProvider>().user?.name ?? '',
          widget.post.userId,
          type,
        );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      if (diff.inMinutes <= 0)
        return widget.locale == 'ar' ? 'الآن' : 'Just now';
      return widget.locale == 'ar'
          ? 'قبل ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return widget.locale == 'ar'
          ? 'قبل ${diff.inHours} ساعة'
          : '${diff.inHours}h ago';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != time.day)) {
      return widget.locale == 'ar' ? 'أمس' : 'Yesterday';
    } else if (diff.inDays < 7) {
      return widget.locale == 'ar'
          ? 'قبل ${diff.inDays} أيام'
          : '${diff.inDays}d ago';
    } else {
      return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
    }
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsScreen(post: widget.post),
      ),
    );
  }

  Widget _buildGridImage(String url, {double? height, bool isHero = false}) {
    Widget image;

    if (url.startsWith('/')) {
      // Local pending file
      image = kIsWeb
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
            )
          : Image.file(
              File(url),
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
            );
    } else {
      // Network file
      final detailUrl =
          CloudinaryService.getOptimizedUrl(url, width: 1200, quality: 'auto');
      if (!_precachedUrls.contains(detailUrl)) {
        _precachedUrls.add(detailUrl);
        precacheImage(CachedNetworkImageProvider(detailUrl), context);
      }

      image = CachedNetworkImage(
        imageUrl:
            CloudinaryService.getOptimizedUrl(url, width: 600, quality: 'auto'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        memCacheWidth: 800, // Memory Optimization
        placeholder: (_, __) => Container(
          color: AppColors.border.withValues(alpha: 0.1),
          child: const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.border.withValues(alpha: 0.1),
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
        ),
      );
    }

    if (isHero && widget.enableHero) {
      image = Hero(tag: widget.post.id, child: image);
    }

    return GestureDetector(
      onTap: _openDetails,
      onDoubleTap: () => _toggleLike(forceLike: true),
      child: image,
    );
  }

  Widget _buildImageCarousel(List<String> urls) {
    if (urls.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500, minHeight: 250),
        child: _buildGridImage(urls[0], isHero: true),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildGridImage(urls[index], isHero: index == 0);
            },
          ),
        ),
        if (urls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == index ? 8 : 6,
                height: _currentImageIndex == index ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.5),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.userName.isEmpty ||
        widget.post.userName == '?' ||
        widget.post.userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = widget.post.allImageUrls.isNotEmpty;
    final isOwner = widget.currentUserId == widget.post.userId;
    final isPending = widget.post.id.startsWith('pending_');
    final isLiked = _localIsLiked ??
        widget.post.reactions.containsKey(widget.currentUserId);
    final totalReactions = _localTotalReactions ?? widget.post.totalReactions;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      blur: 15,
      opacity: isDark ? 0.3 : 0.6,
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: widget.post.userId))),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: widget.post.userImageUrl != null
                              ? CachedNetworkImageProvider(
                                  CloudinaryService.getOptimizedUrl(
                                      widget.post.userImageUrl!,
                                      width: 100,
                                      quality: 'auto'),
                                  maxWidth: 150,
                                  maxHeight: 150,
                                )
                              : null,
                          child: widget.post.userImageUrl == null
                              ? Text(
                                  widget.post.userName.isNotEmpty
                                      ? widget.post.userName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                )
                              : null,
                        ),
                        if (widget.post.isUserVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.verified,
                                  size: 14, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name + title + time
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(userId: widget.post.userId))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.post.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isPromoted)
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Icon(Icons.star_rounded,
                                      color: AppColors.sudanGold, size: 16),
                                ),
                              if (widget.post.userJobTitle != null &&
                                  widget.post.userJobTitle!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.post.userRole == 'shop'
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : AppColors.primary
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.post.userJobTitle!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.post.userRole == 'shop'
                                          ? Colors.amber.shade700
                                          : AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 11, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Text(
                                _getTimeAgo(widget.post.createdAt),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                              ),
                              if (widget.post.category != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getCategoryName(
                                        widget.post.category!, widget.locale),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // More options or pending indicator
                  if (isPending)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    )
                  else if (isOwner)
                    IconButton(
                      icon: Icon(Icons.more_vert,
                          size: 20, color: Colors.grey[500]),
                      onPressed: () => _showOptions(context),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),

            // ─── Pinned ──────────────────────────────────────────────────
            if (widget.post.isPinned)
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.push_pin_rounded,
                        size: 11, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      widget.locale == 'ar' ? 'مُثبت' : 'Pinned',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // ─── Caption ─────────────────────────────────────────────────
            if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, hasImage ? 10 : 0),
                child: ExpandableCaption(
                    caption: widget.post.caption!, locale: widget.locale),
              ),

            // ─── Image Carousel (edge-to-edge) ────────────────────────────
            if (hasImage)
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildImageCarousel(widget.post.allImageUrls),
                  if (_showHeartOverlay)
                    ScaleTransition(
                      scale: _heartOverlayScale,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 100,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 10)
                        ],
                      ),
                    ),
                ],
              ),

            // ─── Poll Widget ──────────────────────────────────────────────
            if (widget.post.poll != null)
              PollWidget(
                  post: widget.post, currentUserId: widget.currentUserId),

            // ─── Actions Bar ─────────────────────────────────────────────
            if (widget.showActions) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    // Like (with scale animation + haptic)
                    ScaleTransition(
                      scale: _likeScaleAnim,
                      child: _buildIconAction(
                        context,
                        icon: isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: totalReactions > 0 ? '$totalReactions' : '',
                        color: isLiked ? Colors.red : Colors.grey[600]!,
                        onTap: _toggleLike,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Comment
                    _buildIconAction(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      label: widget.post.commentsCount > 0
                          ? '${widget.post.commentsCount}'
                          : '',
                      color: Colors.grey[600]!,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentsSheet(
                              postId: widget.post.id,
                              postOwnerId: widget.post.userId),
                        );
                      },
                    ),
                    const Spacer(),
                    // Share
                    _buildIconAction(
                      context,
                      icon: Icons.ios_share_rounded,
                      label: widget.post.sharesCount > 0
                          ? '${widget.post.sharesCount}'
                          : '',
                      color: Colors.grey[600]!,
                      onTap: () => _handleExternalShare(context),
                      isLoading: _isSharing,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: color))
            else
              Icon(icon, size: 22, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  void _handleExternalShare(BuildContext context) async {
    if (_isSharing) return;

    HapticFeedback.lightImpact();
    setState(() => _isSharing = true);

    final String text = widget.post.caption ?? '';
    // Use the direct download link with postId parameter
    final String appLink =
        'https://sudanfree.com/sudan-free.html?postId=${widget.post.id}';

    String shareContent =
        '${widget.post.userName} ${widget.locale == 'ar' ? 'شارك منشوراً على سودان فري' : 'shared a post on SudanFree'}:\n\n';

    if (text.isNotEmpty) {
      shareContent += '$text\n\n';
    }

    shareContent +=
        '${widget.locale == 'ar' ? 'حمل التطبيق وشاهد المنشور' : 'Download app to view post'}:\n$appLink';

    try {
      // Text only share
      // ignore: deprecated_member_use
      await Share.share(
        shareContent,
        subject: widget.locale == 'ar'
            ? 'منشور من سودان فري'
            : 'Post from SudanFree',
      );

      if (!context.mounted) return;
      context.read<PostsProvider>().incrementPostShares(widget.post.id);
    } catch (e) {
      debugPrint('Error sharing: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final user = context.read<AuthProvider>().user;
        final bool canUsePortfolio = user?.role == UserRole.freelancer ||
            user?.role == UserRole.shop ||
            user?.role == UserRole.techService;

        return Wrap(
          children: [
            if (canUsePortfolio)
              ListTile(
                leading: Icon(
                    widget.post.showInProfile
                        ? Icons.business_center_outlined
                        : Icons.add_photo_alternate_outlined,
                    color: AppColors.secondary),
                title: Text(widget.post.showInProfile
                    ? (widget.locale == 'ar'
                        ? 'إزالة من معرض الأعمال'
                        : 'Remove from Portfolio')
                    : (widget.locale == 'ar'
                        ? 'إضافة إلى معرض الأعمال'
                        : 'Add to Portfolio')),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success =
                      await context.read<PostsProvider>().updatePost(
                            postId: widget.post.id,
                            showInProfile: !widget.post.showInProfile,
                          );
                  if (context.mounted) {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? (widget.locale == 'ar'
                                ? 'تم التحديث بنجاح'
                                : 'Updated successfully')
                            : (widget.locale == 'ar'
                                ? 'فشل التحديث'
                                : 'Update failed')),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: Text(widget.locale == 'ar' ? 'تعديل' : 'Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePostScreen(post: widget.post),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(widget.locale == 'ar' ? 'حذف' : 'Delete'),
              onTap: () async {
                Navigator.pop(ctx);
                final success = await context
                    .read<PostsProvider>()
                    .deletePost(widget.post.id);
                if (context.mounted) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? (widget.locale == 'ar'
                              ? 'تم الحذف بنجاح'
                              : 'Deleted successfully')
                          : (widget.locale == 'ar'
                              ? 'فشل الحذف'
                              : 'Deletion failed')),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _getCategoryName(String categoryName, String locale) {
    try {
      final category =
          PostCategory.values.firstWhere((e) => e.name == categoryName);
      return category.getName(locale);
    } catch (_) {
      return categoryName;
    }
  }
}

class ExpandableCaption extends StatefulWidget {
  final String caption;
  final String locale;

  const ExpandableCaption({
    super.key,
    required this.caption,
    required this.locale,
  });

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _isExpanded = false;
  static const int _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinkableText(
              text: widget.caption,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
              maxLines: _isExpanded ? null : _maxLines,
              onHashtagTap: (hashtag) {
                // Navigate to search screen with the hashtag
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: hashtag),
                  ),
                );
              },
              onMentionTap: (username) {
                // Navigate to search screen with the username, which will find the user
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: username),
                  ),
                );
              },
            ),
            if (_extractFirstUrl(widget.caption) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InternalLinkPreviewWidget.isInternalLink(
                        _extractFirstUrl(widget.caption)!)
                    ? InternalLinkPreviewWidget(
                        url: _extractFirstUrl(widget.caption)!)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AnyLinkPreview(
                          link: _extractFirstUrl(widget.caption)!,
                          displayDirection: UIDirection.uiDirectionHorizontal,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[100],
                          errorWidget: const SizedBox.shrink(),
                          errorImage: '',
                          cache: const Duration(days: 7),
                          placeholderWidget: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[100],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.link,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.5)),
                                const SizedBox(width: 8),
                                Text(
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 'Loading link...'
                                      : 'جاري قراءة الرابط...',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            if (!_isExpanded &&
                (widget.caption.length > 150 ||
                    (widget.caption.split('\n').length > _maxLines)))
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  widget.locale == 'ar' ? 'عرض المزيد...' : 'See more...',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _extractFirstUrl(String text) {
    final RegExp urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text);
    if (match != null) {
      String url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      return url;
    }
    return null;
  }
}
