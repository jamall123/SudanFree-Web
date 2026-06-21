import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_card.dart';

/// صفحة عن التطبيق - About Screen
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isAr ? 'عن التطبيق' : 'About',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                const Icon(Icons.handshake, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  isAr ? 'سودان فري' : 'Sudan Free',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? '🇸🇩 منصة الحرفيين والمستقلين السودانيين الأولى'
                      : '🇸🇩 The Premier Sudanese Freelance Platform',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What is Sudan Free
          _SectionTitle(
            icon: Icons.info_outline,
            title: isAr ? 'عن التطبيق' : 'About the App',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.connect_without_contact,
            iconColor: AppColors.primary,
            text: isAr
                ? 'سودان فري هي أول منصة سودانية متكاملة تربط بين الحرفيين، ومقدمي الخدمات المستقلين، والمحلات التجارية، والعملاء. نهدف إلى تنظيم وتسهيل الوصول للخدمات المهنية في جميع أنحاء السودان بكل موثوقية وأمان.'
                : 'Sudan Free is the first integrated Sudanese platform connecting workers, freelancers, shops, and clients. We aim to organize and facilitate access to professional services across Sudan safely and reliably.',
          ),

          const SizedBox(height: 24),

          // For Workers
          _SectionTitle(
            icon: Icons.engineering,
            title: isAr
                ? '👷 لمقدمي الخدمات والحرفيين'
                : '👷 For Service Providers',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.storefront,
            iconColor: Colors.blue,
            text: isAr
                ? '• مساحة مخصصة لعرض مهاراتك وخدماتك للآلاف.\n• توثيق حسابك للحصول على ثقة أكبر وشعار التصافح 🤝.\n• نظام تقييم احترافي يرفع من رتبتك (من مبتدئ إلى أسطورة).\n• استقبال الطلبات المباشرة والتفاوض بحرية.\n• إنشاء العقود داخلياً لضمان حقوقك.\n• معرض أعمال كامل لإظهار إنجازاتك السابقة.'
                : '• Dedicated space to showcase your skills.\n• Account verification for higher trust 🤝.\n• Professional rating system upgrading your rank.\n• Direct job requests and free negotiation.\n• Create in-app contracts to secure rights.\n• Full portfolio to display past achievements.',
          ),

          const SizedBox(height: 24),

          // For Clients
          _SectionTitle(
            icon: Icons.person_search,
            title: isAr ? '👤 للعملاء (الباحثين عن خدمات)' : '👤 For Clients',
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.search,
            iconColor: Colors.teal,
            text: isAr
                ? '• بحث ذكي للوصول للحرفي المناسب في منطقتك.\n• نظام تقييمات موثوق يعكس جودة الحرفي.\n• إمكانية نشر "طلب خدمة" ليتنافس عليه الحرفيون.\n• تواصل مباشر عبر التطبيق، أو الهاتف، أو إنشاء عقد رسمي لحفظ الحقوق.'
                : '• Smart search for the right provider in your area.\n• Reliable review system reflecting quality.\n• Ability to post a "job request" for bids.\n• Direct communication via app, phone, or official contract.',
          ),

          const SizedBox(height: 24),

          // Platform Features
          _SectionTitle(
            icon: Icons.star,
            title: isAr ? '✨ ميزات المنصة المميزة' : '✨ Premium Features',
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.map,
            iconColor: Colors.amber,
            text: isAr
                ? 'مستكشف الخريطة (Map Explorer): خريطة ذكية سريعة تعمل محلياً للبحث عن مقدمي الخدمات والمتاجر المحيطة بك دون استهلاك كبير للإنترنت.'
                : 'Map Explorer: A fast, locally cached smart map to find nearby service providers and shops without consuming much data.',
          ),
          _AboutCard(
            icon: Icons.favorite,
            iconColor: Colors.redAccent,
            text: isAr
                ? 'المفضلة الشاملة (Favorites): مكان واحد لحفظ المنتجات الرائعة من المتاجر، بالإضافة لحفظ الحرفيين والزملاء المفضلين للعودة إليهم بسرعة لاحقاً.'
                : 'Unified Favorites: One place to save great products, as well as favorite freelancers and peers to quickly access them later.',
          ),

          const SizedBox(height: 24),

          // Community Vision
          _SectionTitle(
            icon: Icons.public,
            title: isAr ? '🌍 رؤيتنا المجتمعية' : '🌍 Our Vision',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _AboutCard(
            icon: Icons.groups,
            iconColor: Colors.orange,
            text: isAr
                ? 'نسعى لخلق مجتمع مهني سوداني مترابط، يدعم الشباب ويسهل عليهم تسويق أنفسهم، ويحمي العملاء من خلال الشفافية والتقييم العادل والمستمر.'
                : 'We strive to build a cohesive Sudanese professional community that supports youth in marketing themselves and protects clients through transparent and fair continuous ratings.',
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
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _AboutCard({
    required this.icon,
    required this.iconColor,
    required this.text,
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
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ),
          ],
          ),
        ),
      ),
    );
  }
}
