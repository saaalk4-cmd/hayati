import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notification_actions.dart';
import 'data/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // التطبيق للموبايل فقط وبالطول
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('ar');

  var firebaseReady = false;
  if (AppConfig.hasFirebase) {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      firebaseReadyProvider.overrideWithValue(firebaseReady),
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
  );
  // أزرار الإشعارات وهو مفتوح بتكتب في نفس البيانات اللي الشاشات بتعرضها
  NotificationActions.appContainer = container;

  runApp(
    UncontrolledProviderScope(container: container, child: const HayatiApp()),
  );
}
