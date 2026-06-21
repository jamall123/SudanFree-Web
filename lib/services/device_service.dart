import 'package:universal_io/io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages device identification and ban checking.
/// Uses Android ID (unique per device, resets on factory reset).
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final _deviceInfo = DeviceInfoPlugin();
  final _firestore = FirebaseFirestore.instance;

  String? _cachedDeviceId;

  /// Gets a unique device identifier.
  /// On Android: uses androidId.
  /// On iOS: uses identifierForVendor.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id; // Android hardware ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        _cachedDeviceId = 'unknown_platform';
      }
    } catch (e) {
      debugPrint('DeviceService: Error getting device ID: $e');
      _cachedDeviceId = 'unknown_error';
    }

    return _cachedDeviceId!;
  }

  /// Check if the current device is banned.
  /// Returns the ban reason if banned, null otherwise.
  Future<String?> checkDeviceBan() async {
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore.collection('banned_devices').doc(deviceId).get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['reason'] as String? ?? 'تم حظر هذا الجهاز';
      }
      return null; // Not banned
    } catch (e) {
      debugPrint('DeviceService: Error checking device ban: $e');
      return null; // Allow access on error (fail-open)
    }
  }

  /// Save the device ID to a user's Firestore document.
  Future<void> saveDeviceIdToUser(String userId) async {
    try {
      final deviceId = await getDeviceId();
      await _firestore.collection('users').doc(userId).update({
        'deviceId': deviceId,
      });
      debugPrint('DeviceService: Saved device ID for user $userId');
    } catch (e) {
      debugPrint('DeviceService: Error saving device ID: $e');
    }
  }
}
