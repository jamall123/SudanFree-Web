import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isAr ? 'السياسات وشروط الاستخدام' : 'Policies & Terms',
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
                const Icon(Icons.gavel, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  isAr
                      ? 'سياسات ومعايير الاستخدام'
                      : 'Usage Policies & Standards',
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

          // 1. Strict Usage Warnings
          _SectionTitle(
            icon: Icons.warning_amber_rounded,
            title: isAr
                ? '⚠️ تحذيرات هامة وشروط الاستخدام'
                : '⚠️ Important Warnings & Terms',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          _PolicyCard(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            text: isAr
                ? 'يستخدم هذا التطبيق للبحث عن العمل والخدمات بالطرق المشروعة والآمنة فقط.'
                : 'This app is strictly for legitimate and safe job and service searching.',
          ),
          _PolicyCard(
            icon: Icons.block,
            iconColor: Colors.red,
            text: isAr
                ? 'يمنع منعاً باتاً نشر محتوى مسيء، غير لائق، أو استدراج أي طرف لأغراض غير أخلاقية. أي تصرف مشبوه يعرض حسابك للحظر النهائي فوراً.'
                : 'Posting offensive content or engaging in unethical behavior is strictly prohibited and will result in an immediate permanent ban.',
          ),
          _PolicyCard(
            icon: Icons.gavel,
            iconColor: Colors.orange,
            text: isAr
                ? 'التطبيق يعتبر منصة وسيطة لربط العملاء بأصحاب المهن الحرة والمحلات. نحن لا نتحمل المسؤولية القانونية أو المالية لأي اتفاق يتم خارج أو داخل التطبيق.'
                : 'The app is a medium to connect clients with freelancers and shops. We hold no legal or financial responsibility for agreements made.',
          ),

          const SizedBox(height: 24),

          // 2. Safety Advice
          _SectionTitle(
            icon: Icons.health_and_safety,
            title: isAr ? '🛡️ نصائح السلامة والأمان' : '🛡️ Safety Tips',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _PolicyCard(
            icon: Icons.monetization_on,
            iconColor: Colors.green,
            text: isAr
                ? 'لا تقم بدفع أي مبالغ مالية مقدماً قبل استلام الخدمة أو التأكد من مصداقية الطرف الآخر.'
                : 'Do not pay any money in advance before receiving the service or verifying credibility.',
          ),
          _PolicyCard(
            icon: Icons.place,
            iconColor: Colors.blue,
            text: isAr
                ? 'عند الاتفاق على لقاء للعمل، احرص على أن يكون في أماكن عامة وآمنة.'
                : 'When agreeing to meet, ensure it is in a public and safe place.',
          ),
          _PolicyCard(
            icon: Icons.verified_user,
            iconColor: Colors.purple,
            text: isAr
                ? 'تعامل دائماً مع الحسابات الموثقة (التي تحمل شعار التصافح 🤝) لضمان موثوقية أكبر وأمان في التعاملات.'
                : 'Always deal with verified accounts (with the handshake symbol 🤝) for higher reliability and safer transactions.',
          ),

          const SizedBox(height: 24),

          // 3. Trust Levels
          _SectionTitle(
            icon: Icons.military_tech,
            title: isAr ? '🏆 التقييم ونظام الثقة' : '🏆 Rating & Trust System',
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          _PolicyCard(
            icon: Icons.star,
            iconColor: Colors.amber,
            text: isAr
                ? 'النجوم الممنوحة في التقييمات ترفع من رتبتك من "مستخدم عادي" إلى "محترف" وتزيد فرص ظهورك للعملاء.'
                : 'Stars awarded in reviews upgrade your rank from standard to professional, increasing your visibility.',
          ),
          _PolicyCard(
            icon: Icons.balance,
            iconColor: Colors.blue,
            text: isAr
                ? 'نظام التقييم مصمم لمنع التلاعب. يتم احتساب التقييم الأول فقط من كل عميل لضمان نزاهة النجوم.'
                : 'The rating system prevents manipulation. Only the first rating from each client counts towards stars.',
          ),

          const SizedBox(height: 24),

          // 4. Privacy & Data Deletion
          _SectionTitle(
            icon: Icons.privacy_tip,
            title: isAr
                ? '🔒 سياسة الخصوصية وحذف البيانات'
                : '🔒 Privacy & Data Deletion',
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _PolicyCard(
            icon: Icons.phone_android,
            iconColor: Colors.teal,
            text: isAr
                ? 'بياناتك الشخصية (الاسم، الموقع الجغرافي، رقم الهاتف) تستخدم حصرياً لتحسين تجربتك وربطك بالعملاء داخل التطبيق، ولا نشاركها مع أي جهات خارجية.'
                : 'Your personal data (name, location, phone) is used exclusively to connect you with clients. We do not share it with third parties.',
          ),
          _PolicyCard(
            icon: Icons.location_off,
            iconColor: Colors.indigo,
            text: isAr
                ? 'التحكم في الخريطة: يحق لأي حرفي أو متجر إخفاء موقعه الجغرافي بالكامل من الخريطة العامة في أي وقت عبر الإعدادات ("الظهور على الخريطة"). عند التعطيل، يتم حجب موقعك فوراً لحماية خصوصيتك.'
                : 'Map Control: Any freelancer or shop can hide their location entirely from the public map at any time via settings. When disabled, your location is immediately hidden to protect your privacy.',
          ),
          _PolicyCard(
            icon: Icons.delete_forever,
            iconColor: Colors.deepOrange,
            text: isAr
                ? 'يحق لك المطالبة بحذف حسابك نهائياً. عند طلب الحذف من الإعدادات، يتم مراجعة طلبك لأسباب أمنية (لضمان عدم وجود حقوق معلقة للآخرين) ثم تُحذف كافة بياناتك بالكامل من خوادمنا بما فيها الإعجابات والمفضلات والموقع.'
                : 'You have the right to request account deletion. Upon request, it is reviewed for security reasons, then all your data including favorites and location is permanently deleted.',
          ),

          const SizedBox(height: 40),

          Center(
            child: Text(
              isAr
                  ? 'استخدامك للتطبيق يعني موافقتك الصريحة على هذه السياسات'
                  : 'Using the app means your explicit agreement to these policies',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
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

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _PolicyCard({
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
