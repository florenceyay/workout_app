import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZaw6C9GPrZXKe8jnRo1TX0-_2bf3zZvc',
    appId: '1:1049301786744:android:85d2d6d798d22452788d8d',
    messagingSenderId: '1049301786744',
    projectId: 'workout-app-d466d',
    storageBucket: 'workout-app-d466d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC1lhBx-3ntOdSb3qKk3Z_52CynH_VDfpE',
    appId: '1:1049301786744:ios:9f727cf0f467d9f5788d8d',
    messagingSenderId: '1049301786744',
    projectId: 'workout-app-d466d',
    storageBucket: 'workout-app-d466d.firebasestorage.app',
    iosClientId: '1049301786744-nhff7c77snplll4dlhh9j8e64g1mtuub.apps.googleusercontent.com',
    iosBundleId: 'com.florenceyay.workoutApp',
  );
}
