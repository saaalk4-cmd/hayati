# حياتي: تعليمات للمساعد

- تطبيق Flutter عربي RTL، **أندرويد فقط، وضع طولي**. الواجهة كلها بالعامية المصرية.
- Flutter 3.50+: الـ Material بييجي من `package:material_ui/material_ui.dart` (مش `package:flutter/material.dart`).
- إدارة الحالة: Riverpod 3 (`Notifier` / `NotifierProvider`)، والتنقل: go_router (`lib/core/router/app_router.dart`).
- الألوان من `AppColors` بس (أخضر + ذهبي). أي تصميم على Canva يلتزم بـ `assets/brand/palette.md`.
- مفيش أي مفاتيح أو أسرار في الكود: إعدادات Firebase بتيجي من `--dart-define`، ومفتاح Claude سرّ على Firebase.
- البيانات: `users/{uid}/...` في Firestore. وضع الضيف بيستخدم `SharedPreferences` بنفس الواجهة (`TasksRepository`).
- المساعد: `functions/src/index.ts`. أي قسم جديد يضيف أدوات (`betaZodTool`) تقرأ وتكتب بيانات المستخدم ده بس.
- المحتوى الديني: متضيفش أي آية أو حديث من غير مرجع واضح (السورة:الآية).
- قبل أي commit: `flutter analyze` و `flutter test` و `cd functions && npx tsc --noEmit`.
