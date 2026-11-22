import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:adhan/adhan.dart';
import 'package:hayati/features/lock/pin_pad.dart';
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
}
