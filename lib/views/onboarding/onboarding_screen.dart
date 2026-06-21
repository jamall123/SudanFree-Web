import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/glass_card.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingItem> _getItems(bool isArabic) {
    return [
      OnboardingItem(
        icon: Icons.work_outline_rounded,
        title: isArabic ? 'اعثر على فرص عمل' : 'Find Job Opportunities',
        description: isArabic
            ? 'تواصل مع أصحاب العمل واحصل على مشاريع تناسب مهاراتك بسهولة.'
            : 'Connect with clients and get projects that match your skills easily.',
      ),
      OnboardingItem(
        icon: Icons.verified_user_outlined,
        title: isArabic ? 'بيئة موثوقة وآمنة' : 'Trusted & Safe Environment',
        description: isArabic
            ? 'نظام تقييم ومراجعات يضمن لك التعامل مع أشخاص حقيقيين وموثوقين.'
            : 'Rating and review system ensures you deal with real and trusted people.',
      ),
      OnboardingItem(
        icon: Icons.people_outline_rounded,
        title: isArabic ? 'مجتمع للمستقلين' : 'Freelancers Community',
        description: isArabic
            ? 'شارك خبراتك، اسأل، وتفاعل مع أكبر مجتمع للمستقلين في السودان.'
            : 'Share experiences, ask, and interact with the largest freelancer community in Sudan.',
      ),
    ];
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    // استدعاء callback من OnboardingCheck دائماً
    // (لا تدفع LoginScreen كـ route منفصلة — app.dart يتحكم بالتوجيه)
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    }
    // لا يوجد else — لا نستخدم Navigator هنا أبداً
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final items = _getItems(isArabic);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
          child: Column(
            children: [
            // Skip Button
            Align(
              alignment: isArabic ? Alignment.topLeft : Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  isArabic ? 'تخطي' : 'Skip',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: GlassCard(
                        borderRadius: 32,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassContainer(
                                shape: BoxShape.circle,
                                padding: const EdgeInsets.all(32),
                                blur: 15,
                                opacity: 0.1,
                                color: AppColors.primary,
                                child: Icon(
                                  items[index].icon,
                                  size: 80,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 48),
                              Text(
                                items[index].title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                items[index].description,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          height: 1.5,
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicators and Button
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      items.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < items.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == items.length - 1
                            ? (isArabic ? 'ابدأ الآن' : 'Get Started')
                            : (isArabic ? 'التالي' : 'Next'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
