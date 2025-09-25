
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] -
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );

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
        return windows;
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
    apiKey: 'AIzaSyCTNhbFQhKBgzR62tbb6nUUEHybCM_2ruE',
    appId: '1:1028480689886:web:81fc27f1751af57721844f',
    messagingSenderId: '1028480689886',
    projectId: 'whsmedicine',
    authDomain: 'whsmedicine.firebaseapp.com',
    storageBucket: 'whsmedicine.firebasestorage.app',
    measurementId: 'G-RZWWK4TYN8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCkAQaYc213TRQoDAdPaFmTkMU242350A',
    appId: '1:1028480689886:android:a20a3a3e2d14c59021844f',
    messagingSenderId: '1028480689886',
    projectId: 'whsmedicine',
    storageBucket: 'whsmedicine.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUmkUxkqVQLWMYDxufxE2bVrhFJRKDUcU',
    appId: '1:1028480689886:ios:d0c2cc9ed4afd29e21844f',
    messagingSenderId: '1028480689886',
    projectId: 'whsmedicine',
    storageBucket: 'whsmedicine.firebasestorage.app',
    iosBundleId: 'com.example.rkive',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCUmkUxkqVQLWMYDxufxE2bVrhFJRKDUcU',
    appId: '1:1028480689886:ios:d0c2cc9ed4afd29e21844f',
    messagingSenderId: '1028480689886',
    projectId: 'whsmedicine',
    storageBucket: 'whsmedicine.firebasestorage.app',
    iosBundleId: 'com.example.rkive',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCTNhbFQhKBgzR62tbb6nUUEHybCM_2ruE',
    appId: '1:1028480689886:web:91ff370d247ced7121844f',
    messagingSenderId: '1028480689886',
    projectId: 'whsmedicine',
    authDomain: 'whsmedicine.firebaseapp.com',
    storageBucket: 'whsmedicine.firebasestorage.app',
    measurementId: 'G-Y7SBH36KYC',
  );
}
