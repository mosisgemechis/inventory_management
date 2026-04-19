import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      case TargetPlatform.windows: return windows;
      default: throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBLuXiaD-i1pQdDelNkeuFeAjYD9Yt4Oho',
    authDomain: 'smart-inventory-c5d64.firebaseapp.com',
    projectId: 'smart-inventory-c5d64',
    storageBucket: 'smart-inventory-c5d64.firebasestorage.app',
    messagingSenderId: '948412189680',
    appId: '1:948412189680:web:35955fd1664a325582ab35',
    measurementId: 'G-9CH6KEQJ25',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBLuXiaD-i1pQdDelNkeuFeAjYD9Yt4Oho',
    appId: '1:948412189680:android:650bc78866753177',
    messagingSenderId: '948412189680',
    projectId: 'smart-inventory-c5d64',
    storageBucket: 'smart-inventory-c5d64.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBLuXiaD-i1pQdDelNkeuFeAjYD9Yt4Oho',
    appId: '1:948412189680:ios:86053fdb66753178',
    messagingSenderId: '948412189680',
    projectId: 'smart-inventory-c5d64',
    storageBucket: 'smart-inventory-c5d64.firebasestorage.app',
    iosBundleId: 'com.pharmacy.mgmt',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBLuXiaD-i1pQdDelNkeuFeAjYD9Yt4Oho',
    appId: '1:948412189680:web:35955fd1664a325582ab35',
    messagingSenderId: '948412189680',
    projectId: 'smart-inventory-c5d64',
    storageBucket: 'smart-inventory-c5d64.firebasestorage.app',
  );
}
