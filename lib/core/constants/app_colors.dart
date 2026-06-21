import 'package:flutter/material.dart';

class AppColors {
  // ==================== ألوان سودانية مميزة ====================
  // مستوحاة من النيل الأزرق، الصحراء الذهبية، والتراث السوداني

  // Primary Colors - أزرق نيلي عميق
  static const Color primary = Color(0xFF1A5F7A); // أزرق نيلي
  static const Color primaryDark = Color(0xFF0D3B4C); // أزرق نيلي داكن
  static const Color primaryLight = Color(0xFF2E8BC0); // أزرق نيلي فاتح

  // Secondary Colors - أخضر سوداني
  static const Color secondary = Color(0xFF2D9C6E); // أخضر زمردي
  static const Color secondaryDark = Color(0xFF1E7C52);
  static const Color secondaryLight = Color(0xFF4ECDC4);

  // ==================== ألوان سودانية خاصة ====================
  static const Color sudanGold = Color(0xFFD4AF37); // الذهب السوداني
  static const Color sudanGoldLight = Color(0xFFE6C861);
  static const Color nileBlue = Color(0xFF1A5276); // أزرق النيل
  static const Color desertSand = Color(0xFFF4E4C1); // رمال الصحراء
  static const Color desertOrange = Color(0xFFE07B39); // غروب الصحراء
  static const Color pyramidBrown = Color(0xFF8B5A2B); // لون الأهرامات

  // Accent Colors
  static const Color accent = Color(0xFFFF6B35); // برتقالي حيوي
  static const Color gold = Color(0xFFD4AF37); // ذهبي سوداني

  // Background Colors
  static const Color background = Color(0xFFF8FAFC); // خلفية نظيفة
  static const Color backgroundDark = Color(0xFF0B1120); // أعمق وأكثر أناقة
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF162032); // تباين أفضل مع الخلفية
  static const Color charcoal = Color(0xFF262626);
  static const Color charcoalDark = Color(0xFF1A1A1A);
  static const Color softGrey = Color(0xFF94A3B8);

  // Text Colors
  static const Color textPrimary = Color(0xFF000000); // أسود كامل للوضوح التام
  static const Color textSecondary = Color(0xFF334155); // رمادي غامق جداً
  static const Color textLight = Color(0xFF64748B); // رمادي متوسط
  static const Color textDark = Color(0xFFF1F5F9);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Card Colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark =
      Color(0xFF162032); // متناسق مع surfaceDark

  // Border Colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF2A3A4E); // أوضح قليلاً

  // ==================== تدرجات Premium ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, nileBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sudanGradient = LinearGradient(
    colors: [sudanGold, desertOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [nileBlue, Color(0xFF11998e)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== Glassmorphism Colors ====================
  static Color glassWhite = Colors.white.withValues(alpha: 0.2);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);
  static Color glassDark = Colors.black.withValues(alpha: 0.1);

  // ==================== Dark Mode Glow Colors ====================
  static Color primaryGlow = primary.withValues(alpha: 0.15);
  static Color accentGlow = accent.withValues(alpha: 0.12);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

class AppShadows {
  static List<BoxShadow> small = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> large = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
