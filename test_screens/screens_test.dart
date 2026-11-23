// سكريبت لقطات شاشة (مش جزء من الاختبارات العادية):
// flutter test test_screens --update-goldens
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/theme/app_theme.dart';
import 'package:hayati/core/theme/palettes.dart';
import 'package:hayati/core/widgets/hayati_background.dart';
import 'package:hayati/data/session.dart';
import 'package:hayati/features/habits/habits_screen.dart';
import 'package:hayati/features/assistant/assistant_screen.dart';
import 'package:hayati/features/auth/login_screen.dart';
import 'package:hayati/features/family/family_screen.dart';
import 'package:hayati/features/journal/journal_screen.dart';
import 'package:hayati/features/more/more_screen.dart';
import 'package:hayati/features/more/settings_screen.dart';
import 'package:hayati/features/ramadan/ramadan_screen.dart';
import 'package:hayati/features/stats/stats_screen.dart';
import 'package:hayati/features/tasks/tasks_screen.dart';
import 'package:hayati/features/worship/adhkar_screen.dart';
import 'package:hayati/features/worship/quran_screen.dart';
import 'package:hayati/features/worship/tasbeeh_screen.dart';
import 'package:hayati/features/money/money_screen.dart';
import 'package:hayati/features/onboarding/onboarding_screen.dart';
import 'package:hayati/features/today/today_screen.dart';
import 'package:hayati/features/worship/worship_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont() async {
  final loader = FontLoader('DejaVu');
  for (final f in ['DejaVuSans.ttf', 'DejaVuSans-Bold.ttf']) {
    final bytes = File('/usr/share/fonts/truetype/dejavu/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(File(
            '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytesSync()
        .buffer)));
  await icons.load();
  final emoji = FontLoader('NotoColorEmoji')
    ..addFont(Future.value(ByteData.view(
        File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf').readAsBytesSync().buffer)));
  await emoji.load();
}

Map<String, Object> _seed() {
  final today = DateTime.now();
  String d(int off) {
    final x = today.subtract(Duration(days: off));
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  final created = today.subtract(const Duration(days: 40)).millisecondsSinceEpoch;
  return {
    onboardedKey: true,
    userNameKey: 'أحمد',
    'guest_mode': true,
    'local_tasks':
        '{"1":{"title":"اجتماع الشغل 11 ص","done":false,"dueDate":"${d(0)}","list":"شغل","repeat":"none","source":"app","createdAt":$created},'
        '"2":{"title":"أشتري خضار","done":false,"dueDate":"${d(0)}","list":"مشتريات","repeat":"none","source":"assistant","createdAt":$created},'
        '"3":{"title":"أكلم ماما","done":true,"dueDate":"${d(0)}","list":"عام","repeat":"none","source":"app","createdAt":$created}}',
    'local_habits':
        '{"h1":{"title":"قراءة 10 صفحات","emoji":"📖","weekdays":[1,2,3,4,5,6,7],"done":{${List.generate(12, (i) => '"${d(i)}":true').join(',')}},"source":"app","createdAt":$created},'
        '"h2":{"title":"شرب مية","emoji":"💧","weekdays":[1,2,3,4,5,6,7],"done":{"${d(1)}":true,"${d(2)}":true},"source":"app","createdAt":$created},'
        '"h3":{"title":"مشي 30 دقيقة","emoji":"🏃","weekdays":[1,3,5],"done":{},"source":"app","createdAt":$created}}',
    'local_transactions':
        '{"t1":{"type":"expense","amount":150,"category":"food","date":"${d(0)}","month":"${d(0).substring(0, 7)}","note":"غدا","source":"app","createdAt":$created},'
        '"t2":{"type":"expense","amount":80,"category":"transport","date":"${d(0)}","month":"${d(0).substring(0, 7)}","note":null,"source":"app","createdAt":$created},'
        '"t3":{"type":"income","amount":12000,"category":"salary","date":"${d(0)}","month":"${d(0).substring(0, 7)}","note":"المرتب","source":"app","createdAt":$created}}',
    'store/prayers/${d(0)}': '{"fajr":"mosque","dhuhr":"ontime"}',
    'store/money/settings': '{"monthlyBudget":8000}',
    'store/quran/progress': '{"page":230,"khatmas":0,"dailyGoal":4,"log":{"${d(0)}":3}}',
  };
}

Future<void> _shot(WidgetTester tester, Widget screen, String name,
    {bool dark = false}) async {
  SharedPreferences.setMockInitialValues(_seed());
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      firebaseReadyProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.fromPalette(royalNavy) : AppTheme.fromPalette(emeraldNight),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HayatiBackground(child: screen),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    AppTheme.fallbackFontFamily = 'DejaVu';
    AppTheme.fontFamilyFallback = ['NotoColorEmoji'];
    await initializeDateFormatting('ar');
    await _loadFont();
  });

  testWidgets('today', (t) => _shot(t, const TodayScreen(), 'today'));
  testWidgets('today dark', (t) => _shot(t, const TodayScreen(), 'today_dark', dark: true));
  testWidgets('worship', (t) => _shot(t, const WorshipScreen(), 'worship'));
  testWidgets('habits', (t) => _shot(t, const HabitsScreen(), 'habits'));
  testWidgets('money', (t) => _shot(t, const MoneyScreen(), 'money'));
  testWidgets('onboarding', (t) => _shot(t, const OnboardingScreen(), 'onboarding'));
  testWidgets('login', (t) => _shot(t, const LoginScreen(), 'login'));
  testWidgets('tasks', (t) => _shot(t, const TasksScreen(), 'tasks'));
  testWidgets('more', (t) => _shot(t, const MoreScreen(), 'more'));
  testWidgets('settings', (t) => _shot(t, const SettingsScreen(), 'settings'));
  testWidgets('assistant', (t) => _shot(t, const AssistantScreen(), 'assistant'));
  testWidgets('stats', (t) => _shot(t, const StatsScreen(), 'stats'));
  testWidgets('journal', (t) => _shot(t, const JournalScreen(), 'journal'));
  testWidgets('family', (t) => _shot(t, const FamilyScreen(), 'family'));
  testWidgets('ramadan', (t) => _shot(t, const RamadanScreen(), 'ramadan'));
  testWidgets('quran', (t) => _shot(t, const QuranScreen(), 'quran'));
  testWidgets('tasbeeh', (t) => _shot(t, const TasbeehScreen(), 'tasbeeh'));
  testWidgets('adhkar', (t) => _shot(t, const AdhkarScreen(groupId: 'morning'), 'adhkar'));
}
