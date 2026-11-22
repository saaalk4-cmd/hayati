import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../worship/prayer_service.dart';
import '../worship/prayer_settings.dart';

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.actions = const []});
  final bool fromUser;
  final String text;

  /// ملخص اللي المساعد عمله فعلًا (أضاف مهمة، سجّل مصروف...)
  final List<String> actions;

  Map<String, dynamic> toApi() =>
      {'role': fromUser ? 'user' : 'assistant', 'text': text};
}

/// يتصل بدالة askHayati على Firebase، واللي بدورها بتكلم Claude.
/// مفتاح Claude محفوظ على السيرفر فقط، ومش موجود في التطبيق.
class AssistantService {
  HttpsCallable get _fn =>
      FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
          .httpsCallable(
        'askHayati',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

  Future<ChatMessage> send(
      List<ChatMessage> history, Map<String, dynamic> context) async {
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
  @override
  ChatState build() => const ChatState();

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
      // نبعت آخر 20 رسالة بس عشان الطلب يفضل خفيف
      final recent =
          history.length > 20 ? history.sublist(history.length - 20) : history;
      reply = await ref
          .read(assistantServiceProvider)
          .send(recent, _deviceContext());
    } on FirebaseFunctionsException catch (e) {
      reply = ChatMessage(fromUser: false, text: _errorText(e));
    } catch (_) {
      reply = const ChatMessage(
        fromUser: false,
        text: 'معرفتش أوصل للسيرفر، اتأكد من النت وجرّب تاني.',
      );
    }
    state = ChatState(messages: [...history, reply]);
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

  void clear() => state = const ChatState();
}

final chatProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
