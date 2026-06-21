import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoAdWidget extends StatefulWidget {
  final String videoUrl;

  /// Called when user taps anywhere on video except the mute button
  final VoidCallback? onTapDetails;

  const VideoAdWidget({super.key, required this.videoUrl, this.onTapDetails});

  @override
  State<VideoAdWidget> createState() => _VideoAdWidgetState();
}

class _VideoAdWidgetState extends State<VideoAdWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _isEnded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // ── Caching logic: تنزيل وحفظ الفيديو محلياً لتوفير باقة الإنترنت ──
      final file = await DefaultCacheManager().getSingleFile(widget.videoUrl);

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.setLooping(false);
      _controller!.setVolume(0.0); // يبدأ صامتاً

      _controller!.addListener(_videoListener);

      if (mounted) {
        setState(() => _isInitialized = true);
        // تشغيل تلقائي فور انتهاء التهيئة
        _controller!.play();
      }
    } catch (e) {
      debugPrint('Error initializing video ad: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _videoListener() {
    if (_controller == null) return;
    final bool isEnded =
        _controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration > Duration.zero;
    if (_isEnded != isEnded && mounted) {
      setState(() => _isEnded = isEnded);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _replayVideo() {
    if (_controller == null || !_isInitialized) return;
    _controller!.seekTo(Duration.zero);
    _controller!.play();
    setState(() => _isEnded = false);
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (_controller == null || !_isInitialized) return;
    if (info.visibleFraction > 0.5) {
      if (_isEnded) {
        _replayVideo();
      } else {
        _controller!.play();
      }
    } else {
      _controller!.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return Container(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.grey, size: 40),
              SizedBox(height: 8),
              Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return VisibilityDetector(
      key: Key('video_ad_${widget.videoUrl}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        // تاب خارج أزرار الصوت/الريبلاي → فتح التفاصيل
        onTap: widget.onTapDetails,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // الفيديو
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),

            // زر إعادة التشغيل في المنتصف عند انتهاء الفيديو
            if (_isEnded)
              GestureDetector(
                // منع التاب من الوصول إلى GestureDetector الخارجي
                onTap: () {
                  _replayVideo();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.replay, color: Colors.white, size: 40),
                ),
              ),

            // زر كتم/تفعيل الصوت — أسفل اليمين
            Positioned(
              bottom: 16,
              right: 16,
              child: GestureDetector(
                // منع التاب من الوصول إلى GestureDetector الخارجي (لا يفتح التفاصيل)
                onTap: () {
                  _toggleMute();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
