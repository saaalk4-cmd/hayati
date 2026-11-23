import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hayati/core/utils/date_utils.dart';
import 'package:hayati/data/session.dart';
import 'package:hayati/data/tasks_repository.dart';
import 'package:hayati/data/user_store.dart';
import 'package:hayati/features/assistant/assistant_service.dart';
import 'package:hayati/features/money/money_models.dart';
import 'package:hayati/features/money/money_repository.dart';
import 'package:hayati/features/money/money_screen.dart' show monthKey;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Future<ProviderContainer> make() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        firebaseReadyProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    // زي الشاشة: حد بيسمع للمحادثة عشان متتقفلش
    c.listen(chatProvider, (_, _) {});
    return c;
  }

  Future<ChatMessage> say(ProviderContainer c, String text) async {
    await c.read(chatProvider.notifier).send(text);
    return c.read(chatProvider).messages.last;
  }

  test('المساعد المجاني بيسجّل مصروف ومهمة وصلاة فعلًا', () async {
    final c = await make();
    final now = DateTime.now();

    final r1 = await say(c, 'صرفت 150 أكل');
    expect(r1.fromUser, isFalse);
    expect(r1.text, contains('150'));
    final txs =
        c.read(monthTransactionsProvider(monthKey(now))).value ??
        await c
            .read(transactionsRepositoryProvider)
            .watchMonth(monthKey(now))
            .first;
    expect(txs.single.amount, 150);
    expect(txs.single.type, TxType.expense);
    expect(txs.single.category, 'food');

    await say(c, 'فكّرني أكلم ماما بكرة 5');
    final tasks = await c.read(tasksRepositoryProvider).watch().first;
    expect(tasks.single.title, 'أكلم ماما');
    expect(tasks.single.remindAt?.hour, 17);
    expect(tasks.single.source, 'assistant');

    await say(c, 'صليت الضهر في الجامع');
    final log = await c
        .read(userStoreProvider)
        .get('prayers', HayatiDates.dayKey(now));
    expect(log?['dhuhr'], 'mosque');

    final r4 = await say(c, 'صرفت كام الشهر ده؟');
    expect(r4.text, contains('150'));

    final r5 = await say(c, 'إزيك عامل إيه');
    expect(r5.text, contains('مفهمتش'));

    // المحادثة بتتحفظ
    expect(c.read(chatProvider).messages.length, 10);
  });

  test('رتّبلي يومي بيرد بملخص اليوم', () async {
    final c = await make();
    await say(c, 'ضيف مهمة أذاكر النهارده');
    final r = await say(c, 'رتّبلي يومي');
    expect(r.text, contains('الصلاة الجاية'));
    expect(r.text, contains('أذاكر'));
  });
}
