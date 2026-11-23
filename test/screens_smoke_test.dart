// بيفتح الشاشات الأساسية في وضع الضيف ويتأكد إن مفيش أي خطأ أو overflow
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/theme/app_theme.dart';
import 'package:hayati/data/session.dart';
import 'package:hayati/features/family/family_screen.dart';
import 'package:hayati/features/habits/habits_screen.dart';
import 'package:hayati/features/focus/focus_screen.dart';
import 'package:hayati/features/calendar/calendar_screen.dart';
import 'package:hayati/features/goals/goals_screen.dart';
import 'package:hayati/features/review/weekly_review_screen.dart';
import 'package:hayati/features/search/global_search.dart';
import 'package:hayati/features/money/money_analytics.dart';
import 'package:hayati/features/journal/journal_screen.dart';
import 'package:hayati/features/money/money_screen.dart';
import 'package:hayati/features/more/more_screen.dart';
import 'package:hayati/features/more/settings_screen.dart';
import 'package:hayati/features/ramadan/ramadan_screen.dart';
import 'package:hayati/features/stats/stats_screen.dart';
import 'package:hayati/features/tasks/tasks_screen.dart';
import 'package:hayati/features/today/today_screen.dart';
import 'package:hayati/features/worship/quran_screen.dart';
import 'package:hayati/features/worship/qada_screen.dart';
import 'package:hayati/features/worship/islamic_occasions_screen.dart';
import 'package:hayati/features/worship/tasbeeh_screen.dart';
import 'package:hayati/features/worship/worship_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    await initializeDateFormatting('ar');
  });

  final screens = <String, Widget>{
    'today': const TodayScreen(),
    'worship': const WorshipScreen(),
    'tasks': const TasksScreen(),
    'money': const MoneyScreen(),
    'habits': const HabitsScreen(),
    'more': const MoreScreen(),
    'settings': const SettingsScreen(),
    'journal': const JournalScreen(),
    'family': const FamilyScreen(),
    'stats': const StatsScreen(),
    'ramadan': const RamadanScreen(),
    'quran': const QuranScreen(),
    'tasbeeh': const TasbeehScreen(),
    'qada': const QadaScreen(),
    'islamic_occasions': const IslamicOccasionsScreen(),
    'focus': const FocusScreen(),
    'calendar': const CalendarScreen(),
    'goals': const GoalsScreen(),
    'review': const WeeklyReviewScreen(),
    'search': const GlobalSearchScreen(),
    'money_analytics': const MoneyAnalyticsScreen(),
  };

  for (final e in screens.entries) {
    for (final dark in [false, true]) {
      testWidgets('${e.key} renders${dark ? ' (dark)' : ''}', (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboarded_v1': true,
          'guest_mode': true,
        });
        final prefs = await SharedPreferences.getInstance();
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWithValue(prefs),
              firebaseReadyProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: e.value,
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
