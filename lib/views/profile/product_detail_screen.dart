import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';
import '../../widgets/common/linkable_text.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/full_screen_image_viewer.dart';
import '../../models/user_model.dart';
import '../posts/create_post_screen.dart';
import '../../providers/posts_provider.dart';
import '../posts/comments_sheet.dart';
import 'profile_screen.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final PostModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewerId = context.read<AuthProvider>().user?.id;
      // Increment views count when the product is opened
      FirestoreService().incrementPostViews(widget.product.id, viewerId);
    });
  }

  String _buildProductLink() =>
      'https://sudanfree.com/sudan-free.html?productId=${widget.product.id}';

  Future<void> _copyProductLink(bool isArabic) async {
    await Clipboard.setData(ClipboardData(text: _buildProductLink()));
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(isArabic ? 'تم نسخ رابط المنتج ✅' : 'Product link copied ✅'),
      ]),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _shareInCommunity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          showInCommunity: true,
          showInProfile: false,
          linkedProduct: widget.product,
        ),
      ),
    );
  }

  Future<void> _handleOrderNow(BuildContext context, bool isArabic) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Fetch Shop User to get their WhatsApp number
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final shopUser = await FirestoreService().getUser(widget.product.userId);
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loading

      if (shopUser == null) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content:
                Text(isArabic ? 'حدث خطأ، المتجر غير موجود' : 'Shop not found'),
            backgroundColor: Colors.red));
        return;
      }

      final productUrl = _buildProductLink();
      final message = isArabic
          ? 'مرحباً، أريد طلب هذا المنتج:\n${widget.product.caption?.split('\n').first ?? ''}\n$productUrl\n\nهل هو متوفر؟'
          : 'Hello, I want to order this product:\n${widget.product.caption?.split('\n').first ?? ''}\n$productUrl\n\nIs it available?';

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
                  isArabic ? 'اطلب الآن عبر' : 'Order Now via',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.chat, color: Colors.white)),
                  title: Text(isArabic ? 'واتساب' : 'WhatsApp'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final number =
                        shopUser.whatsappNumber ?? shopUser.phoneNumber;
                    if (number == null || number.isEmpty) return;

                    String formattedNumber = number;
                    if (formattedNumber.startsWith('0')) {
                      formattedNumber = '249${formattedNumber.substring(1)}';
                    }
                    if (!formattedNumber.startsWith('+')) {
                      formattedNumber = '+$formattedNumber';
                    }

                    final whatsappUrl = Uri.parse(
                        'whatsapp://send?phone=$formattedNumber&text=${Uri.encodeComponent(message)}');
                    try {
                      await launchUrl(whatsappUrl);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isArabic
                                ? 'لم يتم العثور على واتساب'
                                : 'WhatsApp not found')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.message_rounded,
                          color: Colors.white)),
                  title: Text(isArabic ? 'محادثة داخل التطبيق' : 'In-App Chat'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final authProvider = context.read<AuthProvider>();
                    final currentUser = authProvider.user;
                    if (currentUser == null) return;

                    final chatProvider = context.read<ChatProvider>();
                    final nav = Navigator.of(context);

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

                      nav.pop(); // dismiss loading
                      if (chat != null) {
                        await chatProvider.sendMessage(
                          senderId: currentUser.id,
                          senderName: currentUser.name,
                          receiverId: shopUser.id,
                          content: message,
                        );
                        nav.push(MaterialPageRoute(
                            builder: (_) => ChatScreen(chat: chat)));
                      }
                    } catch (e) {
                      nav.pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Pop loading
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(isArabic ? 'حدث خطأ' : 'An error occurred'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isArabic = locale == 'ar';
    final currentUser = context.watch<AuthProvider>().user;
    final isMyProduct = currentUser?.id == widget.product.userId;
    final isShopOwner = currentUser?.role == UserRole.shop;
    final allMedia = widget.product.allImageUrls;

    final productTitle = widget.product.caption?.split('\n').first ?? '';
    final productDesc =
        widget.product.caption != null && widget.product.caption!.contains('\n')
            ? widget.product.caption!.split('\n').skip(1).join('\n').trim()
            : '';

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isArabic ? 'تفاصيل المنتج' : 'Product Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Favorite Button (For Clients only, or anyone)
          if (currentUser != null)
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final isFavorite =
                    auth.user?.favoriteProductIds.contains(widget.product.id) ??
                        false;
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : null,
                  ),
                  tooltip: isArabic ? 'مفضلة' : 'Favorite',
                  onPressed: () =>
                      auth.toggleFavoriteProduct(widget.product.id),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: isArabic ? 'نسخ رابط المنتج' : 'Copy link',
            onPressed: () => _copyProductLink(isArabic),
          ),
        ],
      ),
      bottomNavigationBar: (isMyProduct && isShopOwner)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareInCommunity,
                    icon: const Icon(Icons.group_rounded, size: 18),
                    label: Text(
                      isArabic ? 'نشر في المجتمع' : 'Post to Community',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            )
          : (!isMyProduct
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleOrderNow(context, isArabic),
                        icon: const Icon(Icons.shopping_cart_checkout_rounded,
                            size: 20),
                        label: Text(
                          isArabic ? 'اطلب الآن' : 'Order Now',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                )
              : null),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── معرض الصور ──────────────────────────────────────────
            _buildImageGallery(context, allMedia),

            const SizedBox(height: 12),

            // ── Owner Header & Actions ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _InfoCard(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                  userId: widget.product.userId))),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            backgroundImage: widget.product.userImageUrl != null
                                ? CachedNetworkImageProvider(
                                    CloudinaryService.getOptimizedUrl(
                                        widget.product.userImageUrl!,
                                        width: 100,
                                        quality: 'auto'))
                                : null,
                            child: widget.product.userImageUrl == null
                                ? Text(
                                    widget.product.userName.isNotEmpty
                                        ? widget.product.userName[0]
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
                                  widget.product.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                if (widget.product.userJobTitle != null &&
                                    widget.product.userJobTitle!.isNotEmpty)
                                  Text(
                                    widget.product.userJobTitle!,
                                    style: const TextStyle(
                                        color: AppColors.primary, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        final currentUserId = auth.user?.id ?? '';
                        return Consumer<PostsProvider>(
                          builder: (context, postsProvider, _) {
                            final latestPost = postsProvider.posts.firstWhere(
                                (p) => p.id == widget.product.id,
                                orElse: () => widget.product);
                            final isLiked =
                                latestPost.reactions.containsKey(currentUserId);
                            final totalReactions = latestPost.totalReactions;

                            return Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (currentUserId.isEmpty) return;
                                    final type = isLiked ? 'unlike' : 'like';
                                    postsProvider.reactToPost(
                                        latestPost.id,
                                        currentUserId,
                                        auth.user?.name ?? '',
                                        latestPost.userId,
                                        type);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                            isLiked
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: isLiked
                                                ? Colors.red
                                                : Colors.grey[600],
                                            size: 22),
                                        const SizedBox(width: 6),
                                        Text(
                                            totalReactions > 0
                                                ? '$totalReactions'
                                                : '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isLiked
                                                    ? Colors.red
                                                    : Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                                        vertical: 8, horizontal: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.chat_bubble_outline_rounded,
                                            color: Colors.grey[600], size: 22),
                                        const SizedBox(width: 6),
                                        Text(
                                            latestPost.commentsCount > 0
                                                ? '${latestPost.commentsCount}'
                                                : '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── بطاقة الاسم + السعر ────────────────────────────
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اسم المنتج
                        if (productTitle.isNotEmpty)
                          Text(
                            productTitle,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: theme.textTheme.headlineSmall?.color,
                            ),
                          ),

                        if (productTitle.isNotEmpty) const SizedBox(height: 14),

                        // السعر + الحالة + التوصيل
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.product.price != null)
                              _PriceBadge(
                                  price: widget.product.price!,
                                  isArabic: isArabic),
                            if (widget.product.productCondition != null)
                              _ConditionBadge(
                                  condition: widget.product.productCondition!,
                                  isArabic: isArabic),
                            if (widget.product.hasShipping)
                              _ShippingBadge(isArabic: isArabic),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── بطاقة الوصف ────────────────────────────────────
                  if (productDesc.isNotEmpty)
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.description_outlined,
                            label: isArabic ? 'الوصف' : 'Description',
                          ),
                          const SizedBox(height: 10),
                          LinkableText(
                            text: productDesc,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (productDesc.isNotEmpty) const SizedBox(height: 12),

                  // ── بطاقة التفاصيل (الفئة العمرية + الكمية) ────────
                  if (widget.product.productAgeGroup != null ||
                      widget.product.quantity != null)
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.info_outline_rounded,
                            label: isArabic ? 'تفاصيل المنتج' : 'Product Info',
                          ),
                          const SizedBox(height: 12),
                          if (widget.product.productAgeGroup != null)
                            _DetailRow(
                              label: isArabic ? 'الفئة العمرية' : 'Age Group',
                              icon: Icons.people_outline,
                              value: _getAgeGroupLabel(
                                  widget.product.productAgeGroup!, isArabic),
                            ),
                          if (widget.product.productAgeGroup != null &&
                              widget.product.quantity != null)
                            const SizedBox(height: 10),
                          if (widget.product.quantity != null)
                            _DetailRow(
                              label:
                                  isArabic ? 'الكمية المتاحة' : 'Available Qty',
                              icon: Icons.inventory_2_outlined,
                              value: '${widget.product.quantity}',
                            ),
                        ],
                      ),
                    ),

                  if (widget.product.productAgeGroup != null ||
                      widget.product.quantity != null)
                    const SizedBox(height: 12),

                  // ── بطاقة المقاسات ─────────────────────────────────
                  if (widget.product.productSizes.isNotEmpty)
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.straighten_rounded,
                            label: isArabic
                                ? 'المقاسات المتوفرة'
                                : 'Available Sizes',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.product.productSizes
                                .map((s) => _SizeChip(size: s))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                  if (widget.product.productSizes.isNotEmpty)
                    const SizedBox(height: 12),

                  // ── بطاقة الألوان ──────────────────────────────────
                  if (widget.product.productColors.isNotEmpty)
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.palette_outlined,
                            label: isArabic
                                ? 'الألوان / التنوعات'
                                : 'Colors / Variants',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.product.productColors
                                .map((c) => _ColorChip(color: c))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                  if (widget.product.productColors.isNotEmpty)
                    const SizedBox(height: 12),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── معرض الصور ──────────────────────────────────────────────────────────
  Widget _buildImageGallery(BuildContext context, List<String> allMedia) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? Colors.grey[800] : Colors.grey[200];

    if (allMedia.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        width: double.infinity,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child:
            const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        // صور بشاشة كاملة العرض
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.42,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: PageView.builder(
              itemCount: allMedia.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrls: allMedia,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: index == 0
                    ? Hero(
                        tag: 'product_image_${widget.product.id}',
                        child: CachedNetworkImage(
                          imageUrl: allMedia[index],
                          fit: BoxFit.cover,
                          memCacheWidth: 800,
                          placeholder: (_, __) => Container(
                            color: placeholderColor,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: placeholderColor,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey, size: 50),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: allMedia[index],
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (_, __) => Container(
                          color: placeholderColor,
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: placeholderColor,
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey, size: 50),
                        ),
                      ),
              ),
            ),
          ),
        ),

        // مؤشرات الصفحات
        if (allMedia.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                allMedia.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentIndex == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == i
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ),
          ),

        // عداد الصور
        if (allMedia.length > 1)
          Positioned(
            top: 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} / ${allMedia.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  String _getAgeGroupLabel(String group, bool isAr) {
    const labels = {
      'baby': {'ar': '👶 رضيع', 'en': '👶 Baby'},
      'child': {'ar': '🧒 طفل', 'en': '🧒 Child'},
      'youth': {'ar': '👦 شباب', 'en': '👦 Youth'},
      'adult': {'ar': '👨 بالغ', 'en': '👨 Adult'},
      'elderly': {'ar': '👴 كبار', 'en': '👴 Elderly'},
      'all': {'ar': '👨‍👩‍👧 الكل', 'en': '👨‍👩‍👧 All Ages'},
    };
    return labels[group]?[isAr ? 'ar' : 'en'] ?? group;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ══════════════════════════════════════════════════════════════════════════════

/// بطاقة معلومات عامة بحواف دائرية وظل خفيف
class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// عنوان القسم مع أيقونة
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    ]);
  }
}

/// صف تفصيل (أيقونة + تسمية + قيمة)
class _DetailRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  const _DetailRow(
      {required this.label, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.grey[500]),
      const SizedBox(width: 10),
      Text(
        '$label:',
        style: TextStyle(
            fontSize: 14,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    ]);
  }
}

/// شريحة المقاس
class _SizeChip extends StatelessWidget {
  final String size;
  const _SizeChip({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.35)),
      ),
      child: Text(
        size,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

/// شريحة اللون / التنوع
class _ColorChip extends StatelessWidget {
  final String color;
  const _ColorChip({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(color, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// شارة السعر الكبيرة
class _PriceBadge extends StatelessWidget {
  final double price;
  final bool isArabic;
  const _PriceBadge({required this.price, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF5f3dc4)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '${price.toStringAsFixed(0)} SDG',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// شارة حالة المنتج (جديد / مستعمل)
class _ConditionBadge extends StatelessWidget {
  final String condition;
  final bool isArabic;
  const _ConditionBadge({required this.condition, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final isNew = condition == 'new';
    final color = isNew ? Colors.green : Colors.orange;
    final label = isNew
        ? (isArabic ? '✨ جديد' : '✨ New')
        : (isArabic ? '♻️ مستعمل' : '♻️ Used');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isNew ? Colors.green[700] : Colors.orange[700],
        ),
      ),
    );
  }
}

/// شارة التوصيل
class _ShippingBadge extends StatelessWidget {
  final bool isArabic;
  const _ShippingBadge({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
      ),
      child: Text(
        isArabic ? '🚚 توصيل متاح' : '🚚 Ships',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.teal[700],
        ),
      ),
    );
  }
}
