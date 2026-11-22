import 'package:material_ui/material_ui.dart';

/// ملخص سياسة الخصوصية جوه التطبيق (النص الكامل في docs/PRIVACY.md)
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = [
    (
      'إيه البيانات اللي بنحفظها؟',
      'اللي إنت بتكتبه بس: المهام، العادات، الصلوات، القرآن، الفلوس، اليوميات، والمناسبات. وكمان اسمك وإيميلك لو سجّلت بحساب.',
    ),
    (
      'بتتحفظ فين؟',
      'في وضع الضيف: على موبايلك بس. لو سجّلت بحساب: على Google Firebase، وكل مستخدم يقدر يوصل لبياناته هو بس.',
    ),
    (
      'الموقع',
      'بنستخدم موقعك على الموبايل نفسه بس عشان نحسب مواقيت الصلاة والقبلة، ومش بنرفعه على أي سيرفر.',
    ),
    (
      'المساعد الذكي',
      'لما تكلم المساعد، رسالتك والبيانات اللي محتاجها (زي مهامك ومواقيت الصلاة) بتتبعت لخدمة Claude من Anthropic عشان يرد عليك. مش بنستخدمها في إعلانات، ومش بنبيعها لحد.',
    ),
    ('الإعلانات والتتبع', 'مفيش إعلانات، ومفيش أدوات تتبع.'),
    (
      'حقوقك',
      'تقدر تصدّر كل بياناتك كملف، وتقدر تمسح حسابك وكل بياناتك نهائيًا، من «المزيد» ← «بياناتي».',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, body) in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: text.bodyMedium?.copyWith(height: 1.7)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
