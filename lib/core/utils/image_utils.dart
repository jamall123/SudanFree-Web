import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Utility for optimized image loading with memory-aware caching
class ImageUtils {
  /// Get a cached network image with optimized memory settings
  ///
  /// Parameters:
  /// - [imageUrl]: The URL of the image to display
  /// - [fit]: How to fit the image (default: BoxFit.cover)
  /// - [height]: Optional height constraint
  /// - [width]: Optional width constraint
  /// - [onError]: Optional error callback
  static Widget getCachedImage({
    required String imageUrl,
    BoxFit fit = BoxFit.cover,
    double? height,
    double? width,
    VoidCallback? onError,
    Duration fadeInDuration = const Duration(milliseconds: 300),
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      height: height,
      width: width,
      fadeInDuration: fadeInDuration,
      // Memory cache settings for performance
      memCacheHeight: height != null ? (height * 1.5).toInt() : null,
      memCacheWidth: width != null ? (width * 1.5).toInt() : null,
      placeholder: (context, url) => Container(
        color: AppColors.border.withValues(alpha: 0.1),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        onError?.call();
        return Container(
          color: AppColors.border.withValues(alpha: 0.1),
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 20,
          ),
        );
      },
    );
  }

  /// Get a circular cached image (for avatars, profile pictures, etc.)
  static Widget getCircularCachedImage({
    required String imageUrl,
    required double radius,
    Color? backgroundColor,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ?? AppColors.border.withValues(alpha: 0.1),
      backgroundImage: CachedNetworkImageProvider(imageUrl),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint('Error loading circular image: $exception');
      },
    );
  }

  /// Create a high-quality image URL for precaching (used for detailed views)
  /// Typically used with CloudinaryService for optimization
  static String getHighResUrl(String baseUrl) {
    // This is a placeholder - integrate with your CloudinaryService
    // Example: CloudinaryService.getOptimizedUrl(baseUrl, width: 1200, quality: 'auto')
    return baseUrl;
  }

  /// Create a medium-quality image URL for list views
  /// Typically used with CloudinaryService for optimization
  static String getMediumResUrl(String baseUrl) {
    // This is a placeholder - integrate with your CloudinaryService
    // Example: CloudinaryService.getOptimizedUrl(baseUrl, width: 600, quality: 'auto')
    return baseUrl;
  }

  /// Create a low-quality thumbnail URL for thumbnails
  /// Typically used with CloudinaryService for optimization
  static String getThumbnailUrl(String baseUrl) {
    // This is a placeholder - integrate with your CloudinaryService
    // Example: CloudinaryService.getOptimizedUrl(baseUrl, width: 200, quality: 'auto')
    return baseUrl;
  }
}
