import 'package:firebase_core/firebase_core.dart';

/// إعدادات Firebase تُمرَّر وقت البناء عبر --dart-define
/// (لا توجد أي مفاتيح داخل الكود). راجع docs/SETUP.md
class AppConfig {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Web client ID من Firebase (مطلوب لتسجيل الدخول بجوجل)
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// منطقة Cloud Functions
  static const functionsRegion =
      String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'europe-west1');

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty;

  static bool get hasGoogleSignIn => googleServerClientId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseSenderId,
        projectId: firebaseProjectId,
        storageBucket:
            firebaseStorageBucket == '' ? null : firebaseStorageBucket,
      );
}
