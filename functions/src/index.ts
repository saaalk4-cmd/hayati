/**
 * Cloud Functions for «حياتي».
 *
 * askHayati: the in-app assistant. It runs Claude with tools that read and
 * write the signed-in user's own data in Firestore (users/{uid}/...).
 * The Claude API key lives only here, as a Firebase secret.
 */
import crypto from "node:crypto";
import Anthropic from "@anthropic-ai/sdk";
import { betaZodTool } from "@anthropic-ai/sdk/helpers/beta/zod";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
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
      hijri: z.string().max(40).optional(),
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

interface TaskDoc {
  title: string;
  done: boolean;
  dueDate: string | null;
  notes: string | null;
  list?: string;
  repeat?: string;
  priority?: string;
  subtasks?: { title: string; done: boolean }[];
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
          priority: t.priority ?? "normal",
          subtasks: t.subtasks ?? [],
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
      priority: z.enum(["low", "normal", "high"]).describe("Use high only for clearly important/urgent tasks"),
      subtasks: z.array(z.string().min(1).max(120)).max(15).describe("Optional checklist steps; empty array if none"),
    }),
    run: async ({ title, due_date, notes, list, repeat, priority, subtasks }) => {
      const doc: TaskDoc = {
        title,
        done: false,
        dueDate: due_date,
        notes,
        list,
        repeat: due_date ? repeat : "none",
        priority,
        subtasks: subtasks.map((t) => ({ title: t, done: false })),
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

  const journal = userDoc.collection("journal");
  const moodAr: Record<number, string> = { 1: "وحش", 2: "مش أحسن حاجة", 3: "عادي", 4: "كويس", 5: "ممتاز" };

  const getJournal = betaZodTool({
    name: "get_journal",
    description:
      "Read the user's private journal entries (mood 1-5, text, gratitude) for a date range. Only use when the user asks about their journal or mood.",
    inputSchema: z.object({
      from: dayKey.describe("YYYY-MM-DD inclusive"),
      to: dayKey.describe("YYYY-MM-DD inclusive"),
    }),
    run: async ({ from, to }) => {
      const snap = await journal.where("day", ">=", from).where("day", "<=", to).limit(62).get();
      const entries = snap.docs.map((d) => {
        const e = d.data();
        return { day: d.id, mood: e.mood ?? null, text: e.text ?? "", gratitude: e.gratitude ?? "" };
      });
      return JSON.stringify({ count: entries.length, entries });
    },
  });

  const writeJournal = betaZodTool({
    name: "write_journal",
    description:
      "Add to the user's journal for a day: set the mood and/or append text the user dictated. Appends to existing text, never deletes it.",
    inputSchema: z.object({
      day: dayKey.describe("YYYY-MM-DD"),
      mood: z.number().int().min(1).max(5).nullable().describe("1=bad .. 5=great, or null to keep"),
      text: z.string().max(4000).nullable().describe("Text to append, in the user's words"),
      gratitude: z.string().max(500).nullable().describe("Something they're grateful for, or null"),
    }),
    run: async ({ day, mood, text, gratitude }) => {
      const ref = journal.doc(day);
      await db.runTransaction(async (tx) => {
        const cur = (await tx.get(ref)).data() ?? {};
        const join = (a: string | undefined, b: string | null) =>
          b ? (a ? `${a}\n${b}` : b) : (a ?? "");
        tx.set(ref, {
          day,
          mood: mood ?? cur.mood ?? null,
          text: join(cur.text, text),
          gratitude: join(cur.gratitude, gratitude),
          updatedAt: Date.now(),
        });
      });
      actions.push(mood ? `كتبت في يومياتك (المزاج: ${moodAr[mood]})` : "كتبت في يومياتك");
      return JSON.stringify({ ok: true });
    },
  });

  const familyCol = userDoc.collection("family");
  type OccasionDoc = { id: string; title: string; type: string; month: number; day: number; year: number | null; remindDaysBefore: number };
  type PersonDoc = { id: string; name: string; relation: string; everyDays: number; lastContact: number | null };
  const readItems = async <T,>(doc: string): Promise<T[]> =>
    (((await familyCol.doc(doc).get()).data()?.items as T[] | undefined) ?? []);

  const listFamily = betaZodTool({
    name: "list_occasions_and_people",
    description:
      "List the user's yearly occasions (birthdays, anniversaries) with days until each, and the people they want to keep in touch with (silat al-rahim) with days since last contact.",
    inputSchema: z.object({ today: dayKey.describe("The user's local date") }),
    run: async ({ today }) => {
      const [occ, people] = await Promise.all([
        readItems<OccasionDoc>("occasions"),
        readItems<PersonDoc>("people"),
      ]);
      const t = new Date(`${today}T00:00:00Z`);
      const daysUntil = (m: number, d: number) => {
        let next = new Date(Date.UTC(t.getUTCFullYear(), m - 1, d));
        if (next < t) next = new Date(Date.UTC(t.getUTCFullYear() + 1, m - 1, d));
        return Math.round((next.getTime() - t.getTime()) / 86_400_000);
      };
      return JSON.stringify({
        occasions: occ.map((o) => ({ title: o.title, type: o.type, date: `${o.month}/${o.day}`, days_until: daysUntil(o.month, o.day) }))
          .sort((a, b) => a.days_until - b.days_until),
        people: people.map((p) => ({
          id: p.id, name: p.name, relation: p.relation, every_days: p.everyDays,
          days_since_contact: p.lastContact ? Math.floor((Date.now() - p.lastContact) / 86_400_000) : null,
        })),
      });
    },
  });

  const addOccasion = betaZodTool({
    name: "add_occasion",
    description: "Add a yearly occasion (birthday, anniversary, other) with a reminder.",
    inputSchema: z.object({
      title: z.string().min(1).max(120).describe("e.g. عيد ميلاد ماما"),
      type: z.enum(["birthday", "anniversary", "other"]),
      month: z.number().int().min(1).max(12),
      day: z.number().int().min(1).max(31),
      year: z.number().int().min(1900).max(2100).nullable().describe("Birth/start year if known"),
      remind_days_before: z.number().int().min(0).max(30),
    }),
    run: async ({ title, type, month, day, year, remind_days_before }) => {
      const items = await readItems<OccasionDoc>("occasions");
      items.push({ id: crypto.randomUUID(), title, type, month, day, year, remindDaysBefore: remind_days_before });
      await familyCol.doc("occasions").set({ items }, { merge: true });
      actions.push(`أضفت مناسبة: ${title} (${day}/${month})`);
      return JSON.stringify({ ok: true });
    },
  });

  const logContact = betaZodTool({
    name: "log_contact",
    description:
      "Record that the user just contacted someone from their people list (by id from list_occasions_and_people), or add a new person to keep in touch with when person_id is null.",
    inputSchema: z.object({
      person_id: z.string().max(100).nullable(),
      new_person_name: z.string().max(80).nullable().describe("Only when adding a new person"),
      relation: z.string().max(40).nullable(),
      every_days: z.number().int().min(1).max(365).nullable().describe("How often they want to contact them"),
    }),
    run: async ({ person_id, new_person_name, relation, every_days }) => {
      const items = await readItems<PersonDoc>("people");
      if (person_id) {
        const p = items.find((x) => x.id === person_id);
        if (!p) return JSON.stringify({ ok: false, error: "not_found" });
        p.lastContact = Date.now();
        actions.push(`سجّلت إنك كلمت ${p.name} 💚`);
      } else if (new_person_name) {
        items.push({ id: crypto.randomUUID(), name: new_person_name, relation: relation ?? "", everyDays: every_days ?? 14, lastContact: null });
        actions.push(`أضفت ${new_person_name} لصلة الرحم`);
      } else {
        return JSON.stringify({ ok: false, error: "need person_id or new_person_name" });
      }
      await familyCol.doc("people").set({ items }, { merge: true });
      return JSON.stringify({ ok: true });
    },
  });

  const dayOverview = betaZodTool({
    name: "get_day_overview",
    description:
      "One call that returns everything about the user's day: open tasks (overdue and due that day), habits scheduled that day and which are done, prayer log, Quran pages vs daily goal, money spent that day and month vs budget, upcoming occasions within 7 days, and people they haven't contacted in a while. Call this FIRST when the user asks to plan or organize their day, or asks how their day is going.",
    inputSchema: z.object({ day: dayKey.describe("The user's local date") }),
    run: async ({ day }) => {
      const month = day.slice(0, 7);
      const [taskSnap, habitSnap, prayerSnap, quranSnap, txSnap, moneySnap, occ, people] = await Promise.all([
        tasks.where("done", "==", false).limit(200).get(),
        habits.get(),
        userDoc.collection("prayers").doc(day).get(),
        userDoc.collection("quran").doc("progress").get(),
        transactions.where("month", "==", month).get(),
        userDoc.collection("money").doc("settings").get(),
        readItems<OccasionDoc>("occasions"),
        readItems<PersonDoc>("people"),
      ]);
      const open = taskSnap.docs.map((d) => ({ id: d.id, ...(d.data() as TaskDoc) }));
      const overdue = open.filter((t) => t.dueDate && t.dueDate < day);
      const dueToday = open.filter((t) => t.dueDate === day);
      const someday = open.filter((t) => !t.dueDate).slice(0, 10);
      const wd = weekdayOf(day);
      const habitList = habitSnap.docs
        .map((d) => ({ id: d.id, ...(d.data() as HabitDoc) }))
        .filter((h) => (h.weekdays?.length ? h.weekdays : [1, 2, 3, 4, 5, 6, 7]).includes(wd))
        .map((h) => ({ id: h.id, title: `${h.emoji} ${h.title}`, done: Boolean(h.done?.[day]), streak: habitStreak(h, day), reminder: h.reminder }));
      const q = quranSnap.data() ?? {};
      const qLog = (q.log as Record<string, number> | undefined) ?? {};
      let spentToday = 0, spentMonth = 0;
      for (const d of txSnap.docs) {
        const t = d.data() as { type: string; amount: number; date: string };
        if (t.type !== "expense") continue;
        spentMonth += t.amount;
        if (t.date === day) spentToday += t.amount;
      }
      const budget = (moneySnap.data()?.monthlyBudget as number | null | undefined) ?? null;
      const t0 = new Date(`${day}T00:00:00Z`);
      const until = (m: number, dd: number) => {
        let n = new Date(Date.UTC(t0.getUTCFullYear(), m - 1, dd));
        if (n < t0) n = new Date(Date.UTC(t0.getUTCFullYear() + 1, m - 1, dd));
        return Math.round((n.getTime() - t0.getTime()) / 86_400_000);
      };
      const slim = (t: TaskDoc & { id: string }) => ({ id: t.id, title: t.title, due_date: t.dueDate, list: t.list ?? "عام" });
      return JSON.stringify({
        day,
        tasks: { overdue: overdue.map(slim), due_today: dueToday.map(slim), anytime: someday.map(slim) },
        habits: habitList,
        prayers_logged: prayerSnap.data() ?? {},
        quran: { pages_today: qLog[day] ?? 0, daily_goal: q.dailyGoal ?? 4, khatma_page: q.page ?? 0 },
        money: { spent_today: spentToday, spent_month: spentMonth, monthly_budget: budget, remaining: budget === null ? null : budget - spentMonth },
        upcoming_occasions: occ.map((o) => ({ title: o.title, days_until: until(o.month, o.day) })).filter((o) => o.days_until <= 7),
        people_to_contact: people
          .filter((p) => p.lastContact && (Date.now() - p.lastContact) / 86_400_000 >= p.everyDays)
          .map((p) => ({ id: p.id, name: p.name, days_since: Math.floor((Date.now() - (p.lastContact ?? 0)) / 86_400_000) })),
      });
    },
  });

  const weekSummary = betaZodTool({
    name: "get_week_summary",
    description:
      "Summarize the last 7 days ending on the given day: prayers logged per day, habit completion rate, tasks completed vs due, Quran pages, money spent, and average mood. Use for weekly reviews and motivation.",
    inputSchema: z.object({ end_day: dayKey.describe("Usually the user's local date") }),
    run: async ({ end_day }) => {
      const days: string[] = [];
      const c = new Date(`${end_day}T12:00:00Z`);
      for (let i = 0; i < 7; i++) {
        days.unshift(c.toISOString().slice(0, 10));
        c.setUTCDate(c.getUTCDate() - 1);
      }
      const months = [...new Set(days.map((d) => d.slice(0, 7)))];
      const [prayerDocs, habitSnap, taskSnap, quranSnap, journalSnap, ...txSnaps] = await Promise.all([
        Promise.all(days.map((d) => userDoc.collection("prayers").doc(d).get())),
        habits.get(),
        tasks.where("dueDate", ">=", days[0]).where("dueDate", "<=", end_day).get(),
        userDoc.collection("quran").doc("progress").get(),
        journal.where("day", ">=", days[0]).where("day", "<=", end_day).get(),
        ...months.map((m) => transactions.where("month", "==", m).get()),
      ]);
      const prayersPerDay = prayerDocs.map((d, i) => {
        const data = d.data() ?? {};
        const values = prayerNames.map((p) => data[p]).filter(Boolean);
        return { day: days[i], logged: values.filter((v) => v !== "missed").length, mosque: values.filter((v) => v === "mosque").length };
      });
      let scheduled = 0, hits = 0;
      for (const d of habitSnap.docs) {
        const h = d.data() as HabitDoc;
        const wds = h.weekdays?.length ? h.weekdays : [1, 2, 3, 4, 5, 6, 7];
        for (const day of days) {
          if (!wds.includes(weekdayOf(day))) continue;
          scheduled++;
          if (h.done?.[day]) hits++;
        }
      }
      const taskList = taskSnap.docs.map((d) => d.data() as TaskDoc);
      const qLog = (quranSnap.data()?.log as Record<string, number> | undefined) ?? {};
      let spent = 0;
      for (const snap of txSnaps) {
        for (const d of snap.docs) {
          const t = d.data() as { type: string; amount: number; date: string };
          if (t.type === "expense" && days.includes(t.date)) spent += t.amount;
        }
      }
      const moods = journalSnap.docs.map((d) => d.data().mood as number | null).filter((m): m is number => typeof m === "number");
      return JSON.stringify({
        days: `${days[0]} → ${end_day}`,
        prayers_per_day: prayersPerDay,
        prayers_logged_total: prayersPerDay.reduce((s, d) => s + d.logged, 0),
        habit_completion_rate: scheduled ? Math.round((hits / scheduled) * 100) : null,
        tasks_done: taskList.filter((t) => t.done).length,
        tasks_due: taskList.length,
        quran_pages: days.reduce((s, d) => s + (qLog[d] ?? 0), 0),
        spent_egp: spent,
        average_mood: moods.length ? Math.round((moods.reduce((a, b) => a + b, 0) / moods.length) * 10) / 10 : null,
      });
    },
  });

  const logRamadan = betaZodTool({
    name: "log_ramadan_day",
    description:
      "During Ramadan: record whether the user fasted and/or prayed taraweeh on a given Ramadan day (1-30). Use the Hijri date given in the context.",
    inputSchema: z.object({
      hijri_year: z.number().int().min(1440).max(1500),
      day: z.number().int().min(1).max(30),
      fasted: z.boolean().nullable().describe("null = leave unchanged"),
      taraweeh: z.boolean().nullable().describe("null = leave unchanged"),
    }),
    run: async ({ hijri_year, day, fasted, taraweeh }) => {
      const update: Record<string, unknown> = {};
      if (fasted !== null) update.fasted = { [String(day)]: fasted };
      if (taraweeh !== null) update.taraweeh = { [String(day)]: taraweeh };
      await userDoc.collection("ramadan").doc(String(hijri_year)).set(update, { merge: true });
      actions.push(`سجّلت يوم ${day} رمضان${fasted ? " • صيام ✓" : ""}${taraweeh ? " • تراويح ✓" : ""}`);
      return JSON.stringify({ ok: true });
    },
  });

  const qadaRef = userDoc.collection("qada").doc("state");
  const qadaTool = betaZodTool({
    name: "qada_prayers",
    description:
      "Missed prayers to make up (qada). action=get returns remaining and done counts per prayer. action=log records that the user made up `count` of a prayer (or a full day of 5 when prayer=all).",
    inputSchema: z.object({
      action: z.enum(["get", "log"]),
      prayer: z.enum(["fajr", "dhuhr", "asr", "maghrib", "isha", "all"]).describe("Ignored for get"),
      count: z.number().int().min(1).max(100).describe("How many made up; 1 if unsure. Ignored for get"),
    }),
    run: async ({ action, prayer, count }) => {
      if (action === "get") {
        const d = (await qadaRef.get()).data() ?? {};
        return JSON.stringify({ owed: d.owed ?? {}, done: d.done ?? {}, daily_goal_days: d.dailyGoal ?? 1 });
      }
      const targets = prayer === "all" ? [...prayerNames] : [prayer];
      await db.runTransaction(async (tx) => {
        const d = (await tx.get(qadaRef)).data() ?? {};
        const owed = { ...(d.owed ?? {}) } as Record<string, number>;
        const done = { ...(d.done ?? {}) } as Record<string, number>;
        for (const p of targets) {
          const n = Math.min(count, owed[p] ?? 0);
          owed[p] = (owed[p] ?? 0) - n;
          done[p] = (done[p] ?? 0) + n;
        }
        tx.set(qadaRef, { owed, done }, { merge: true });
      });
      actions.push(prayer === "all" ? `سجّلت قضاء ${count} يوم كامل` : `سجّلت قضاء ${count} ${prayerAr[prayer as (typeof prayerNames)[number]]}`);
      return JSON.stringify({ ok: true });
    },
  });

  const focusTool = betaZodTool({
    name: "get_focus_stats",
    description:
      "Focus (Pomodoro) minutes and sessions per day for the last N days, ending on the given day. Use when the user asks how focused/productive they were.",
    inputSchema: z.object({
      end_day: dayKey.describe("Usually the user's local date"),
      days: z.number().int().min(1).max(31),
    }),
    run: async ({ end_day, days }) => {
      const keys: string[] = [];
      const c = new Date(`${end_day}T12:00:00Z`);
      for (let i = 0; i < days; i++) {
        keys.unshift(c.toISOString().slice(0, 10));
        c.setUTCDate(c.getUTCDate() - 1);
      }
      const snaps = await Promise.all(keys.map((k) => userDoc.collection("focus").doc(k).get()));
      const perDay = snaps.map((s, i) => ({
        day: keys[i],
        minutes: (s.data()?.minutes as number | undefined) ?? 0,
        sessions: (s.data()?.sessions as number | undefined) ?? 0,
      }));
      return JSON.stringify({
        total_minutes: perDay.reduce((a, d) => a + d.minutes, 0),
        per_day: perDay,
      });
    },
  });

  return [
    focusTool,
    qadaTool,
    logRamadan,
    dayOverview,
    weekSummary,
    listFamily,
    addOccasion,
    logContact,
    getJournal,
    writeJournal,
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
  const hijri = ctx.hijri ? `\nالتاريخ الهجري: ${ctx.hijri}.` : "";
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
