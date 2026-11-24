import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/sound/sfx.dart';
import '../../core/notifications.dart';
import '../../core/theme/palettes.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/motion.dart';
import '../../data/tasks_repository.dart';
import '../../data/user_store.dart';

/// دقايق التركيز النهارده: users/{uid}/focus/{yyyy-MM-dd} => {minutes, sessions}
final focusTodayProvider = StreamProvider<(int, int)>((ref) {
  final day = HayatiDates.dayKey(DateTime.now());
  return ref
      .watch(userStoreProvider)
      .watch('focus', day)
      .map(
        (d) => (
          (d?['minutes'] as num?)?.toInt() ?? 0,
          (d?['sessions'] as num?)?.toInt() ?? 0,
        ),
      );
});

enum _Phase { idle, focus, rest }

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _notifId = 5000500;
  int _focusMin = 25;
  final int _restMin = 5;
  _Phase _phase = _Phase.idle;
  DateTime? _endsAt;
  Duration _left = const Duration(minutes: 25);
  bool _paused = false;
  String? _taskId;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _total =>
      Duration(minutes: _phase == _Phase.rest ? _restMin : _focusMin);

  void _start(_Phase phase) {
    final total = Duration(
      minutes: phase == _Phase.rest ? _restMin : _focusMin,
    );
    setState(() {
      _phase = phase;
      _paused = false;
      _left = total;
      _endsAt = DateTime.now().add(total);
    });
    _tick();
    _scheduleEndNotification();
  }

  // الوقت بيتحسب من «امتى هيخلص» فلو التطبيق راح الخلفية ورجع، العدّاد بيفضل مظبوط
  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final end = _endsAt;
      if (end == null || _paused) return;
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        _finish();
      } else {
        setState(() => _left = left);
      }
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    SoundFx.play(Sfx.milestone);
    if (_phase == _Phase.focus) {
      await _logSession(_focusMin);
      if (mounted) showCelebration(context);
      _start(_Phase.rest);
    } else {
      setState(() {
        _phase = _Phase.idle;
        _left = Duration(minutes: _focusMin);
      });
    }
  }

  Future<void> _logSession(int minutes) async {
    final store = ref.read(userStoreProvider);
    final day = HayatiDates.dayKey(DateTime.now());
    final cur = await store.get('focus', day);
    await store.merge('focus', day, {
      'minutes': ((cur?['minutes'] as num?)?.toInt() ?? 0) + minutes,
      'sessions': ((cur?['sessions'] as num?)?.toInt() ?? 0) + 1,
    });
  }

  Future<void> _scheduleEndNotification() async {
    final n = AppNotifications.instance;
    await n.init();
    if (!n.ready || _endsAt == null) return;
    await n.plugin.cancel(id: _notifId);
    try {
      await n.plugin.zonedSchedule(
        id: _notifId,
        scheduledDate: tz.TZDateTime.from(_endsAt!, tz.local),
        notificationDetails: AppNotifications.channel(
          'focus_v2',
          'وضع التركيز',
          'انتهاء جلسة التركيز',
        ),
        androidScheduleMode: await n.scheduleMode(),
        title: _phase == _Phase.focus
            ? '⏱️ خلصت جلسة التركيز'
            : '☕ الراحة خلصت',
        body: _phase == _Phase.focus
            ? 'برافو! خد 5 دقايق راحة'
            : 'يلا نرجع نركّز',
      );
    } catch (_) {}
  }

  void _togglePause() {
    setState(() {
      if (_paused) {
        _endsAt = DateTime.now().add(_left);
        _paused = false;
        _scheduleEndNotification();
      } else {
        _paused = true;
        AppNotifications.instance.plugin.cancel(id: _notifId);
      }
    });
  }

  void _reset() {
    _ticker?.cancel();
    AppNotifications.instance.plugin.cancel(id: _notifId);
    setState(() {
      _phase = _Phase.idle;
      _paused = false;
      _left = Duration(minutes: _focusMin);
    });
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final (minutes, sessions) = ref.watch(focusTodayProvider).value ?? (0, 0);
    final today = HayatiDates.dayKey(DateTime.now());
    final tasks = (ref.watch(tasksProvider).value ?? const [])
        .where(
          (t) =>
              !t.done &&
              (t.dueDate == null || t.dueDate!.compareTo(today) <= 0),
        )
        .toList();
    final progress = _phase == _Phase.idle
        ? 0.0
        : 1 - _left.inMilliseconds / _total.inMilliseconds;

    return Scaffold(
      appBar: AppBar(title: const Text('وضع التركيز')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_phase == _Phase.idle)
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 15, label: Text('15 د')),
                ButtonSegment(value: 25, label: Text('25 د')),
                ButtonSegment(value: 50, label: Text('50 د')),
              ],
              selected: {_focusMin},
              onSelectionChanged: (v) => setState(() {
                _focusMin = v.first;
                _left = Duration(minutes: _focusMin);
              }),
            ),
          const SizedBox(height: 28),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _RingPainter(
                  progress,
                  p.track,
                  _phase == _Phase.rest ? p.primary : p.accent,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fmt(_left),
                        textDirection: TextDirection.ltr,
                        style: text.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(switch (_phase) {
                        _Phase.idle => 'جاهز تركّز؟',
                        _Phase.focus => _paused ? 'متوقف' : 'ركّز 🎯',
                        _Phase.rest => 'استريح ☕',
                      }, style: text.titleMedium?.copyWith(color: p.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (_phase == _Phase.idle && tasks.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _taskId,
              decoration: const InputDecoration(
                labelText: 'هتركّز على إيه؟ (اختياري)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('من غير مهمة')),
                for (final t in tasks.take(20))
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _taskId = v),
            ),
          if (_phase != _Phase.idle && _taskId != null)
            Text(
              tasks.where((t) => t.id == _taskId).firstOrNull?.title ?? '',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          const SizedBox(height: 16),
          if (_phase == _Phase.idle)
            FilledButton.icon(
              onPressed: () => _start(_Phase.focus),
              icon: const Icon(Icons.play_arrow),
              label: const Text('ابدأ'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    label: Text(_paused ? 'كمّل' : 'وقفة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.stop),
                    label: const Text('إنهاء'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Text('⏱️', style: TextStyle(fontSize: 26)),
              title: Text('ركّزت النهارده $minutes دقيقة'),
              subtitle: Text('$sessions جلسة'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.color);
  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 14,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
