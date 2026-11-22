# حياتي 🌿

تطبيق Android عربي (RTL) لتنظيم الحياة اليومية في مكان واحد: العبادات، المهام، العادات، الفلوس، اليوميات، والمناسبات.
وفيه **مساعد ذكي (Claude)** بيرتّب يومك ويضيف مهامك بالكلام العادي.

- التطبيق: Flutter (أندرويد فقط، وضع طولي) + Riverpod + go_router
- السيرفر: Firebase (Auth + Firestore + Cloud Functions)
- المساعد: دالة `askHayati` على Cloud Functions بتكلم Claude API، ومفتاح Claude موجود على السيرفر بس
- الألوان: أخضر زيتوني + ذهبي ([assets/brand/palette.md](assets/brand/palette.md))

## الحالة: المرحلة 1 ✅

- تسجيل الدخول (جوجل / بريد إلكتروني) + وضع ضيف بيحفظ على الجهاز
- قفل التطبيق برمز PIN + بصمة، وبيتقفل بعد 30 ثانية في الخلفية
- الشاشة الرئيسية «يومي»: التحية، التاريخ الميلادي والهجري، مهام النهارده، آية اليوم
- «مهامي»: إضافة، تعليم كمنتهية، حذف بالسحب
- «مساعد حياتي»: محادثة مع Claude بيقرأ مهامك ويضيف ويعلّم عليها
- وضع نهاري / ليلي / تلقائي
- باقي الأقسام بتعرض «قريبًا إن شاء الله»

الخطة الكاملة في [docs/ROADMAP.md](docs/ROADMAP.md).

## التحميل

كل رفع على `main` بيشغّل GitHub Actions ويبني APK:
**Actions** ← آخر تشغيل ← **Artifacts** ← `hayati-apk`.

> لو أسرار Firebase مش متضافة في GitHub، الـ APK هيشتغل في **وضع الضيف** بس.
> خطوات ربط Firebase وClaude في [docs/SETUP.md](docs/SETUP.md).

## التشغيل محليًا

```bash
flutter pub get
flutter run --dart-define-from-file=env.json   # env.json فيه إعدادات Firebase (مش بيترفع على GitHub)
```

## هيكل المشروع

```
lib/
  core/        الثيم، الألوان، الإعدادات، الراوتر، أدوات مشتركة
  data/        الجلسة (تسجيل الدخول)، المهام، الإعدادات
  features/    today · tasks · assistant · lock · auth · more · placeholder
functions/     Cloud Functions (TypeScript): askHayati ← Claude
firestore.rules
```
