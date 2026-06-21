import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_card.dart';

/// شاشة نصائح السلامة - Safety Tips Screen
class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmartGuideService.showMicroTip(
        context,
        messageAr: 'اقرأ هذه النصائح لتجربة استخدام آمنة وموثوقة 🛡️',
        messageEn: 'Read these tips for a safe and secure experience 🛡️',
        tipId: 'safety_tips_tip',
        icon: Icons.security_rounded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.safetyTipsTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [AppColors.primaryLight.withValues(alpha: 0.3), Colors.white],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  l10n.protectYourself,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // For Workers Section
          _SectionTitle(
            icon: Icons.engineering,
            title: l10n.forFreelancers,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),

          _SafetyTip(
            icon: Icons.money,
            iconColor: Colors.green,
            title: l10n.safetyTipAskDeposit,
            description: l10n.safetyTipAskDepositDesc,
          ),

          _SafetyTip(
            icon: Icons.phone_callback,
            iconColor: Colors.orange,
            title: l10n.safetyTipConfirmCall,
            description: l10n.safetyTipConfirmCallDesc,
          ),

          _SafetyTip(
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: l10n.safetyTipVerifyAddress,
            description: l10n.safetyTipVerifyAddressDesc,
          ),

          _SafetyTip(
            icon: Icons.receipt_long,
            iconColor: Colors.purple,
            title: l10n.safetyTipKeepProof,
            description: l10n.safetyTipKeepProofDesc,
          ),

          _SafetyTip(
            icon: Icons.location_off,
            iconColor: Colors.indigo,
            title: Localizations.localeOf(context).languageCode == 'ar'
                ? 'خصوصية موقعك على الخريطة'
                : 'Map Location Privacy',
            description: Localizations.localeOf(context).languageCode == 'ar'
                ? 'يمكنك دائماً إخفاء موقعك من الخريطة بالذهاب إلى "الإعدادات -> الظهور على الخريطة" لإيقافه.'
                : 'You can always hide your location from the map by going to "Settings -> Show on Map".',
          ),

          const SizedBox(height: 24),

          // For Clients Section
          _SectionTitle(
            icon: Icons.person,
            title: l10n.forClients,
            color: Colors.teal,
          ),
          const SizedBox(height: 12),

          _SafetyTip(
            icon: Icons.star,
            iconColor: Colors.amber,
            title: l10n.safetyTipCheckReviews,
            description: l10n.safetyTipCheckReviewsDesc,
          ),

          _SafetyTip(
            icon: Icons.photo_library,
            iconColor: Colors.blue,
            title: l10n.safetyTipSeePortfolio,
            description: l10n.safetyTipSeePortfolioDesc,
          ),

          _SafetyTip(
            icon: Icons.handshake,
            iconColor: Colors.green,
            title: l10n.safetyTipAgreePrice,
            description: l10n.safetyTipAgreePriceDesc,
          ),

          const SizedBox(height: 24),

          // Contracts and Communication Section
          _SectionTitle(
            icon: Icons.handshake,
            title: Localizations.localeOf(context).languageCode == 'ar'
                ? 'العقود والتواصل'
                : 'Contracts & Communication',
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),

          _SafetyTip(
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.blue,
            title: Localizations.localeOf(context).languageCode == 'ar'
                ? 'استخدام المحادثة الداخلية'
                : 'Use Internal Chat',
            description: Localizations.localeOf(context).languageCode == 'ar'
                ? 'استخدم المحادثة داخل التطبيق حصرياً لإنشاء وتنسيق العقود، وتجنب استخدامها للمحادثات الطويلة لحفظ بياناتك.'
                : 'Use in-app chat exclusively for creating and formatting contracts, avoid long chats to save data.',
          ),

          _SafetyTip(
            icon: Icons.verified_user,
            iconColor: Colors.green,
            title: Localizations.localeOf(context).languageCode == 'ar'
                ? 'حفظ الحقوق بالعقود'
                : 'Protect Rights with Contracts',
            description: Localizations.localeOf(context).languageCode == 'ar'
                ? 'استخدم ميزة "إنشاء عقد" في المحادثة لتوثيق الخدمة والسعر. العقد المقبول يُعد إثباتاً للاتفاق بين الطرفين.'
                : 'Use "Create Contract" feature in chat to document service and price. An accepted contract serves as proof.',
          ),

          const SizedBox(height: 24),

          // Warning Box
          GlassCard(
            borderRadius: 12,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.warning,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.safetyWarningDesc,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
      ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _SafetyTip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _SafetyTip({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(
                                0xFFCBD5E1) // فاتح وواضح في الوضع المظلم
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          ],
          ),
        ),
      ),
    );
  }
}
