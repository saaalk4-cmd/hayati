import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebase = ref.watch(firebaseReadyProvider);
    final session = ref.read(sessionProvider.notifier);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const Center(child: BrandMark()),
            const SizedBox(height: 24),
            Text(
              'حياتي',
              textAlign: TextAlign.center,
              style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'يومك كله في مكان واحد\nعباداتك، مهامك، فلوسك، وذكرياتك',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 40),
            if (firebase && AppConfig.hasGoogleSignIn)
              FilledButton.icon(
                onPressed: _busy ? null : () => _run(session.signInWithGoogle),
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: const Text('الدخول بحساب جوجل'),
              ),
            if (firebase) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _openEmailSheet(context),
                icon: const Icon(Icons.mail_outline),
                label: const Text('الدخول بالبريد الإلكتروني'),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : () => _run(session.continueAsGuest),
              child: const Text('جرّب من غير حساب'),
            ),
            if (!firebase) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold200.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'النسخة دي مبنية من غير ربط بالسيرفر، فالبيانات هتتحفظ على الموبايل بس، والمساعد الذكي مش هيشتغل.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  void _openEmailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _EmailSheet(),
    );
  }
}

class _EmailSheet extends ConsumerStatefulWidget {
  const _EmailSheet();

  @override
  ConsumerState<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends ConsumerState<_EmailSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(sessionProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await s.registerWithEmail(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await s.signInWithEmail(_email.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'اكتب بريدك الأول');
      return;
    }
    try {
      await ref.read(sessionProvider.notifier).resetPassword(email);
      setState(() => _error = 'بعتنالك رابط تغيير كلمة المرور على بريدك');
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _register ? 'حساب جديد' : 'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (_register) ...[
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسمك'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(),
                  )
                : Text(_register ? 'إنشاء الحساب' : 'دخول'),
          ),
          TextButton(
            onPressed: () => setState(() => _register = !_register),
            child: Text(
              _register ? 'عندي حساب بالفعل' : 'معنديش حساب، عايز أسجّل',
            ),
          ),
          if (!_register)
            TextButton(
              onPressed: _forgot,
              child: const Text('نسيت كلمة المرور'),
            ),
        ],
      ),
    );
  }
}
