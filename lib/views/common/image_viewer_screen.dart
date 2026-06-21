import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: heroTag != null
                ? Hero(
                    tag: heroTag!,
                    child: _buildPhotoView(),
                  )
                : _buildPhotoView(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left:
                10, // Close button on left for RTL consistency if needed, but usually top-left or top-right. Let's stick to standard top-left back/close.
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoView() {
    return PhotoView(
      imageProvider: NetworkImage(imageUrl),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.error_outline, color: Colors.white, size: 50),
      ),
    );
  }
}
