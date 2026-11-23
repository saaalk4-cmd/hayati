import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/notifications.dart';
import '../../data/session.dart';
import '../worship/prayer_settings.dart';

const onboardedKey = 'onboarded_v1';
const userNameKey = 'user_name';

/// بيتغير لما المستخدم يخلّص التعريف (عشان الراوتر يعيد التوجيه)
final onboardedProvider = NotifierProvider<OnboardedController, bool>(
  OnboardedController.new,
);

class OnboardedController extends Notifier<bool> {
  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(onboardedKey) ?? false;

  Future<void> finish(String name) async {
    final prefs = ref.read(sharedPrefsProvider);
    if (name.trim().isNotEmpty) await prefs.setString(userNameKey, name.trim());
    await prefs.setBool(onboardedKey, true);
    state = true;
  }
}

/// الاسم اللي المستخدم كتبه في التعريف (لو مفيش اسم من الحساب)
final localNameProvider = Provider<String?>((ref) {
  ref.watch(onboardedProvider);
  return ref.read(sharedPrefsProvider).getString(userNameKey);
});

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  int _index = 0;

  static const _slides = [
    (
      Icons.wb_sunny_rounded,
      'يومك كله في مكان واحد',
      'الصلاة، المهام، العادات، الفلوس، واليوميات. كلها في شاشة واحدة بتبدأ بيها يومك.',
    ),
    (
      Icons.mosque_rounded,
      'عباداتك بهدوء',
      'مواقيت الصلاة حسب مكانك، والأذان، والأذكار بعدّاد، وورد القرآن، والقبلة.',
    ),
    (
      Icons.auto_awesome,
      'مساعد ذكي بيفهمك',
      'قوله «صرفت 100 جنيه أكل» أو «رتّبلي يومي»، وهو يسجّل ويخطط معاك.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _index == _slides.length + 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: last
                  ? const SizedBox(height: 48)
                  : TextButton(
                      onPressed: () => _page.animateToPage(
                        _slides.length,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('تخطّي'),
                    ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final (icon, title, body) in _slides)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.emerald700,
                                  AppColors.emerald900,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald900.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: 64,
                              color: AppColors.gold500,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const BrandMark(size: 96),
                        const SizedBox(height: 32),
                        Text(
                          'نناديك بإيه؟',
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _name,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _page.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                          decoration: const InputDecoration(hintText: 'اسمك'),
                        ),
                      ],
                    ),
                  ),
                  _PermissionsPage(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i <= _slides.length + 1; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.gold500
                          : AppColors.emerald100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _page.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                child: Text(last ? 'يلا نبدأ' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() =>
      ref.read(onboardedProvider.notifier).finish(_name.text);
}

/// آخر صفحة: نطلب الأذونات بشرح بسيط (ويقدر يتخطاها)
class _PermissionsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<_PermissionsPage> {
  bool _loc = false;
  bool _notif = false;
  bool _busy = false;

  Future<void> _askLocation() async {
    setState(() => _busy = true);
    final err = await ref
        .read(prayerSettingsProvider.notifier)
        .detectLocation();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loc = err == null;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _askNotifications() async {
    final ok = await AppNotifications.instance.requestPermissions();
    if (mounted) setState(() => _notif = ok);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget item(
      IconData icon,
      String title,
      String body,
      bool done,
      VoidCallback onTap,
    ) => Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.emerald700, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(body),
        trailing: done
            ? const Icon(Icons.check_circle, color: AppColors.emerald500)
            : TextButton(
                onPressed: _busy ? null : onTap,
                child: const Text('اسمح'),
              ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'خلّينا نجهّز التطبيق',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'تقدر تغيّر ده في أي وقت من الإعدادات',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          item(
            Icons.location_on_outlined,
            'الموقع',
            'عشان مواقيت الصلاة والقبلة تبقى دقيقة. مش بيترفع على أي سيرفر.',
            _loc,
            _askLocation,
          ),
          const SizedBox(height: 8),
          item(
            Icons.notifications_active_outlined,
            'الإشعارات',
            'للأذان، وملخص الصبح، وتذكير المهام والعادات.',
            _notif,
            _askNotifications,
          ),
        ],
      ),
    );
  }
}
