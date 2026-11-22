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
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { z } from "zod";

initializeApp();
const db = getFirestore();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const MODEL = "claude-opus-5-5";
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
  timezoneOffsetMinutes: z.number().int().min(-900).max(900).optional(),
});

const SYSTEM_PROMPT = `أنت «مساعد حياتي»، مساعد شخصي داخل تطبيق موبايل عربي اسمه «حياتي» لتنظيم الحياة اليومية لمستخدم مسلم.

طريقة كلامك:
- اتكلم بالعامية المصرية، بأسلوب ودود ومحترم ومختصر. الردود قصيرة تناسب شاشة الموبايل.
- من غير Markdown معقد: لا جداول ولا عناوين. ممكن تستخدم سطور قصيرة أو ترقيم بسيط.

اللي تقدر تعمله:
- تشوف مهام المستخدم وتضيف مهام جديدة وتعلّم على المهام اللي خلصت، باستخدام الأدوات المتاحة.
- ترتب يومه وتقترح أولويات وخطط بناءً على مهامه الحقيقية، فاقرأ المهام الأول قبل ما تقترح.
- لما المستخدم يطلب إضافة حاجة، أضفها على طول من غير ما تسأل تأكيد، إلا لو الطلب مش واضح.
- لما تحدد تاريخ، استخدم الصيغة YYYY-MM-DD واحسبه من تاريخ النهارده المكتوب تحت.

حدود:
- الأقسام دي لسه تحت الإنشاء في التطبيق: الصلاة، العادات، الفلوس، اليوميات، المناسبات. لو طلب حاجة منها، قوله إنها جاية قريب إن شاء الله، واعرض تضيفها كمهمة لو ده يفيده.
- متألّفش آيات أو أحاديث. لو استشهدت بآية اذكر السورة ورقم الآية، ولو مش متأكد متستشهدش.
- في الأسئلة الطبية أو القانونية أو المالية الكبيرة، قدّم معلومة عامة وانصحه يرجع لمتخصص.`;

interface TaskDoc {
  title: string;
  done: boolean;
  dueDate: string | null;
  notes: string | null;
  source: string;
  createdAt: number;
}

function buildTools(uid: string, actions: string[]) {
  const tasks = db.collection("users").doc(uid).collection("tasks");

  const listTasks = betaZodTool({
    name: "list_tasks",
    description:
      "List the user's tasks. Returns each task's id, title, done flag and due date (YYYY-MM-DD or null). Call this before planning the user's day or answering questions about their tasks.",
    inputSchema: z.object({
      include_done: z
        .boolean()
        .describe("Also return completed tasks. Default false."),
    }),
    run: async ({ include_done }) => {
      const snap = await tasks.orderBy("createdAt", "desc").limit(100).get();
      const list = snap.docs
        .map((d) => ({ id: d.id, ...(d.data() as TaskDoc) }))
        .filter((t) => include_done || !t.done)
        .map((t) => ({
          id: t.id,
          title: t.title,
          done: t.done,
          due_date: t.dueDate ?? null,
          notes: t.notes ?? null,
        }));
      return JSON.stringify({ count: list.length, tasks: list });
    },
  });

  const addTask = betaZodTool({
    name: "add_task",
    description:
      "Add one task to the user's task list. Use one call per task; several calls in parallel are fine.",
    inputSchema: z.object({
      title: z.string().min(1).max(200).describe("Short task title in Arabic"),
      due_date: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .nullable()
        .describe("Due date as YYYY-MM-DD, or null if none"),
      notes: z.string().max(500).nullable().describe("Optional details"),
    }),
    run: async ({ title, due_date, notes }) => {
      const doc: TaskDoc = {
        title,
        done: false,
        dueDate: due_date,
        notes,
        source: "assistant",
        createdAt: Date.now(),
      };
      const ref = await tasks.add(doc);
      actions.push(`أضفت مهمة: ${title}`);
      return JSON.stringify({ ok: true, id: ref.id });
    },
  });

  const completeTask = betaZodTool({
    name: "complete_task",
    description:
      "Mark a task as done (or not done). Get the task id from list_tasks first.",
    inputSchema: z.object({
      task_id: z.string().min(1).max(100),
      done: z.boolean().describe("true to mark done, false to reopen"),
    }),
    run: async ({ task_id, done }) => {
      const ref = tasks.doc(task_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      await ref.update({ done });
      const title = (snap.data() as TaskDoc).title;
      actions.push(done ? `خلّصت: ${title}` : `رجّعت: ${title}`);
      return JSON.stringify({ ok: true });
    },
  });

  return [listTasks, addTask, completeTask];
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
    const { messages, timezoneOffsetMinutes = 120 } = parsed.data;

    const last = messages[messages.length - 1];
    if (last.role !== "user") {
      throw new HttpsError("invalid-argument", "آخر رسالة لازم تكون من المستخدم");
    }

    const { day, label } = localDate(timezoneOffsetMinutes);
    await checkDailyLimit(uid, day);

    const actions: string[] = [];
    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    try {
      const final = await client.beta.messages.toolRunner({
        model: MODEL,
        max_tokens: 16000,
        output_config: { effort: "low" },
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: `${SYSTEM_PROMPT}\n\nالنهارده عند المستخدم: ${label}.`,
        tools: buildTools(uid, actions),
        messages: messages.map((m) => ({ role: m.role, content: m.text })),
        max_iterations: 8,
      });

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
