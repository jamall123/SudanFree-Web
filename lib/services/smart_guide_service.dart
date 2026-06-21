import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../providers/locale_provider.dart';
import 'package:provider/provider.dart';

/// خدمة الإرشاد الذكي — المحرك المركزي لحفظ حالة التلميحات وعرضها
class SmartGuideService {
  static const _prefix = 'guide_tip_';

  /// هل شاهد المستخدم هذا التلميح من قبل؟
  static Future<bool> hasSeenTip(String tipId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$tipId') ?? false;
  }

  /// تسجيل أن المستخدم شاهد التلميح
  static Future<void> markTipSeen(String tipId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$tipId', true);
  }

  /// هل شاهد المستخدم إرشاد أول دخول؟
  static Future<bool> hasCompletedFirstGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_prefix}first_guide_completed') ?? false;
  }

  /// تسجيل اكتمال إرشاد أول دخول
  static Future<void> markFirstGuideCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefix}first_guide_completed', true);
  }

  /// إظهار تلميح سريع (Micro-Tip) — يظهر مرة واحدة فقط
  static Future<void> showMicroTip(
    BuildContext context, {
    required String messageAr,
    required String messageEn,
    required String tipId,
    IconData icon = Icons.lightbulb_outline,
    Duration delay = const Duration(milliseconds: 800),
  }) async {
    if (await hasSeenTip(tipId)) return;

    await markTipSeen(tipId);

    // تأخير بسيط ليظهر بعد تحميل الشاشة
    await Future.delayed(delay);

    if (!context.mounted) return;

    final isArabic = context.read<LocaleProvider>().isArabic;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                isArabic ? messageAr : messageEn,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.primary,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
