import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'backend.dart';
import 'firebase_backend.dart';
import 'local_backend.dart';

/// Picks the backend once, when the app starts.
///
/// * Default: use Firebase if it is configured (google-services.json is in
///   android/app/), otherwise fall back to local storage on this device.
/// * Force one with --dart-define=BACKEND=local or --dart-define=BACKEND=firebase.
Future<Backend> selectBackend() async {
  const forced = String.fromEnvironment('BACKEND');

  if (forced != 'local') {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      return FirebaseBackend();
    } catch (e) {
      if (forced == 'firebase') rethrow;
      debugPrint('Firebase not configured, using local storage. ($e)');
    }
  }
  return LocalBackend.create();
}
