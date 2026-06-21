import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class LocaleProvider extends ChangeNotifier {
  final CacheService _cacheService = CacheService();

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  bool get isEnglish => _locale.languageCode == 'en';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    final savedLanguage = _cacheService.getLanguage();

    if (savedLanguage != null) {
      _locale = Locale(savedLanguage);
    } else {
      // No saved language, use system language
      final systemLocale = PlatformDispatcher.instance.locale;
      if (systemLocale.languageCode == 'en') {
        _locale = const Locale('en');
      } else {
        // Default to Arabic for Sudan/any other
        _locale = const Locale('ar');
      }
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _isLoading = true;
    notifyListeners();

    // Short delay to show loading state
    await Future.delayed(const Duration(milliseconds: 150));

    _locale = locale;
    await _cacheService.saveLanguage(locale.languageCode);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    if (_locale.languageCode == 'ar') {
      await setLocale(const Locale('en'));
    } else {
      await setLocale(const Locale('ar'));
    }
  }
}
