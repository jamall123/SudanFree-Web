import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/constants/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double? opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Border? border;
  final BoxShape shape;
  final double? width;
  final double? height;
  final bool enableBlur; // Add performance flag

  const GlassContainer({
    super.key,
    required this.child,
    this.blur,
    this.opacity,
    this.borderRadius,
    this.padding,
    this.margin,
    this.color,
    this.border,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
    this.enableBlur = false, // Default to faux-glass (high performance)
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlassEnabled =
        context.watch<ThemeProvider>().isGlassmorphismEnabled;

    // Premium Adaptive Glass Settings
    final double activeBlur = blur ?? 20.0;
    final double activeOpacity = opacity ?? (isDark ? 0.08 : 0.05);

    // Adaptive Colors
    final Color baseColor = color ?? (isDark ? Colors.white : AppColors.primary);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : AppColors.primary.withValues(alpha: 0.2);

    final resolvedBorderRadius = shape == BoxShape.circle
        ? null
        : (borderRadius ?? BorderRadius.circular(20));

    final innerContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: resolvedBorderRadius,
        color: isGlassEnabled ? null : (color ?? Theme.of(context).cardColor),
        gradient: isGlassEnabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: activeOpacity),
                  baseColor.withValues(
                      alpha: (activeOpacity * 0.5).clamp(0.0, 1.0)),
                ],
              )
            : null,
        boxShadow: isGlassEnabled
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.15) // Neon Cyan glow
                      : AppColors.primary.withValues(alpha: 0.15), // Primary color glow
                  blurRadius: isDark ? 30 : 20,
                  spreadRadius: isDark ? 1 : 0,
                  offset: isDark ? Offset.zero : const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: border ??
            (isGlassEnabled
                ? Border.all(color: borderColor, width: 1.0)
                : Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                    width: 1.0,
                  )),
      ),
      child: child,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: (isGlassEnabled && enableBlur)
          ? RepaintBoundary(
              child: ClipRRect(
                borderRadius: resolvedBorderRadius ?? BorderRadius.zero,
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: activeBlur, sigmaY: activeBlur),
                  child: innerContainer,
                ),
              ),
            )
          : innerContainer,
    );
  }
}
