import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/date_utils.dart';
import '../../data/user_store.dart';
import '../worship/prayer_service.dart';
import '../worship/prayer_settings.dart';

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.actions = const [],
    this.isError = false,
  });
  final bool fromUser;
  final String text;

  /// رسالة خطأ من التطبيق (مش من المساعد): مش بتتبعت ولا بتتحفظ
  final bool isError;

  /// ملخص اللي المساعد عمله فعلًا (أضاف مهمة، سجّل مصروف...)
  final List<String> actions;

  Map<String, dynamic> toApi() => {
    'role': fromUser ? 'user' : 'assistant',
    'text': text,
  };

  Map<String, dynamic> toMap() => {
    'u': fromUser,
    't': text,
    if (actions.isNotEmpty) 'a': actions,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    fromUser: (m['u'] as bool?) ?? false,
    text: (m['t'] as String?) ?? '',
    actions: ((m['a'] as List?) ?? const []).cast<String>(),
  );
}

/// بنحفظ آخر 40 رسالة بس
const _maxSaved = 40;

/// يتصل بدالة askHayati على Firebase، واللي بدورها بتكلم Claude.
/// مفتاح Claude محفوظ على السيرفر فقط، ومش موجود في التطبيق.
class AssistantService {
  HttpsCallable get _fn =>
      FirebaseFunctions.instanceFor(
        region: AppConfig.functionsRegion,
      ).httpsCallable(
        'askHayati',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

  Future<ChatMessage> send(
    List<ChatMessage> history,
    Map<String, dynamic> context,
  ) async {
    final now = DateTime.now();
    final res = await _fn.call<Map<String, dynamic>>({
      'messages': history.map((m) => m.toApi()).toList(),
      'localTime': now.toIso8601String(),
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'context': context,
    });
    final data = Map<String, dynamic>.from(res.data);
    return ChatMessage(
      fromUser: false,
      text: (data['reply'] ?? '') as String,
      actions: ((data['actions'] ?? const []) as List).cast<String>(),
    );
  }
}

final assistantServiceProvider = Provider((ref) => AssistantService());

class ChatState {
  const ChatState({this.messages = const [], this.sending = false});
  final List<ChatMessage> messages;
  final bool sending;
}

class ChatController extends Notifier<ChatState> {
  bool _loaded = false;

  @override
  ChatState build() {
    ref.watch(userStoreProvider); // لو المستخدم اتغير نحمّل محادثته هو
    _loaded = false;
    Future.microtask(_load);
    return const ChatState();
  }

  /// المحادثة محفوظة: users/{uid}/assistant/chat
  Future<void> _load() async {
    try {
      final d = await ref.read(userStoreProvider).get('assistant', 'chat');
      final list = [
        for (final e in (d?['messages'] as List?) ?? const [])
          ChatMessage.fromMap((e as Map).cast<String, dynamic>()),
      ];
      if (!_loaded && state.messages.isEmpty && list.isNotEmpty) {
        state = ChatState(messages: list);
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save(List<ChatMessage> messages) async {
    final keep = messages.where((m) => !m.isError).toList();
    final tail = keep.length > _maxSaved
        ? keep.sublist(keep.length - _maxSaved)
        : keep;
    try {
      await ref.read(userStoreProvider).merge('assistant', 'chat', {
        'messages': [for (final m in tail) m.toMap()],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;
    final history = [
      ...state.messages,
      ChatMessage(fromUser: true, text: trimmed),
    ];
    state = ChatState(messages: history, sending: true);
    ChatMessage reply;
    try {
      // نبعت آخر 20 رسالة بس عشان الطلب يفضل خفيف (من غير رسايل الأخطاء)
      final clean = history.where((m) => !m.isError).toList();
      final start = clean.length > 20 ? clean.length - 20 : 0;
      // لازم أول رسالة تكون من المستخدم
      var recent = clean.sublist(start);
      while (recent.isNotEmpty && !recent.first.fromUser) {
        recent = recent.sublist(1);
      }
      reply = await ref
          .read(assistantServiceProvider)
          .send(recent, _deviceContext());
    } on FirebaseFunctionsException catch (e) {
      reply = ChatMessage(fromUser: false, text: _errorText(e), isError: true);
    } catch (_) {
      reply = const ChatMessage(
        fromUser: false,
        text: 'معرفتش أوصل للسيرفر، اتأكد من النت وجرّب تاني.',
        isError: true,
      );
    }
    state = ChatState(messages: [...history, reply]);
    if (!reply.isError) _save(state.messages);
  }

  /// معلومات محسوبة على الموبايل (المواقيت مرتبطة بموقع الجهاز)
  Map<String, dynamic> _deviceContext() {
    final settings = ref.read(prayerSettingsProvider);
    final times = computePrayerTimes(settings, DateTime.now());
    final next = nextPrayer(settings, DateTime.now());
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return {
      'place': settings.placeLabel,
      'prayerTimes': {
        for (final p in PrayerName.values) p.name: hm(times[p]),
        'sunrise': hm(times.sunrise),
      },
      'nextPrayer': {'name': next.name.name, 'time': hm(next.time)},
      'hijri': HayatiDates.hijri(DateTime.now()),
    };
  }

  String _errorText(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'لازم تسجّل الدخول الأول عشان تستخدم المساعد.';
      case 'resource-exhausted':
        return e.message ?? 'وصلت للحد اليومي للمساعد، جرّب بكرة إن شاء الله.';
      case 'not-found':
        return 'المساعد لسه ما اتفعّلش على السيرفر (راجع docs/SETUP.md).';
      default:
        return 'حصلت مشكلة في المساعد، جرّب تاني بعد شوية.';
    }
  }

  void clear() {
    state = const ChatState();
    _save(const []);
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// اقتراحات على حسب وقت اليوم (بتظهر في شاشة المساعد)
List<String> smartSuggestions(DateTime now) {
  final h = now.hour;
  final friday = now.weekday == DateTime.friday;
  return [
    if (h >= 4 && h < 12) ...[
      'رتّبلي يومي النهارده',
      'إيه المهام المطلوبة النهارده؟',
    ],
    if (h >= 12 && h < 18) ...[
      'فاضل قد إيه على الصلاة الجاية؟',
      'صرفت كام النهارده؟',
    ],
    if (h >= 18 || h < 4) ...[
      'لخّصلي يومي',
      'إيه اللي لسه ما خلصتهوش؟',
      'اكتبلي يومية النهارده',
    ],
    if (friday) 'ضيف مهمة: قراءة سورة الكهف',
    'لخّصلي أسبوعي',
    'سجّل إني صليت الضهر في المسجد',
  ];
}
