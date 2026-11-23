import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_colors.dart';
import '../../data/session.dart';
import 'assistant_service.dart';
import '../../core/theme/palettes.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialPrompt});

  /// رسالة بتتبعت تلقائي أول ما الشاشة تفتح (مثلًا «رتّبلي يومي»)
  final String? initialPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _listening = false;

  /// اضغط على المايك وقول طلبك بالعربي، والكلام بيتكتب في الخانة
  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الكلام بالصوت مش متاح، اتأكد من إذن المايك'),
          ),
        );
      }
      return;
    }
    final locales = await _speech.locales();
    final arabic =
        locales
            .where(
              (l) =>
                  l.localeId.startsWith('ar_EG') ||
                  l.localeId.startsWith('ar-EG'),
            )
            .firstOrNull ??
        locales.where((l) => l.localeId.startsWith('ar')).firstOrNull;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _input.text = r.recognizedWords;
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          setState(() => _listening = false);
          _send();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: arabic?.localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final q = widget.initialPrompt;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(sessionProvider) is UserSession) _send(q);
      });
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(t);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final chat = ref.watch(chatProvider);
    final enabled = session is UserSession;

    ref.listen(chatProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('مساعد حياتي'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: 'محادثة جديدة',
              onPressed: () => ref.read(chatProvider.notifier).clear(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !enabled
                ? const _Disabled()
                : chat.messages.isEmpty
                ? _Welcome(
                    onPick: _send,
                    suggestions: smartSuggestions(DateTime.now()),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (chat.sending && i == 0) return const _Typing();
                      final idx =
                          chat.messages.length -
                          1 -
                          (i - (chat.sending ? 1 : 0));
                      return _Bubble(message: chat.messages[idx]);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'بسمعك... 🎙️'
                            : 'اكتب أو اتكلم...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'كلّمه بصوتك',
                    onPressed: enabled && !chat.sending ? _toggleVoice : null,
                    icon: Icon(
                      _listening ? Icons.stop_circle : Icons.mic_none,
                      color: _listening ? AppColors.danger : AppColors.gold700,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: enabled && !chat.sending ? _send : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick, required this.suggestions});
  final void Function(String) onPick;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.auto_awesome, size: 56, color: AppColors.gold500),
        const SizedBox(height: 12),
        Text(
          'أهلًا! أنا مساعدك في «حياتي»',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'أقدر أرتب يومك، أضيف مهام، وأفكّرك باللي ناسيه.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final s in suggestions)
              ActionChip(label: Text(s), onPressed: () => onPick(s)),
          ],
        ),
      ],
    );
  }
}

class _Disabled extends ConsumerWidget {
  const _Disabled();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(firebaseReadyProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          online
              ? 'المساعد الذكي محتاج حساب عشان يحفظ مهامك ويوصل لها.\nسجّل الدخول من «المزيد» ← «الإعدادات» ← «تسجيل الدخول بحساب».'
              : 'المساعد الذكي والحسابات لسه مش متفعّلين في النسخة دي.\nلحد ما يتفعّلوا، كل حاجة شغالة وبياناتك محفوظة على الموبايل.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.fromUser;
    final maxW = MediaQuery.of(context).size.width * 0.8;
    return Align(
      alignment: user
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: user
                  ? scheme.primary
                  : AppColors.gold500.withValues(alpha: 0.14),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(20),
                topEnd: const Radius.circular(20),
                bottomStart: Radius.circular(user ? 4 : 20),
                bottomEnd: Radius.circular(user ? 20 : 4),
              ),
            ),
            child: SelectableText(
              message.text,
              style: TextStyle(
                color: user ? scheme.onPrimary : null,
                height: 1.7,
              ),
            ),
          ),
          // اللي المساعد عمله فعلًا: كبسولات خضرا تحت الرسالة (زي تصميم Canva)
          for (final a in message.actions)
            Container(
              constraints: BoxConstraints(maxWidth: maxW),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.emerald500.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check,
                    size: 16,
                    color: AppColors.emerald700,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      a,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.emerald900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
