import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/portfolio_project_model.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/common/linkable_text.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/squad_model.dart';
import 'squad_profile_screen.dart';
import '../../providers/auth_provider.dart';
import 'create_portfolio_project_screen.dart';

class PortfolioProjectDetailScreen extends StatefulWidget {
  final PortfolioProjectModel project;
  final String providerName;
  final String? providerImageUrl;

  const PortfolioProjectDetailScreen({
    super.key,
    required this.project,
    required this.providerName,
    this.providerImageUrl,
  });

  @override
  State<PortfolioProjectDetailScreen> createState() =>
      _PortfolioProjectDetailScreenState();
}

class _PortfolioProjectDetailScreenState
    extends State<PortfolioProjectDetailScreen> {
  late final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  bool _isAr(BuildContext ctx) => ctx.watch<LocaleProvider>().isArabic;

  void _showFullImage(
      BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
            imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('لا يمكن فتح الرابط: $url')),
          );
        }
      }
    }
  }

  String _getCategoryName(String? categoryKey, bool isAr) {
    if (categoryKey == null) return isAr ? 'أخرى' : 'Other';
    const categories = {
      'design': {'ar': 'تصميم', 'en': 'Design'},
      'programming': {'ar': 'برمجة', 'en': 'Programming'},
      'maintenance': {'ar': 'صيانة', 'en': 'Maintenance'},
      'construction': {'ar': 'بناء وتشييد', 'en': 'Construction'},
      'electrical': {'ar': 'كهرباء', 'en': 'Electrical'},
      'plumbing': {'ar': 'سباكة', 'en': 'Plumbing'},
      'painting': {'ar': 'دهان وطلاء', 'en': 'Painting'},
      'carpentry': {'ar': 'نجارة', 'en': 'Carpentry'},
      'other': {'ar': 'أخرى', 'en': 'Other'},
    };
    return categories[categoryKey]?[isAr ? 'ar' : 'en'] ??
        (isAr ? 'أخرى' : 'Other');
  }

  String _getStatusName(String? status, bool isAr) {
    if (status == 'completed') return isAr ? 'مكتمل' : 'Completed';
    if (status == 'ongoing') return isAr ? 'قيد التنفيذ' : 'Ongoing';
    return isAr ? 'غير محدد' : 'Not specified';
  }

  String _getTypeName(String? type, bool isAr) {
    if (type == 'personal') return isAr ? 'شخصي' : 'Personal';
    if (type == 'client') return isAr ? 'لعميل' : 'Client';
    if (type == 'startup') return isAr ? 'شركة ناشئة' : 'Startup';
    return isAr ? 'أخرى' : 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authUser = context.watch<AuthProvider>().user;
    final isOwner = authUser?.id == widget.project.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'تفاصيل المشروع' : 'Project Details'),
        centerTitle: true,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: isAr ? 'تعديل المشروع' : 'Edit Project',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePortfolioProjectScreen(
                      existingProject: widget.project,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Image Gallery Carousel ───
            _buildImageGallery(context, isDark),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header Info ───
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getCategoryName(widget.project.category, isAr),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(widget.project.createdAt,
                            locale: isAr ? 'ar' : 'en'),
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.project.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // ─── Project Executors (Provider & Collaborators) ───
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isAr ? 'منفذي المشروع' : 'Project Executors',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Main Provider
                            _buildCollaboratorItem(
                              context: context,
                              imageUrl: widget.providerImageUrl,
                              name: widget.providerName,
                              userId: widget.project.userId,
                              isOwner: true,
                            ),
                            // Collaborators
                            if (widget.project.collaborators != null)
                              ...widget.project.collaborators!
                                  .map((c) => _buildCollaboratorItem(
                                        context: context,
                                        imageUrl: c['imageUrl'] as String?,
                                        name: c['name'] as String? ?? '',
                                        userId: c['id'] as String?,
                                        isOwner: false,
                                      )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Status and Type ───
                  if (widget.project.status != null ||
                      widget.project.projectType != null) ...[
                    Row(
                      children: [
                        if (widget.project.status != null)
                          Expanded(
                            child: _InfoTile(
                              icon: Icons.task_alt,
                              title: isAr ? 'حالة المشروع' : 'Status',
                              value:
                                  _getStatusName(widget.project.status, isAr),
                              color: widget.project.status == 'completed'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        if (widget.project.status != null &&
                            widget.project.projectType != null)
                          const SizedBox(width: 16),
                        if (widget.project.projectType != null)
                          Expanded(
                            child: _InfoTile(
                              icon: Icons.work_outline,
                              title: isAr ? 'نوع المشروع' : 'Type',
                              value: _getTypeName(
                                  widget.project.projectType, isAr),
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── Description ───
                  Text(
                    isAr ? 'تفاصيل المشروع' : 'Project Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  LinkableText(
                    text: widget.project.description,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),

                  const SizedBox(height: 24),

                  // ─── Purpose ───
                  if (widget.project.purpose != null &&
                      widget.project.purpose!.isNotEmpty) ...[
                    Text(
                      isAr ? 'ما يهدف إليه المشروع' : 'Project Purpose',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        border: Border(
                            left: BorderSide(
                                color: Colors.blue.shade300, width: 4)),
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8)),
                      ),
                      child: Text(
                        widget.project.purpose!,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ─── External Link ───
                  if (widget.project.externalLink != null &&
                      widget.project.externalLink!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _launchUrl(widget.project.externalLink!),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                            isAr ? 'زيارة رابط المشروع' : 'Visit Project Link',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[100],
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Image Gallery ──────────────────────────────────────────────────────
  Widget _buildImageGallery(BuildContext context, bool isDark) {
    final urls = widget.project.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _imagePageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _showFullImage(context, urls, index),
              child: CachedNetworkImage(
                imageUrl: urls[index],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(
                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, url, error) => Container(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_not_supported_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('تعذّر تحميل الصورة',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentImageIndex == i ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2)
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined,
                    size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  '${_currentImageIndex + 1} / ${urls.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Collaborator Item ─────────────────────────────────────────────────
  Widget _buildCollaboratorItem({
    required BuildContext context,
    String? imageUrl,
    required String name,
    String? userId,
    required bool isOwner,
  }) {
    final canNavigate = userId != null && userId.isNotEmpty;
    return GestureDetector(
      onTap: canNavigate
          ? () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                final squadDoc = await FirebaseFirestore.instance
                    .collection('squads')
                    .doc(userId)
                    .get();
                if (!context.mounted) return;
                Navigator.pop(context); // close dialog

                if (squadDoc.exists) {
                  final squad = SquadModel.fromFirestore(squadDoc);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SquadProfileScreen(squad: squad)));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: userId)));
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
              }
            }
          : null,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOwner
                          ? AppColors.primary
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isOwner ? 2.5 : 1,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.person_outline_rounded,
                            color: AppColors.primary, size: 28)
                        : null,
                  ),
                ),
                if (isOwner)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.star_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
                if (!isOwner && canNavigate)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_outward_rounded,
                          color: Colors.white, size: 9),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: canNavigate ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoTile(
      {required this.icon,
      required this.title,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Full Screen Image Viewer ═══
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer(
      {required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.imageUrls.length > 1
            ? Text('${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(fontSize: 16))
            : null,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.grey, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }
}
