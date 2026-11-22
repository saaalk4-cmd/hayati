# إعداد Firebase ومساعد Claude

الخطوات دي بتتعمل **مرة واحدة**. من غيرها التطبيق شغال في وضع الضيف بس.

## 1) مشروع Firebase

1. ادخل على https://console.firebase.google.com واعمل مشروع جديد باسم `hayati`.
2. **Authentication** ← Sign-in method ← فعّل **Google** و **Email/Password**.
3. **Firestore Database** ← Create database (اختار منطقة `europe-west1` أو أقرب منطقة ليك).
4. **Project settings** ← Your apps ← Add app ← **Android**:
   - Package name: `com.hayati.hayati`
   - SHA-1: من مفتاح التوقيع (الخطوة 3 تحت)
5. من نفس الصفحة خد القيم دي (هتلاقيها في ملف `google-services.json`):

| GitHub Secret | من فين |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
| `FIREBASE_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |
| `FIREBASE_STORAGE_BUCKET` | `project_info.storage_bucket` |
| `GOOGLE_SERVER_CLIENT_ID` | الـ OAuth client اللي `client_type` بتاعه `3` (Web client) |

ضيفهم في GitHub: الريبو ← **Settings** ← **Secrets and variables** ← **Actions** ← **New repository secret**.

## 2) خطة Blaze

Cloud Functions محتاجة خطة **Blaze** (الدفع حسب الاستخدام). للاستخدام الشخصي غالبًا بتكون مجانية أو قريبة من المجانية. يُفضّل تعمل **Budget alert** من Google Cloud Billing.

## 3) مفتاح التوقيع (عشان تسجيل الدخول بجوجل)

تسجيل الدخول بجوجل محتاج مفتاح توقيع ثابت، وبصمته (SHA-1) تكون متسجلة في Firebase:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hayati
keytool -list -v -keystore release.jks -alias hayati   # انسخ SHA-1 و SHA-256 وحطهم في Firebase
base64 -w0 release.jks                                # الناتج ده هو ANDROID_KEYSTORE_BASE64
```

ضيف في GitHub Secrets: `ANDROID_KEYSTORE_BASE64`، `ANDROID_KEYSTORE_PASSWORD`، `ANDROID_KEY_ALIAS` (`hayati`)، `ANDROID_KEY_PASSWORD`.

> ⚠️ احتفظ بملف `release.jks` وكلمة السر في مكان آمن. لو ضاعوا، مش هتقدر تحدّث التطبيق على Play Store.

## 4) مساعد Claude (Cloud Functions)

1. اعمل مفتاح API من https://platform.claude.com (Settings ← API Keys).
2. على جهازك (محتاج Node.js 22):

```bash
npm install -g firebase-tools
firebase login
cp .firebaserc.example .firebaserc        # وحط فيه الـ project id
firebase functions:secrets:set ANTHROPIC_API_KEY   # الصق المفتاح لما يطلبه
cd functions && npm install && cd ..
firebase deploy --only functions,firestore
```

### إعدادات المساعد (في `functions/src/index.ts`)

- الموديل: `claude-opus-5-5` بـ effort منخفض عشان الردود تبقى سريعة
- **الحد اليومي**: 40 رسالة لكل مستخدم (`DAILY_LIMIT`)
- مفعّل **fallback** على السيرفر: لو الموديل رفض طلب، Anthropic بتعيد تشغيله على موديل بديل تلقائيًا
- المساعد بيوصل لمهام المستخدم اللي طالبه بس (`users/{uid}/tasks`)

## 5) جرّب

اعمل push على `main` ← نزّل الـ APK من Actions ← سجّل الدخول ← افتح «اسأل حياتي» واكتب: «ضيف مهمة أشتري عيش بكرة».
