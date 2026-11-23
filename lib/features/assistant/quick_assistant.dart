// تنفيذ الأوامر السريعة على بيانات المستخدم (ضيف أو حساب) من غير نت
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/utils/date_utils.dart';
import '../../data/task.dart';
import '../../data/tasks_repository.dart';
import '../../data/user_store.dart';
import '../habits/habits_repository.dart';
import '../money/money_models.dart';
import '../money/money_repository.dart';
import '../money/money_screen.dart' show monthKey;
import '../search/global_search.dart' show matchesQuery, normalizeArabic;
import '../worship/prayer_log.dart';
import '../worship/prayer_service.dart';
import '../worship/prayer_settings.dart';
import '../worship/quran_progress.dart';
import 'assistant_service.dart' show ChatMessage;
import 'quick_commands.dart';

const quickHelpText = '''أقدر أعمل الحاجات دي من غير نت 👇

💸 «صرفت 150 أكل» أو «قبضت المرتب 5000»
✅ «فكّرني أكلم ماما بكرة 5» أو «لازم أدفع الإيجار يوم الخميس»
🕌 «صليت الضهر» أو «صليت كله في الجامع»
📖 «قريت 5 صفحات»
🔥 «عملت الرياضة»
⏰ «فاضل قد إيه على المغرب؟» أو «إيه مواقيت الصلاة؟»
📊 «صرفت كام الشهر ده؟» أو «إيه مهامي بكرة؟»''';

const quickExamples = [
  'صرفت 150 أكل',
  'فكّرني أكلم ماما بكرة 5',
  'صليت الضهر',
  'فاضل قد إيه على المغرب؟',
  'إيه مهامي النهارده؟',
  'بتعرف تعمل إيه؟',
];

String _money(double v) => formatMoney(v.roundToDouble());

String _dayName(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return 'النهارده';
  if (diff == 1) return 'بكرة';
  if (diff == 2) return 'بعد بكرة';
  return arFormat('EEEE d MMMM', d);
}

class QuickAssistant {
  QuickAssistant(this.ref);
  final Ref ref;

  Future<ChatMessage> handle(String text) async {
    final now = DateTime.now();
    final cmd = parseCommand(text, now);
    if (cmd == null) {
      return const ChatMessage(
        fromUser: false,
        text: 'معلش مفهمتش 🙏 جرّب تقولها بطريقة أبسط، زي «صرفت 150 أكل» أو «فكّرني أكلم ماما بكرة 5».\nاكتب «بتعرف تعمل إيه؟» عشان تشوف كل الأوامر.',
      );
    }
    try {
      return await _run(cmd, now);
    } catch (_) {
      return const ChatMessage(
        fromUser: false,
        text: 'حصلت مشكلة وأنا بسجّل، جرّب تاني',
        isError: true,
      );
    }
  }

  /// يقرا قيمة StreamProvider وهو ماسكه مفتوح لحد ما توصل (عشان ميتقفلش في النص)
  Future<T> _value<T>(ProviderListenable<AsyncValue<T>> p) async {
    final done = Completer<T>();
    final sub = ref.listen<AsyncValue<T>>(p, (_, next) {
      if (done.isCompleted) return;
      if (next.hasValue) {
        done.complete(next.requireValue);
      } else if (next.hasError) {
        done.completeError(next.error!);
      }
    }, fireImmediately: true);
    try {
      return await done.future.timeout(const Duration(seconds: 10));
    } finally {
      sub.close();
    }
  }

  ChatMessage _reply(String text, [List<String> actions = const []]) =>
      ChatMessage(fromUser: false, text: text, actions: actions);

  Future<ChatMessage> _run(QuickCommand cmd, DateTime now) async {
    final today = HayatiDates.dayKey(now);
    switch (cmd) {
      case AddExpense(:final amount, :final category, :final note):
        await ref
            .read(transactionsRepositoryProvider)
            .add(
              Transaction(
                id: '',
                type: TxType.expense,
                amount: amount,
                category: category,
                date: today,
                note: note.isEmpty ? null : note,
                source: 'assistant',
                createdAt: now,
              ),
            );
        final c = categoryById(category);
        return _reply('تمام، سجّلت ${_money(amount)} في «${c.name}» 💸', [
          'مصروف ${_money(amount)} • ${c.name}',
        ]);

      case AddIncome(:final amount, :final category, :final note):
        await ref
            .read(transactionsRepositoryProvider)
            .add(
              Transaction(
                id: '',
                type: TxType.income,
                amount: amount,
                category: category,
                date: today,
                note: note.isEmpty ? null : note,
                source: 'assistant',
                createdAt: now,
              ),
            );
        return _reply('مبروك! سجّلت دخل ${_money(amount)} 💰', [
          'دخل ${_money(amount)}',
        ]);

      case AddTaskCommand(:final title, :final dueDate, :final remindAt):
        await ref
            .read(tasksRepositoryProvider)
            .addTask(
              HayatiTask(
                id: '',
                title: title,
                dueDate: dueDate == null ? null : HayatiDates.dayKey(dueDate),
                remindAt: remindAt,
                source: 'assistant',
                createdAt: now,
              ),
            );
        final when = remindAt != null
            ? ' ${_dayName(remindAt, now)} الساعة ${formatPrayerTime(remindAt)} وهفكّرك ⏰'
            : dueDate != null
            ? ' ${_dayName(dueDate, now)}'
            : '';
        return _reply('ضفت «$title»$when ✅', ['مهمة: $title']);

      case LogPrayers(:final prayers, :final mosque):
        final status = mosque ? PrayerStatus.mosque : PrayerStatus.ontime;
        await ref.read(userStoreProvider).merge('prayers', today, {
          for (final p in prayers) p.name: status.name,
          'updatedAt': now.millisecondsSinceEpoch,
        });
        final names = prayers.length == 5
            ? 'الصلوات الخمس'
            : prayers.map((p) => p.ar).join(' و');
        return _reply(
          'تقبّل الله 🤲 علّمت $names${mosque ? ' في الجامع' : ''}',
          ['صلاة: $names'],
        );

      case LogQuran(:final pages):
        final q = await _value(quranProgressProvider);
        var page = q.page + pages;
        var khatmas = q.khatmas;
        final finished = page >= quranPages;
        if (finished) {
          page = 0;
          khatmas++;
        }
        await ref.read(userStoreProvider).merge('quran', 'progress', {
          'page': page,
          'khatmas': khatmas,
          'log': {today: q.todayPages + pages},
        });
        final total = q.todayPages + pages;
        return _reply(
          finished
              ? 'ما شاء الله! ختمت القرآن 🎉 ربنا يتقبّل منك'
              : 'ما شاء الله 📖 سجّلت $pages صفحات (النهارده $total من ${q.dailyGoal})',
          ['قرآن: $pages صفحات'],
        );

      case MarkDone(:final name):
        final habits = await _value(habitsProvider);
        final habit = habits
            .where(
              (h) =>
                  matchesQuery(h.title, name) ||
                  normalizeArabic(name).contains(normalizeArabic(h.title)),
            )
            .firstOrNull;
        if (habit != null) {
          if (!habit.isDoneOn(now)) {
            await ref.read(habitsRepositoryProvider).setDone(habit, now, true);
          }
          return _reply('برافو! علّمت «${habit.title}» النهارده 🔥', [
            'عادة: ${habit.title}',
          ]);
        }
        final tasks = await _value(tasksProvider);
        final task = tasks
            .where((t) => !t.done && matchesQuery(t.title, name))
            .firstOrNull;
        if (task != null) {
          await ref.read(tasksRepositoryProvider).toggle(task);
          return _reply('عاش! خلّصت «${task.title}» ✅', [
            'خلصت: ${task.title}',
          ]);
        }
        return _reply(
          'ملقيتش عادة أو مهمة اسمها «$name» 🤔 تحب أضيفها مهمة؟ قول «ضيف مهمة $name»',
        );

      case AskNextPrayer(:final prayer):
        final settings = ref.read(prayerSettingsProvider);
        if (prayer != null) {
          var t = computePrayerTimes(settings, now)[prayer];
          if (!t.isAfter(now)) {
            t = computePrayerTimes(
              settings,
              now.add(const Duration(days: 1)),
            )[prayer];
          }
          return _reply(
            '${prayer.ar} الساعة ${formatPrayerTime(t)} (${formatCountdown(t.difference(now))}) 🕌',
          );
        }
        final next = nextPrayer(settings, now);
        return _reply(
          'الصلاة الجاية ${next.name.ar} الساعة ${formatPrayerTime(next.time)} (${formatCountdown(next.time.difference(now))}) 🕌',
        );

      case AskPrayerTimes():
        final t = computePrayerTimes(ref.read(prayerSettingsProvider), now);
        final lines = [
          for (final p in PrayerName.values)
            '${p.ar}: ${formatPrayerTime(t[p])}',
        ];
        return _reply('مواقيت النهارده 🕌\n${lines.join('\n')}');

      case AskMonthSpent():
        final list = await _value(monthTransactionsProvider(monthKey(now)));
        final s = MonthSummary(list);
        final budget = (await _value(moneySettingsProvider)).monthlyBudget;
        final top = s.byCategory().firstOrNull;
        final b = StringBuffer('صرفت ${_money(s.spent)} الشهر ده');
        if (top != null) {
          b.write('، أكتره على «${top.$1.name}» (${_money(top.$2)})');
        }
        if (budget != null && budget > 0) {
          final left = budget - s.spent;
          b.write(
            left >= 0
                ? '\nفاضلك ${_money(left)} من الميزانية 👍'
                : '\nعدّيت الميزانية بـ ${_money(-left)} ⚠️',
          );
        }
        return _reply(b.toString());

      case AskTasks(:final day):
        final key = HayatiDates.dayKey(day);
        final isToday = key == today;
        final tasks = (await _value(tasksProvider))
            .where(
              (t) =>
                  !t.done &&
                  (t.dueDate == key || (isToday && t.dueDate == null)),
            )
            .toList();
        final label = _dayName(day, now);
        if (tasks.isEmpty) return _reply('مفيش مهام $label 🎉');
        return _reply(
          'مهامك $label (${tasks.length}):\n${tasks.take(10).map((t) => '• ${t.title}').join('\n')}',
        );

      case AskDayOverview():
        final settings = ref.read(prayerSettingsProvider);
        final next = nextPrayer(settings, now);
        final tasks =
            (await _value(tasksProvider))
                .where(
                  (t) => !t.done && (t.dueDate == today || t.dueDate == null),
                )
                .toList()
              ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
        final habits = (await _value(habitsProvider))
            .where((h) => h.weekdays.contains(now.weekday) && !h.isDoneOn(now))
            .toList();
        final prayed = await _value(prayerLogProvider(today));
        final b = StringBuffer('يومك في سطور ☀️\n');
        b.write(
          '\n🕌 الصلاة الجاية ${next.name.ar} ${formatPrayerTime(next.time)} (${formatCountdown(next.time.difference(now))})',
        );
        b.write(
          '\n   صليت ${prayed.values.where((s) => s != PrayerStatus.missed).length} من 5',
        );
        if (tasks.isEmpty) {
          b.write('\n\n✅ مفيش مهام، يومك فاضي');
        } else {
          b.write('\n\n✅ مهامك (${tasks.length}) ابدأ بالأولى:');
          for (final t in tasks.take(5)) {
            b.write('\n• ${t.title}');
          }
        }
        if (habits.isNotEmpty) {
          b.write(
            '\n\n🔥 عادات فاضلة: ${habits.map((h) => '${h.emoji} ${h.title}').join('، ')}',
          );
        }
        return _reply(b.toString());

      case AskHelp():
        return _reply(quickHelpText);
    }
  }
}

final quickAssistantProvider = Provider((ref) => QuickAssistant(ref));
