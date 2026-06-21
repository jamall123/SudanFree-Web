import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/verification_badge.dart';
import '../../providers/locale_provider.dart';
import 'package:provider/provider.dart';
import '../../core/utils/job_titles_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math' as math;

/// شاشة بطاقة الهوية الرقمية للحرفي/المتجر
class DigitalIdCardScreen extends StatefulWidget {
  final UserModel user;
  const DigitalIdCardScreen({super.key, required this.user});

  @override
  State<DigitalIdCardScreen> createState() => _DigitalIdCardScreenState();
}

class _DigitalIdCardScreenState extends State<DigitalIdCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;
  bool _isFlipped = false;

  Future<void> _shareCard() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/sudanfree_${_isFlipped ? 'qr' : 'id'}_${widget.user.id}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _isFlipped
            ? 'احصل على تطبيق SudanFree الآن وتواصل معي! ${widget.user.name}'
            : 'SudanFree Digital ID — ${widget.user.name}',
      );
    } catch (e) {
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.read<LocaleProvider>().isArabic;
    final user = widget.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        title: Text(isAr ? 'بطاقة الهوية الرقمية' : 'Digital ID Card'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isSharing ? null : _shareCard,
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share),
            tooltip: isAr ? 'مشاركة البطاقة' : 'Share Card',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _cardKey,
            child: GestureDetector(
              onTap: () => setState(() => _isFlipped = !_isFlipped),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
                duration: const Duration(milliseconds: 600),
                builder: (context, double value, child) {
                  bool showFront = value < 90;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(value * math.pi / 180),
                    child: showFront
                        ? _buildFront(isAr, user)
                        : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _buildBack(isAr, user),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFront(bool isAr, UserModel user) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2332),
            Color(0xFF0D1B2A),
          ],
        ),
        border: Border.all(
          color: AppColors.sudanGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sudanGold.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.sudanGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.verified_user,
                      color: AppColors.sudanGold, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'SudanFree',
                  style: TextStyle(
                    color: AppColors.sudanGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  isAr ? 'هوية رقمية' : 'DIGITAL ID',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Avatar + Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sudanGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sudanGold.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user.profileImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: CloudinaryService.getOptimizedUrl(
                                user.profileImageUrl!,
                                width: 200,
                                quality: 'auto'),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.primary,
                            child: Center(
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SmartVerificationBadge(user: user, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.getRoleDisplayName(isAr ? 'ar' : 'en'),
                        style: TextStyle(
                          color: AppColors.sudanGold.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (user.jobTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          JobTitlesUtils.getLocalizedTitle(
                              user.jobTitle!, isAr ? 'ar' : 'en'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Colors.white.withValues(alpha: 0.1)),
          ),

          // Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildStat(
                  icon: Icons.star_rounded,
                  value: user.rating.toStringAsFixed(1),
                  label: isAr ? 'التقييم' : 'Rating',
                  color: Colors.amber,
                ),
                _buildStatDivider(),
                _buildStat(
                  icon: Icons.work_history,
                  value: '${user.completedJobs}',
                  label: isAr ? 'أعمال' : 'Jobs',
                  color: Colors.blue,
                ),
                _buildStatDivider(),
                _buildStat(
                  icon: Icons.reviews,
                  value: '${user.reviewsCount}',
                  label: isAr ? 'تقييمات' : 'Reviews',
                  color: Colors.green,
                ),
              ],
            ),
          ),

          // Top Skills / Shop Category
          if (user.role == UserRole.shop && user.shopCategory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'تصنيف المتجر' : 'Shop Category',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      user.getShopCategoryName(isAr ? 'ar' : 'en'),
                      style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else if (user.skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'المهارات الأساسية' : 'Core Skills',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: user.skills
                        .take(4)
                        .map((skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                JobTitlesUtils.getLocalizedTitle(
                                    skill, isAr ? 'ar' : 'en'),
                                style: TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // Location + Reputation
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                if (user.state != null) ...[
                  Icon(Icons.location_on,
                      color: Colors.white.withValues(alpha: 0.4), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    user.locationDisplay,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11),
                  ),
                ],
                const Spacer(),
                ReputationScoreWidget(user: user, size: 38, showLabel: false),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
              color: Colors.white.withValues(alpha: 0.03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2,
                    color: Colors.white.withValues(alpha: 0.3), size: 16),
                const SizedBox(width: 8),
                Text(
                  'sudanfree.app/profile/${user.id.substring(0, 8)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(bool isAr, UserModel user) {
    return Container(
      width: 340,
      height: 420, // Match front roughly
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2332),
            Color(0xFF0D1B2A),
          ],
        ),
        border: Border.all(
          color: AppColors.sudanGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sudanGold.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isAr ? 'امسح الرمز للتواصل معي' : 'Scan to connect with me',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'إذا لم يكن لديك التطبيق، سيتم توجيهك لتحميله!'
                : 'If you do not have the app, you will be redirected to download it!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data:
                  'https://sudanfree.com/sudan-free.html?profileId=${user.id}',
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app,
                  color: Colors.white.withValues(alpha: 0.5), size: 16),
              const SizedBox(width: 8),
              Text(
                isAr ? 'اضغط للعودة للهوية' : 'Tap to return to ID',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
