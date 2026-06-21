import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../services/cloudinary_service.dart';
import '../../views/posts/post_details_screen.dart';
import 'full_screen_image_viewer.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final BoxFit fit;
  final bool enableZoom;
  final dynamic post;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.enableZoom = false,
    this.post,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Track precached images to avoid redundant precaching
  final Set<int> _precachedIndices = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Precache the current and adjacent images (current-1, current, current+1)
  void _precacheAdjacentImages(int currentIndex) {
    final indicesToPrecache = [
      if (currentIndex > 0) currentIndex - 1,
      currentIndex,
      if (currentIndex < widget.imageUrls.length - 1) currentIndex + 1,
    ];

    for (final index in indicesToPrecache) {
      // Skip if already precached
      if (_precachedIndices.contains(index)) continue;

      _precachedIndices.add(index);

      final url = widget.imageUrls[index];
      try {
        precacheImage(
          CachedNetworkImageProvider(
            CloudinaryService.getOptimizedUrl(url,
                width: 1200, quality: 'auto'),
          ),
          context,
        ).catchError((error) {
          // Silently handle precache errors
          debugPrint('Image precache error for index $index: $error');
        });
      } catch (e) {
        debugPrint('Image precache exception for index $index: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    // Precache adjacent images on initial build
    _precacheAdjacentImages(_currentIndex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                // Precache adjacent images when user scrolls
                _precacheAdjacentImages(index);
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              return GestureDetector(
                onTap: () {
                  if (widget.enableZoom) {
                    if (widget.post != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailsScreen(post: widget.post!),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(
                            imageUrls: widget.imageUrls,
                            initialIndex: index,
                          ),
                        ),
                      );
                    }
                  }
                },
                child: CachedNetworkImage(
                  imageUrl: CloudinaryService.getOptimizedUrl(url,
                      width: 600, quality: 'auto'),
                  fit: widget.fit,
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
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: _currentIndex == index ? 16.0 : 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
