import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:adhan/adhan.dart';
import 'package:hayati/data/task.dart';
import 'package:hayati/features/family/family_models.dart';
import 'package:hayati/features/habits/habit.dart';
import 'package:hayati/features/journal/journal_repository.dart';
import 'package:hayati/features/lock/pin_pad.dart';
import 'package:hayati/features/money/money_models.dart';
import 'package:hayati/features/assistant/assistant_service.dart';
import 'package:hayati/features/money/money_repository.dart';
import 'package:hayati/features/money/money_screen.dart';
import 'package:hayati/features/onboarding/onboarding_screen.dart';
import 'package:hayati/data/session.dart';
import 'package:hayati/data/user_store.dart';
import 'package:hayati/features/account/backup_restore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hayati/features/stats/stats.dart';
import 'package:hayati/features/ramadan/ramadan.dart';
import 'package:hayati/features/widget/home_widget_sync.dart';
import 'package:hayati/features/reminders/smart_reminders.dart';
import 'package:hayati/features/worship/prayer_log.dart';
import 'package:hayati/features/worship/adhkar_data.dart';
import 'package:hayati/features/worship/prayer_service.dart';
import 'package:hayati/features/worship/prayer_settings.dart';
import 'package:hayati/features/worship/quran_progress.dart';
import 'package:hayati/features/worship/qada.dart';
import 'package:hayati/features/worship/islamic_occasions.dart';
import 'package:hayati/features/goals/goals.dart';
import 'package:hayati/features/search/global_search.dart';
import 'package:hayati/features/money/money_analytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('HayatiDates', () {
    test('greeting depends on hour', () {
      expect(HayatiDates.greeting(DateTime(2026, 1, 1, 8)), 'صباح الخير');
      expect(HayatiDates.greeting(DateTime(2026, 1, 1, 14)), 'نهارك سعيد');
      expect(HayatiDates.greeting(DateTime(2026, 1, 1, 21)), 'مساء الخير');
    });

    test('dayKey format', () {
      expect(HayatiDates.dayKey(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('hijri date is produced', () {
      expect(HayatiDates.hijri(DateTime(2026, 11, 22)), contains('هـ'));
    });
  });

  group('LocalTasksRepository', () {
    test('add, toggle, delete', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalTasksRepository(await SharedPreferences.getInstance());

      await repo.add('مهمة 1');
      await repo.add('مهمة 2', dueDate: '2026-11-22');
      var tasks = await repo.watch().first;
      expect(tasks.length, 2);

      await repo.toggle(tasks.firstWhere((t) => t.title == 'مهمة 1'));
      tasks = await repo.watch().first;
      // المهام المنتهية بتنزل تحت
      expect(tasks.last.title, 'مهمة 1');
      expect(tasks.last.done, isTrue);

      await repo.delete(tasks.first.id);
      tasks = await repo.watch().first;
      expect(tasks.map((t) => t.title), ['مهمة 1']);
    });
  });

  testWidgets('PinPad reports 4-digit pin', (tester) async {
    String? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinPad(
            onCompleted: (pin) async {
              got = pin;
              return true;
            },
          ),
        ),
      ),
    );
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(got, '1234');
  });

  group('Worship', () {
    const cairo = PrayerSettings(
      latitude: 30.0444,
      longitude: 31.2357,
      placeLabel: 'القاهرة',
      method: CalculationMethod.egyptian,
      madhab: Madhab.shafi,
      adhanNotifications: false,
      hasRealLocation: true,
    );

    test('prayer times are in order', () {
      final t = computePrayerTimes(cairo, DateTime(2026, 11, 22));
      expect(t[PrayerName.fajr].isBefore(t.sunrise), isTrue);
      expect(t.sunrise.isBefore(t[PrayerName.dhuhr]), isTrue);
      expect(t[PrayerName.dhuhr].isBefore(t[PrayerName.asr]), isTrue);
      expect(t[PrayerName.asr].isBefore(t[PrayerName.maghrib]), isTrue);
      expect(t[PrayerName.maghrib].isBefore(t[PrayerName.isha]), isTrue);
    });

    test('next prayer after isha is tomorrow fajr', () {
      final today = computePrayerTimes(cairo, DateTime(2026, 11, 22));
      final after = today[PrayerName.isha].add(const Duration(minutes: 1));
      final next = nextPrayer(cairo, after);
      expect(next.name, PrayerName.fajr);
      expect(next.time.isAfter(after), isTrue);
    });

    test('juz of page', () {
      expect(juzOfPage(1), 1);
      expect(juzOfPage(21), 1);
      expect(juzOfPage(22), 2);
      expect(juzOfPage(604), 30);
    });

    test('every dhikr has a source and a positive count', () {
      for (final g in allAdhkar) {
        for (final d in g.items) {
          expect(d.source.trim(), isNotEmpty, reason: d.text);
          expect(d.count, greaterThan(0));
        }
      }
    });
  });

  group('Habits', () {
    final today = DateTime(2026, 11, 22); // أحد
    Habit h(
      Set<String> done, {
      Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
    }) => Habit(
      id: 'h',
      title: 'قراءة',
      weekdays: weekdays,
      done: done,
      createdAt: DateTime(2026, 1, 1),
    );

    test('streak counts consecutive days including today', () {
      expect(h({'2026-11-22', '2026-11-21', '2026-11-20'}).streak(today), 3);
    });

    test('streak continues from yesterday if today not done yet', () {
      expect(h({'2026-11-21', '2026-11-20'}).streak(today), 2);
    });

    test('gap breaks the streak', () {
      expect(h({'2026-11-22', '2026-11-20'}).streak(today), 1);
    });

    test('unscheduled days are skipped', () {
      // الجمعة (5) مش مجدولة، فالسلسلة بتعدّي عليها
      final habit = h(
        {'2026-11-22', '2026-11-20'},
        weekdays: const {1, 2, 3, 4, 6, 7},
      );
      expect(habit.streak(today), 1); // السبت 21 مجدول ومش متعمل
      final habit2 = h(
        {'2026-11-22', '2026-11-21', '2026-11-19'},
        weekdays: const {1, 2, 3, 4, 6, 7},
      );
      expect(habit2.streak(today), 3);
    });

    test('map round trip', () {
      final a = h({'2026-11-22'});
      final b = Habit.fromMap('h', a.toMap());
      expect(b.done, a.done);
      expect(b.weekdays, a.weekdays);
    });
  });

  group('Repeating tasks', () {
    test('daily task creates next day', () {
      final t = HayatiTask(
        id: '1',
        title: 'رياضة',
        dueDate: '2026-11-22',
        repeat: TaskRepeat.daily,
        remindAt: DateTime(2026, 11, 22, 7, 30),
        createdAt: DateTime(2026, 11, 1),
      );
      final n = t.nextOccurrence('2')!;
      expect(n.dueDate, '2026-11-23');
      expect(n.remindAt, DateTime(2026, 11, 23, 7, 30));
      expect(n.done, isFalse);
    });

    test('monthly and none', () {
      final t = HayatiTask(
        id: '1',
        title: 'فاتورة',
        dueDate: '2026-11-30',
        repeat: TaskRepeat.monthly,
        createdAt: DateTime(2026, 11, 1),
      );
      expect(t.nextOccurrence('2')!.dueDate!.startsWith('2026-12'), isTrue);
      final once = HayatiTask(id: '3', title: 'x', createdAt: DateTime(2026));
      expect(once.nextOccurrence('4'), isNull);
    });
  });

  group('Money', () {
    Transaction tx(TxType type, double amount, String cat) => Transaction(
      id: '$amount$cat',
      type: type,
      amount: amount,
      category: cat,
      date: '2026-11-22',
      createdAt: DateTime(2026, 11, 22),
    );

    test('month summary', () {
      final s = MonthSummary([
        tx(TxType.expense, 150, 'food'),
        tx(TxType.expense, 50, 'transport'),
        tx(TxType.expense, 100, 'food'),
        tx(TxType.income, 10000, 'salary'),
      ]);
      expect(s.spent, 300);
      expect(s.income, 10000);
      final cats = s.byCategory();
      expect(cats.first.$1.id, 'food');
      expect(cats.first.$2, 250);
    });

    test('formatMoney', () {
      expect(formatMoney(1500), '1,500 ج.م');
      expect(formatMoney(12.5), '12.50 ج.م');
      expect(formatMoney(1234567), '1,234,567 ج.م');
    });

    test('transaction map round trip', () {
      final t = tx(TxType.expense, 75, 'bills');
      final r = Transaction.fromMap('x', t.toMap());
      expect(r.amount, 75);
      expect(r.month, '2026-11');
      expect(r.type, TxType.expense);
    });
  });

  group('Journal', () {
    JournalEntry e(String day, {int? mood, String text = ''}) => JournalEntry(
      day: day,
      mood: mood,
      text: text,
      updatedAt: DateTime(2026),
    );

    test('empty entry detection', () {
      expect(e('2026-11-22').isEmpty, isTrue);
      expect(e('2026-11-22', mood: 4).isEmpty, isFalse);
    });

    test('on this day finds last month and last year', () {
      final all = [
        e('2026-10-22', text: 'شهر فات'),
        e('2025-11-22', mood: 5),
        e('2026-11-21', text: 'امبارح'),
      ];
      final found = onThisDay(all, DateTime(2026, 11, 22));
      expect(found.map((x) => x.$1), containsAll(['من شهر', 'من سنة']));
      expect(found.length, 2);
    });
  });

  group('Family', () {
    test('occasion days until and age', () {
      const o = Occasion(
        id: '1',
        title: 'عيد ميلاد ماما',
        type: OccasionType.birthday,
        month: 11,
        day: 25,
        year: 1970,
      );
      final now = DateTime(2026, 11, 22, 15);
      expect(o.daysUntil(now), 3);
      expect(o.yearsAtNext(now), 56);
      const passed = Occasion(
        id: '2',
        title: 'x',
        type: OccasionType.other,
        month: 1,
        day: 1,
      );
      expect(passed.nextDate(now), DateTime(2027, 1, 1));
    });

    test('person due', () {
      final p = Person(
        id: '1',
        name: 'خالتي',
        everyDays: 7,
        lastContact: DateTime(2026, 11, 10),
      );
      expect(p.isDue(DateTime(2026, 11, 22)), isTrue);
      expect(p.contactedNow().isDue(DateTime.now()), isFalse);
    });
  });

  group('Stats', () {
    test('compute week stats', () {
      final days = periodDays(StatsPeriod.week, DateTime(2026, 11, 22));
      expect(days.length, 7);
      final r = computeStats(
        days: days,
        prayerLogs: {
          '2026-11-22': {
            PrayerName.fajr: PrayerStatus.mosque,
            PrayerName.dhuhr: PrayerStatus.ontime,
            PrayerName.asr: PrayerStatus.missed,
          },
        },
        habits: [
          Habit(
            id: 'h',
            title: 'x',
            done: const {'2026-11-22', '2026-11-21'},
            createdAt: DateTime(2026, 11, 1),
          ),
        ],
        tasks: [
          HayatiTask(
            id: '1',
            title: 'a',
            dueDate: '2026-11-20',
            done: true,
            createdAt: DateTime(2026),
          ),
          HayatiTask(
            id: '2',
            title: 'b',
            dueDate: '2026-11-21',
            createdAt: DateTime(2026),
          ),
          HayatiTask(
            id: '3',
            title: 'c',
            dueDate: '2026-10-01',
            done: true,
            createdAt: DateTime(2026),
          ),
        ],
        transactions: [
          Transaction(
            id: 't',
            type: TxType.expense,
            amount: 100,
            category: 'food',
            date: '2026-11-22',
            createdAt: DateTime(2026),
          ),
          Transaction(
            id: 'u',
            type: TxType.expense,
            amount: 999,
            category: 'food',
            date: '2026-11-01',
            createdAt: DateTime(2026),
          ),
        ],
        quranLog: const {'2026-11-22': 4, '2026-11-20': 2, '2026-10-01': 50},
        journal: [
          JournalEntry(day: '2026-11-22', mood: 4, updatedAt: DateTime(2026)),
          JournalEntry(day: '2026-11-21', mood: 2, updatedAt: DateTime(2026)),
        ],
      );
      expect(r.prayersDone, 2);
      expect(r.prayersMosque, 1);
      expect(r.prayersTotal, 35);
      expect(r.habitRate, closeTo(2 / 7, 0.001));
      expect(r.tasksDone, 1);
      expect(r.tasksTotal, 2);
      expect(r.spent, 100);
      expect(r.quranPages, 6);
      expect(r.avgMood, 3);
      expect(r.shareText(StatsPeriod.week), contains('حياتي'));
    });
  });

  testWidgets('onboarding saves name and finishes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    expect(container.read(onboardedProvider), isFalse);
    await tester.tap(find.text('تخطّي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'أحمد');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('خلّينا نجهّز التطبيق'), findsOneWidget);
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();
    expect(container.read(onboardedProvider), isTrue);
    expect(prefs.getString(userNameKey), 'أحمد');
  });

  group('Smart reminders', () {
    test('fasting days include Monday/Thursday and skip Ramadan', () {
      final list = upcomingFastingDays(
        DateTime(2026, 11, 22),
        monThu: true,
        whiteDays: true,
        days: 14,
      );
      expect(list, isNotEmpty);
      for (final (d, _) in list) {
        final isMonThu =
            d.weekday == DateTime.monday || d.weekday == DateTime.thursday;
        expect(isMonThu || list.any((x) => x.$2.contains('البيض')), isTrue);
      }
      final none = upcomingFastingDays(
        DateTime(2026, 11, 22),
        monThu: false,
        whiteDays: false,
      );
      expect(none, isEmpty);
    });

    test('morning summary text', () {
      final day = DateTime(2026, 11, 23);
      final text = morningSummaryText(
        day: day,
        tasks: [
          HayatiTask(
            id: '1',
            title: 'x',
            dueDate: '2026-11-23',
            createdAt: DateTime(2026),
          ),
          HayatiTask(
            id: '2',
            title: 'y',
            dueDate: '2026-11-20',
            createdAt: DateTime(2026),
          ),
          HayatiTask(
            id: '3',
            title: 'z',
            dueDate: '2026-11-30',
            createdAt: DateTime(2026),
          ),
        ],
        habits: const [],
        spentMonth: 3000,
        budget: 8000,
      );
      expect(text, contains('2 مهام'));
      expect(text, contains('5,000'));
    });
  });

  test('local store deep merge keeps nested history', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalUserStore(await SharedPreferences.getInstance());
    await store.merge('quran', 'progress', {
      'page': 10,
      'log': {'2026-11-21': 4},
    });
    await store.merge('quran', 'progress', {
      'page': 13,
      'log': {'2026-11-22': 3},
    });
    final d = await store.get('quran', 'progress');
    expect(d!['page'], 13);
    expect(d['log'], {'2026-11-21': 4, '2026-11-22': 3});
    expect(deepMerge({'a': 1}, {'b': 2}), {'a': 1, 'b': 2});
  });

  test('home widget payload has 6 ordered prayer times', () {
    const cairo = PrayerSettings(
      latitude: 30.0444,
      longitude: 31.2357,
      placeLabel: 'القاهرة',
      method: CalculationMethod.egyptian,
      madhab: Madhab.shafi,
      adhanNotifications: false,
      hasRealLocation: true,
    );
    final p = buildWidgetPayload(
      settings: cairo,
      now: DateTime(2026, 11, 23, 10),
      tasksLeft: 3,
      habitsDone: 1,
      habitsTotal: 4,
    );
    final times = p.times.split(',').map(int.parse).toList();
    expect(times.length, 6);
    for (var i = 1; i < times.length; i++) {
      expect(times[i] > times[i - 1], isTrue);
    }
    expect(p.names.split(',').first, 'الفجر');
    expect(p.tasksLine, contains('3'));
    expect(p.habitsLine, 'عادات النهارده: 1/4');
  });

  group('Ramadan', () {
    test('before Ramadan: countdown is positive', () {
      final info = ramadanInfo(DateTime(2026, 11, 23));
      expect(info.isRamadan, isFalse);
      expect(info.daysUntilRamadan, greaterThan(0));
      expect(info.daysUntilRamadan, lessThan(120));
    });

    test('inside Ramadan: day and Eid countdown', () {
      final before = ramadanInfo(DateTime(2026, 11, 23));
      final first = DateTime(
        2026,
        11,
        23,
      ).add(Duration(days: before.daysUntilRamadan));
      final info = ramadanInfo(first.add(const Duration(days: 4)));
      expect(info.isRamadan, isTrue);
      expect(info.day, 5);
      expect(info.daysUntilEid, greaterThan(20));
      expect(info.isLastTen, isFalse);
    });
  });

  test('prayer minute offsets shift times', () {
    const base = PrayerSettings(
      latitude: 30.0444,
      longitude: 31.2357,
      placeLabel: 'القاهرة',
      method: CalculationMethod.egyptian,
      madhab: Madhab.shafi,
      adhanNotifications: false,
      hasRealLocation: true,
    );
    final shifted = base.copyWith(offsets: {'maghrib': 3, 'fajr': -2});
    final day = DateTime(2026, 11, 23);
    final a = computePrayerTimes(base, day);
    final b = computePrayerTimes(shifted, day);
    expect(
      b[PrayerName.maghrib].difference(a[PrayerName.maghrib]).inMinutes,
      3,
    );
    expect(b[PrayerName.fajr].difference(a[PrayerName.fajr]).inMinutes, -2);
    expect(b[PrayerName.dhuhr], a[PrayerName.dhuhr]);
  });

  test('task priority and subtasks round trip and sort', () async {
    final t = HayatiTask(
      id: '1',
      title: 'مشروع',
      createdAt: DateTime(2026),
      priority: TaskPriority.high,
      subtasks: const [Subtask('خطوة 1', done: true), Subtask('خطوة 2')],
    );
    final r = HayatiTask.fromMap('1', t.toMap());
    expect(r.priority, TaskPriority.high);
    expect(r.subtasks.length, 2);
    expect(r.subtasksDone, 1);
    // التكرار بيرجّع المهام الفرعية من غير علامات
    final rep = HayatiTask(
      id: '2',
      title: 'x',
      dueDate: '2026-11-23',
      repeat: TaskRepeat.daily,
      createdAt: DateTime(2026),
      subtasks: const [Subtask('a', done: true)],
    );
    expect(rep.nextOccurrence('3')!.subtasks.first.done, isFalse);

    SharedPreferences.setMockInitialValues({});
    final repo = LocalTasksRepository(await SharedPreferences.getInstance());
    await repo.addTask(
      HayatiTask(id: '', title: 'عادية', createdAt: DateTime(2026, 1, 2)),
    );
    await repo.addTask(
      HayatiTask(
        id: '',
        title: 'مهمة جدًا',
        createdAt: DateTime(2026, 1, 1),
        priority: TaskPriority.high,
      ),
    );
    final list = await repo.watch().first;
    expect(list.first.title, 'مهمة جدًا');
    await repo.update(list.first.copyWith(subtasks: const [Subtask('s')]));
    expect((await repo.watch().first).first.subtasks.length, 1);
  });

  test('recurring expenses apply once per month', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalUserStore(prefs);
    final repo = LocalTransactionsRepository(prefs);
    const rent = RecurringExpense(
      id: 'r1',
      title: 'الإيجار',
      amount: 3000,
      category: 'home',
      dayOfMonth: 5,
    );
    var settings = const MoneySettings(recurring: [rent]);
    // قبل المعاد: مفيش حاجة
    expect(dueRecurring(settings, DateTime(2026, 11, 3)), isEmpty);
    // بعد المعاد: يتسجل مرة واحدة
    final now = DateTime(2026, 11, 23);
    expect(await applyRecurring(store, repo, settings, now), 1);
    final saved = await store.get('money', 'settings');
    settings = MoneySettings(
      recurring: const [rent],
      recurringApplied: (saved!['recurringApplied'] as Map)
          .cast<String, String>(),
    );
    expect(await applyRecurring(store, repo, settings, now), 0);
    final txs = await repo.watchMonth('2026-11').first;
    expect(txs.length, 1);
    expect(txs.first.amount, 3000);
    expect(txs.first.date, '2026-11-05');
  });

  test('transactions CSV', () {
    final csv = transactionsToCsv([
      Transaction(
        id: '1',
        type: TxType.expense,
        amount: 50,
        category: 'food',
        date: '2026-11-23',
        note: 'غدا, مع الشغل',
        createdAt: DateTime(2026),
      ),
    ]);
    final lines = csv.split('\n');
    expect(lines.first, startsWith('التاريخ'));
    expect(lines[1], contains('"غدا, مع الشغل"'));
    expect(lines[1], contains('أكل'));
  });

  group('Assistant memory', () {
    test('chat message map round trip', () {
      const m = ChatMessage(
        fromUser: false,
        text: 'تمام',
        actions: ['أضفت مهمة'],
      );
      final r = ChatMessage.fromMap(m.toMap());
      expect(r.text, 'تمام');
      expect(r.fromUser, isFalse);
      expect(r.actions, ['أضفت مهمة']);
    });

    test('saved chat loads on start', () async {
      SharedPreferences.setMockInitialValues({
        'store/assistant/chat': '{"messages":[{"u":true,"t":"رتّبلي يومي"},{"u":false,"t":"حاضر","a":["x"]}]}',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          firebaseReadyProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      c.read(chatProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final msgs = c.read(chatProvider).messages;
      expect(msgs.length, 2);
      expect(msgs.last.actions, ['x']);
    });

    test('smart suggestions depend on time', () {
      expect(
        smartSuggestions(DateTime(2026, 11, 23, 8)),
        contains('رتّبلي يومي النهارده'),
      );
      expect(
        smartSuggestions(DateTime(2026, 11, 23, 21)),
        contains('لخّصلي يومي'),
      );
      expect(
        smartSuggestions(DateTime(2026, 11, 27, 9)),
        contains('ضيف مهمة: قراءة سورة الكهف'),
      );
    });
  });

  test('qada state math', () {
    const s = QadaState(
      owed: {PrayerName.fajr: 10, PrayerName.dhuhr: 4},
      done: {PrayerName.fajr: 5},
      dailyGoal: 2,
    );
    expect(s.totalOwed, 14);
    expect(s.totalDone, 5);
    expect(s.daysToFinish, 5);
    expect(s.progress, closeTo(5 / 19, 0.001));
  });

  group('Backup restore', () {
    test('parse account export and guest export', () {
      final account = parseBackup(
        '{"app":"hayati","tasks":{"t1":{"title":"a"}},"prayers":{"2026-11-23":{"fajr":"mosque"}}}',
      );
      expect(account.length, 2);
      expect(
        account.any((d) => d.collection == 'prayers' && d.id == '2026-11-23'),
        isTrue,
      );
      final guest = parseBackup(
        '{"app":"hayati","local_habits":{"h1":{"title":"b"}},"store/quran/progress":{"page":5}}',
      );
      expect(guest.map((d) => d.collection).toSet(), {'habits', 'quran'});
      expect(() => parseBackup('{"x":1}'), throwsFormatException);
    });

    test('restore into guest storage merges', () async {
      SharedPreferences.setMockInitialValues({
        'local_tasks': '{"old":{"title":"قديمة","done":false,"createdAt":1}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final docs = parseBackup(
        '{"app":"hayati","tasks":{"new":{"title":"جديدة","done":false,"createdAt":2}},"quran":{"progress":{"page":40}}}',
      );
      final n = await applyBackup(docs, const GuestSession(), prefs);
      expect(n, 2);
      final tasks = await LocalTasksRepository(prefs).watch().first;
      expect(tasks.map((t) => t.title).toSet(), {'قديمة', 'جديدة'});
      expect(
        (await LocalUserStore(prefs).get('quran', 'progress'))!['page'],
        40,
      );
    });
  });

  test('islamic occasions upcoming and ordered', () {
    final now = DateTime(2026, 11, 23);
    final list = upcomingIslamicOccasions(now);
    expect(list.length, islamicOccasions.length);
    for (var i = 1; i < list.length; i++) {
      expect(!list[i].date.isBefore(list[i - 1].date), isTrue);
    }
    expect(
      list.every((o) => o.daysFrom(now) >= 0 && o.daysFrom(now) <= 366),
      isTrue,
    );
    final ramadan = list.firstWhere((o) => o.occasion.id == 'ramadan');
    final eid = list.firstWhere((o) => o.occasion.id == 'eid_fitr');
    expect(eid.date.isAfter(ramadan.date), isTrue);
    // عرفة قبل الأضحى بيوم
    final arafah = list.firstWhere((o) => o.occasion.id == 'arafah');
    final adha = list.firstWhere((o) => o.occasion.id == 'eid_adha');
    expect(adha.date.difference(arafah.date).inDays, 1);
  });

  test('الأهداف: تقدّم الخطوات والحفظ والقراءة', () {
    const g = Goal(
      id: 'a',
      title: 'جزء عمّ',
      steps: [GoalStep('1'), GoalStep('2')],
    );
    expect(g.progress, 0);
    var list = upsertGoal(const [], g);
    list = toggleStep(list, 'a', 0);
    expect(list.single.progress, 0.5);
    list = toggleStep(list, 'a', 1);
    expect(list.single.completed, isTrue);
    list = toggleStep(list, 'a', 9); // خطوة مش موجودة: مفيش تغيير
    expect(list.single.doneCount, 2);
    final back = Goal.fromMap(list.single.toMap());
    expect(back.title, 'جزء عمّ');
    expect(back.steps.map((s) => s.done), [true, true]);
    expect(upsertGoal(list, back.copyWith(title: 'x')).single.title, 'x');
  });

  test('تحليلات الفلوس: آخر 6 شهور ومتوسط اليوم', () {
    final m = lastMonths(DateTime(2026, 2, 10));
    expect(m.length, 6);
    expect(m.first, DateTime(2025, 9));
    expect(m.last, DateTime(2026, 2));
    // الشهر الحالي: على الأيام اللي فاتت بس
    expect(dailyAverage(500, DateTime(2026, 2), DateTime(2026, 2, 10)), 50);
    // شهر خلص: على كل أيامه
    expect(dailyAverage(310, DateTime(2026, 1), DateTime(2026, 2, 10)), 10);
  });

  test('البحث: توحيد الكتابة العربية والمقتطف', () {
    expect(normalizeArabic('أُسْرة'), 'اسره');
    expect(matchesQuery('اجتماع الشغل مع أحمد', 'احمد اجتماع'), isTrue);
    expect(matchesQuery('مستشفى', 'مستشفي'), isTrue);
    expect(matchesQuery('شراء خضار', 'لحمة'), isFalse);
    expect(matchesQuery('أي حاجة', '   '), isFalse);
    final s = snippet('${'كلام ' * 30}المفتاح هنا ${'تاني ' * 30}', 'المفتاح');
    expect(s, contains('المفتاح'));
    expect(s.startsWith('…'), isTrue);
  });
}
