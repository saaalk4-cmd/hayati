import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'journal_repository.dart';
import '../../core/utils/date_utils.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, required this.day});
  final String day;

  @override
  ConsumerState<JournalEditorScreen> createState() => _State();
}

class _State extends ConsumerState<JournalEditorScreen> {
  final _text = TextEditingController();
  final _gratitude = TextEditingController();
  int? _mood;
  bool _loaded = false;
  Timer? _debounce;
  // بنحتفظ بالـ repository عشان نحفظ في dispose (ref مش متاح هناك)
  JournalRepository? _repo;

  @override
  void dispose() {
    _debounce?.cancel();
    _save();
    _text.dispose();
    _gratitude.dispose();
    super.dispose();
  }

  void _load(List<JournalEntry> all) {
    if (_loaded) return;
    final e = all.where((x) => x.day == widget.day).firstOrNull;
    _text.text = e?.text ?? '';
    _gratitude.text = e?.gratitude ?? '';
    _mood = e?.mood;
    _loaded = true;
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    if (!_loaded) return;
    final e = JournalEntry(
      day: widget.day,
      mood: _mood,
      text: _text.text,
      gratitude: _gratitude.text,
      updatedAt: DateTime.now(),
    );
    final repo = _repo;
    if (repo == null) return;
    e.isEmpty ? repo.delete(widget.day) : repo.save(e);
  }

  @override
  Widget build(BuildContext context) {
    _repo = ref.read(journalRepositoryProvider);
    final all = ref.watch(journalProvider).value;
    if (all == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _load(all);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(arFormat('EEEE d MMMM', DateTime.parse(widget.day))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'مزاجك النهارده عامل إزاي؟',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in moodEmojis.entries)
                GestureDetector(
                  onTap: () {
                    setState(() => _mood = _mood == m.key ? null : m.key);
                    _changed();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _mood == m.key
                          ? scheme.secondary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                    child: Text(m.value, style: const TextStyle(fontSize: 36)),
                  ),
                ),
            ],
          ),
          if (_mood != null)
            Center(
              child: Text(
                moodNames[_mood]!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            onChanged: (_) => _changed(),
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'إيه اللي حصل النهارده؟ حسيت بإيه؟',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gratitude,
            onChanged: (_) => _changed(),
            minLines: 2,
            maxLines: null,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.favorite_outline),
              hintText: 'الحمد لله على...',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'بيتحفظ تلقائي ✓',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
