import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/brand_mark.dart';
import 'lock_service.dart';
import 'pin_pad.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    final lock = ref.read(lockProvider);
    if (!lock.biometrics) return;
    await ref.read(lockProvider.notifier).unlockWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const BrandMark(size: 72),
            const SizedBox(height: 20),
            Text(
              'اكتب رمز الدخول',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: _error == null
                  ? null
                  : Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
            ),
            const Spacer(),
            PinPad(
              onCompleted: (pin) async {
                final ok = await ref
                    .read(lockProvider.notifier)
                    .unlockWithPin(pin);
                if (!ok) setState(() => _error = 'الرمز غلط، جرّب تاني');
                return ok;
              },
              extraAction: lock.biometrics
                  ? IconButton(
                      iconSize: 32,
                      onPressed: _tryBiometrics,
                      icon: const Icon(Icons.fingerprint),
                    )
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
