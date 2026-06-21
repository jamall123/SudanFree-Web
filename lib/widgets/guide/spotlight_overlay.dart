import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// طبقة Spotlight شفافة مع ثقب مضاء حول العنصر المستهدف
class SpotlightOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final String message;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final String nextLabel;
  final String skipLabel;
  final bool isLast;

  const SpotlightOverlay({
    super.key,
    required this.targetKey,
    required this.message,
    required this.onNext,
    required this.onSkip,
    this.nextLabel = 'التالي',
    this.skipLabel = 'تخطي',
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    // حساب مركز العنصر ونصف القطر
    final targetRect = Rect.fromLTWH(
      targetPosition.dx - 8,
      targetPosition.dy - 8,
      targetSize.width + 16,
      targetSize.height + 16,
    );

    // تحديد موقع الفقاعة (أعلى أو أسفل العنصر)
    final screenHeight = MediaQuery.of(context).size.height;
    final showBelow = targetRect.center.dy < screenHeight * 0.5;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // الخلفية الداكنة مع ثقب
          Positioned.fill(
            child: GestureDetector(
              onTap: onNext,
              child: CustomPaint(
                painter: _SpotlightPainter(targetRect: targetRect),
              ),
            ),
          ),

          // فقاعة النص
          Positioned(
            left: 24,
            right: 24,
            top: showBelow ? targetRect.bottom + 20 : null,
            bottom: showBelow ? null : screenHeight - targetRect.top + 20,
            child: _buildTipBubble(context, showBelow),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBubble(BuildContext context, bool showBelow) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * (showBelow ? 20 : -20)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: Color(0xFF1A1A2E),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    skipLabel,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                  ),
                  child: Text(
                    isLast ? 'تمام ✓' : nextLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام الخلفية الداكنة مع ثقب مضاء
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;

  _SpotlightPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withValues(alpha: 0.85);

    // رسم الخلفية الكاملة
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // إنشاء ثقب بزوايا مستديرة
    final spotlightRRect = RRect.fromRectAndRadius(
      targetRect,
      const Radius.circular(16),
    );

    // رسم الخلفية مع استثناء الثقب
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(spotlightRRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // إطار مضيء حول الثقب
    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(spotlightRRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
