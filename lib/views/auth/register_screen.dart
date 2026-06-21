import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/custom_text_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/privacy_policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final locale = context.read<LocaleProvider>().locale.languageCode;
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          locale == 'ar'
              ? 'شروط الاستخدام والخصوصية'
              : 'Terms of Use and Privacy',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(locale == 'ar'
            ? 'بالضغط على "موافق"، أنت تؤكد اطلاعك وموافقتك على شروط الاستخدام وسياسة الخصوصية الخاصة بنا.'
            : 'By clicking "Agree", you confirm that you have read and agreed to our Terms of Use and Privacy Policy.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
            child: Text(locale == 'ar' ? 'قراءة الشروط' : 'Read Terms'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Show loading overlay
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final success = await authProvider.signUpWithEmail(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );

              if (mounted) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading overlay
                }
              }

              if (success && mounted) {
                // مسح كل الـ stack - app.dart سيعرض ProfileSetupScreen تلقائياً
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              } else if (!success && mounted) {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        authProvider.errorMessage ?? 'Registration failed'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(locale == 'ar' ? 'موافق' : 'Agree'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final authProvider = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;
    final isLoading = authProvider.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signup),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Welcome Text
                Text(
                  locale == 'ar'
                      ? 'مرحباً بك في سودان فري!'
                      : 'Welcome to SudanFree!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  locale == 'ar'
                      ? 'أنشئ حسابك للبدء في رحلة العمل الحر'
                      : 'Create your account to start your freelance journey',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),

                const SizedBox(height: 32),

                // Email Field
                CustomTextField(
                  label: l10n.email,
                  hint: 'example@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return locale == 'ar'
                          ? 'البريد الإلكتروني مطلوب'
                          : 'Email is required';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return locale == 'ar'
                          ? 'بريد إلكتروني غير صالح'
                          : 'Invalid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                PasswordTextField(
                  label: AppStrings.get(AppStrings.password, locale),
                  hint: locale == 'ar'
                      ? 'أدخل كلمة المرور'
                      : 'Enter your password',
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return locale == 'ar'
                          ? 'كلمة المرور مطلوبة'
                          : 'Password is required';
                    }
                    if (value.length < 6) {
                      return locale == 'ar'
                          ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                          : 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Password Field
                PasswordTextField(
                  label:
                      locale == 'ar' ? 'تأكيد كلمة المرور' : 'Confirm Password',
                  hint: locale == 'ar'
                      ? 'أعد إدخال كلمة المرور'
                      : 'Re-enter password',
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return locale == 'ar'
                          ? 'تأكيد كلمة المرور مطلوب'
                          : 'Confirm password is required';
                    }
                    if (value != _passwordController.text) {
                      return locale == 'ar'
                          ? 'كلمات المرور غير متطابقة'
                          : 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Register Button
                GradientButton(
                  text: AppStrings.get(AppStrings.signup, locale),
                  isLoading: isLoading,
                  onPressed: _handleRegister,
                ),

                const SizedBox(height: 24),

                // Terms and Conditions
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                  child: Text(
                    locale == 'ar'
                        ? 'بالتسجيل، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                        : 'By registering, you agree to the Terms of Use and Privacy Policy',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.get(AppStrings.haveAccount, locale),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppStrings.get(AppStrings.login, locale)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
