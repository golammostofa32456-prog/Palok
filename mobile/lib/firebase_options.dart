import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'PALOK web platform is not configured yet.',
      );
    }

    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAwMRN9t_T_FlkzR3h-NHJdgS1-FiJZbbik',
    appId: '1:435380341116:android:c9e7bf67afed6242c87cf9',
    messagingSenderId: '435380341116',
    projectId: 'palok-a2783',
    storageBucket: 'palok-a2783.firebasestorage.app',
  );
}
