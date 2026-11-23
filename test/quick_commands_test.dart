import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/features/assistant/quick_commands.dart';
import 'package:hayati/features/worship/prayer_service.dart';

void main() {
  // الاتنين 23 نوفمبر 2026 الساعة 10 الصبح
  final now = DateTime(2026, 11, 23, 10);
  QuickCommand? p(String s) => parseCommand(s, now);

  group('المصروف والدخل', () {
    test('صرفت 150 أكل', () {
      final c = p('صرفت 150 أكل') as AddExpense;
      expect(c.amount, 150);
      expect(c.category, 'food');
      expect(c.note, 'أكل');
    });
    test('أرقام عربي وبنزين', () {
      final c = p('دفعت ٢٠٠ بنزين') as AddExpense;
      expect(c.amount, 200);
      expect(c.category, 'transport');
    });
    test('اشتريت خضار ب 80', () {
      final c = p('اشتريت خضار ب 80') as AddExpense;
      expect(c.amount, 80);
      expect(c.category, 'food');
      expect(c.note, 'خضار');
    });
    test('رقم بالكلام', () {
      final c = p('صرفت ميتين على الدكتور') as AddExpense;
      expect(c.amount, 200);
      expect(c.category, 'health');
    });
    test('قبضت المرتب 5 آلاف', () {
      final c = p('قبضت المرتب 5 الف') as AddIncome;
      expect(c.amount, 5000);
      expect(c.category, 'salary');
    });
    test('صرفت من غير رقم => مش مفهوم', () {
      expect(p('صرفت كتير'), isNull);
    });
  });

  group('المهام', () {
    test('فكرني أكلم ماما بكرة 5', () {
      final c = p('فكّرني أكلم ماما بكرة 5') as AddTaskCommand;
      expect(c.title, 'أكلم ماما');
      expect(c.dueDate, DateTime(2026, 11, 24));
      expect(c.remindAt, DateTime(2026, 11, 24, 17));
    });
    test('الساعة 8 الصبح', () {
      final c = p('فكرني اخد الدوا الساعة 8 الصبح') as AddTaskCommand;
      expect(c.title, 'اخد الدوا');
      // 8 الصبح عدّت النهارده => بكرة
      expect(c.remindAt, DateTime(2026, 11, 24, 8));
    });
    test('9 ونص بالليل', () {
      final c = p('فكرني ابعت الإيميل 9 ونص بالليل') as AddTaskCommand;
      expect(c.title, 'ابعت الإيميل');
      expect(c.remindAt, DateTime(2026, 11, 23, 21, 30));
    });
    test('يوم الخميس', () {
      final c = p('لازم أدفع الإيجار يوم الخميس') as AddTaskCommand;
      expect(c.title, 'أدفع الإيجار');
      expect(c.dueDate, DateTime(2026, 11, 26));
      expect(c.remindAt, isNull);
    });
    test('الأحد الجاي', () {
      final c = p('ضيف مهمة اجتماع الشغل الأحد') as AddTaskCommand;
      expect(c.title, 'اجتماع الشغل');
      expect(c.dueDate, DateTime(2026, 11, 29));
    });
    test('مهمة من غير ميعاد', () {
      final c = p('عايز اشتري هدية لأختي') as AddTaskCommand;
      expect(c.title, 'اشتري هدية لأختي');
      expect(c.dueDate, isNull);
    });
  });

  group('العبادات', () {
    test('صليت الضهر', () {
      final c = p('صليت الضهر') as LogPrayers;
      expect(c.prayers, [PrayerName.dhuhr]);
      expect(c.mosque, isFalse);
    });
    test('صليت العصر والمغرب في الجامع', () {
      final c = p('صليت العصر والمغرب في الجامع') as LogPrayers;
      expect(c.prayers, [PrayerName.asr, PrayerName.maghrib]);
      expect(c.mosque, isTrue);
    });
    test('صليت كله', () {
      expect((p('صليت كله') as LogPrayers).prayers.length, 5);
    });
    test('قريت 5 صفحات', () {
      expect((p('قريت 5 صفحات') as LogQuran).pages, 5);
      expect((p('قرأت جزء') as LogQuran).pages, 20);
    });
  });

  group('الأسئلة', () {
    test('فاضل قد ايه على المغرب', () {
      final c = p('فاضل قد ايه على المغرب؟') as AskNextPrayer;
      expect(c.prayer, PrayerName.maghrib);
    });
    test('امتى الصلاة الجاية', () {
      expect((p('امتى الصلاة الجاية') as AskNextPrayer).prayer, isNull);
    });
    test('مواقيت الصلاة النهارده', () {
      expect(p('ايه مواقيت الصلاة النهارده؟'), isA<AskPrayerTimes>());
    });
    test('صرفت كام', () {
      expect(p('صرفت كام الشهر ده؟'), isA<AskMonthSpent>());
    });
    test('مهامي بكرة', () {
      final c = p('ايه مهامي بكرة؟') as AskTasks;
      expect(c.day, DateTime(2026, 11, 24));
    });
    test('بتعرف تعمل ايه', () {
      expect(p('بتعرف تعمل ايه؟'), isA<AskHelp>());
    });
  });

  test('عملت الرياضة', () {
    expect((p('عملت الرياضة') as MarkDone).name, 'الرياضه');
  });

  test('كلام مش مفهوم', () {
    expect(p('إزيك عامل إيه'), isNull);
    expect(p(''), isNull);
  });
}
