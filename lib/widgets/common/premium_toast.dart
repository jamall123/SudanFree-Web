import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Premium toast/snackbar with modern design
class PremiumToast {
  /// Show success toast
  static void success(BuildContext context, String message) {
    _show(context, message, ToastType.success);
  }

  /// Show error toast
  static void error(BuildContext context, String message) {
    _show(context, message, ToastType.error);
  }

  /// Show info toast
  static void info(BuildContext context, String message) {
    _show(context, message, ToastType.info);
  }

  /// Show warning toast
  static void warning(BuildContext context, String message) {
    _show(context, message, ToastType.warning);
  }

  static void _show(BuildContext context, String message, ToastType type) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _getConfig(type);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: config.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: config.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        elevation: 8,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static _ToastConfig _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.error_rounded,
          color: AppColors.error,
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_rounded,
          color: AppColors.info,
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: Icons.warning_rounded,
          color: AppColors.warning,
        );
    }
  }
}

enum ToastType { success, error, info, warning }

class _ToastConfig {
  final IconData icon;
  final Color color;

  _ToastConfig({required this.icon, required this.color});
}
