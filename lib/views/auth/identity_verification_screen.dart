import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pinput/pinput.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/custom_text_field.dart';
import '../../core/utils/app_error_handler.dart';
import '../../widgets/common/glass_container.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  int _currentStep = 0;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  bool _isPhoneVerified = false;
  bool _useWhatsAppOTP = false; // Toggle between SMS and WhatsApp

  File? _personalPhoto;
  File? _idCardPhoto;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      if (user.phoneNumber != null) {
        _phoneController.text = user.phoneNumber!;
      }
      _isPhoneVerified = user.isVerified;
      if (_isPhoneVerified) {
        _currentStep = 1;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    final success = _useWhatsAppOTP
        ? await authProvider.sendWhatsAppOTP(_phoneController.text.trim())
        : await authProvider
            .sendPhoneVerification(_phoneController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await authProvider.updateUserProfile({
        'verificationMethod': _useWhatsAppOTP ? 'whatsapp' : 'sms',
        'verificationPhoneNumber': _phoneController.text.trim(),
        'verificationRequestedAt': Timestamp.now(),
      });
      setState(() => _codeSent = true);
    } else {
      final error = authProvider.errorMessage ?? 'Failed to send code';
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    final success = _useWhatsAppOTP
        ? await authProvider.verifyWhatsAppOTP(
            _phoneController.text.trim(), _otpController.text.trim())
        : await authProvider.verifyOTPAndLink(_otpController.text.trim());

    if (success) {
      await authProvider.updateUserProfile({'isVerified': true});
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPhoneVerified = true;
          _currentStep = 1;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        final error = authProvider.errorMessage ?? 'Invalid code';
        messenger.showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _pickPersonalPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, maxWidth: 800);
    if (picked != null) {
      setState(() => _personalPhoto = File(picked.path));
    }
  }

  Future<void> _pickIdCardPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200); // Usually need higher res for ID
    if (picked != null) {
      setState(() => _idCardPhoto = File(picked.path));
    }
  }

  Future<void> _submitVerification() async {
    if (!_isPhoneVerified || _personalPhoto == null || _idCardPhoto == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user!.id;

      // 1. Upload personal verification photo
      String? selfieUrl;
      try {
        selfieUrl = await StorageService()
            .uploadVerificationSelfie(userId, _personalPhoto!);
      } catch (e) {
        debugPrint('Personal photo upload error: $e');
        throw Exception('فشل رفع الصورة الشخصية');
      }

      // 2. Upload ID Card
      String idCardUrl;
      try {
        idCardUrl = await StorageService().uploadIdCard(userId, _idCardPhoto!);
      } catch (e) {
        debugPrint('ID card upload error: $e');
        throw Exception('فشل رفع صورة الهوية');
      }

      // 3. Create verification request
      await FirebaseFirestore.instance.collection('verification_requests').add({
        'userId': userId,
        'status': 'pending',
        'submittedData': {
          'method': _useWhatsAppOTP ? 'whatsapp' : 'sms',
          'phoneNumber': _phoneController.text.trim(),
          'selfieUrl': selfieUrl,
          'idCardUrl': idCardUrl,
          'notes': '', // Optional notes field
        },
        'createdAt': Timestamp.now(),
      });

      // 4. Update user profile with verification data (but not isVerified yet)
      await auth.updateUserProfile({
        'verificationSelfieUrl': selfieUrl,
        'idCardUrl': idCardUrl,
        'verificationStatus': VerificationStatus.pending.name,
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e, stack) {
      if (context.mounted)
        AppErrorHandler.show(context, e, stack,
            logContext: 'IdentityVerification.submit');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    final isArabic = context.read<LocaleProvider>().isArabic;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(isArabic ? 'تم تقديم الطلب!' : 'Request Submitted!'),
          ],
        ),
        content: Text(
          isArabic
              ? 'تم إرسال طلب التوثيق للمراجعة بنجاح. سنقوم بإعلامك فور الانتهاء من مراجعته.'
              : 'Your verification request has been submitted for review. We will notify you once it is completed.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: PrimaryButton(
              text: isArabic ? 'حسناً' : 'OK',
              onPressed: () {
                Navigator.pop(ctx); // close dialog
                if (context.mounted) Navigator.pop(context); // close screen
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final status = user?.verificationStatus ?? VerificationStatus.none;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isArabic ? 'توثيق الحساب' : 'Identity Verification'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.9),
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    AppColors.primary.withValues(alpha: 0.15)
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    AppColors.primary.withValues(alpha: 0.1)
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
          // Coming soon notice
          GlassContainer(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(14),
            borderRadius: BorderRadius.circular(12),
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            child: Row(
              children: [
                const Icon(Icons.construction_rounded,
                    color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'سيتم تفعيل هذه الميزة قريباً ، شكراً لصبركم!'
                        : 'This feature will be activated soon. Thank you for your patience!',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: status == VerificationStatus.verified ||
                    status == VerificationStatus.pending
                ? _buildStatusScreen(status, isArabic)
                : Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    onStepContinue: () {
                      if (_currentStep == 0 && !_isPhoneVerified) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                              content: Text(isArabic
                                  ? 'يرجى تأكيد رقم الهاتف أولاً'
                                  : 'Please verify phone first')),
                        );
                        return;
                      }
                      if (_currentStep == 1 && _personalPhoto == null) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                              content: Text(isArabic
                                  ? 'يرجى التقاط صورة شخصية'
                                  : 'Please take a personal photo')),
                        );
                        return;
                      }
                      if (_currentStep == 2 && _idCardPhoto == null) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                              content: Text(isArabic
                                  ? 'يرجى رفع صورة الهوية'
                                  : 'Please upload ID card photo')),
                        );
                        return;
                      }
                      if (_currentStep < 3) {
                        setState(() => _currentStep += 1);
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep -= 1);
                      }
                    },
                    controlsBuilder: (context, details) {
                      if (_currentStep == 0 && !_isPhoneVerified) {
                        return const SizedBox.shrink();
                      }
                      if (_currentStep == 3) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16),
                          child: PrimaryButton(
                            text: isArabic
                                ? 'تأكيد وتقديم الطلب'
                                : 'Confirm & Submit',
                            isLoading: _isSubmitting,
                            onPressed: _submitVerification,
                          ),
                        );
                      }
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(isArabic ? 'متابعة' : 'Continue'),
                            ),
                            const SizedBox(width: 8),
                            if (_currentStep > 0)
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: Text(isArabic ? 'رجوع' : 'Back'),
                              ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      _buildPhoneStep(isArabic),
                      _buildPersonalPhotoStep(isArabic),
                      _buildIdCardStep(isArabic),
                      _buildSubmitStep(isArabic, theme),
                    ],
                  ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildStatusScreen(VerificationStatus status, bool isArabic) {
    final theme = Theme.of(context);
    final isVerified = status == VerificationStatus.verified;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVerified ? Icons.check_circle : Icons.pending,
              color: isVerified ? Colors.green : Colors.orange,
              size: 100,
            ),
            const SizedBox(height: 24),
            Text(
              isVerified
                  ? (isArabic
                      ? 'حسابك موثق بالكامل'
                      : 'Your account is fully verified')
                  : (isArabic
                      ? 'طلبك قيد المراجعة'
                      : 'Your request is pending review'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isVerified
                  ? (isArabic
                      ? 'تتمتع الآن بجميع مزايا الحساب الموثق. تظهر أيقونة المصافحة بجانب اسمك في بطاقتك وملفك الشخصي.'
                      : 'You now enjoy all verified account benefits. A handshake icon appears next to your name on your card and profile.')
                  : (isArabic
                      ? 'نحن نقوم بمراجعة بياناتك وصورة هويتك. سيتم إعلامك قريباً.'
                      : 'We are reviewing your data and ID photo. You will be notified soon.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Step _buildPhoneStep(bool isArabic) {
    final theme = Theme.of(context);
    return Step(
      title: Text(isArabic ? 'تأكيد رقم الهاتف' : 'Verify Phone Number'),
      isActive: _currentStep >= 0,
      state: _isPhoneVerified ? StepState.complete : StepState.indexed,
      content: _isPhoneVerified
          ? Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(isArabic ? 'تم تأكيد رقم الهاتف' : 'Phone number verified',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_codeSent) ...[
                  // OTP Method Selection
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surface,
                    border: Border.all(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.3)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'طريقة التحقق' : 'Verification Method',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text(isArabic
                                    ? 'رسالة نصية (SMS)'
                                    : 'SMS Message'),
                                subtitle: Text(isArabic
                                    ? 'تلقي الرمز عبر SMS'
                                    : 'Receive code via SMS'),
                                value: false,
                                // ignore: deprecated_member_use
                                groupValue: _useWhatsAppOTP,
                                // ignore: deprecated_member_use
                                onChanged: (value) => setState(
                                    () => _useWhatsAppOTP = value ?? false),
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: Text(isArabic ? 'واتساب' : 'WhatsApp'),
                                subtitle: Text(isArabic
                                    ? 'تلقي الرمز عبر واتساب'
                                    : 'Receive code via WhatsApp'),
                                value: true,
                                groupValue: _useWhatsAppOTP,
                                onChanged: (value) => setState(
                                    () => _useWhatsAppOTP = value ?? false),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: isArabic ? 'رقم الهاتف' : 'Phone Number',
                    hint: '09xxxxxxxx',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: isArabic ? 'إرسال الرمز' : 'Send Code',
                    isLoading: _isLoading,
                    onPressed: _sendCode,
                  ),
                ] else ...[
                  Text(
                    isArabic ? 'أدخل الرمز المرسل إلى' : 'Enter code sent to',
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _phoneController.text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Pinput(
                      length: 6,
                      controller: _otpController,
                      onCompleted: (_) => _verifyOtp(),
                      defaultPinTheme: PinTheme(
                        width: 50,
                        height: 56,
                        textStyle: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: isArabic ? 'تحقق الآن' : 'Verify Now',
                    isLoading: _isLoading,
                    onPressed: _verifyOtp,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _codeSent = false),
                    child: Text(isArabic
                        ? 'تغيير رقم الهاتف؟'
                        : 'Change phone number?'),
                  ),
                ],
              ],
            ),
    );
  }

  Step _buildPersonalPhotoStep(bool isArabic) {
    final theme = Theme.of(context);
    return Step(
      title: Text(isArabic ? 'التقاط صورة شخصية' : 'Take a Personal Photo'),
      isActive: _currentStep >= 1,
      state: _personalPhoto != null ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          Text(
            isArabic
                ? 'يرجى التقاط صورة شخصية واضحة لملفك الشخصي.'
                : 'Please take a clear personal photo for your profile.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickPersonalPhoto,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage:
                  _personalPhoto != null ? FileImage(_personalPhoto!) : null,
              child: _personalPhoto == null
                  ? const Icon(Icons.camera_alt,
                      size: 40, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _pickPersonalPhoto,
            icon: const Icon(Icons.camera),
            label: Text(isArabic
                ? (_personalPhoto == null ? 'التقط صورة' : 'تغيير الصورة')
                : 'Take Photo'),
          ),
        ],
      ),
    );
  }

  Step _buildIdCardStep(bool isArabic) {
    final theme = Theme.of(context);
    return Step(
      title: Text(isArabic ? 'رفع صورة الهوية' : 'Upload ID Card'),
      isActive: _currentStep >= 2,
      state: _idCardPhoto != null ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          Text(
            isArabic
                ? 'يرجى التقاط صورة واضحة لبطاقة الهوية الوطنية أو جواز السفر.'
                : 'Please take a clear photo of your National ID or Passport.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_idCardPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_idCardPhoto!,
                  height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _pickIdCardPhoto,
            icon: const Icon(Icons.credit_card),
            label: Text(isArabic
                ? (_idCardPhoto == null ? 'التقاط صورة الهوية' : 'تغيير الصورة')
                : 'Capture ID Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Step _buildSubmitStep(bool isArabic, ThemeData theme) {
    return Step(
      title: Text(isArabic ? 'تأكيد وتقديم الطلب' : 'Confirm & Submit Request'),
      isActive: _currentStep >= 3,
      content: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.withValues(alpha: 0.05),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic ? 'الخصوصية والأمان' : 'Privacy & Security',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'هذه المعلومات تُستخدم لغرض توثيق حسابك فقط بهدف خلق بيئة آمنة للمستخدمين.\n\nلن يتم مشاركة هذه المعلومات مع أي جهة خارجية، ولن يطلع عليها أي شخص إلا في الحالات القانونية.'
                  : 'This information is used solely for verifying your account to create a safe environment.\n\nIt will not be shared with any third party and will only be accessible in legal cases.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
