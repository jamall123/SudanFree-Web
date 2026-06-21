import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../views/profile/profile_screen.dart';
import '../../views/posts/post_details_screen.dart';
import '../../views/profile/product_detail_screen.dart';

class InternalLinkPreviewWidget extends StatefulWidget {
  final String url;

  const InternalLinkPreviewWidget({super.key, required this.url});

  @override
  State<InternalLinkPreviewWidget> createState() =>
      _InternalLinkPreviewWidgetState();

  /// Helper to check if a URL is an internal deep link
  static bool isInternalLink(String url) {
    return url.contains('sudanfree.com/sudan-free.html') ||
        url.contains('jamall123.github.io/HOME_WEB');
  }
}

class _InternalLinkPreviewWidgetState extends State<InternalLinkPreviewWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _profileId;
  String? _postId;
  String? _productId;

  @override
  void initState() {
    super.initState();
    _parseUrl();
  }

  void _parseUrl() {
    try {
      final uri = Uri.parse(widget.url);
      _profileId = uri.queryParameters['profileId'];
      _postId = uri.queryParameters['postId'];
      _productId = uri.queryParameters['productId'];
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_profileId != null && _profileId!.isNotEmpty) {
      return FutureBuilder<UserModel?>(
        future: _firestoreService.getUser(_profileId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildLoading();
          if (!snapshot.hasData || snapshot.data == null)
            return const SizedBox.shrink();
          return _buildProfileCard(snapshot.data!);
        },
      );
    } else if (_postId != null && _postId!.isNotEmpty) {
      return FutureBuilder<PostModel?>(
        future: _firestoreService.getPost(_postId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildLoading();
          if (!snapshot.hasData || snapshot.data == null)
            return const SizedBox.shrink();
          return _buildPostCard(snapshot.data!, false);
        },
      );
    } else if (_productId != null && _productId!.isNotEmpty) {
      return FutureBuilder<PostModel?>(
        future: _firestoreService.getPost(_productId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildLoading();
          if (!snapshot.hasData || snapshot.data == null)
            return const SizedBox.shrink();
          return _buildPostCard(snapshot.data!, true);
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(
            'جاري استخراج البيانات...',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)));
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user.profileImageUrl != null
                  ? CachedNetworkImageProvider(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Icon(Icons.person, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.jobTitle ??
                        (user.role == UserRole.shop ? 'متجر' : 'مستقل'),
                    style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(PostModel post, bool isProduct) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (isProduct) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: post)));
        } else {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostDetailsScreen(post: post)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: post.userImageUrl != null
                            ? CachedNetworkImageProvider(post.userImageUrl!)
                            : null,
                        child: post.userImageUrl == null
                            ? const Icon(Icons.person, size: 12)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.userName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (post.caption != null && post.caption!.isNotEmpty)
                    Text(
                      post.caption!,
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
