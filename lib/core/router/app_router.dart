import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/session.dart';
import '../../features/assistant/assistant_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/habits/habit_detail_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/journal/journal_editor_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/placeholder/coming_soon_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/worship/adhkar_screen.dart';
import '../../features/worship/prayer_settings_screen.dart';
import '../../features/worship/qibla_screen.dart';
import '../../features/worship/quran_screen.dart';
import '../../features/worship/worship_screen.dart';

/// يخلي GoRouter يعيد تقييم الـ redirect لما الجلسة تتغير
class _SessionListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable();
  ref.listen(sessionProvider, (_, _) => listenable.ping());
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final atLogin = state.matchedLocation == '/login';
      if (session is SessionLoading) return null;
      if (session is SignedOut) return atLogin ? null : '/login';
      if (atLogin) return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/assistant', builder: (_, _) => const AssistantScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/worship',
                builder: (_, _) => const WorshipScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const PrayerSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'qibla',
                    builder: (_, _) => const QiblaScreen(),
                  ),
                  GoRoute(
                    path: 'quran',
                    builder: (_, _) => const QuranScreen(),
                  ),
                  GoRoute(
                    path: 'adhkar/:group',
                    builder: (_, state) =>
                        AdhkarScreen(groupId: state.pathParameters['group']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tasks', builder: (_, _) => const TasksScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/money', builder: (_, _) => const MoneyScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'habits',
                    builder: (_, _) => const HabitsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => HabitDetailScreen(
                          habitId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'journal',
                    builder: (_, _) => const JournalScreen(),
                    routes: [
                      GoRoute(
                        path: ':day',
                        builder: (_, state) => JournalEditorScreen(
                          day: state.pathParameters['day']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'occasions',
                    builder: (_, _) => const ComingSoonScreen(
                      title: 'مناسباتي وأهلي',
                      icon: Icons.cake,
                      features: [
                        'أعياد ميلاد ومناسبات بتذكير',
                        'تذكير بصلة الرحم',
                      ],
                    ),
                  ),
                  GoRoute(
                    path: 'stats',
                    builder: (_, _) => const ComingSoonScreen(
                      title: 'إحصائياتي',
                      icon: Icons.insights,
                      features: ['ملخص أسبوعي وشهري', 'تقرير تقدر تشاركه'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
