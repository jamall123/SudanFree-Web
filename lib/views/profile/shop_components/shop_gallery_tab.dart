import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/user_model.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/common/full_screen_image_viewer.dart';

class ShopGalleryTab extends StatelessWidget {
  final UserModel user;
  final bool isMe;

  const ShopGalleryTab({
    super.key,
    required this.user,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final images = user.shopImages;
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? (isMe
                      ? 'لا توجد صور في المعرض. يمكنك إضافتها من إعدادات الملف.'
                      : 'لا توجد صور في المعرض حالياً')
                  : (isMe
                      ? 'No images in gallery. Add from profile settings.'
                      : 'No images in gallery'),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                        imageUrls: images, initialIndex: index)));
          },
          child: Hero(
            tag: 'shop_gallery_${images[index]}',
            child: CachedNetworkImage(
              imageUrl: CloudinaryService.getOptimizedUrl(images[index],
                  width: 300, quality: 'auto'),
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
