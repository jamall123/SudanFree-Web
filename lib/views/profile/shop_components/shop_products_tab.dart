import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/post_model.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/cloudinary_service.dart';
import '../product_detail_screen.dart';
import '../../../widgets/common/linkable_text.dart';

class ShopProductsTab extends StatelessWidget {
  final Stream<List<PostModel>> postsStream;
  final bool isMe;

  const ShopProductsTab({
    super.key,
    required this.postsStream,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<PostModel>>(
      stream: postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = (snapshot.data ?? [])
            .where((p) => isMe ? true : p.showInProfile)
            .toList();

        products.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  isMe ? l10n.emptyStoreOwner : l10n.emptyStoreVisitor,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final imageUrl = product.allImageUrls.isNotEmpty
                ? product.allImageUrls.first
                : null;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product)),
                );
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
                          imageUrl != null
                              ? Hero(
                                  tag: 'product_image_${product.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: CloudinaryService.getOptimizedUrl(
                                        imageUrl,
                                        width: 400,
                                        quality: 'auto'),
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    placeholder: (_, __) =>
                                        Container(color: Colors.grey[200]),
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.broken_image),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                      child: Icon(Icons.image,
                                          color: Colors.grey)),
                                ),
                          if (isMe && !product.showInProfile)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.visibility_off,
                                        size: 12, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      Localizations.localeOf(context)
                                                  .languageCode ==
                                              'ar'
                                          ? 'مخفي'
                                          : 'Hidden',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
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
                            LinkableText(
                              text: product.caption ?? l10n.noData,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (product.price != null)
                              Text(
                                '${product.price} SDG',
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
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
