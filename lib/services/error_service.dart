import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logError(dynamic exception, StackTrace? stack,
      {String? context}) async {
    // Log to console always
    debugPrint('ErrorService: Caught error: $exception');
    if (stack != null) debugPrint('Stack: $stack');

    // Log to Firestore even in debug for this version as requested
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String os = Platform.operatingSystem;
      final String osVersion = Platform.operatingSystemVersion;

      await _firestore.collection('system_errors').add({
        'exception': exception.toString(),
        'stackTrace': stack?.toString(),
        'context': context ?? 'General',
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'platform': os,
        'osVersion': osVersion,
        'isFatal': true, // Assuming runZonedGuarded catches fatal-ish errors
      });
    } catch (e) {
      // Fallback if logging fails
      debugPrint('ErrorService: Failed to log error to Firestore: $e');
    }
  }

  // Log non-fatal warning/error
  Future<void> logWarning(String message, {String? context}) async {
    debugPrint('ErrorService [Warning]: $message');
    try {
      await _firestore.collection('system_errors').add({
        'exception': message,
        'context': context ?? 'Warning',
        'timestamp': FieldValue.serverTimestamp(),
        'isFatal': false,
      });
    } catch (_) {}
  }
}
