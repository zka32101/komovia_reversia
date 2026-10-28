// File generated normally by the FlutterFire CLI (`flutterfire configure`).
//
// PLACEHOLDER VALUES ONLY. This project has no real Firebase project wired
// up yet. Run `flutterfire configure` against your own Firebase project to
// replace this file with real credentials before shipping.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_WEB_APP_ID',
    messagingSenderId: '000000000000',
    projectId: 'komovia-reversia-placeholder',
    authDomain: 'komovia-reversia-placeholder.firebaseapp.com',
    storageBucket: 'komovia-reversia-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_ANDROID_API_KEY',
    appId: 'PLACEHOLDER_ANDROID_APP_ID',
    messagingSenderId: '000000000000',
    projectId: 'komovia-reversia-placeholder',
    storageBucket: 'komovia-reversia-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_IOS_API_KEY',
    appId: 'PLACEHOLDER_IOS_APP_ID',
    messagingSenderId: '000000000000',
    projectId: 'komovia-reversia-placeholder',
    storageBucket: 'komovia-reversia-placeholder.appspot.com',
    iosBundleId: 'com.komovia.komoviaReversia',
  );
}
