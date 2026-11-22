import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'lock_service.dart';
import 'pin_pad.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _first;
  String? _error;
  int _padKey = 0;

  Future<bool> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
        _padKey++;
      });
      return true;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'الرمزين مش زي بعض، ابدأ من الأول';
        _padKey++;
      });
      return false;
    }
    final lock = ref.read(lockProvider.notifier);
    var bio = false;
    if (await lock.canUseBiometrics() && mounted) {
      bio =
          await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('تفعيل البصمة؟'),
              content: const Text('تقدر تفتح التطبيق ببصمتك بدل الرمز.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('لا'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('فعّل'),
                ),
              ],
            ),
          ) ??
          false;
    }
    await lock.enable(pin, biometrics: bio);
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قفل التطبيق')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              _first == null
                  ? 'اختار رمز من 4 أرقام'
                  : 'اكتب الرمز تاني للتأكيد',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(height: 24, child: _error == null ? null : Text(_error!)),
            const Spacer(),
            PinPad(key: ValueKey(_padKey), onCompleted: _onPin),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
