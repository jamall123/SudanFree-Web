/// Configuration for image caching optimization
///
/// This file defines best practices for image caching across the app
/// to prevent OOM (Out of Memory) errors and reduce storage footprint
class ImageCacheConfig {
  // === Memory Cache Settings ===

  /// Maximum memory cache size in MB
  /// Adjust based on device memory capabilities
  static const int maxMemoryCacheSizeMB = 100;

  /// Maximum number of images to keep in memory cache
  static const int maxMemoryCacheCount = 200;

  /// Image dimensions to store in memory (helps with memory calculations)
  static const int defaultImageHeight = 600;
  static const int defaultImageWidth = 800;

  // === Disk Cache Settings ===

  /// Maximum disk cache size in MB
  static const int maxDiskCacheSizeMB = 500;

  /// Disk cache retention days
  static const int diskCacheRetentionDays = 30;

  // === Image Quality Settings ===

  /// JPEG compression quality for cached images (0-100)
  static const int jpegQuality = 85;

  /// PNG compression level (0-9, where 9 is maximum compression)
  static const int pngCompressionLevel = 6;

  // === Loading Settings ===

  /// Fade-in animation duration for images
  static const Duration fadeInDuration = Duration(milliseconds: 300);

  /// Placeholder color while loading
  static const String placeholderColor = '#F0F0F0';

  // === Optimization Rules ===

  /// Maximum simultaneous image downloads
  static const int maxConcurrentDownloads = 3;

  /// Connection timeout for image downloads
  static const Duration imageDownloadTimeout = Duration(seconds: 30);

  /// Retry count for failed downloads
  static const int downloadRetryCount = 2;

  // === Image Resolution Presets ===

  /// Thumbnail resolution (for list views, avatars)
  static const ResolutionPreset thumbnail =
      ResolutionPreset(width: 200, height: 200, quality: 'auto');

  /// Medium resolution (for card views, post images)
  static const ResolutionPreset medium =
      ResolutionPreset(width: 600, height: 600, quality: 'auto');

  /// High resolution (for detail views, full-screen)
  static const ResolutionPreset high =
      ResolutionPreset(width: 1200, height: 1200, quality: 'auto');

  /// Full resolution (for gallery, zoom views)
  static const ResolutionPreset full =
      ResolutionPreset(width: 2000, height: 2000, quality: 'auto');
}

/// Resolution preset for images
class ResolutionPreset {
  final int width;
  final int height;
  final String quality;

  const ResolutionPreset({
    required this.width,
    required this.height,
    required this.quality,
  });
}

/// Guidelines for image loading:
///
/// 1. LAZY LOADING
///    - Only load images that are visible on screen
///    - Use ListView/GridView builders to lazily build images
///    - Implement viewport caching to avoid re-rendering
///
/// 2. RESOLUTION OPTIMIZATION
///    - Use thumbnail resolution for thumbnails
///    - Use medium resolution for list/card views
///    - Use high resolution for detail views
///    - Avoid loading full resolution unless necessary
///
/// 3. MEMORY MANAGEMENT
///    - Set memCacheWidth and memCacheHeight on CachedNetworkImage
///    - Limit precaching to current + adjacent images only
///    - Clear image cache when leaving heavy image screens
///    - Monitor memory usage and clear cache if needed
///
/// 4. NETWORK OPTIMIZATION
///    - Use JPEG for photos and complex images
///    - Use PNG for graphics and logos
///    - Compress images on backend before serving
///    - Use WebP format for modern devices when available
///
/// 5. ERROR HANDLING
///    - Provide meaningful placeholders while loading
///    - Show error icons on failed loads
///    - Retry failed downloads automatically
///    - Log errors for debugging
