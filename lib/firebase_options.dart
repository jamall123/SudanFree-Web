import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCGdUP0ZJhFlXfmTSP4S-AvM5WMCOdih4A',
    appId: '1:233114260:web:de4ee3967ea04073620281',
    messagingSenderId: '233114260',
    projectId: 'sudanfree-d04fc',
    authDomain: 'sudanfree-d04fc.firebaseapp.com',
    storageBucket: 'sudanfree-d04fc.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGdUP0ZJhFlXfmTSP4S-AvM5WMCOdih4A',
    appId: '1:233114260:android:3da75a538ebd6627620281',
    messagingSenderId: '233114260',
    projectId: 'sudanfree-d04fc',
    storageBucket: 'sudanfree-d04fc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGdUP0ZJhFlXfmTSP4S-AvM5WMCOdih4A',
    appId: '1:233114260:ios:someid', // Dummy for now
    messagingSenderId: '233114260',
    projectId: 'sudanfree-d04fc',
    storageBucket: 'sudanfree-d04fc.firebasestorage.app',
    iosBundleId: 'com.sudanfree.sudan_free',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCGdUP0ZJhFlXfmTSP4S-AvM5WMCOdih4A',
    appId: '1:233114260:ios:someid', // Dummy for now
    messagingSenderId: '233114260',
    projectId: 'sudanfree-d04fc',
    storageBucket: 'sudanfree-d04fc.firebasestorage.app',
    iosBundleId: 'com.sudanfree.sudan_free.RunnerTests',
  );
}
