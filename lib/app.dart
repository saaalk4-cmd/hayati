import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/session.dart';
import 'data/settings.dart';
import 'features/lock/lock_screen.dart';
import 'features/family/family_models.dart';
import 'features/family/occasion_reminders.dart';
import 'features/habits/habit_reminders.dart';
import 'features/habits/habits_repository.dart';
import 'features/lock/lock_service.dart';
import 'features/tasks/task_reminders.dart';
import 'data/tasks_repository.dart';
import 'features/worship/adhan_notifications.dart';
import 'features/worship/prayer_settings.dart';

class HayatiApp extends ConsumerStatefulWidget {
  const HayatiApp({super.key});

  @override
  ConsumerState<HayatiApp> createState() => _HayatiAppState();
}

class _HayatiAppState extends ConsumerState<HayatiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // جدولة إشعارات الأذان للأيام الجاية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdhanNotifications.instance.reschedule(ref.read(prayerSettingsProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(lockProvider.notifier);
    if (state == AppLifecycleState.paused) lock.onPaused();
    if (state == AppLifecycleState.resumed) {
      lock.onResumed();
      AdhanNotifications.instance.reschedule(ref.read(prayerSettingsProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final locked = ref.watch(lockProvider.select((s) => s.locked));
    final session = ref.watch(sessionProvider);
    ref.listen(
      prayerSettingsProvider,
      (_, next) => AdhanNotifications.instance.reschedule(next),
    );
    // مزامنة تذكيرات العادات والمهام مع البيانات
    ref.listen(habitsProvider, (_, next) {
      final v = next.value;
      if (v != null) HabitReminders.sync(v);
    });
    ref.listen(occasionsProvider, (_, next) {
      final v = next.value;
      if (v != null) OccasionReminders.sync(v);
    });
    ref.listen(tasksProvider, (_, next) {
      final v = next.value;
      if (v != null) TaskReminders.sync(v);
    });

    return MaterialApp.router(
      title: 'حياتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) {
        if (session is SessionLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // شاشة القفل فوق كل حاجة لما يكون فيه مستخدم داخل
        if (locked && session is! SignedOut) return const LockScreen();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
