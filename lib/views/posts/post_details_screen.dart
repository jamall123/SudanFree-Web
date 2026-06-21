import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../widgets/common/linkable_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/mentions/mention_overlay.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/full_screen_image_viewer.dart';
import '../../services/firestore_service.dart';
import '../../providers/posts_provider.dart';
import '../../views/posts/comments_sheet.dart';
import '../profile/profile_screen.dart';

import '../../core/constants/app_colors.dart';
import '../profile/product_detail_screen.dart';

/// شاشة تفاصيل المنشور/المنتج مع إمكانية التعليق والتفاعل
class PostDetailsScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailsScreen({super.key, required this.post});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  String _getTimeAgo(DateTime time, BuildContext context) {
    final diff = DateTime.now().difference(time);
    final locale = context.read<LocaleProvider>().locale.languageCode;
    if (diff.inMinutes < 60) {
      return locale == 'ar'
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return locale == 'ar'
          ? 'منذ ${diff.inHours} ساعة'
          : '${diff.inHours}h ago';
    } else {
      return locale == 'ar' ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    }
  }

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  // Mentions Logic
  List<UserModel> _filteredPartners = [];
  bool _showMentions = false;
  int _mentionStart = -1;
  final Map<String, String> _mentionedUsers = {}; // name -> id
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Fetch partners when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchPartners();
    });
    _commentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;
    if (selection.baseOffset < 0) return;

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);

    // Check for @
    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt != -1) {
      final query = textBeforeCursor.substring(lastAt + 1);

      // Basic validation: query shouldn't have newlines or too many spaces
      if (query.contains('\n') || query.split(' ').length > 3) {
        if (_showMentions) setState(() => _showMentions = false);
        return;
      }

      final partners = context.read<AuthProvider>().partners;
      final matches = partners
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (matches.isNotEmpty) {
        setState(() {
          _filteredPartners = matches;
          _showMentions = true;
          _mentionStart = lastAt;
        });
      } else {
        setState(() => _showMentions = false);
      }
    } else {
      if (_showMentions) setState(() => _showMentions = false);
    }
  }

  void _selectMention(UserModel user) {
    if (_mentionStart < 0) return;

    final text = _commentController.text;
    final selection = _commentController.selection;
    final cursorPos = selection.baseOffset;

    // Be safe about bounds
    // textBeforeCursor check ensured lastAt < cursorPos
    final start = _mentionStart;
    final end = cursorPos;

    if (start >= 0 && end > start && end <= text.length) {
      final newText = text.replaceRange(start, end, '@${user.name} ');
      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: start + user.name.length + 2));

      _mentionedUsers['@${user.name}'] = user.id;
      setState(() => _showMentions = false);
    }
  }

  /// إشارة لجميع الشركاء دفعة واحدة
  void _selectAllPartners() {
    if (_mentionStart < 0) return;

    final partners = context.read<AuthProvider>().partners;
    if (partners.isEmpty) return;

    final text = _commentController.text;
    final selection = _commentController.selection;
    final cursorPos = selection.baseOffset;
    final start = _mentionStart;
    final end = cursorPos;

    if (start >= 0 && end > start && end <= text.length) {
      // Build mentions string for all partners
      final mentionsText = partners.map((p) => '@${p.name}').join(' ');
      final newText = text.replaceRange(start, end, '$mentionsText ');
      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: start + mentionsText.length + 1),
      );

      // Add all partners to mentioned users map
      for (var partner in partners) {
        _mentionedUsers['@${partner.name}'] = partner.id;
      }

      setState(() => _showMentions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.read<LocaleProvider>().locale.languageCode == 'ar';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(isArabic ? 'التفاصيل' : 'Details')),
            Text(
              _getTimeAgo(widget.post.createdAt, context),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.user == null) return const SizedBox.shrink();
              final isFavorite =
                  auth.user!.favoriteProductIds.contains(widget.post.id);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                tooltip: isArabic ? 'حفظ للمفضلة' : 'Save to Favorites',
                onPressed: () => auth.toggleFavoriteProduct(widget.post.id),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image(s) Carousel
                      if (widget.post.allImageUrls.isNotEmpty)
                        Column(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context)
                                  .size
                                  .width, // Square format
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: widget.post.allImageUrls.length,
                                onPageChanged: (index) {
                                  setState(() => _currentPage = index);
                                },
                                itemBuilder: (context, index) {
                                  final imageUrl =
                                      widget.post.allImageUrls[index];
                                  final widgetContent = GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullScreenImageViewer(
                                            imageUrls: widget.post.allImageUrls,
                                            initialIndex: index,
                                          ),
                                        ),
                                      );
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          CloudinaryService.getOptimizedUrl(
                                              imageUrl,
                                              width: 1200,
                                              quality: 'auto'),
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    ),
                                  );

                                  // Only first image gets the hero tag to match the feed
                                  if (index == 0) {
                                    return Hero(
                                      tag: widget.post.id,
                                      child: widgetContent,
                                    );
                                  }
                                  return widgetContent;
                                },
                              ),
                            ),
                            if (widget.post.allImageUrls.length > 1) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.post.allImageUrls.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentPage == index
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[300],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                      // Caption / Description
                      if (widget.post.caption != null &&
                          widget.post.caption!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: LinkableText(
                            text: widget.post.caption!,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ),

                      // --- Owner Header ---
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                        userId: widget.post.userId)));
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                backgroundImage:
                                    widget.post.userImageUrl != null
                                        ? CachedNetworkImageProvider(
                                            CloudinaryService.getOptimizedUrl(
                                                widget.post.userImageUrl!,
                                                width: 100,
                                                quality: 'auto'))
                                        : null,
                                child: widget.post.userImageUrl == null
                                    ? Text(
                                        widget.post.userName.isNotEmpty
                                            ? widget.post.userName[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.post.userName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    if (widget.post.userJobTitle != null &&
                                        widget.post.userJobTitle!.isNotEmpty)
                                      Text(
                                        widget.post.userJobTitle!,
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // --- Interactive Actions Bar ---
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final currentUserId = auth.user?.id ?? '';
                          return Consumer<PostsProvider>(
                            builder: (context, postsProvider, _) {
                              // Get latest post data if available in provider, else use widget.post
                              final latestPost = postsProvider.posts.firstWhere(
                                  (p) => p.id == widget.post.id,
                                  orElse: () => widget.post);
                              final isLiked = latestPost.reactions
                                  .containsKey(currentUserId);
                              final totalReactions = latestPost.totalReactions;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    // Like Button
                                    InkWell(
                                      onTap: () {
                                        if (currentUserId.isEmpty) return;
                                        final type =
                                            isLiked ? 'unlike' : 'like';
                                        postsProvider.reactToPost(
                                          latestPost.id,
                                          currentUserId,
                                          auth.user?.name ?? '',
                                          latestPost.userId,
                                          type,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isLiked
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              color: isLiked
                                                  ? Colors.red
                                                  : Colors.grey[600],
                                              size: 22,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              totalReactions > 0
                                                  ? '$totalReactions'
                                                  : '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isLiked
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Comment Button
                                    InkWell(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => CommentsSheet(
                                              postId: latestPost.id,
                                              postOwnerId: latestPost.userId),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons
                                                    .chat_bubble_outline_rounded,
                                                color: Colors.grey[600],
                                                size: 22),
                                            const SizedBox(width: 6),
                                            Text(
                                              latestPost.commentsCount > 0
                                                  ? '${latestPost.commentsCount}'
                                                  : '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                              ),
                                            ),
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
                      ),

                      const SizedBox(height: 20),
                      // Comments section has been temporarily frozen/removed for display-only mode

                      // ── بطاقة المنتج المرتبط ──────────────────────────────────
                      if (widget.post.linkedProductId != null)
                        _LinkedProductBanner(post: widget.post),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mentions Overlay
          if (_showMentions)
            Positioned(
              bottom: 70,
              left: 16,
              right: 16,
              child: MentionOverlay(
                partners: _filteredPartners,
                locale: Localizations.localeOf(context).languageCode,
                onSelectAll:
                    _filteredPartners.length > 1 ? _selectAllPartners : null,
                onSelectUser: _selectMention,
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
/// بانر المنتج المرتبط — يظهر في أسفل تفاصيل المنشور المجتمعي
/// يتيح الانتقال المباشر لصفحة تفاصيل المنتج
// ════════════════════════════════════════════════════════════════════════════
class _LinkedProductBanner extends StatefulWidget {
  final PostModel post;
  const _LinkedProductBanner({required this.post});

  @override
  State<_LinkedProductBanner> createState() => _LinkedProductBannerState();
}

class _LinkedProductBannerState extends State<_LinkedProductBanner> {
  PostModel? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final doc =
          await FirestoreService().getPost(widget.post.linkedProductId!);
      if (mounted) {
        setState(() {
          _product = doc;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.read<LocaleProvider>().locale.languageCode == 'ar';

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    // Use snapshot data from the post itself if Firestore fetch failed
    final productName = _product?.caption?.split('\n').first ??
        widget.post.linkedProductName ??
        (isArabic ? 'منتج' : 'Product');
    final imageUrl =
        _product?.allImageUrls.firstOrNull ?? widget.post.linkedProductImage;
    final price = _product?.price ?? widget.post.linkedProductPrice;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          if (_product != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: _product!),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // صورة المنتج
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[200],
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined,
                              color: AppColors.primary, size: 30),
                        ),
                ),
                const SizedBox(width: 14),

                // تفاصيل المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // تسمية "المنتج المرتبط"
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isArabic ? '🛍️ منتج مرتبط' : '🛍️ Linked Product',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Text(
                        productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${price.toStringAsFixed(0)} SDG',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),

                // سهم الانتقال
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isArabic
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
