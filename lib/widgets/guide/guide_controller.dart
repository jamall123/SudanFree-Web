import 'package:flutter/material.dart';
import '../../services/smart_guide_service.dart';
import 'spotlight_overlay.dart';

/// خطوة إرشاد واحدة
class GuideStep {
  final GlobalKey targetKey;
  final String messageAr;
  final String messageEn;

  const GuideStep({
    required this.targetKey,
    required this.messageAr,
    required this.messageEn,
  });
}

/// المتحكم المركزي لإدارة تسلسل الإرشاد
class GuideController {
  final List<GuideStep> steps;
  final BuildContext context;
  final bool isArabic;
  int _currentStep = 0;
  OverlayEntry? _overlayEntry;

  GuideController({
    required this.steps,
    required this.context,
    required this.isArabic,
  });

  /// بدء عرض الإرشاد
  Future<void> start() async {
    if (await SmartGuideService.hasCompletedFirstGuide()) return;
    if (steps.isEmpty) return;

    // تأخير بسيط لضمان بناء الواجهة بالكامل
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!context.mounted) return;

    _currentStep = 0;
    _showStep();
  }

  void _showStep() {
    if (!context.mounted) return;
    if (_currentStep >= steps.length) {
      _complete();
      return;
    }

    final step = steps[_currentStep];

    // تحقق من أن العنصر المستهدف موجود في الشاشة
    if (step.targetKey.currentContext == null) {
      _currentStep++;
      _showStep();
      return;
    }

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => SpotlightOverlay(
        targetKey: step.targetKey,
        message: isArabic ? step.messageAr : step.messageEn,
        isLast: _currentStep == steps.length - 1,
        nextLabel: isArabic ? 'التالي' : 'Next',
        skipLabel: isArabic ? 'تخطي' : 'Skip',
        onNext: _next,
        onSkip: _skip,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _next() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _currentStep++;
    _showStep();
  }

  void _skip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _complete();
  }

  void _complete() {
    SmartGuideService.markFirstGuideCompleted();
  }

  /// تنظيف عند التخلص من الشاشة
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
