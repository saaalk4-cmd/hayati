/**
 * أدوات «حياتي» اللي Claude بيستخدمها عشان يقرا ويكتب بيانات المستخدم ده بس
 * (users/{uid}/...). الملف مشترك بين:
 * - askHayati (Cloud Functions) بـ firebase-admin و betaZodTool
 * - سيرفر الـ Connector (connector/) بـ Firestore REST و MCP
 */
import { z } from "zod";

/** تعريف أداة: اسم ووصف ومدخلات (zod) ودالة بترجع نص JSON */
export interface ToolDef<S extends z.ZodTypeAny = z.ZodTypeAny> {
  name: string;
  description: string;
  inputSchema: S;
  run: (args: z.infer<S>) => Promise<string>;
}

/* eslint-disable @typescript-eslint/no-explicit-any */
export type DocData = Record<string, any>;
export interface DocSnap {
  id: string;
  exists: boolean;
  data(): DocData | undefined;
}
export interface QueryDocSnap extends DocSnap {
  data(): DocData;
}
export interface QuerySnap {
  docs: QueryDocSnap[];
}
export interface QueryLike {
  where(field: string, op: any, value: unknown): QueryLike;
  orderBy(field: string, dir?: any): QueryLike;
  limit(n: number): QueryLike;
  get(): Promise<QuerySnap>;
}
export interface CollRefLike extends QueryLike {
  doc(id: string): DocRefLike;
  add(data: DocData): Promise<{ id: string }>;
}
export interface DocRefLike {
  id: string;
  get(): Promise<DocSnap>;
  set(data: DocData, opts?: { merge?: boolean }): Promise<unknown>;
  update(data: DocData): Promise<unknown>;
  delete(): Promise<unknown>;
  collection(name: string): CollRefLike;
}
export interface TxLike {
  get(ref: any): Promise<DocSnap>;
  set(ref: any, data: DocData, opts?: { merge?: boolean }): unknown;
}
/** الجزء اللي الأدوات بتستخدمه من Firestore (admin SDK أو REST) */
export interface DbLike {
  collection(name: string): CollRefLike;
  runTransaction<R>(fn: (tx: TxLike) => Promise<R>): Promise<R>;
}

/** اللي كل بيئة بتوفّره: قاعدة البيانات، وFieldValue، وطريقة تعريف الأداة */
export interface ToolDeps<T = unknown> {
  db: DbLike;
  FieldValue: { delete(): unknown };
  defineTool: <S extends z.ZodTypeAny>(def: ToolDef<S>) => T;
}

export interface TaskDoc {
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

export interface HabitDoc {
  title: string;
  emoji: string;
  weekdays: number[];
  reminder: string | null;
  done: Record<string, boolean>;
  source: string;
  createdAt: number;
}

/** Monday=1 ... Sunday=7, matching Dart's DateTime.weekday. */
export function weekdayOf(day: string): number {
  const d = new Date(`${day}T12:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d;
}

export function habitStreak(h: HabitDoc, today: string): number {
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

export function buildTools<T>(deps: ToolDeps<T>, uid: string, actions: string[]): T[] {
  const { db, FieldValue, defineTool: betaZodTool } = deps;
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
      const list = snap.docs.map((d) => ({ id: d.id, ...(d.data() as {
        type: string; amount: number; category: string; date: string; note: string | null;
      }) }));
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
        occasions: occ.map((o) => ({ id: o.id, title: o.title, type: o.type, date: `${o.month}/${o.day}`, days_until: daysUntil(o.month, o.day) }))
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

  const goalsRef = userDoc.collection("goals").doc("state");
  type GoalDoc = { id: string; title: string; emoji?: string; steps?: { t: string; d: boolean }[]; deadline?: string };
  const goalsTool = betaZodTool({
    name: "goals",
    description:
      "The user's long-term goals, each with steps. action=list returns goals with step indexes and progress. action=add creates a goal with steps (break a big goal into 3-6 concrete steps if the user didn't give any). action=toggle_step marks a step done/undone by goal_id and step_index.",
    inputSchema: z.object({
      action: z.enum(["list", "add", "toggle_step"]),
      title: z.string().max(120).describe("For add; empty otherwise"),
      emoji: z.string().max(8).describe("For add, one emoji; empty otherwise"),
      steps: z.array(z.string().max(120)).max(12).describe("For add; [] otherwise"),
      deadline: dayKey.nullable().describe("For add, optional yyyy-MM-dd"),
      goal_id: z.string().max(64).describe("For toggle_step; empty otherwise"),
      step_index: z.number().int().min(0).max(50).describe("For toggle_step; 0 otherwise"),
    }),
    run: async ({ action, title, emoji, steps, deadline, goal_id, step_index }) => {
      if (action === "list") {
        const list = ((await goalsRef.get()).data()?.list ?? []) as GoalDoc[];
        return JSON.stringify(
          list.map((g) => ({
            id: g.id,
            title: g.title,
            deadline: g.deadline ?? null,
            steps: (g.steps ?? []).map((s, i) => ({ index: i, title: s.t, done: s.d })),
            done: (g.steps ?? []).filter((s) => s.d).length,
            total: (g.steps ?? []).length,
          })),
        );
      }
      let message = "";
      await db.runTransaction(async (tx) => {
        const list = [...(((await tx.get(goalsRef)).data()?.list ?? []) as GoalDoc[])];
        if (action === "add") {
          if (!title.trim()) throw new Error("title required");
          const g: GoalDoc = {
            id: `${Date.now()}`,
            title: title.trim(),
            emoji: emoji || "🎯",
            steps: steps.filter((s) => s.trim()).map((s) => ({ t: s.trim(), d: false })),
          };
          if (deadline) g.deadline = deadline;
          list.push(g);
          message = `ضفت هدف «${g.title}» بـ ${g.steps!.length} خطوات`;
        } else {
          const g = list.find((x) => x.id === goal_id);
          const step = g?.steps?.[step_index];
          if (!g || !step) throw new Error("goal or step not found");
          step.d = !step.d;
          message = `${step.d ? "خلّصت" : "رجّعت"} خطوة «${step.t}» في «${g.title}»`;
        }
        tx.set(goalsRef, { list }, { merge: true });
      });
      actions.push(message);
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

  // ───────────── التعديل ─────────────
  const keep = <V,>(v: V | null | undefined) => v !== null && v !== undefined;
  const pick = (o: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(o).filter(([, v]) => keep(v)));

  const updateTask = betaZodTool({
    name: "update_task",
    description:
      "Edit a task's fields (get its id from list_tasks). Pass null for anything to keep as is. To clear the due date pass clear_due_date=true.",
    inputSchema: z.object({
      task_id: z.string().min(1).max(100),
      title: z.string().min(1).max(200).nullable(),
      due_date: dayKey.nullable(),
      clear_due_date: z.boolean().describe("true removes the due date"),
      notes: z.string().max(500).nullable(),
      list: z.enum(["عام", "شغل", "بيت", "مشتريات", "دراسة"]).nullable(),
      priority: z.enum(["low", "normal", "high"]).nullable(),
      repeat: z.enum(["none", "daily", "weekly", "monthly"]).nullable(),
    }),
    run: async ({ task_id, title, due_date, clear_due_date, notes, list, priority, repeat }) => {
      const ref = tasks.doc(task_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      const changes: Record<string, unknown> = pick({ title, dueDate: due_date, notes, list, priority, repeat });
      if (clear_due_date) {
        changes.dueDate = null;
        changes.repeat = "none";
      }
      if (!Object.keys(changes).length) return JSON.stringify({ ok: false, error: "nothing_to_change" });
      await ref.update(changes);
      actions.push(`عدّلت المهمة: ${title ?? (snap.data() as TaskDoc).title}`);
      return JSON.stringify({ ok: true, changed: Object.keys(changes) });
    },
  });

  const updateHabit = betaZodTool({
    name: "update_habit",
    description: "Edit a habit (id from list_habits). Pass null to keep a field; clear_reminder=true removes its reminder.",
    inputSchema: z.object({
      habit_id: z.string().min(1).max(100),
      title: z.string().min(1).max(120).nullable(),
      emoji: z.string().max(8).nullable(),
      weekdays: z.array(z.number().int().min(1).max(7)).min(1).max(7).nullable(),
      reminder: z.string().regex(/^\d{2}:\d{2}$/).nullable(),
      clear_reminder: z.boolean(),
    }),
    run: async ({ habit_id, title, emoji, weekdays, reminder, clear_reminder }) => {
      const ref = habits.doc(habit_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      const changes: Record<string, unknown> = pick({
        title, emoji, reminder,
        weekdays: weekdays ? [...new Set(weekdays)].sort() : null,
      });
      if (clear_reminder) changes.reminder = null;
      if (!Object.keys(changes).length) return JSON.stringify({ ok: false, error: "nothing_to_change" });
      await ref.update(changes);
      actions.push(`عدّلت العادة: ${title ?? (snap.data() as HabitDoc).title}`);
      return JSON.stringify({ ok: true, changed: Object.keys(changes) });
    },
  });

  const listTransactions = betaZodTool({
    name: "list_transactions",
    description: "List a month's transactions with their ids (newest first), to find one to edit or delete.",
    inputSchema: z.object({ month: monthKey.describe("YYYY-MM") }),
    run: async ({ month }) => {
      const snap = await transactions.where("month", "==", month).get();
      const list = snap.docs
        .map((d) => ({ id: d.id, ...(d.data() as { type: string; amount: number; category: string; date: string; note: string | null }) }))
        .sort((a, b) => b.date.localeCompare(a.date))
        .slice(0, 100)
        .map((t) => ({ id: t.id, type: t.type, amount: t.amount, category: catAr[t.category] ?? t.category, date: t.date, note: t.note }));
      return JSON.stringify({ count: list.length, transactions: list });
    },
  });

  const updateTransaction = betaZodTool({
    name: "update_transaction",
    description: "Fix a recorded expense/income (id from list_transactions or get_money_summary). Pass null to keep a field.",
    inputSchema: z.object({
      transaction_id: z.string().min(1).max(100),
      amount: z.number().positive().max(100_000_000).nullable(),
      category: z.enum([...expenseCats, ...incomeCats]).nullable(),
      date: dayKey.nullable(),
      note: z.string().max(200).nullable(),
    }),
    run: async ({ transaction_id, amount, category, date, note }) => {
      const ref = transactions.doc(transaction_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      const cur = snap.data() as { type: string };
      if (category) {
        const isIncomeCat = (incomeCats as readonly string[]).includes(category);
        if (isIncomeCat !== (cur.type === "income")) {
          return JSON.stringify({ ok: false, error: "category_does_not_match_type" });
        }
      }
      const changes: Record<string, unknown> = pick({ amount, category, date, note, month: date ? date.slice(0, 7) : null });
      if (!Object.keys(changes).length) return JSON.stringify({ ok: false, error: "nothing_to_change" });
      await ref.update(changes);
      actions.push(`عدّلت ${cur.type === "income" ? "الدخل" : "المصروف"}${amount ? `: ${amount} ج.م` : ""}`);
      return JSON.stringify({ ok: true, changed: Object.keys(changes) });
    },
  });

  const updateGoal = betaZodTool({
    name: "update_goal",
    description:
      "Edit a goal (id from goals list): title, emoji, deadline, or replace its steps (steps with the same title keep their done state). Pass null to keep a field.",
    inputSchema: z.object({
      goal_id: z.string().min(1).max(64),
      title: z.string().min(1).max(120).nullable(),
      emoji: z.string().max(8).nullable(),
      deadline: dayKey.nullable(),
      clear_deadline: z.boolean(),
      steps: z.array(z.string().min(1).max(120)).max(20).nullable(),
    }),
    run: async ({ goal_id, title, emoji, deadline, clear_deadline, steps }) => {
      let name = "";
      const found = await db.runTransaction(async (tx) => {
        const list = [...(((await tx.get(goalsRef)).data()?.list ?? []) as GoalDoc[])];
        const g = list.find((x) => x.id === goal_id);
        if (!g) return false;
        if (title) g.title = title;
        if (emoji) g.emoji = emoji;
        if (deadline) g.deadline = deadline;
        if (clear_deadline) delete g.deadline;
        if (steps) {
          const done = new Map((g.steps ?? []).map((s) => [s.t, s.d]));
          g.steps = steps.map((t) => ({ t, d: done.get(t) ?? false }));
        }
        name = g.title;
        tx.set(goalsRef, { list }, { merge: true });
        return true;
      });
      if (!found) return JSON.stringify({ ok: false, error: "not_found" });
      actions.push(`عدّلت الهدف: ${name}`);
      return JSON.stringify({ ok: true });
    },
  });

  const updateOccasion = betaZodTool({
    name: "update_occasion",
    description: "Edit a yearly occasion (id from list_occasions_and_people). Pass null to keep a field.",
    inputSchema: z.object({
      occasion_id: z.string().min(1).max(100),
      title: z.string().min(1).max(120).nullable(),
      type: z.enum(["birthday", "anniversary", "other"]).nullable(),
      month: z.number().int().min(1).max(12).nullable(),
      day: z.number().int().min(1).max(31).nullable(),
      year: z.number().int().min(1900).max(2100).nullable(),
      remind_days_before: z.number().int().min(0).max(30).nullable(),
    }),
    run: async ({ occasion_id, title, type, month, day, year, remind_days_before }) => {
      const items = await readItems<OccasionDoc>("occasions");
      const o = items.find((x) => x.id === occasion_id);
      if (!o) return JSON.stringify({ ok: false, error: "not_found" });
      Object.assign(o, pick({ title, type, month, day, year, remindDaysBefore: remind_days_before }));
      await familyCol.doc("occasions").set({ items }, { merge: true });
      actions.push(`عدّلت المناسبة: ${o.title}`);
      return JSON.stringify({ ok: true });
    },
  });

  const updatePerson = betaZodTool({
    name: "update_person",
    description: "Edit someone in the keep-in-touch list (id from list_occasions_and_people). Pass null to keep a field.",
    inputSchema: z.object({
      person_id: z.string().min(1).max(100),
      name: z.string().min(1).max(80).nullable(),
      relation: z.string().max(40).nullable(),
      every_days: z.number().int().min(1).max(365).nullable(),
    }),
    run: async ({ person_id, name, relation, every_days }) => {
      const items = await readItems<PersonDoc>("people");
      const p = items.find((x) => x.id === person_id);
      if (!p) return JSON.stringify({ ok: false, error: "not_found" });
      Object.assign(p, pick({ name, relation, everyDays: every_days }));
      await familyCol.doc("people").set({ items }, { merge: true });
      actions.push(`عدّلت بيانات ${p.name}`);
      return JSON.stringify({ ok: true });
    },
  });

  const updateJournal = betaZodTool({
    name: "update_journal",
    description:
      "Rewrite a journal day's mood, text or gratitude (replaces, unlike write_journal which appends). Read it with get_journal first. Pass null to keep a field.",
    inputSchema: z.object({
      day: dayKey,
      mood: z.number().int().min(1).max(5).nullable(),
      text: z.string().max(8000).nullable(),
      gratitude: z.string().max(1000).nullable(),
    }),
    run: async ({ day, mood, text, gratitude }) => {
      const ref = journal.doc(day);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      const changes = pick({ mood, text, gratitude });
      if (!Object.keys(changes).length) return JSON.stringify({ ok: false, error: "nothing_to_change" });
      await ref.update({ ...changes, updatedAt: Date.now() });
      actions.push(`عدّلت يومية ${day}`);
      return JSON.stringify({ ok: true });
    },
  });

  // ───────────── المسح (على خطوتين) وسلة المحذوفات ─────────────
  const TRASH_DAYS = 30;
  const trash = userDoc.collection("trash");
  const pendingRef = userDoc.collection("assistant").doc("pending_delete");
  const kinds = ["task", "habit", "transaction", "journal", "goal", "occasion", "person"] as const;
  type Kind = (typeof kinds)[number];
  const kindAr: Record<Kind, string> = {
    task: "مهمة", habit: "عادة", transaction: "عملية فلوس", journal: "يومية",
    goal: "هدف", occasion: "مناسبة", person: "شخص",
  };
  const docCol: Partial<Record<Kind, CollRefLike>> = { task: tasks, habit: habits, transaction: transactions, journal };
  const listDoc: Partial<Record<Kind, { ref: DocRefLike; field: string }>> = {
    goal: { ref: goalsRef, field: "list" },
    occasion: { ref: familyCol.doc("occasions"), field: "items" },
    person: { ref: familyCol.doc("people"), field: "items" },
  };

  /** بيرجّع العنصر نفسه (للعرض وللسلة) أو null */
  async function findItem(kind: Kind, id: string): Promise<DocData | null> {
    const col = docCol[kind];
    if (col) {
      const snap = await col.doc(id).get();
      return snap.exists ? (snap.data() ?? {}) : null;
    }
    const { ref, field } = listDoc[kind]!;
    const items = ((await ref.get()).data()?.[field] ?? []) as DocData[];
    return items.find((x) => x.id === id) ?? null;
  }

  function describeItem(kind: Kind, d: DocData): string {
    switch (kind) {
      case "task": return `${d.title}${d.dueDate ? ` (${d.dueDate})` : ""}`;
      case "habit": return `${d.emoji ?? ""} ${d.title}`.trim();
      case "transaction": return `${d.type === "income" ? "دخل" : "مصروف"} ${d.amount} ج.م • ${catAr[d.category] ?? d.category} • ${d.date}${d.note ? ` • ${d.note}` : ""}`;
      case "journal": return `يومية ${d.day}: ${String(d.text ?? "").slice(0, 80)}`;
      case "goal": return `${d.emoji ?? "🎯"} ${d.title}`;
      case "occasion": return `${d.title} (${d.day}/${d.month})`;
      case "person": return `${d.name}${d.relation ? ` (${d.relation})` : ""}`;
    }
  }

  async function purgeOldTrash(): Promise<void> {
    const cutoff = Date.now() - TRASH_DAYS * 86_400_000;
    const old = await trash.where("deletedAt", "<", cutoff).limit(50).get();
    await Promise.all(old.docs.map((d) => trash.doc(d.id).delete()));
  }

  const prepareDelete = betaZodTool({
    name: "prepare_delete",
    description:
      "Step 1 of deleting: returns exactly what would be deleted and a one-time confirmation code. Show the user the item and ask them to confirm. Do NOT call confirm_delete until the user explicitly says yes in their own reply. Deleted items go to a trash for 30 days and can be restored.",
    inputSchema: z.object({
      kind: z.enum(kinds),
      id: z.string().min(1).max(100).describe("Item id (for journal: the day YYYY-MM-DD)"),
    }),
    run: async ({ kind, id }) => {
      const item = await findItem(kind, id);
      if (!item) return JSON.stringify({ ok: false, error: "not_found" });
      const code = Math.random().toString(36).slice(2, 8);
      await pendingRef.set({ code, kind, id, expiresAt: Date.now() + 10 * 60_000 });
      return JSON.stringify({
        ok: true,
        will_delete: `${kindAr[kind]}: ${describeItem(kind, item)}`,
        confirmation_code: code,
        next: "Ask the user to confirm. Only after they say yes, call confirm_delete with this code (valid 10 minutes).",
      });
    },
  });

  const confirmDelete = betaZodTool({
    name: "confirm_delete",
    description:
      "Step 2 of deleting: only after the user explicitly confirmed in chat. Moves the item prepared by prepare_delete to the trash (restorable for 30 days).",
    inputSchema: z.object({ confirmation_code: z.string().min(4).max(12) }),
    run: async ({ confirmation_code }) => {
      const p = (await pendingRef.get()).data();
      if (!p || p.code !== confirmation_code || (p.expiresAt as number) < Date.now()) {
        return JSON.stringify({ ok: false, error: "invalid_or_expired_code", hint: "call prepare_delete again" });
      }
      const kind = p.kind as Kind;
      const id = p.id as string;
      const item = await findItem(kind, id);
      if (!item) return JSON.stringify({ ok: false, error: "not_found" });
      await trash.add({ kind, itemId: id, data: item, label: describeItem(kind, item), deletedAt: Date.now() });
      const col = docCol[kind];
      if (col) {
        await col.doc(id).delete();
      } else {
        const { ref, field } = listDoc[kind]!;
        await db.runTransaction(async (tx) => {
          const items = ((await tx.get(ref)).data()?.[field] ?? []) as DocData[];
          tx.set(ref, { [field]: items.filter((x) => x.id !== id) }, { merge: true });
        });
      }
      await pendingRef.set({ code: null, expiresAt: 0 });
      await purgeOldTrash();
      actions.push(`مسحت ${kindAr[kind]}: ${describeItem(kind, item)} (في السلة 30 يوم)`);
      return JSON.stringify({ ok: true, in_trash_days: TRASH_DAYS });
    },
  });

  const listTrash = betaZodTool({
    name: "list_trash",
    description: "List deleted items still in the trash (last 30 days), newest first, with ids for restore_deleted.",
    inputSchema: z.object({}),
    run: async () => {
      await purgeOldTrash();
      const snap = await trash.orderBy("deletedAt", "desc").limit(50).get();
      return JSON.stringify({
        items: snap.docs.map((d) => {
          const t = d.data();
          return {
            id: d.id,
            what: `${kindAr[t.kind as Kind] ?? t.kind}: ${t.label}`,
            deleted_at: new Date(t.deletedAt as number).toISOString().slice(0, 10),
          };
        }),
      });
    },
  });

  const restoreDeleted = betaZodTool({
    name: "restore_deleted",
    description: "Put an item from the trash back where it was (id from list_trash).",
    inputSchema: z.object({ trash_id: z.string().min(1).max(100) }),
    run: async ({ trash_id }) => {
      const ref = trash.doc(trash_id);
      const snap = await ref.get();
      if (!snap.exists) return JSON.stringify({ ok: false, error: "not_found" });
      const t = snap.data()!;
      const kind = t.kind as Kind;
      const col = docCol[kind];
      if (col) {
        await col.doc(t.itemId as string).set(t.data as DocData);
      } else {
        const { ref: listRef, field } = listDoc[kind]!;
        await db.runTransaction(async (tx) => {
          const items = ((await tx.get(listRef)).data()?.[field] ?? []) as DocData[];
          if (!items.some((x) => x.id === t.itemId)) items.push(t.data as DocData);
          tx.set(listRef, { [field]: items }, { merge: true });
        });
      }
      await ref.delete();
      actions.push(`رجّعت ${kindAr[kind]}: ${t.label}`);
      return JSON.stringify({ ok: true });
    },
  });

  return [
    updateTask,
    updateHabit,
    listTransactions,
    updateTransaction,
    updateGoal,
    updateOccasion,
    updatePerson,
    updateJournal,
    prepareDelete,
    confirmDelete,
    listTrash,
    restoreDeleted,
    focusTool,
    qadaTool,
    goalsTool,
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

