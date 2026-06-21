import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/sudan_locations.dart';
import '../../models/user_model.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/region_detection_service.dart';
import '../../core/utils/app_error_handler.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/inputs/custom_text_field.dart';

import '../settings/privacy_policy_screen.dart';

import 'identity_verification_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final UserModel? existingUser;
  const ProfileSetupScreen({super.key, this.existingUser});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _customSkillController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _closingHoursController = TextEditingController();

  UserRole? _selectedRole;
  ShopCategory? _selectedShopCategory;
  String? _selectedState;
  String? _selectedLocality;
  double? _latitude;
  double? _longitude;
  final List<JobCategory> _selectedCategories = [];
  final List<String> _customJobTitles = [];
  // Client interests
  final List<ShopCategory> _selectedShopInterests = [];
  final List<JobCategory> _selectedServiceInterests = [];
  int _currentStep = 0;

  void _switchRole(UserRole role) {
    // ── Security Lock: Prevent jumping between Provider Types ──
    if (widget.existingUser != null) {
      final oldRole = widget.existingUser!.role;
      if (oldRole != UserRole.client &&
          role != UserRole.client &&
          role != oldRole) {
        final locale = context.read<LocaleProvider>().locale.languageCode;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(locale == 'ar'
                ? 'لا يمكنك تحويل الحساب لمهنة جديدة للحفاظ على تقييماتك السابقة. يمكنك البقاء كعميل أو كمهنتك الأصلية فقط.'
                : 'You cannot switch to a new provider type to protect your reviews. You can only be a Client or your original profession.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return; // Reject the switch
      }
    }

    setState(() {
      if (_selectedRole != role) {
        _selectedCategories.clear();
        _selectedShopCategory = null;
        _customSkillController.clear();
        _customJobTitles.clear();
        // Reset step to 0 when role changes to avoid out-of-bounds
        // (client has 4 steps, service providers have 5)
        _currentStep = 0;
      }
      _selectedRole = role;
    });
  }

  bool _isOutsideSudan =
      true; // fail-closed: assume outside until proven otherwise
  bool _isLoadingRegion = true;
  bool _isVerifyingGPS = false;
  bool _detectionFailed = false; // true when ALL IP APIs failed
  bool _isDetectingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _checkRegionLocation();
    if (widget.existingUser != null) {
      final user = widget.existingUser!;
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
      _neighborhoodController.text = user.neighborhood ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _hourlyRateController.text = user.hourlyRate?.toString() ?? '';
      _openingHoursController.text = user.openingHours ?? '';
      _closingHoursController.text = user.closingHours ?? '';
      _selectedRole = user.role;
      _selectedShopCategory = user.shopCategory;
      _selectedState = user.state;
      _selectedLocality = user.locality;
      _latitude = user.latitude;
      _longitude = user.longitude;

      for (var skill in user.skills) {
        try {
          final category = JobCategory.values.firstWhere(
              (c) => c.name == skill || c.toString().split('.').last == skill,
              orElse: () => JobCategory.other);
          if (category == JobCategory.other) {
            // This is a custom skill name, not a known category
            if (!_customJobTitles.contains(skill) && skill != 'other') {
              _customJobTitles.add(skill);
            }
          } else if (!_selectedCategories.contains(category)) {
            _selectedCategories.add(category);
          }
        } catch (_) {}
      }
      // If we loaded custom titles, ensure 'other' chip is selected to show the section
      if (_customJobTitles.isNotEmpty &&
          !_selectedCategories.contains(JobCategory.other)) {
        _selectedCategories.add(JobCategory.other);
      }

      // Load custom shop category if applicable
      if (user.role == UserRole.shop &&
          user.shopCategory == ShopCategory.other &&
          user.jobTitle != null &&
          user.jobTitle!.isNotEmpty) {
        _customJobTitles.add(user.jobTitle!);
      }

      // Load client interests
      if (user.role == UserRole.client) {
        for (final s in user.shopInterests) {
          try {
            final cat = ShopCategory.values.firstWhere((e) => e.name == s);
            if (!_selectedShopInterests.contains(cat))
              _selectedShopInterests.add(cat);
          } catch (_) {}
        }
        for (final s in user.serviceInterests) {
          try {
            final cat = JobCategory.values.firstWhere((e) => e.name == s);
            if (!_selectedServiceInterests.contains(cat))
              _selectedServiceInterests.add(cat);
          } catch (_) {}
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _neighborhoodController.dispose();
    _phoneController.dispose();
    _hourlyRateController.dispose();
    _customSkillController.dispose();
    _openingHoursController.dispose();
    _closingHoursController.dispose();
    super.dispose();
  }

  Future<void> _checkRegionLocation() async {
    // Use multi-API cascading detection (ip-api.com → ipwho.is → freeipapi.com)
    final result = await RegionDetectionService.detectByIP();

    if (!mounted) return;
    setState(() {
      _isOutsideSudan = result.isOutsideSudan;
      _detectionFailed = result.result == RegionResult.unknown;
      _isLoadingRegion = false;
    });

    // If detection failed (all APIs down) and user is new,
    // auto-select client role as safety measure
    if (_detectionFailed && widget.existingUser == null) {
      debugPrint(
          'RegionDetection: All APIs failed → restricting to client for safety');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _locationError = null;
      _isDetectingLocation = true;
    });
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'خدمات الموقع مقفلة.';
          _isDetectingLocation = false;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'تم رفض إذن الوصول للموقع.';
            _isDetectingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'تم رفض إذن الموقع بشكل دائم.';
          _isDetectingLocation = false;
        });
        return;
      }
    } catch (e) {
      setState(() {
        _locationError = 'خطأ في أذونات الموقع.';
        _isDetectingLocation = false;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _selectedState = _matchState(place.administrativeArea ?? '');
            if (_selectedState != null) {
              _selectedLocality = _matchLocality(
                  place.locality ?? place.subAdministrativeArea ?? '',
                  _selectedState!);
            }
          });
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(const SnackBar(
              content: Text('تم تحديد الموقع بنجاح'),
              backgroundColor: AppColors.success));
        }
      }
    } catch (e) {
      setState(() => _locationError = 'فشل في تحديد الموقع تلقائياً.');
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _verifyLocationWithGPS(String locale) async {
    setState(() {
      _isVerifyingGPS = true;
    });

    if (mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(locale == 'ar'
                ? 'جاري التحقق من الموقع عبر GPS...'
                : 'Verifying location via GPS...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: Colors.grey[800],
      ));
    }

    try {
      final gpsResult = await RegionDetectionService.detectByGPS();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (gpsResult == null) {
        // GPS unavailable (permissions denied or service off)
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(locale == 'ar'
              ? 'لم نتمكن من الوصول لخدمات الموقع. تأكد من تفعيل GPS والأذونات.'
              : 'Could not access location services. Make sure GPS and permissions are enabled.'),
          backgroundColor: AppColors.warning,
        ));
        return;
      }

      // GPS returned a definitive result — update state accordingly
      setState(() {
        _isOutsideSudan = gpsResult.isOutsideSudan;
        _detectionFailed = false; // GPS resolved the uncertainty
      });

      if (gpsResult.isInSudan) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(locale == 'ar'
              ? '✅ تم التحقق بنجاح! أنت داخل السودان.'
              : '✅ Verified successfully! You are in Sudan.'),
          backgroundColor: AppColors.success,
        ));
      } else {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(locale == 'ar'
              ? 'يبدو أنك خارج السودان حالياً. يمكنك التسجيل كعميل.'
              : 'It appears you are outside Sudan. You can register as a client.'),
          backgroundColor: AppColors.warning,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(locale == 'ar'
              ? 'حدث خطأ أثناء التحقق من الموقع'
              : 'Error verifying location'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted)
        setState(() {
          _isVerifyingGPS = false;
        });
    }
  }

  String? _matchState(String adminArea) {
    if (adminArea.isEmpty) return null;
    final area = adminArea.toLowerCase();

    if (area.contains('khartoum')) return 'الخرطوم';
    if (area.contains('jazira') || area.contains('gezira')) return 'الجزيرة';
    if (area.contains('river nile')) return 'نهر النيل';
    if (area.contains('northern')) return 'الشمالية';
    if (area.contains('kassala')) return 'كسلا';
    if (area.contains('gedaref') ||
        area.contains('qadaref') ||
        area.contains('qadarif')) return 'القضارف';
    if (area.contains('red sea')) return 'البحر الأحمر';
    if (area.contains('sennar')) return 'سنار';
    if (area.contains('blue nile')) return 'النيل الأزرق';
    if (area.contains('white nile')) return 'النيل الأبيض';
    if (area.contains('north') && area.contains('kordofan'))
      return 'شمال كردفان';
    if (area.contains('south') && area.contains('kordofan'))
      return 'جنوب كردفان';
    if (area.contains('west') && area.contains('kordofan')) return 'غرب كردفان';
    if (area.contains('north') && area.contains('darfur')) return 'شمال دارفور';
    if (area.contains('south') && area.contains('darfur')) return 'جنوب دارفور';
    if (area.contains('west') && area.contains('darfur')) return 'غرب دارفور';
    if (area.contains('central') && area.contains('darfur'))
      return 'وسط دارفور';
    if (area.contains('east') && area.contains('darfur')) return 'شرق دارفور';

    for (var s in SudanLocations.states) {
      if (adminArea.contains(s) || s.contains(adminArea)) return s;
    }
    return null;
  }

  String? _matchLocality(String localityArea, String state) {
    if (localityArea.isEmpty) return null;
    final area = localityArea.toLowerCase();
    final localities = SudanLocations.getLocalities(state);

    if (area.contains('khartoum north') || area.contains('bahri'))
      return 'بحري';
    if (area.contains('khartoum')) return 'الخرطوم';
    if (area.contains('omdurman')) return 'أم درمان';
    if (area.contains('karari')) return 'كرري';
    if (area.contains('umbadda') || area.contains('ombadda')) return 'أم بدة';
    if (area.contains('jebel aulia')) return 'جبل أولياء';
    if (area.contains('sharq an nil') || area.contains('east nile'))
      return 'شرق النيل';
    if (area.contains('wad madani') || area.contains('wad medani'))
      return 'ود مدني';
    if (area.contains('port sudan')) return 'بورتسودان';
    if (area.contains('kassala')) return 'كسلا';
    if (area.contains('nyala')) return 'نيالا';
    if (area.contains('el fasher') || area.contains('al fashir'))
      return 'الفاشر';
    if (area.contains('al ubayyid') || area.contains('el obeid'))
      return 'الأبيض';

    for (var l in localities) {
      if (localityArea.contains(l) || l.contains(localityArea)) return l;
    }
    return null;
  }

  void _showAddCustomJobTitleDialog(String locale) {
    if (_selectedRole != UserRole.shop) {
      final totalSelected =
          _selectedCategories.where((c) => c != JobCategory.other).length +
              _customJobTitles.length;
      if (totalSelected >= 2) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(locale == 'ar'
                ? 'عذراً، يمكنك اختيار مسميين وظيفيين كحد أقصى'
                : 'Sorry, you can select up to 2 categories'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      if (_customJobTitles.isNotEmpty) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(locale == 'ar'
                ? 'عذراً، يمكنك إضافة نوع متجر مخصص واحد فقط'
                : 'Sorry, you can only add one custom shop type'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    _customSkillController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        final isShop = _selectedRole == UserRole.shop;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isShop ? Icons.store_outlined : Icons.work_outline,
                  color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                isShop
                    ? (locale == 'ar' ? 'نوع متجر مخصص' : 'Custom Shop Type')
                    : (locale == 'ar' ? 'مسمى وظيفي مخصص' : 'Custom Job Title'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isShop
                    ? (locale == 'ar'
                        ? 'اكتب نوع متجرك إذا لم تجده في القائمة'
                        : 'Type your shop category if not listed')
                    : (locale == 'ar'
                        ? 'اكتب اسم مهنتك إذا لم تجدها في القائمة'
                        : 'Type your profession if not listed'),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customSkillController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: isShop
                      ? (locale == 'ar'
                          ? 'مثال: محل هدايا، عطور...'
                          : 'e.g. Gift Shop, Perfumes...')
                      : (locale == 'ar'
                          ? 'مثال: نجار، حداد، ميكانيكي...'
                          : 'e.g. Carpenter, Blacksmith...'),
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.edit,
                      color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: AppColors.primary.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) {
                  _confirmAddCustomTitle(locale);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(locale == 'ar' ? 'إلغاء' : 'Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _confirmAddCustomTitle(locale);
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(locale == 'ar' ? 'إضافة' : 'Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmAddCustomTitle(String locale) {
    final title = _customSkillController.text.trim();
    if (title.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              locale == 'ar' ? 'الرجاء الكتابة أولاً' : 'Please type first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_customJobTitles.contains(title)) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(locale == 'ar'
              ? 'هذا المسمى مضاف بالفعل'
              : 'This title is already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _customJobTitles.add(title);
      _customSkillController.clear();
      if (_selectedRole == UserRole.shop) {
        _selectedShopCategory = ShopCategory.other;
      } else {
        if (!_selectedCategories.contains(JobCategory.other)) {
          _selectedCategories.add(JobCategory.other);
        }
      }
    });
  }

  int get _totalSteps =>
      _isServiceProvider ? 5 : 5; // عميل ومقدمو الخدمات لهم 5 خطوات
  bool get _isServiceProvider =>
      _selectedRole == UserRole.freelancer ||
      _selectedRole == UserRole.techService ||
      _selectedRole == UserRole.privateService ||
      _selectedRole == UserRole.shop;

  Future<void> _handleSubmit() async {
    if (_selectedRole == null) return;

    final authProvider = context.read<AuthProvider>();

    // If it's a new account, show Terms confirmation
    if (widget.existingUser == null) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'شروط الاستخدام والخصوصية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'بالضغط على "موافق"، أنت تؤكد اطلاعك وموافقتك على شروط الاستخدام وسياسة الخصوصية الخاصة بنا.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              child: const Text('قراءة الشروط'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('موافق'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    bool success = false;

    // Prepare skills list
    List<String>? skills;
    if (_selectedRole == UserRole.freelancer ||
        _selectedRole == UserRole.techService ||
        _selectedRole == UserRole.privateService) {
      skills = _selectedCategories
          .where((c) => c != JobCategory.other)
          .map((c) => c.name)
          .toList();
      // Add all custom job titles
      if (_customJobTitles.isNotEmpty) {
        skills.addAll(_customJobTitles);
      }
    }

    // Show loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Map<String, dynamic> profileData = {
        'name': _nameController.text.trim(),
        'role': _selectedRole!.name,
        'bio': _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        'phoneNumber': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'whatsappNumber': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'state': _selectedState,
        'locality': _selectedLocality,
        'neighborhood': _neighborhoodController.text.trim().isNotEmpty
            ? _neighborhoodController.text.trim()
            : null,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'updatedAt': DateTime.now(),
        'searchKeywords': UserModel.generateSearchKeywords(
          name: _nameController.text.trim(),
          jobTitle: (_selectedRole == UserRole.shop &&
                  _selectedShopCategory == ShopCategory.other &&
                  _customJobTitles.isNotEmpty)
              ? _customJobTitles.first
              : widget.existingUser?.jobTitle,
          skills: _selectedCategories
              .where((c) => c != JobCategory.other)
              .map((c) => c.name)
              .toList()
            ..addAll(_customJobTitles),
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
          state: _selectedState,
          locality: _selectedLocality,
          neighborhood: _neighborhoodController.text.trim().isNotEmpty
              ? _neighborhoodController.text.trim()
              : null,
          shopCategory: _selectedShopCategory,
          role: _selectedRole,
        ),
        // ── اهتمامات العميل (للتحديث) ──
        if (_selectedRole == UserRole.client) ...{
          'shopInterests': _selectedShopInterests.map((e) => e.name).toList(),
          'serviceInterests':
              _selectedServiceInterests.map((e) => e.name).toList(),
        },
      };
      // Removed legacy idCard upload from profile creation

      // Add freelancer/tech-specific fields
      if (_selectedRole == UserRole.freelancer ||
          _selectedRole == UserRole.techService ||
          _selectedRole == UserRole.privateService) {
        profileData['skills'] = skills;
        if (_hourlyRateController.text.isNotEmpty) {
          profileData['hourlyRate'] =
              double.tryParse(_hourlyRateController.text);
        }
      }

      // Add shop-specific fields
      if (_selectedRole == UserRole.shop) {
        profileData['shopCategory'] = _selectedShopCategory?.name;
        profileData['openingHours'] =
            _openingHoursController.text.trim().isNotEmpty
                ? _openingHoursController.text.trim()
                : null;
        profileData['closingHours'] =
            _closingHoursController.text.trim().isNotEmpty
                ? _closingHoursController.text.trim()
                : null;
      }

      // ─── حذف بيانات نوع الحساب القديم عند التحويل ───
      if (widget.existingUser != null &&
          _selectedRole != widget.existingUser!.role) {
        final oldRole = widget.existingUser!.role;

        // إذا كان الحساب القديم متجر → حذف بيانات المتجر
        if (oldRole == UserRole.shop && _selectedRole != UserRole.shop) {
          profileData['shopCategory'] = FieldValue.delete();
          profileData['shopImages'] = FieldValue.delete();
          profileData['openingHours'] = FieldValue.delete();
          profileData['closingHours'] = FieldValue.delete();
        }

        // إذا كان الحساب القديم مقدم خدمات → حذف بيانات الخدمات
        if ((oldRole == UserRole.freelancer ||
                oldRole == UserRole.techService ||
                oldRole == UserRole.privateService) &&
            _selectedRole != UserRole.freelancer &&
            _selectedRole != UserRole.techService &&
            _selectedRole != UserRole.privateService) {
          profileData['skills'] = FieldValue.delete();
          profileData['hourlyRate'] = FieldValue.delete();
          profileData['jobTitle'] = FieldValue.delete();
        }
      }

      if (widget.existingUser != null) {
        success = await authProvider.updateUserProfile(profileData);
      } else {
        success = await authProvider.createUserProfile(
          name: _nameController.text.trim(),
          role: _selectedRole!,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          state: _selectedState,
          locality: _selectedLocality,
          skills: skills,
          hourlyRate: (_selectedRole == UserRole.freelancer ||
                      _selectedRole == UserRole.techService ||
                      _selectedRole == UserRole.privateService) &&
                  _hourlyRateController.text.isNotEmpty
              ? double.tryParse(_hourlyRateController.text)
              : null,
          shopCategory: _selectedShopCategory,
          jobTitle: (_selectedRole == UserRole.shop &&
                  _selectedShopCategory == ShopCategory.other &&
                  _customJobTitles.isNotEmpty)
              ? _customJobTitles.first
              : null,
          openingHours: _openingHoursController.text.trim().isNotEmpty
              ? _openingHoursController.text.trim()
              : null,
          closingHours: _closingHoursController.text.trim().isNotEmpty
              ? _closingHoursController.text.trim()
              : null,
          latitude: _latitude,
          longitude: _longitude,
          // ── اهتمامات العميل ──
          shopInterests: _selectedRole == UserRole.client
              ? _selectedShopInterests.map((e) => e.name).toList()
              : null,
          serviceInterests: _selectedRole == UserRole.client
              ? _selectedServiceInterests.map((e) => e.name).toList()
              : null,
        );
      }
    } catch (e, stack) {
      success = false;
      if (mounted) {
        if (context.mounted) Navigator.pop(context); // Close loading overlay
        AppErrorHandler.show(context, e, stack,
            logContext: 'ProfileSetupScreen.handleSubmit');
      }
      return;
    }

    // ── Always close loading overlay first ──
    if (mounted && Navigator.canPop(context)) {
      if (context.mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    if (success) {
      if (widget.existingUser != null) {
        // تحديث الحساب
        if (context.mounted) Navigator.pop(context);
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('تم حفظ البيانات بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        // إنشاء حساب جديد — app.dart سيتولى التوجيه تلقائياً إلى HomeScreen
        // بعد notifyListeners() في createUserProfile
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح! 🎉'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        // لا نحتاج Navigator هنا — app.dart يعرض HomeScreen تلقائياً
        // عند تغيُّر isNewUser إلى false
      }
    } else {
      // ── Operation returned false without exception → show error ──
      final locale = context.read<LocaleProvider>().locale.languageCode;
      final errorMsg = context.read<AuthProvider>().errorMessage;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg ??
              (locale == 'ar'
                  ? 'فشل في حفظ البيانات. يرجى المحاولة مرة أخرى.'
                  : 'Failed to save profile. Please try again.')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.loading;
    final isEditing = widget.existingUser != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isEditing
            ? (locale == 'ar' ? 'تعديل الملف الشخصي' : 'Edit Profile')
            : (locale == 'ar' ? 'إكمال الملف الشخصي' : 'Complete Profile')),
        automaticallyImplyLeading: isEditing,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.transparent,
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    onSurface: isDark ? Colors.grey.shade400 : Colors.grey.shade600, // Makes lines visible
                  ),
            ),
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep.clamp(0, _totalSteps - 1),
            onStepTapped: (step) {
              // Apply validation before allowing jump forward
              if (step > _currentStep) {
                if (_currentStep == 0) {
                  if (_isLoadingRegion || _isVerifyingGPS) return;
                  if (_selectedRole == null) return;
                }
                if (_currentStep == 1) {
                  final nameText = _nameController.text.trim();
                  final nameRegExp = RegExp(r'[a-zA-Z\u0600-\u06FF]');
                  final phoneText = _phoneController.text.trim();
                  final phoneRegExp = RegExp(r'^\+?[0-9]{9,15}$');
                  if (nameText.length < 2 || !nameRegExp.hasMatch(nameText))
                    return;
                  if (phoneText.isEmpty || !phoneRegExp.hasMatch(phoneText))
                    return;
                }
              }
              setState(() => _currentStep = step);
            },
            onStepContinue: () {
              if (_currentStep == 0) {
                if (_isLoadingRegion || _isVerifyingGPS) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'يرجى الانتظار حتى يكتمل التحقق من الموقع'
                          : 'Please wait for location verification to complete'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                if (_selectedRole == null) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'اختر نوع الحساب'
                          : 'Select an account type'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
              }
              if (_currentStep == 1) {
                final nameText = _nameController.text.trim();
                final nameRegExp = RegExp(
                    r'[a-zA-Z\u0600-\u06FF]'); // يحتوي على أحرف حقيقية (عربية أو إنجليزية) ولا يقبل مسافات فقط أو رموز
                if (nameText.length < 2 || !nameRegExp.hasMatch(nameText)) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'يرجى كتابة اسم حقيقي (أحرف فقط)'
                          : 'Please enter a valid real name (letters only)'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                final phoneText = _phoneController.text.trim();
                final phoneRegExp = RegExp(
                    r'^\+?[0-9]{9,15}$'); // أرقام فقط وقد يبدأ بـ + وطوله منطقي
                if (phoneText.isEmpty || !phoneRegExp.hasMatch(phoneText)) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'رقم الهاتف إجباري ويجب أن يكون صحيحاً'
                          : 'A valid phone number is required'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                if (_selectedRole == UserRole.freelancer ||
                    _selectedRole == UserRole.techService ||
                    _selectedRole == UserRole.privateService) {
                  if (_hourlyRateController.text.trim().isEmpty) {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(locale == 'ar'
                            ? 'السعر بالساعة إجباري لتقديم الخدمات'
                            : 'Hourly rate is required for service providers'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                    return;
                  }
                }
              }
              if (_currentStep == 2 &&
                  (_selectedRole == UserRole.freelancer ||
                      _selectedRole == UserRole.techService ||
                      _selectedRole == UserRole.privateService ||
                      _selectedRole == UserRole.shop)) {
                if (_selectedState == null) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'يجب تحديد الولاية لمقدمي الخدمات العامة والمتاجر'
                          : 'State must be selected for general services and shops'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
                // التحقق من المحلية
                if (_selectedLocality == null) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(locale == 'ar'
                          ? 'يجب تحديد المحلية'
                          : 'Locality must be selected'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }
              }

              final maxStep = _totalSteps - 1;
              if (_currentStep < maxStep) {
                setState(() => _currentStep++);
              } else {
                _handleSubmit();
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              }
            },
            controlsBuilder: (context, details) {
              final isLastStep = _currentStep == _totalSteps - 1;
              final isCheckingLocation =
                  _currentStep == 0 && (_isLoadingRegion || _isVerifyingGPS);

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        text: isLastStep
                            ? (widget.existingUser != null
                                ? (locale == 'ar'
                                    ? 'حفظ التغييرات'
                                    : 'Save Changes')
                                : (locale == 'ar'
                                    ? 'إنشاء الحساب'
                                    : 'Create Account'))
                            : (locale == 'ar' ? 'التالي' : 'Next'),
                        isLoading: isLastStep && isLoading,
                        enabled: !isCheckingLocation,
                        onPressed: isCheckingLocation
                            ? () {
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(locale == 'ar'
                                        ? 'يرجى الانتظار قليلاً حتى يكتمل تحديد الموقع'
                                        : 'Please wait while location is being detected'),
                                    backgroundColor: AppColors.warning,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            : details.onStepContinue,
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          text: locale == 'ar' ? 'السابق' : 'Previous',
                          isOutlined: true,
                          onPressed: details.onStepCancel,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            steps: _buildSteps(locale),
          ),
        ),
      ),
      ),
    );
  }

  List<Step> _buildSteps(String locale) {
    final steps = <Step>[
      // Step 1: Choose Role
      Step(
        title: Text(AppStrings.get(AppStrings.chooseRole, locale)),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: (_isLoadingRegion && widget.existingUser == null)
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري التحقق من موقعك...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // ── Outside Sudan Banner (IP detection or detection failure) ──
                  if ((_isOutsideSudan || _detectionFailed) &&
                      widget.existingUser == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _detectionFailed
                            ? Colors.orange.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _detectionFailed
                              ? Colors.orange
                              : AppColors.warning,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _detectionFailed
                                    ? Icons.wifi_off_rounded
                                    : Icons.public_off,
                                color: _detectionFailed
                                    ? Colors.orange
                                    : AppColors.warning,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _detectionFailed
                                      ? (locale == 'ar'
                                          ? 'لم نتمكن من تحديد موقعك تلقائياً. يرجى التحقق عبر GPS لفتح جميع أنواع الحسابات.'
                                          : 'Could not detect your location automatically. Please verify via GPS to unlock all account types.')
                                      : (locale == 'ar'
                                          ? 'يظهر اتصالك أنك خارج السودان. يمكنك التسجيل كـ "عميل" فقط.\nإذا كنت داخل السودان، يمكنك التحقق عبر GPS.'
                                          : 'Your connection shows you are outside Sudan. You can only register as "Client".\nIf you are in Sudan, verify via GPS.'),
                                  style: TextStyle(
                                    color: _detectionFailed
                                        ? Colors.orange.shade800
                                        : AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _isVerifyingGPS
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.my_location, size: 20),
                              label: Text(
                                _isVerifyingGPS
                                    ? (locale == 'ar'
                                        ? 'جاري التحقق...'
                                        : 'Verifying...')
                                    : (locale == 'ar'
                                        ? 'تحقق من موقعي عبر GPS'
                                        : 'Verify my location via GPS'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isVerifyingGPS
                                  ? null
                                  : () => _verifyLocationWithGPS(locale),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withValues(alpha: 0.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          if (_detectionFailed) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(
                                  locale == 'ar'
                                      ? 'إعادة المحاولة'
                                      : 'Retry Detection',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isLoadingRegion = true;
                                  });
                                  _checkRegionLocation();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // ── Service Provider Roles (only when inside Sudan OR editing) ──
                  if ((!_isOutsideSudan && !_detectionFailed) ||
                      widget.existingUser != null) ...[
                    _buildRoleCard(
                      context,
                      role: UserRole.freelancer,
                      icon: Icons.handyman_outlined,
                      title: locale == 'ar'
                          ? 'مقدم خدمات فنية'
                          : 'Craft Service Provider',
                      description: locale == 'ar'
                          ? 'كهربائي، سباك، نجار، وغيرها من الخدمات الميدانية'
                          : 'Electrician, Plumber, Carpenter, etc.',
                      isSelected: _selectedRole == UserRole.freelancer,
                      onTap: () => _switchRole(UserRole.freelancer),
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context,
                      role: UserRole.techService,
                      icon: Icons.computer_outlined,
                      title: locale == 'ar'
                          ? 'مقدم خدمات تقنية'
                          : 'Tech Service Provider',
                      description: locale == 'ar'
                          ? 'مبرمج، مصمم، مونتاج، أو العمل عن بعد'
                          : 'Programmer, Designer, Video Editor, or Remote Worker',
                      isSelected: _selectedRole == UserRole.techService,
                      onTap: () => _switchRole(UserRole.techService),
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context,
                      role: UserRole.privateService,
                      icon: Icons.school_outlined,
                      title: locale == 'ar'
                          ? 'مقدم خدمات خاصة'
                          : 'Private Service Provider',
                      description: locale == 'ar'
                          ? 'مدرس خصوصي، محامي، طباخ، مترجم، مرشد سياحي، وغيرها'
                          : 'Private Tutor, Lawyer, Chef, Translator, Tour Guide, etc.',
                      isSelected: _selectedRole == UserRole.privateService,
                      onTap: () => _switchRole(UserRole.privateService),
                    ),
                    const SizedBox(height: 12),
                    _buildRoleCard(
                      context,
                      role: UserRole.shop,
                      icon: Icons.store_outlined,
                      title: locale == 'ar'
                          ? 'صاحب معرض / متجر'
                          : 'Shop / Gallery Owner',
                      description: locale == 'ar'
                          ? 'أملك متجرًا أو معرضًا وأعرض منتجاتي'
                          : 'I own a store/gallery and display my products',
                      isSelected: _selectedRole == UserRole.shop,
                      onTap: () => _switchRole(UserRole.shop),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ── Client Role (always visible) ──
                  _buildRoleCard(
                    context,
                    role: UserRole.client,
                    icon: Icons.person_search_outlined,
                    title: locale == 'ar' ? 'عميل' : 'Client',
                    description: locale == 'ar'
                        ? 'أبحث عن عمال ومستقلين ومنتجات (للتصفح والتفاعل)'
                        : 'I am looking for workers, freelancers, and products (Browse and Interact)',
                    isSelected: _selectedRole == UserRole.client,
                    onTap: () => _switchRole(UserRole.client),
                  ),
                ],
              ),
      ),

      // Step 2: Basic Info
      Step(
        title:
            Text(locale == 'ar' ? 'المعلومات الأساسية' : 'Basic Information'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              CustomTextField(
                label: _selectedRole == UserRole.shop
                    ? (locale == 'ar' ? 'اسم المتجر' : 'Shop Name')
                    : AppStrings.get(AppStrings.name, locale),
                hint: _selectedRole == UserRole.shop
                    ? (locale == 'ar' ? 'أدخل اسم المتجر' : 'Enter shop name')
                    : (locale == 'ar'
                        ? 'أدخل اسمك الكامل'
                        : 'Enter your full name'),
                controller: _nameController,
                isRequired: true,
                prefixIcon: _selectedRole == UserRole.shop
                    ? Icons.store
                    : Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label:
                    locale == 'ar' ? 'رقم واتساب / الهاتف' : 'WhatsApp / Phone',
                hint: '+249123456789',
                controller: _phoneController,
                isRequired: true,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: _selectedRole == UserRole.shop
                    ? (locale == 'ar' ? 'وصف المتجر' : 'Shop Description')
                    : AppStrings.get(AppStrings.bio, locale),
                hint: _selectedRole == UserRole.shop
                    ? (locale == 'ar'
                        ? 'اكتب وصفًا للمتجر ومنتجاته...'
                        : 'Write a description for your shop...')
                    : (locale == 'ar'
                        ? 'اكتب نبذة مختصرة عنك...'
                        : 'Write a short bio about yourself...'),
                controller: _bioController,
                maxLines: 3,
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: locale == 'ar'
                    ? 'اسم المنطقة / الحي'
                    : 'Neighborhood / Street',
                hint: locale == 'ar'
                    ? 'أدخل اسم الحي لتسهيل البحث عنك...'
                    : 'Enter your neighborhood name...',
                controller: _neighborhoodController,
                prefixIcon: Icons.location_city_outlined,
              ),
              if (_selectedRole == UserRole.freelancer ||
                  _selectedRole == UserRole.techService ||
                  _selectedRole == UserRole.privateService) ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── وصف قصير فوق حقل الإدخال ──
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 8, right: 4, left: 4),
                      child: Text(
                        locale == 'ar'
                            ? 'ما هو المبلغ الذي يرضيك للعمل المتواصل\nلمدة ساعة (بدون تكاليف خارجية)؟'
                            : 'What amount satisfies you for\none hour of continuous work?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                      ),
                    ),
                    // ── حقل الإدخال بتسمية مختصرة ──
                    CustomTextField(
                      label: locale == 'ar' ? 'السعر بالساعة' : 'Hourly Rate',
                      hint: '100',
                      controller: _hourlyRateController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.attach_money,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          locale == 'ar' ? 'SDG/ساعة' : 'SDG/hr',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_selectedRole == UserRole.shop) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerField(
                        label: locale == 'ar' ? 'وقت الفتح' : 'Opening Time',
                        controller: _openingHoursController,
                        icon: Icons.access_time,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePickerField(
                        label: locale == 'ar' ? 'وقت الإغلاق' : 'Closing Time',
                        controller: _closingHoursController,
                        icon: Icons.access_time_filled,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),

      // Step 3: Location
      Step(
        title: Text(locale == 'ar' ? 'الموقع' : 'Location'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedRole == UserRole.techService ||
                _selectedRole == UserRole.client)
              Container(
                margin: const EdgeInsets.only(bottom: 16, top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale == 'ar'
                            ? 'تحديد الموقع اختياري لحسابك، يمكنك تجاوزه إذا أردت.'
                            : 'Setting location is optional for your account, you can skip it if you want.',
                        style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isDetectingLocation ? null : _fetchCurrentLocation,
                icon: _isDetectingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_isDetectingLocation
                    ? (locale == 'ar' ? 'جاري تحديد الموقع...' : 'Detecting...')
                    : (locale == 'ar'
                        ? 'تحديد موقعي التلقائي'
                        : 'Auto Detect My Location')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                ),
              ),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                    child: Text(_locationError!,
                        style: const TextStyle(color: AppColors.error))),
              ),
            const SizedBox(height: 24),
            Text(
              locale == 'ar' ? 'الولاية' : 'State',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedState,
              decoration: InputDecoration(
                hintText: locale == 'ar' ? 'اختر الولاية' : 'Select state',
                prefixIcon: const Icon(Icons.location_city),
              ),
              items: SudanLocations.states
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(SudanLocations.getStateName(s, locale))))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedState = v;
                  _selectedLocality = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedState != null) ...[
              Text(
                locale == 'ar' ? 'المحلية' : 'Locality',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocality,
                decoration: InputDecoration(
                  hintText: locale == 'ar' ? 'اختر المحلية' : 'Select locality',
                  prefixIcon: const Icon(Icons.location_on),
                ),
                items: SudanLocations.getLocalities(_selectedState!)
                    .map((l) => DropdownMenuItem(
                        value: l,
                        child: Text(SudanLocations.getLocalityName(l, locale))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLocality = v),
              ),
            ],
          ],
        ),
      ),
    ];

    // Step 4: Work Categories (for freelancers) or Shop Category (for shops) or Awareness (for clients)
    if (_selectedRole == UserRole.freelancer ||
        _selectedRole == UserRole.techService ||
        _selectedRole == UserRole.privateService) {
      steps.add(
        Step(
          title: Text(locale == 'ar' ? 'مجالات العمل' : 'Work Fields'),
          isActive: _currentStep >= 3,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                locale == 'ar' ? 'اختر مجالات عملك' : 'Choose your work fields',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: JobCategory.values.where((category) {
                  if (category == JobCategory.other) return false;
                  if (_selectedRole == UserRole.techService) {
                    return [
                      JobCategory.webDevelopment,
                      JobCategory.mobileDevelopment,
                      JobCategory.design,
                      JobCategory.writing,
                      JobCategory.translation,
                      JobCategory.marketing,
                      JobCategory.dataEntry,
                      JobCategory.videoEditing,
                      JobCategory.photography,
                      JobCategory.tutoring,
                      JobCategory.teaching
                    ].contains(category);
                  } else if (_selectedRole == UserRole.privateService) {
                    return [
                      JobCategory.privateTutoring,
                      JobCategory.teachingConsultant,
                      JobCategory.eventCatering,
                      JobCategory.baker,
                      JobCategory.pastryChef,
                      JobCategory.waiter,
                      JobCategory.clinicReception,
                      JobCategory.appointmentBooking,
                      JobCategory.clinicInquiry,
                      JobCategory.lawyer,
                      JobCategory.chef,
                      JobCategory.translator,
                      JobCategory.tourGuide,
                      JobCategory.cooking,
                    ].contains(category);
                  } else {
                    return ![
                      JobCategory.webDevelopment,
                      JobCategory.mobileDevelopment,
                      JobCategory.design,
                      JobCategory.writing,
                      JobCategory.translation,
                      JobCategory.marketing,
                      JobCategory.dataEntry,
                      JobCategory.videoEditing,
                      JobCategory.photography,
                      JobCategory.tutoring,
                      JobCategory.teaching,
                      JobCategory.privateTutoring,
                      JobCategory.teachingConsultant,
                      JobCategory.eventCatering,
                      JobCategory.baker,
                      JobCategory.pastryChef,
                      JobCategory.waiter,
                      JobCategory.clinicReception,
                      JobCategory.appointmentBooking,
                      JobCategory.clinicInquiry,
                      JobCategory.lawyer,
                      JobCategory.chef,
                      JobCategory.translator,
                    ].contains(category);
                  }
                }).map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  final job = JobModel(
                    id: '',
                    clientId: '',
                    clientName: '',
                    title: '',
                    description: '',
                    category: category,
                    budgetMin: 0,
                    budgetMax: 0,
                    deadline: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  return FilterChip(
                    label: Text(job.getCategoryDisplayName(locale)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        // "أخرى" doesn't count toward the 2-category limit
                        final totalSelected = _selectedCategories
                                .where((c) => c != JobCategory.other)
                                .length +
                            _customJobTitles.length;
                        if (category != JobCategory.other &&
                            totalSelected >= 2) {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(locale == 'ar'
                                  ? 'عذراً، يمكنك اختيار مسميين وظيفيين كحد أقصى'
                                  : 'Sorry, you can select up to 2 categories'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _selectedCategories.add(category);
                        });
                      } else {
                        setState(() {
                          _selectedCategories.remove(category);
                          // If deselecting "أخرى", clear custom titles
                          if (category == JobCategory.other) {
                            _customJobTitles.clear();
                            _customSkillController.clear();
                          }
                        });
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),

              // ── Custom job titles display ──
              if (_customJobTitles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  locale == 'ar' ? 'المسميات المخصصة:' : 'Custom titles:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customJobTitles.map((title) {
                    return Chip(
                      label: Text(title),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _customJobTitles.remove(title);
                          if (_customJobTitles.isEmpty) {
                            _selectedCategories.remove(JobCategory.other);
                          }
                        });
                      },
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      deleteIconColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],

              // ── Add custom job title button ──
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddCustomJobTitleDialog(locale),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(
                    locale == 'ar'
                        ? 'أضف مسمى وظيفي مخصص'
                        : 'Add custom job title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedRole == UserRole.shop) {
      steps.add(
        Step(
          title: Text(locale == 'ar' ? 'تصنيف المتجر' : 'Shop Category'),
          isActive: _currentStep >= 3,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                locale == 'ar'
                    ? 'اختر تصنيف متجرك'
                    : 'Choose your shop category',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ShopCategory.values.map((category) {
                  final isSelected = _selectedShopCategory == category;
                  return FilterChip(
                    label: Text(_getShopCategoryName(category, locale)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedShopCategory = selected ? category : null;
                      });
                    },
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.secondary,
                  );
                }).toList(),
              ),

              // ── Custom shop types display ──
              if (_customJobTitles.isNotEmpty &&
                  _selectedRole == UserRole.shop) ...[
                const SizedBox(height: 16),
                Text(
                  locale == 'ar' ? 'النوع المخصص:' : 'Custom type:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customJobTitles.map((title) {
                    return Chip(
                      label: Text(title),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _customJobTitles.remove(title);
                          if (_customJobTitles.isEmpty) {
                            _selectedShopCategory = null;
                          }
                        });
                      },
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      deleteIconColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],

              // ── Add custom type button ──
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddCustomJobTitleDialog(locale),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(
                    locale == 'ar'
                        ? 'أضف نوع متجر مخصص'
                        : 'Add custom shop type',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Client Step 4: Interests
      steps.add(
        Step(
          title: Text(locale == 'ar' ? 'اهتماماتك' : 'Your Interests'),
          isActive: _currentStep >= 3,
          state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Location reminder
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.teal, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        locale == 'ar'
                            ? 'تأكد من إضافة موقعك في الخطوة السابقة لنوصلك بأقرب مقدمي الخدمات في منطقتك!'
                            : 'Make sure to add your location in the previous step so we can connect you with the nearest service providers in your area!',
                        style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              // Shop interests
              Text(
                locale == 'ar'
                    ? '🏪 أنواع المتاجر التي تهمك'
                    : '🏪 Shop types you are interested in',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                locale == 'ar'
                    ? 'سنعرض لك هذه الأنواع أولاً في قائمة المتاجر'
                    : 'We will show these types first in the shops list',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ShopCategory.values.map((cat) {
                  final isSelected = _selectedShopInterests.contains(cat);
                  return FilterChip(
                    label: Text(_getShopCategoryName(cat, locale)),
                    selected: isSelected,
                    onSelected: (val) => setState(() {
                      val
                          ? _selectedShopInterests.add(cat)
                          : _selectedShopInterests.remove(cat);
                    }),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.secondary,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Service interests
              Text(
                locale == 'ar'
                    ? '🔧 الخدمات التي تحتاجها'
                    : '🔧 Services you need',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                locale == 'ar'
                    ? 'سنُظهر لك مقدمي هذه الخدمات في الواجهة الرئيسية'
                    : 'We will highlight providers of these services on the main screen',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <JobCategory>[
                  JobCategory.electrical,
                  JobCategory.plumbing,
                  JobCategory.carpentry,
                  JobCategory.painting,
                  JobCategory.cleaning,
                  JobCategory.cooking,
                  JobCategory.webDevelopment,
                  JobCategory.mobileDevelopment,
                  JobCategory.design,
                  JobCategory.translation,
                  JobCategory.marketing,
                  JobCategory.videoEditing,
                  JobCategory.photography,
                  JobCategory.privateTutoring,
                  JobCategory.lawyer,
                  JobCategory.carMaintenance,
                ].map((cat) {
                  final isSelected = _selectedServiceInterests.contains(cat);
                  final job = JobModel(
                    id: '',
                    clientId: '',
                    clientName: '',
                    title: '',
                    description: '',
                    category: cat,
                    budgetMin: 0,
                    budgetMax: 0,
                    deadline: DateTime.now(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  return FilterChip(
                    label: Text(job.getCategoryDisplayName(locale)),
                    selected: isSelected,
                    onSelected: (val) => setState(() {
                      val
                          ? _selectedServiceInterests.add(cat)
                          : _selectedServiceInterests.remove(cat);
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      // Client Step 5: Awareness
      steps.add(
        Step(
          title: Text(locale == 'ar'
              ? 'معاً نبني المستقبل'
              : 'Together we build the future'),
          isActive: _currentStep >= 4,
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 10),
                    ],
                  ),
                  child: const Icon(Icons.volunteer_activism_outlined,
                      size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  locale == 'ar'
                      ? 'شكراً لدعمك!'
                      : 'Thank you for your support!',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  locale == 'ar'
                      ? 'نحن نقدر دعمك لهذا الجيل من المبدعين والحرفيين.\n\nمن أجل مجتمع آمن، نرجو منك الإبلاغ فوراً عن أي صفحات أو عروض مشبوهة.'
                      : 'We appreciate your support for this generation of creators and craftsmen.\n\nFor a safe community, please report any suspicious pages or offers immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: Colors.grey[800]),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    // Step 5: Verification (for service providers only)
    if (_isServiceProvider) {
      steps.add(
        Step(
          title: Text(
              locale == 'ar' ? 'التوثيق (اختياري)' : 'Verification (Optional)'),
          isActive: _currentStep >= 4,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Info about verification
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 48, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      locale == 'ar'
                          ? 'وثّق حسابك لزيادة الثقة'
                          : 'Verify your account to increase trust',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locale == 'ar'
                          ? 'يمكنك رفع صورتك الشخصية وتوثيق هويتك من الإعدادات بعد إكمال إنشاء الحساب للحصول على شعار التصافح 🤝 بجانب اسمك.'
                          : 'You can upload your profile photo and verify your identity from Settings after creating your account to get the handshake verification symbol 🤝 next to your name.',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (widget.existingUser != null) ...[
                const SizedBox(height: 16),
                // ID Verification Button (editing mode only)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const IdentityVerificationScreen()),
                      );
                    },
                    icon: const Icon(Icons.verified_user),
                    label: Text(locale == 'ar'
                        ? 'الانتقال لصفحة التوثيق'
                        : 'Go to Verification Page'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return steps;
  }

  String _getShopCategoryName(ShopCategory category, String locale) {
    final names = {
      'ar': {
        ShopCategory.electronics: 'إلكترونيات',
        ShopCategory.clothing: 'ملابس',
        ShopCategory.furniture: 'أثاث',
        ShopCategory.food: 'مواد غذائية',
        ShopCategory.restaurant: 'مطعم',
        ShopCategory.supermarket: 'سوبرماركت',
        ShopCategory.pharmacy: 'صيدلية',
        ShopCategory.beauty: 'تجميل ومستحضرات',
        ShopCategory.automotive: 'قطع غيار سيارات',
        ShopCategory.building: 'مواد بناء',
        ShopCategory.jewelry: 'مجوهرات',
        ShopCategory.mobile: 'جوالات وإكسسوارات',
        ShopCategory.bookstore: 'مكتبة',
        ShopCategory.sports: 'رياضة',
        ShopCategory.toys: 'ألعاب أطفال',
        ShopCategory.home: 'أدوات منزلية',
        ShopCategory.other: 'أخرى',
      },
      'en': {
        ShopCategory.electronics: 'Electronics',
        ShopCategory.clothing: 'Clothing',
        ShopCategory.furniture: 'Furniture',
        ShopCategory.food: 'Food & Grocery',
        ShopCategory.restaurant: 'Restaurant',
        ShopCategory.supermarket: 'Supermarket',
        ShopCategory.pharmacy: 'Pharmacy',
        ShopCategory.beauty: 'Beauty & Cosmetics',
        ShopCategory.automotive: 'Auto Parts',
        ShopCategory.building: 'Building Materials',
        ShopCategory.jewelry: 'Jewelry',
        ShopCategory.mobile: 'Mobile & Accessories',
        ShopCategory.bookstore: 'Bookstore',
        ShopCategory.sports: 'Sports',
        ShopCategory.toys: 'Toys & Kids',
        ShopCategory.home: 'Home Appliances',
        ShopCategory.other: 'Other',
      },
    };
    return names[locale]?[category] ?? category.name;
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () => _showTimePicker(controller),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          controller.text.isNotEmpty
              ? _formatTimeDisplay(
                  controller.text, Localizations.localeOf(context).languageCode)
              : (Localizations.localeOf(context).languageCode == 'ar'
                  ? 'اختر الوقت'
                  : 'Select Time'),
          style: TextStyle(
            color: controller.text.isNotEmpty ? null : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _showTimePicker(TextEditingController controller) async {
    // Parse existing value or default to 9:00
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (controller.text.isNotEmpty) {
      try {
        final parts = controller.text.split(':');
        initial =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Store in HH:mm 24-hour format for reliable parsing
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String _formatTimeDisplay(String time, String locale) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final am = locale == 'ar' ? 'ص' : 'AM';
      final pm = locale == 'ar' ? 'م' : 'PM';
      final period = hour >= 12 ? pm : am;
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $period';
    } catch (_) {
      return time;
    }
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required UserRole role,
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    bool comingSoon = false,
  }) {
    final color =
        role == UserRole.shop ? AppColors.secondary : AppColors.primary;

    return InkWell(
      onTap: comingSoon
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch_outlined,
                          size: 48, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text('قريباً',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'هذا النوع من الحسابات سيكون متاحاً قريباً!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              );
            }
          : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: comingSoon ? 0.55 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: isSelected ? color : null,
                                ),
                          ),
                        ),
                        if (comingSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('قريباً',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
