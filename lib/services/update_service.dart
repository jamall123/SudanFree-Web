import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../core/constants/app_colors.dart';

class UpdateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _updateCheckInProgress = false;
  static DateTime? _lastUpdateCheckTime;
  static const Duration _updateCheckCooldown = Duration(minutes: 30);

  /// Check for app updates with rate limiting to prevent excessive Firebase calls
  static Future<void> checkForUpdate(BuildContext context) async {
    // Rate limit: don't check more than once per 30 minutes
    if (_updateCheckInProgress) return;
    if (_lastUpdateCheckTime != null &&
        DateTime.now().difference(_lastUpdateCheckTime!) <
            _updateCheckCooldown) {
      return;
    }

    _updateCheckInProgress = true;
    try {
      // Fetch minimum required version from Firestore
      final doc = await _firestore.collection('app_config').doc('main').get();
      if (!doc.exists) {
        debugPrint('UpdateService: app_config document not found');
        return;
      }

      final data = doc.data();
      if (data == null) {
        debugPrint('UpdateService: app_config data is null');
        return;
      }

      final minVersion = data['min_version'] as String?;
      final storeUrl = data['store_url'] as String?;

      if (minVersion == null || storeUrl == null) {
        debugPrint(
          'UpdateService: Missing version or URL in config. minVersion=$minVersion, storeUrl=$storeUrl',
        );
        return;
      }

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isUpdateRequired(currentVersion, minVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, storeUrl);
        }
      }

      _lastUpdateCheckTime = DateTime.now();
    } catch (e, stackTrace) {
      debugPrint('UpdateService check error: $e\n$stackTrace');
      // Silently fail - don't interrupt user experience
    } finally {
      _updateCheckInProgress = false;
    }
  }

  static bool _isUpdateRequired(String currentVersion, String minVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final minParts = minVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < minParts.length; i++) {
      if (i >= currentParts.length) return true; // Current is shorter
      if (currentParts[i] < minParts[i]) return true; // Current is older
      if (currentParts[i] > minParts[i]) return false; // Current is newer
    }
    return false; // Versions are equal
  }

  static void _showUpdateDialog(BuildContext context, String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force update
      builder: (context) {
        final isArabic = context.read<LocaleProvider>().isArabic;
        return PopScope(
          canPop: false, // Prevent back button
          child: AlertDialog(
            title: Text(
              isArabic ? 'تحديث إجباري' : 'Update Required',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            content: Text(
              isArabic
                  ? 'نسختك الحالية قديمة جداً. يرجى تحديث التطبيق للمتابعة واستخدام أحدث الميزات بأمان.'
                  : 'Your app version is too old. Please update to continue using the app safely.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  try {
                    final uri = Uri.parse(storeUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint('UpdateService: Cannot launch URL: $storeUrl');
                      if (context.mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'لا يمكن فتح المتجر. يرجى محاولة يدويًا.'
                                  : 'Cannot open store. Please try manually.',
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('UpdateService: Error launching URL: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isArabic ? 'تحديث الآن' : 'Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }
}
