import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';
import 'dart:ui';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/error_service.dart';
import 'services/network_service.dart';
import 'services/performance_service.dart';
import 'core/utils/app_error_handler.dart';
import 'core/config/image_cache_config.dart';
import 'firebase_options.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Handling background message: ${message.messageId}');
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Configure image caching to prevent OOM
    imageCache.maximumSize = ImageCacheConfig.maxMemoryCacheCount;
    imageCache.maximumSizeBytes = ImageCacheConfig.maxMemoryCacheSizeMB * 1024 * 1024;
    
    // Initialize OneSignal with the current package API
    try {
      await OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '5b1ec6d9-34d2-44ee-b985-d58a598e71d7');
      OneSignal.initialize(oneSignalAppId);
      // Prompt for permission on iOS only
      try {
        await OneSignal.Notifications.requestPermission(true);
      } catch (_) {}
    } catch (e) {
      debugPrint('OneSignal init warning: $e');
    }

    // Initialize network monitoring
    await NetworkService().initialize();

    // Initialize Firebase with performance tracking
    final initTrace = PerformanceService().startTrace('app_startup');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Enable Offline Persistence for Firestore (Do this immediately after Firebase init)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true, 
        cacheSizeBytes: 50 * 1024 * 1024, // 50 MB limit instead of unlimited
      );

      // Setup background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Initialize notifications with a timeout so it doesn't freeze the app if offline
      try {
        final notificationService = NotificationService();
        await notificationService.initialize().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Notification service init timed out or failed (likely offline): $e');
      }
      
      initTrace.putAttribute('status', 'success');
    } catch (e, stack) {
      debugPrint('Firebase initialization error: $e');
      initTrace.putAttribute('status', 'error');
      // Try to log if Firebase initialized partially
      try {
        await ErrorService().logError(e, stack, context: 'FirebaseInit');
      } catch (_) {}
    }
    
    // Initialize cache service
    try {
      final cacheService = CacheService();
      await cacheService.initialize();
    } catch (e, stack) {
      debugPrint('Cache service error: $e');
      ErrorService().logError(e, stack, context: 'CacheServiceInit');
    }

    initTrace.stop();
    
    // Setup global error handling for Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppErrorHandler.log(details.exception, details.stack, context: 'FlutterError');
    };
    
    // Catch asynchronous errors (Flutter 3.3+)
    PlatformDispatcher.instance.onError = (error, stack) {
      AppErrorHandler.log(error, stack, context: 'PlatformDispatcher');
      return true; // prevent default behavior
    };

    // Replace the Red Screen of Death with a custom friendly error UI
    ErrorWidget.builder = (FlutterErrorDetails details) {
      bool inDebug = false;
      assert(() { inDebug = true; return true; }());
      if (inDebug) {
        return ErrorWidget(details.exception);
      }
      return Scaffold(
        body: Center(
          child: Padding(
             padding: const EdgeInsets.all(20),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.error_outline, color: Colors.red, size: 50),
                 const SizedBox(height: 16),
                 const Text(
                   'حدث خطأ غير متوقع',
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   'تم إرسال تقرير بالخطأ إلى فريق الدعم. نعتذر عن الإزعاج.',
                   textAlign: TextAlign.center,
                   style: TextStyle(color: Colors.grey[600]),
                 ),
               ],
             )
          )
        ),
      );
    };
    
    // Setup timeago for Arabic
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    
    runApp(const SudanFreeApp());
  }, (error, stack) {
    // Catch all other asynchronous errors
    debugPrint('Caught global error: $error');
    AppErrorHandler.log(error, stack, context: 'GlobalAsyncError');
  });
}
