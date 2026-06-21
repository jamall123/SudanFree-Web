import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/ad_model.dart';
import '../../widgets/common/image_carousel.dart';
import 'video_ad_widget.dart';

class AdWidget extends StatelessWidget {
  final AdModel ad;
  final VoidCallback? onTap;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? margin;

  const AdWidget({
    super.key,
    required this.ad,
    this.onTap,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = ad.mediaType == AdMediaType.video && ad.mediaUrl.isNotEmpty;

    final appliedMargin = margin ?? const EdgeInsets.only(bottom: 8);
    final appliedBorderRadius = borderRadius ?? BorderRadius.zero;

    // ── Video Ad: clean fullscreen player, no badge/gradient overlay ──
    if (isVideo) {
      return Container(
        margin: appliedMargin,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: appliedBorderRadius,
        ),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          height: 400,
          child: VideoAdWidget(
            videoUrl: ad.mediaUrl,
            onTapDetails: onTap, // tap anywhere except mute → open details
          ),
        ),
      );
    }

    // ── Image Ad: existing style with badge + gradient ──
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: appliedMargin,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: appliedBorderRadius,
        ),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          height: 400,
          child: Stack(
            children: [
              Positioned.fill(child: _buildImageBackground(isDark)),

              // Gradient Overlay for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Sponsored badge at top right
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.campaign, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        ad.advertiserName != null
                            ? 'إعلان من ${ad.advertiserName}'
                            : 'إعلان ممول',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Ad Content at the bottom
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageBackground(bool isDark) {
    if (ad.mediaUrls.isNotEmpty) {
      return ad.mediaUrls.length == 1
          ? CachedNetworkImage(
              imageUrl: ad.mediaUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => Container(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: const Icon(Icons.error, color: Colors.grey)),
            )
          : ImageCarousel(
              imageUrls: ad.mediaUrls,
              height: 220,
              fit: BoxFit.cover,
            );
    } else if (ad.mediaUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ad.mediaUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => Container(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: const Icon(Icons.error, color: Colors.grey)),
      );
    }
    return Container(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200);
  }
}
