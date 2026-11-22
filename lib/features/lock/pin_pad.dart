import 'package:material_ui/material_ui.dart';

/// لوحة أرقام لإدخال رمز من 4 أرقام
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.extraAction});

  /// يرجّع true لو الرمز اتقبل؛ لو false بنمسح الإدخال
  final Future<bool> Function(String pin) onCompleted;
  final Widget? extraAction;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  static const _length = 4;
  String _pin = '';
  bool _checking = false;

  Future<void> _tap(String d) async {
    if (_checking || _pin.length >= _length) return;
    setState(() => _pin += d);
    if (_pin.length == _length) {
      _checking = true;
      final ok = await widget.onCompleted(_pin);
      _checking = false;
      if (mounted && !ok) setState(() => _pin = '');
    }
  }

  void _back() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String d) => SizedBox(
          width: 76,
          height: 76,
          child: TextButton(
            style: TextButton.styleFrom(shape: const CircleBorder()),
            onPressed: () => _tap(d),
            child: Text(d,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? scheme.secondary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map(key).toList(),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 76, height: 76, child: widget.extraAction),
              key('0'),
              SizedBox(
                width: 76,
                height: 76,
                child: IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
