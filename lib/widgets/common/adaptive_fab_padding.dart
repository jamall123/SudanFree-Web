import 'package:flutter/material.dart';

/// ويدجت ذكي يحسب المسافة المثالية لزر الـ FAB بناءً على:
/// 1. وجود شريط تنقل التطبيق السفلي (Bottom Nav Bar) من عدمه
/// 2. نوع تنقل نظام أندرويد (أزرار ثلاثة أم إيماءات سحب)
/// 3. حالة ظهور/إخفاء شريط التنقل أثناء التمرير
class AdaptiveFabPadding extends StatelessWidget {
  final Widget child;

  /// true = شاشة داخل HomeScreen (المجتمع، الطلبات)
  /// false = شاشة مستقلة (ملف شخصي، لوحة تحكم)
  final bool hasBottomNavBar;

  /// هل شريط التنقل ظاهر حالياً؟ (فقط عندما hasBottomNavBar = true)
  final bool isNavBarVisible;

  const AdaptiveFabPadding({
    super.key,
    required this.child,
    this.hasBottomNavBar = false,
    this.isNavBarVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    double bottomPadding;

    if (hasBottomNavBar) {
      if (isNavBarVisible) {
        // ── شريط التنقل ظاهر ──
        // نحسب بنفس معادلة home_screen.dart بالضبط:
        // bottomMargin = bottomInset > 30 ? bottomInset + 8 : bottomInset + 14
        // ارتفاع الشريط = 62
        // أعلى نقطة = bottomMargin + 62
        // FAB الافتراضي يبدأ من 16px من أسفل الشاشة، لذا نطرحها
        final navBarMargin =
            bottomInset > 30 ? bottomInset + 8 : bottomInset + 14;
        final navBarTopEdge = navBarMargin + 62;
        bottomPadding =
            navBarTopEdge - 16 + 8; // 8 = مسافة أمان بين الزر والشريط
      } else {
        // ── شريط التنقل مخفي (أثناء التمرير) ──
        // نحتاج فقط أن نبقى فوق أزرار النظام
        bottomPadding = bottomInset > 30 ? (bottomInset - 16) : 0.0;
      }
    } else {
      // ── شاشة مستقلة بدون شريط تنقل ──
      bottomPadding = bottomInset > 30 ? (bottomInset - 16) : 8.0;
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomPadding.clamp(0.0, 200.0)),
      child: child,
    );
  }
}
