import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:hayati/features/lock/pin_pad.dart';
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
}
