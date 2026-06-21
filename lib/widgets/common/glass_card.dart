import 'package:flutter/material.dart';
import 'glass_container.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: margin,
      padding: padding,
      borderRadius: BorderRadius.circular(borderRadius),
      color: backgroundColor,
      border: borderColor != null
          ? Border.all(color: borderColor!, width: 1.0)
          : null,
      child: child,
    );
  }
}
