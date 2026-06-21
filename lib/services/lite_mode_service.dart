import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LiteModeService extends ChangeNotifier {
  static const String _liteModeKey = 'is_lite_mode';
  bool _isLiteMode = false;

  bool get isLiteMode => _isLiteMode;

  LiteModeService() {
    _loadLiteMode();
  }

  Future<void> _loadLiteMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLiteMode = prefs.getBool(_liteModeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading lite mode: $e');
    }
  }

  Future<void> toggleLiteMode(bool value) async {
    try {
      _isLiteMode = value;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_liteModeKey, value);
    } catch (e) {
      debugPrint('Error saving lite mode: $e');
    }
  }
}
