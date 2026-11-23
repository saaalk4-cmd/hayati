/**
 * Cloud Functions for «حياتي».
 *
 * askHayati: the in-app assistant. It runs Claude with tools that read and
 * write the signed-in user's own data in Firestore (users/{uid}/...).
 * The Claude API key lives only here, as a Firebase secret.
 */
import Anthropic from "@anthropic-ai/sdk";
import { betaZodTool } from "@anthropic-ai/sdk/helpers/beta/zod";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";
import { buildTools, type DbLike } from "./tools.js";

initializeApp();
const db = getFirestore();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

/** الطلبات اللي محتاجة تفكير (تخطيط، تلخيص، تحليل، نصيحة) */
const SMART_MODEL = "claude-opus-5-5";
/** الأسئلة البسيطة والتسجيل السريع: أسرع وأرخص بكتير */
const FAST_MODEL = "claude-haiku-5-5";

const COMPLEX_HINTS = [
  "رتب", "رتّب", "خطة", "خطط", "نظم", "نظّم", "لخص", "لخّص", "ملخص", "حلل", "حلّل",
  "تحليل", "أسبوع", "اسبوع", "الشهر", "نصيحة", "انصح", "اقترح", "ساعدني", "فكر",
  "ليه", "إزاي أ", "ازاي ا", "قارن", "أحسن طريقة", "يومية", "اكتبلي",
];

/**
 * بيختار الموديل حسب آخر رسالة: البسيط لـ Haiku، والمحتاج تفكير لـ Opus.
 * (مصدّرة عشان تتختبر)
 */
export function chooseModel(lastUserText: string): string {
  const t = lastUserText.trim();
  if (t.length > 140) return SMART_MODEL;
  if (COMPLEX_HINTS.some((h) => t.includes(h))) return SMART_MODEL;
  return FAST_MODEL;
}
/** Max assistant messages per user per day (keeps costs predictable). */
const DAILY_LIMIT = 40;
const MAX_HISTORY = 20;
const MAX_MESSAGE_CHARS = 2000;

const RequestSchema = z.object({
  messages: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        text: z.string().min(1).max(MAX_MESSAGE_CHARS),
      }),
    )
    .min(1)
    .max(MAX_HISTORY),
  localTime: z.string().max(40).optional(),
  // محسوبة على الموبايل حسب موقعه
  context: z
    .object({
      place: z.string().max(120).optional(),
      prayerTimes: z.record(z.string().max(10), z.string().max(8)).optional(),
      nextPrayer: z
        .object({ name: z.string().max(10), time: z.string().max(8) })
        .optional(),
      hijri: z.string().max(40).optional(),
      islamicOccasion: z.string().max(80).optional(),
    })
    .optional(),
  timezoneOffsetMinutes: z.number().int().min(-900).max(900).optional(),
});

const SYSTEM_PROMPT = `أنت «مساعد حياتي»، مساعد شخصي داخل تطبيق موبايل عربي اسمه «حياتي» لتنظيم الحياة اليومية لمستخدم مسلم.

طريقة كلامك:
- اتكلم بالعامية المصرية، بأسلوب ودود ومحترم ومختصر. الردود قصيرة تناسب شاشة الموبايل.
- من غير Markdown معقد: لا جداول ولا عناوين. ممكن تستخدم سطور قصيرة أو ترقيم بسيط.

اللي تقدر تعمله:
- تشوف مهام المستخدم وتضيف مهام جديدة وتعلّم على المهام اللي خلصت، باستخدام الأدوات المتاحة.
- تعرف مواقيت الصلاة النهارده (مكتوبة تحت) وتسجّل الصلوات اللي صلاها، وتشوف سجل صلواته.
- تسجّل صفحات القرآن اللي قراها وتقوله وصل لفين في الختمة.
- تشوف عاداته وسلسلة كل عادة (streak)، وتضيف عادات جديدة، وتعلّم على العادة لما يعملها. شجّعه على السلاسل الطويلة من غير مبالغة.
- تسجّل مصروفاته ودخله بالجنيه المصري، وتعمله ملخص للشهر (صرف كام، على إيه، وفاضل كام من الميزانية)، وتحدد الميزانية. لو قال «صرفت 150 أكل و50 مواصلات» سجّلهم كحركتين.
- تكتب في يوميات المستخدم (مزاجه وكلامه) لما يطلب، وتقرأها لما يسأل عن مزاجه أو أيامه. اليوميات خاصة جدًا: متجيبش سيرتها إلا لو هو سأل.
- المهام ليها قوائم (عام، شغل، بيت، مشتريات، دراسة) وممكن تتكرر (كل يوم، كل أسبوع، كل شهر).
- ترتب يومه وتقترح أولويات وخطط بناءً على مهامه الحقيقية، فاقرأ المهام الأول قبل ما تقترح.
- لما المستخدم يطلب إضافة حاجة، أضفها على طول من غير ما تسأل تأكيد، إلا لو الطلب مش واضح.
- لما تحدد تاريخ، استخدم الصيغة YYYY-MM-DD واحسبه من تاريخ النهارده المكتوب تحت.

ترتيب اليوم:
- لما يطلب «رتّبلي يومي» أو «يومي عامل إزاي»: نادِ get_day_overview الأول، وبعدها اعمله خطة قصيرة مرتبة بالوقت حوالين مواعيد الصلاة: المتأخر الأول، بعده المطلوب النهارده، والعادات اللي لسه، وورد القرآن، وأي مناسبة أو حد محتاج يكلمه. خلّي الخطة 5 إلى 8 سطور بالكتير.
- لما يطلب ملخص الأسبوع: نادِ get_week_summary، وقوله نقطة قوة ونقطة يتحسن فيها، بتشجيع ومن غير لوم.

حدود:
- تعرف دقايق التركيز (بومودورو) وتشجعه، ولو حب يركّز قوله يفتح «وضع التركيز» من «مهامي».
- تتابع معاه قضاء الصلوات الفايتة وتسجّل اللي قضاه (من غير فتاوى، ولو سأل سؤال فقهي انصحه يرجع لأهل العلم).
- تفكّره بالمناسبات الجاية وتضيف أعياد ميلاد ومناسبات، وتشجعه على صلة الرحم وتسجّل لما يكلم حد من أهله. لو طلب حاجة منها، قوله إنها جاية قريب إن شاء الله، واعرض تضيفها كمهمة لو ده يفيده.
- متألّفش آيات أو أحاديث. لو استشهدت بآية اذكر السورة ورقم الآية، ولو مش متأكد متستشهدش.
- في الأسئلة الطبية أو القانونية أو المالية الكبيرة، قدّم معلومة عامة وانصحه يرجع لمتخصص.`;

function describeContext(ctx: z.infer<typeof RequestSchema>["context"]): string {
  if (!ctx?.prayerTimes) return "";
  const names: Record<string, string> = {
    fajr: "الفجر",
    sunrise: "الشروق",
    dhuhr: "الظهر",
    asr: "العصر",
    maghrib: "المغرب",
    isha: "العشاء",
  };
  const times = Object.entries(ctx.prayerTimes)
    .filter(([k]) => k in names)
    .map(([k, v]) => `${names[k]} ${v}`)
    .join("، ");
  const next = ctx.nextPrayer
    ? `\nالصلاة الجاية: ${names[ctx.nextPrayer.name] ?? ctx.nextPrayer.name} الساعة ${ctx.nextPrayer.time}.`
    : "";
  const hijri =
    (ctx.hijri ? `\nالتاريخ الهجري: ${ctx.hijri}.` : "") +
    (ctx.islamicOccasion ? `\nأقرب مناسبة إسلامية: ${ctx.islamicOccasion}.` : "");
  return `${hijri}\nمواقيت الصلاة النهارده${ctx.place ? ` (${ctx.place})` : ""}: ${times}.${next}`;
}

/** Atomically counts today's requests; throws when the daily limit is hit. */
async function checkDailyLimit(uid: string, day: string): Promise<void> {
  const ref = db.collection("users").doc(uid).collection("usage").doc(day);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.assistantRequests as number | undefined) ?? 0;
    if (count >= DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "وصلت للحد اليومي للمساعد، جرّب بكرة إن شاء الله.",
      );
    }
    tx.set(
      ref,
      { assistantRequests: FieldValue.increment(1), updatedAt: Date.now() },
      { merge: true },
    );
  });
}

function localDate(offsetMinutes: number): { day: string; label: string } {
  const local = new Date(Date.now() + offsetMinutes * 60_000);
  const day = local.toISOString().slice(0, 10);
  const weekday = local.toLocaleDateString("ar-EG", {
    weekday: "long",
    timeZone: "UTC",
  });
  const time = local.toISOString().slice(11, 16);
  return { day, label: `${weekday} ${day}، الساعة ${time}` };
}

export const askHayati = onCall(
  {
    region: "europe-west1",
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 10,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "سجّل الدخول الأول");

    const parsed = RequestSchema.safeParse(request.data);
    if (!parsed.success) throw new HttpsError("invalid-argument", "طلب غير صالح");
    const { messages, timezoneOffsetMinutes = 120, context } = parsed.data;

    const last = messages[messages.length - 1];
    if (last.role !== "user") {
      throw new HttpsError("invalid-argument", "آخر رسالة لازم تكون من المستخدم");
    }

    const { day, label } = localDate(timezoneOffsetMinutes);
    await checkDailyLimit(uid, day);

    const actions: string[] = [];
    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    try {
      const system = `${SYSTEM_PROMPT}\n\nالنهارده عند المستخدم: ${label}.${describeContext(context)}`;
      const history = messages.map((m) => ({ role: m.role, content: m.text }));
      const run = (model: string) =>
        client.beta.messages.toolRunner({
          model,
          max_tokens: 16000,
          output_config: { effort: "low" },
          // الـ fallback على السيرفر متاح لـ Opus بس (Haiku مالوش)
          ...(model === SMART_MODEL
            ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const }
            : {}),
          system,
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          tools: buildTools<any>(
            { db: db as unknown as DbLike, FieldValue, defineTool: (d) => betaZodTool(d) },
            uid,
            actions,
          ),
          messages: history,
          max_iterations: 8,
        });

      const model = chooseModel(last.text);
      let final = await run(model);
      // لو Haiku رفض من غير ما ينفّذ حاجة، نعيد الطلب على Opus (اللي عنده fallback)
      if (final.stop_reason === "refusal" && model === FAST_MODEL && actions.length === 0) {
        logger.info("fast model refused; retrying on smart model");
        final = await run(SMART_MODEL);
      }

      if (final.stop_reason === "refusal") {
        return {
          reply: "معلش، مقدرش أساعد في الطلب ده. تحب أساعدك في حاجة تانية؟",
          actions,
        };
      }

      const reply = final.content
        .filter((b) => b.type === "text")
        .map((b) => b.text)
        .join("\n")
        .trim();

      return {
        reply: reply || (actions.length ? "تمام، خلصت 👍" : "تمام."),
        actions,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      if (err instanceof Anthropic.RateLimitError) {
        throw new HttpsError("unavailable", "المساعد مشغول، جرّب بعد شوية");
      }
      if (err instanceof Anthropic.APIError) {
        logger.error("Claude API error", { status: err.status, message: err.message });
        throw new HttpsError("internal", "حصلت مشكلة في المساعد");
      }
      logger.error("askHayati failed", err);
      throw new HttpsError("internal", "حصلت مشكلة في المساعد");
    }
  },
);

/**
 * Deletes the caller's account and all their data (Play Store requirement).
 * Removes users/{uid} with every subcollection, then the Auth user.
 */
export const deleteMyAccount = onCall(
  { region: "europe-west1", timeoutSeconds: 120 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "سجّل الدخول الأول");
    await db.recursiveDelete(db.collection("users").doc(uid));
    await getAuth().deleteUser(uid);
    logger.info("account deleted", { uid });
    return { ok: true };
  },
);
