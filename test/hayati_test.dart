import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:adhan/adhan.dart';
import 'package:hayati/data/task.dart';
import 'package:hayati/features/habits/habit.dart';
import 'package:hayati/features/lock/pin_pad.dart';
import 'package:hayati/features/money/money_models.dart';
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
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PinPad(onCompleted: (pin) async {
          got = pin;
          return true;
        }),
      ),
    ));
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
    Habit h(Set<String> done, {Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7}}) =>
        Habit(
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
      final habit = h({'2026-11-22', '2026-11-20'},
          weekdays: const {1, 2, 3, 4, 6, 7});
      expect(habit.streak(today), 1); // السبت 21 مجدول ومش متعمل
      final habit2 = h({'2026-11-22', '2026-11-21', '2026-11-19'},
          weekdays: const {1, 2, 3, 4, 6, 7});
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
}
