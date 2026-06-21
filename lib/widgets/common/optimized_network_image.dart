import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cloudinary_service.dart';

enum ImageQuality { thumbnail, medium, full }

class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageQuality quality;
  final BorderRadiusGeometry? borderRadius;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.quality = ImageQuality.medium,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    // تحديد العرض المطلوب لتقليل استهلاك الذاكرة وسرعة التحميل (CDN)
    int? cdnWidth;
    int? memCacheWidth;
    switch (quality) {
      case ImageQuality.thumbnail:
        cdnWidth = 200;
        memCacheWidth = 200;
        break;
      case ImageQuality.medium:
        cdnWidth = 600;
        memCacheWidth = 600;
        break;
      case ImageQuality.full:
        // السماح بالتحميل بجودة كاملة بدون تحديد
        break;
    }

    final String optimizedUrl = CloudinaryService.getOptimizedUrl(
      imageUrl,
      width: cdnWidth,
      quality: 'auto',
    );

    Widget imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth, // منع استهلاك الرام بصور كبيرة
      fadeInDuration: const Duration(milliseconds: 300), // FadeIn animation سلس
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return RepaintBoundary(
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
    );
  }
}
