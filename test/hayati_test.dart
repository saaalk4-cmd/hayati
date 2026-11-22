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
import 'package:hayati/features/onboarding/onboarding_screen.dart';
import 'package:hayati/data/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hayati/features/stats/stats.dart';
import 'package:hayati/features/worship/prayer_log.dart';
import 'package:hayati/features/worship/adhkar_data.dart';
import 'package:hayati/features/worship/prayer_service.dart';
import 'package:hayati/features/worship/prayer_settings.dart';
import 'package:hayati/features/worship/quran_progress.dart';
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
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();
    expect(container.read(onboardedProvider), isTrue);
    expect(prefs.getString(userNameKey), 'أحمد');
  });
}
