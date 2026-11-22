import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/session.dart';
import 'data/settings.dart';
import 'features/lock/lock_screen.dart';
import 'features/lock/lock_service.dart';

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
    if (state == AppLifecycleState.resumed) lock.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final locked = ref.watch(lockProvider.select((s) => s.locked));
    final session = ref.watch(sessionProvider);

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // شاشة القفل فوق كل حاجة لما يكون فيه مستخدم داخل
        if (locked && session is! SignedOut) return const LockScreen();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
