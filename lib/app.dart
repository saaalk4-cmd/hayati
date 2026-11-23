import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/hayati_background.dart';
import 'data/session.dart';
import 'data/settings.dart';
import 'features/lock/lock_screen.dart';
import 'features/family/family_models.dart';
import 'features/family/occasion_reminders.dart';
import 'features/habits/habit_reminders.dart';
import 'features/habits/habits_repository.dart';
import 'features/lock/lock_service.dart';
import 'features/widget/home_widget_sync.dart';
import 'features/money/money_models.dart';
import 'features/money/money_repository.dart';
import 'features/money/money_screen.dart';
import 'features/reminders/smart_reminders.dart';
import 'features/tasks/task_reminders.dart';
import 'data/task.dart';
import 'data/user_store.dart';
import 'data/tasks_repository.dart';
import 'features/habits/habit.dart';
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
    // المصروفات الثابتة: تتسجل لوحدها لما معادها ييجي
    ref.listenManual(moneySettingsProvider, (_, next) {
      final v = next.value;
      if (v == null) return;
      applyRecurring(
        ref.read(userStoreProvider),
        ref.read(transactionsRepositoryProvider),
        v,
        DateTime.now(),
      );
    }, fireImmediately: true);
    // ويدجت الشاشة الرئيسية بيتحدث مع أي تغيير في المواقيت أو المهام أو العادات
    ref.listenManual(
      widgetPayloadProvider,
      (_, next) => HomeWidgetSync.push(next),
      fireImmediately: true,
    );
    // ملخص الصبح: بيتحسب من البيانات الحالية ويتجدول للصبح الجاي
    ref.listenManual(_morningInputsProvider, (_, next) {
      SmartReminders.syncMorning(
        settings: ref.read(reminderSettingsProvider),
        tasks: next.$1,
        habits: next.$2,
        spentMonth: next.$3,
        budget: next.$4,
      );
    }, fireImmediately: true);
    // جدولة إشعارات الأذان للأيام الجاية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdhanNotifications.instance.reschedule(ref.read(prayerSettingsProvider));
      SmartReminders.syncFasting(ref.read(reminderSettingsProvider));
      SmartReminders.syncWeeklyReview(ref.read(reminderSettingsProvider));
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
    final palette = ref.watch(paletteProvider);
    final textScale = ref.watch(textScaleProvider);
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
    ref.listen(reminderSettingsProvider, (_, next) {
      SmartReminders.syncFasting(next);
      SmartReminders.syncWeeklyReview(next);
    });

    return MaterialApp.router(
      title: 'حياتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromPalette(palette),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        // حجم الخط من الإعدادات (فوق إعداد الموبايل نفسه)
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(context).scale(1) * textScale,
          ),
        ),
        child: Builder(
          builder: (context) {
            final Widget content;
            if (session is SessionLoading) {
              content = const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else if (locked && session is! SignedOut) {
              // شاشة القفل فوق كل حاجة لما يكون فيه مستخدم داخل
              content = const LockScreen();
            } else {
              // الشاشات العادية بترسم خلفيتها من خلال الانتقال (HayatiPageTransitionsBuilder)
              return child ?? const SizedBox.shrink();
            }
            return HayatiBackground(child: content);
          },
        ),
      ),
    );
  }
}

/// مدخلات ملخص الصبح: المهام، العادات، مصروف الشهر، الميزانية
final _morningInputsProvider =
    Provider<(List<HayatiTask>, List<Habit>, double, double?)>((ref) {
      final month = monthKey(DateTime.now());
      return (
        ref.watch(tasksProvider).value ?? const [],
        ref.watch(habitsProvider).value ?? const [],
        MonthSummary(
          ref.watch(monthTransactionsProvider(month)).value ?? const [],
        ).spent,
        ref.watch(moneySettingsProvider).value?.monthlyBudget,
      );
    });
