# حياتي: تعليمات للمساعد

- تطبيق Flutter عربي RTL، **أندرويد فقط، وضع طولي**. الواجهة كلها بالعامية المصرية.
- Flutter 3.50+: الـ Material بييجي من `package:material_ui/material_ui.dart` (مش `package:flutter/material.dart`).
- إدارة الحالة: Riverpod 3 (`Notifier` / `NotifierProvider`)، والتنقل: go_router (`lib/core/router/app_router.dart`).
- الألوان من الثيم: `context.palette` (زمرّدي ليلي الأساسي، كحلي ملكي، رملي دافي في `lib/core/theme/palettes.dart`). ممنوع الأبيض الخالص أو ألوان ثابتة للخلفيات. `AppColors` للذهبي/الأخضر الثابت بس. أي تصميم على Canva يلتزم بالثيم الغامق.
- الأزرار: متستخدمش `Size.fromHeight` (بيكسر الأزرار جوه Row). الحركة من `core/widgets/motion.dart` (`staggered`، `PopOnChange`، `showCelebration`).
- مفيش أي مفاتيح أو أسرار في الكود: إعدادات Firebase بتيجي من `--dart-define`، ومفتاح Claude سرّ على Firebase.
- البيانات: `users/{uid}/...` في Firestore. وضع الضيف بيستخدم `SharedPreferences` بنفس الواجهة (`TasksRepository` للمهام، و`UserStore` لأي مستند تاني). أي مجموعة جديدة لازم تتضاف في `firestore.rules`.
- أدوات Claude في `functions/src/tools.ts` (مشتركة): أي قسم جديد يضيف أداة هناك تقرأ وتكتب بيانات المستخدم ده بس، ومن غير أدوات حذف.
- سيرفر توصيل Claude (MCP Connector): `connector/` على Cloudflare Workers (`https://hayati.saaalk4.workers.dev/mcp`). بيكلّم Firestore بتوكن المستخدم نفسه (القواعد هي الحماية). النشر: `cd connector && npx wrangler deploy`.
- المساعد جوه التطبيق: الأوامر السريعة المجانية (`lib/features/assistant/quick_commands.dart`). مساعد Claude المدفوع (`functions/src/index.ts`) مستخبي ويتفعّل بـ `--dart-define=REMOTE_ASSISTANT=true`.
- المحتوى الديني: متضيفش أي آية أو حديث من غير مرجع واضح (السورة:الآية).
- أي مجموعة بيانات جديدة لازم تتضاف كمان في `userCollections` في `lib/features/account/account_data.dart` (عشان التصدير) وفي `firestore.rules`.
- صور المتجر: `python3 tool/store_screenshots.py` بعد اللقطات.
- لقطات شاشة للمراجعة: `flutter test test_screens --update-goldens` (النتيجة في `test_screens/out`).
- قبل أي commit: `flutter analyze` و `flutter test` و `cd functions && npx tsc --noEmit` و `cd connector && npm run typecheck && npm test`.
