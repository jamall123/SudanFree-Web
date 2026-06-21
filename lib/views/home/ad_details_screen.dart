import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../models/ad_model.dart';
import '../../core/constants/app_colors.dart';
import '../../services/firestore/ad_service.dart';

class AdDetailsScreen extends StatefulWidget {
  final AdModel ad;

  const AdDetailsScreen({super.key, required this.ad});

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  int _selectedImageIndex = 0;
  List<String> _images = [];

  // Video player state
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();

    if (widget.ad.mediaType == AdMediaType.video &&
        widget.ad.mediaUrl.isNotEmpty) {
      _initVideoController();
    } else {
      _images = widget.ad.mediaUrls.isNotEmpty
          ? widget.ad.mediaUrls
          : (widget.ad.mediaUrl.isNotEmpty ? [widget.ad.mediaUrl] : []);
      if (_images.length > 5) _images = _images.sublist(0, 5);
    }
  }

  Future<void> _initVideoController() async {
    try {
      final file =
          await DefaultCacheManager().getSingleFile(widget.ad.mediaUrl);
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.setLooping(false);
      _videoController!.setVolume(1.0); // في شاشة التفاصيل يبدأ بالصوت
      _videoController!.play();
      if (mounted) setState(() => _videoInitialized = true);
    } catch (e) {
      debugPrint('Error loading video in details: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text('تفاصيل الإعلان',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Video Ad Media ───
              if (widget.ad.mediaType == AdMediaType.video)
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: _videoInitialized && _videoController != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Video Player
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            // Controls Bar
                            Container(
                              color: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  // Play/Pause
                                  ValueListenableBuilder<VideoPlayerValue>(
                                    valueListenable: _videoController!,
                                    builder: (_, value, __) {
                                      final isPlaying = value.isPlaying;
                                      final isEnded =
                                          value.position >= value.duration &&
                                              value.duration > Duration.zero;
                                      return IconButton(
                                        icon: Icon(
                                          isEnded
                                              ? Icons.replay
                                              : (isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow),
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          if (isEnded) {
                                            _videoController!
                                                .seekTo(Duration.zero);
                                            _videoController!.play();
                                          } else if (isPlaying) {
                                            _videoController!.pause();
                                          } else {
                                            _videoController!.play();
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  // Seek Bar
                                  Expanded(
                                    child: ValueListenableBuilder<
                                        VideoPlayerValue>(
                                      valueListenable: _videoController!,
                                      builder: (_, value, __) {
                                        final duration = value
                                            .duration.inMilliseconds
                                            .toDouble();
                                        final position = value
                                            .position.inMilliseconds
                                            .toDouble()
                                            .clamp(0.0, duration);
                                        return Slider(
                                          value: duration > 0
                                              ? position / duration
                                              : 0,
                                          activeColor: AppColors.primary,
                                          inactiveColor: Colors.white24,
                                          onChanged: duration > 0
                                              ? (v) => _videoController!.seekTo(
                                                    Duration(
                                                        milliseconds:
                                                            (v * duration)
                                                                .toInt()),
                                                  )
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                  // Mute Button
                                  IconButton(
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off
                                          : Icons.volume_up,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isMuted = !_isMuted;
                                        _videoController!
                                            .setVolume(_isMuted ? 0.0 : 1.0);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(
                          height: 250,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                        ),
                )
              // ─── Image Ad Media ───
              else if (_images.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: _images[_selectedImageIndex],
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (context, url) => Container(
                      height: 350,
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 350,
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child:
                          const Icon(Icons.error, size: 50, color: Colors.grey),
                    ),
                  ),
                )
              else
                Container(
                  height: 350,
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.campaign, size: 80, color: Colors.grey),
                  ),
                ),

              // Thumbnails Row
              if (_images.length > 1)
                Container(
                  height: 80,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_images.length, (index) {
                      final isSelected = index == _selectedImageIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImageIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 4)
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: _images[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error, size: 20),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // Content
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Advertiser Badge
                    if (widget.ad.advertiserName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.ad.advertiserName!,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Title
                    Text(
                      widget.ad.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category/Location info
                    if (widget.ad.targetCategory != 'all')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          widget.ad.targetCategory,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    // Description with Read More
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الوصف',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.ad.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Action Button
                    if (widget.ad.actionUrl != null &&
                        widget.ad.actionUrl!.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () async {
                            AdService().recordClick(widget.ad.id);
                            final uri = Uri.tryParse(widget.ad.actionUrl!);
                            if (uri != null) {
                              try {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'زيارة الرابط',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.open_in_new),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
