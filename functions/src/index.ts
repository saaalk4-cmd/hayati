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
  // محسوبة على الموبايل حسب موقعه
  context: z
    .object({
      place: z.string().max(120).optional(),
      prayerTimes: z.record(z.string().max(10), z.string().max(8)).optional(),
      nextPrayer: z
        .object({ name: z.string().max(10), time: z.string().max(8) })
        .optional(),
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
- المهام ليها قوائم (عام، شغل، بيت، مشتريات، دراسة) وممكن تتكرر (كل يوم، كل أسبوع، كل شهر).
- ترتب يومه وتقترح أولويات وخطط بناءً على مهامه الحقيقية، فاقرأ المهام الأول قبل ما تقترح.
- لما المستخدم يطلب إضافة حاجة، أضفها على طول من غير ما تسأل تأكيد، إلا لو الطلب مش واضح.
- لما تحدد تاريخ، استخدم الصيغة YYYY-MM-DD واحسبه من تاريخ النهارده المكتوب تحت.

حدود:
- الأقسام دي لسه تحت الإنشاء في التطبيق: اليوميات، المناسبات. لو طلب حاجة منها، قوله إنها جاية قريب إن شاء الله، واعرض تضيفها كمهمة لو ده يفيده.
- متألّفش آيات أو أحاديث. لو استشهدت بآية اذكر السورة ورقم الآية، ولو مش متأكد متستشهدش.
- في الأسئلة الطبية أو القانونية أو المالية الكبيرة، قدّم معلومة عامة وانصحه يرجع لمتخصص.`;

interface TaskDoc {
  title: string;
  done: boolean;
  dueDate: string | null;
  notes: string | null;
  list?: string;
  repeat?: string;
  source: string;
  createdAt: number;
}

interface HabitDoc {
  title: string;
  emoji: string;
  weekdays: number[];
  reminder: string | null;
  done: Record<string, boolean>;
  source: string;
  createdAt: number;
}

/** Monday=1 ... Sunday=7, matching Dart's DateTime.weekday. */
function weekdayOf(day: string): number {
  const d = new Date(`${day}T12:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

function habitStreak(h: HabitDoc, today: string): number {
  const days = h.weekdays?.length ? h.weekdays : [1, 2, 3, 4, 5, 6, 7];
  const cursor = new Date(`${today}T12:00:00Z`);
  const key = () => cursor.toISOString().slice(0, 10);
  if (!h.done?.[key()]) cursor.setUTCDate(cursor.getUTCDate() - 1);
  let count = 0;
  for (let i = 0; i < 400; i++) {
    if (days.includes(weekdayOf(key()))) {
      if (!h.done?.[key()]) break;
      count++;
    }
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return count;
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
          list: t.list ?? "عام",
          repeat: t.repeat ?? "none",
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
      list: z
        .enum(["عام", "شغل", "بيت", "مشتريات", "دراسة"])
        .describe("Which list the task belongs to. Use عام if unsure."),
      repeat: z
        .enum(["none", "daily", "weekly", "monthly"])
        .describe("Repeat rule; needs a due_date when not none"),
    }),
    run: async ({ title, due_date, notes, list, repeat }) => {
      const doc: TaskDoc = {
        title,
        done: false,
        dueDate: due_date,
        notes,
        list,
        repeat: due_date ? repeat : "none",
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

  const userDoc = db.collection("users").doc(uid);
  const prayerNames = ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const;
  const prayerAr: Record<(typeof prayerNames)[number], string> = {
    fajr: "الفجر",
    dhuhr: "الظهر",
    asr: "العصر",
    maghrib: "المغرب",
    isha: "العشاء",
  };
  const statusAr = {
    mosque: "في المسجد",
    ontime: "في وقتها",
    late: "متأخر",
    missed: "فاتتني",
  } as const;
  const dayKey = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

  const getPrayerLog = betaZodTool({
    name: "get_prayer_log",
    description:
      "Get which prayers the user logged on a given day. Status values: mosque, ontime, late, missed; a missing prayer means not logged yet.",
    inputSchema: z.object({ day: dayKey.describe("YYYY-MM-DD") }),
    run: async ({ day }) => {
      const snap = await userDoc.collection("prayers").doc(day).get();
      const data = snap.data() ?? {};
      const log = Object.fromEntries(
        prayerNames.map((p) => [p, (data[p] as string | null) ?? null]),
      );
      return JSON.stringify({ day, log });
    },
  });

  const logPrayer = betaZodTool({
    name: "log_prayer",
    description:
      "Record that the user prayed (or missed) a prayer on a day. Use the user's local date unless they name another day.",
    inputSchema: z.object({
      day: dayKey.describe("YYYY-MM-DD"),
      prayer: z.enum(prayerNames),
      status: z.enum(["mosque", "ontime", "late", "missed"]),
    }),
    run: async ({ day, prayer, status }) => {
      await userDoc
        .collection("prayers")
        .doc(day)
        .set({ [prayer]: status, updatedAt: Date.now() }, { merge: true });
      actions.push(`سجّلت صلاة ${prayerAr[prayer]}: ${statusAr[status]}`);
      return JSON.stringify({ ok: true });
    },
  });

  const QURAN_PAGES = 604;
  const getQuranProgress = betaZodTool({
    name: "get_quran_progress",
    description:
      "Get the user's Quran reading progress: last page read (0-603, 0 = not started), completed khatmas, daily goal in pages, and pages read on a given day.",
    inputSchema: z.object({ day: dayKey.describe("The user's local date") }),
    run: async ({ day }) => {
      const d = (await userDoc.collection("quran").doc("progress").get()).data() ?? {};
      const log = (d.log as Record<string, number> | undefined) ?? {};
      return JSON.stringify({
        page: d.page ?? 0,
        total_pages: QURAN_PAGES,
        khatmas: d.khatmas ?? 0,
        daily_goal: d.dailyGoal ?? 4,
        pages_read_that_day: log[day] ?? 0,
      });
    },
  });

  const logQuranPages = betaZodTool({
    name: "log_quran_pages",
    description:
      "Add pages of Quran the user just read. Advances their khatma; a finished khatma restarts from page 0.",
    inputSchema: z.object({
      day: dayKey.describe("The user's local date"),
      pages: z.number().int().min(1).max(604),
    }),
    run: async ({ day, pages }) => {
      const ref = userDoc.collection("quran").doc("progress");
      const result = await db.runTransaction(async (tx) => {
        const d = (await tx.get(ref)).data() ?? {};
        const log = (d.log as Record<string, number> | undefined) ?? {};
        let page = ((d.page as number | undefined) ?? 0) + pages;
        let khatmas = (d.khatmas as number | undefined) ?? 0;
        let finished = false;
        if (page >= QURAN_PAGES) {
          page = 0;
          khatmas += 1;
          finished = true;
        }
        tx.set(
          ref,
          { page, khatmas, log: { [day]: (log[day] ?? 0) + pages } },
          { merge: true },
        );
        return { page, khatmas, finished };
      });
      actions.push(`سجّلت ${pages} صفحة قرآن`);
      return JSON.stringify({ ok: true, ...result });
    },
  });

  const habits = userDoc.collection("habits");

  const listHabits = betaZodTool({
    name: "list_habits",
    description:
      "List the user's habits with id, title, scheduled weekdays (1=Mon..7=Sun), whether done on the given day, and current streak.",
    inputSchema: z.object({ day: dayKey.describe("The user's local date") }),
    run: async ({ day }) => {
      const snap = await habits.get();
      const list = snap.docs.map((d) => {
        const h = d.data() as HabitDoc;
        return {
          id: d.id,
          title: h.title,
          emoji: h.emoji,
          weekdays: h.weekdays,
          scheduled_that_day: (h.weekdays?.length ? h.weekdays : [1, 2, 3, 4, 5, 6, 7]).includes(weekdayOf(day)),
          done_that_day: Boolean(h.done?.[day]),
          streak: habitStreak(h, day),
          reminder: h.reminder,
        };
      });
      return JSON.stringify({ count: list.length, habits: list });
    },
  });

  const addHabit = betaZodTool({
    name: "add_habit",
    description:
      "Create a new recurring habit for the user (e.g. read 10 pages daily).",
    inputSchema: z.object({
      title: z.string().min(1).max(120),
      emoji: z.string().max(8).describe("One emoji that fits the habit"),
      weekdays: z
        .array(z.number().int().min(1).max(7))
        .min(1)
        .max(7)
        .describe("Days it applies: 1=Mon..7=Sun. All 7 for daily."),
      reminder: z
        .string()
        .regex(/^\d{2}:\d{2}$/)
        .nullable()
        .describe("Daily reminder time HH:mm (24h), or null"),
    }),
    run: async ({ title, emoji, weekdays, reminder }) => {
      const doc: HabitDoc = {
        title,
        emoji,
        weekdays: [...new Set(weekdays)].sort(),
        reminder,
        done: {},
        source: "assistant",
        createdAt: Date.now(),
      };
      const ref = await habits.add(doc);
      actions.push(`أضفت عادة: ${emoji} ${title}`);
      return JSON.stringify({ ok: true, id: ref.id });
    },
  });

  const checkHabit = betaZodTool({
    name: "check_habit",
    description:
      "Mark a habit as done (or undone) on a day. Get the habit id from list_habits first.",
    inputSchema: z.object({
      habit_id: z.string().min(1).max(100),
      day: dayKey.describe("YYYY-MM-DD"),
      done: z.boolean(),
    }),
    run: async ({ habit_id, day, done }) => {
      const ref = habits.doc(habit_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      await ref.update({ [`done.${day}`]: done ? true : FieldValue.delete() });
      const h = snap.data() as HabitDoc;
      actions.push(done ? `علّمت على: ${h.emoji} ${h.title}` : `شلت العلامة: ${h.title}`);
      return JSON.stringify({ ok: true });
    },
  });

  const transactions = userDoc.collection("transactions");
  const expenseCats = [
    "food", "transport", "bills", "home", "health",
    "education", "fun", "clothes", "charity", "other",
  ] as const;
  const incomeCats = ["salary", "freelance", "gift", "other_income"] as const;
  const catAr: Record<string, string> = {
    food: "أكل", transport: "مواصلات", bills: "فواتير", home: "بيت",
    health: "صحة", education: "تعليم", fun: "ترفيه", clothes: "لبس",
    charity: "صدقة وهدايا", other: "تانية", salary: "مرتب",
    freelance: "شغل حر", gift: "هدية", other_income: "دخل تاني",
  };
  const monthKey = z.string().regex(/^\d{4}-\d{2}$/);

  const addTransaction = betaZodTool({
    name: "add_transaction",
    description:
      "Record money the user spent (expense) or received (income), in Egyptian pounds. Pick the closest category. One call per item.",
    inputSchema: z.object({
      type: z.enum(["expense", "income"]),
      amount: z.number().positive().max(100_000_000),
      category: z
        .enum([...expenseCats, ...incomeCats])
        .describe("expense: food, transport, bills, home, health, education, fun, clothes, charity, other. income: salary, freelance, gift, other_income"),
      date: dayKey.describe("YYYY-MM-DD, normally the user's local date"),
      note: z.string().max(200).nullable().describe("Short description, e.g. غدا مع الشغل"),
    }),
    run: async ({ type, amount, category, date, note }) => {
      const isIncomeCat = (incomeCats as readonly string[]).includes(category);
      const cat = type === "income"
        ? (isIncomeCat ? category : "other_income")
        : (isIncomeCat ? "other" : category);
      await transactions.add({
        type, amount, category: cat, date, month: date.slice(0, 7),
        note, source: "assistant", createdAt: Date.now(),
      });
      actions.push(
        `${type === "expense" ? "سجّلت مصروف" : "سجّلت دخل"}: ${amount} ج.م (${catAr[cat]})`,
      );
      return JSON.stringify({ ok: true });
    },
  });

  const getMoneySummary = betaZodTool({
    name: "get_money_summary",
    description:
      "Summarize the user's money for a month: total spent, income, monthly budget and what's left, spending per category, and the 15 latest transactions.",
    inputSchema: z.object({ month: monthKey.describe("YYYY-MM") }),
    run: async ({ month }) => {
      const [snap, settings] = await Promise.all([
        transactions.where("month", "==", month).get(),
        userDoc.collection("money").doc("settings").get(),
      ]);
      let spent = 0, income = 0;
      const byCat: Record<string, number> = {};
      const list = snap.docs.map((d) => d.data() as {
        type: string; amount: number; category: string; date: string; note: string | null;
      });
      for (const t of list) {
        if (t.type === "income") income += t.amount;
        else {
          spent += t.amount;
          byCat[catAr[t.category] ?? t.category] = (byCat[catAr[t.category] ?? t.category] ?? 0) + t.amount;
        }
      }
      const budget = (settings.data()?.monthlyBudget as number | null | undefined) ?? null;
      const latest = list
        .sort((a, b) => b.date.localeCompare(a.date))
        .slice(0, 15)
        .map((t) => ({ ...t, category: catAr[t.category] ?? t.category }));
      return JSON.stringify({
        month, currency: "EGP", spent, income,
        monthly_budget: budget,
        remaining_budget: budget === null ? null : budget - spent,
        spent_by_category: byCat,
        latest,
      });
    },
  });

  const setMonthlyBudget = betaZodTool({
    name: "set_monthly_budget",
    description: "Set (or clear with null) the user's monthly spending budget in EGP.",
    inputSchema: z.object({ budget: z.number().positive().max(100_000_000).nullable() }),
    run: async ({ budget }) => {
      await userDoc.collection("money").doc("settings").set({ monthlyBudget: budget }, { merge: true });
      actions.push(budget === null ? "شلت الميزانية الشهرية" : `حددت الميزانية: ${budget} ج.م`);
      return JSON.stringify({ ok: true });
    },
  });

  return [
    addTransaction,
    getMoneySummary,
    setMonthlyBudget,
    listHabits,
    addHabit,
    checkHabit,
    listTasks,
    addTask,
    completeTask,
    getPrayerLog,
    logPrayer,
    getQuranProgress,
    logQuranPages,
  ];
}

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
  return `\nمواقيت الصلاة النهارده${ctx.place ? ` (${ctx.place})` : ""}: ${times}.${next}`;
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
      const final = await client.beta.messages.toolRunner({
        model: MODEL,
        max_tokens: 16000,
        output_config: { effort: "low" },
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: `${SYSTEM_PROMPT}\n\nالنهارده عند المستخدم: ${label}.${describeContext(context)}`,
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
