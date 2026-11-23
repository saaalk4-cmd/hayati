/**
 * Firestore REST بنفس شكل firebase-admin اللي الأدوات بتستخدمه (DbLike).
 * كل الطلبات بتتبعت بتوكن المستخدم نفسه، فقواعد الحماية (firestore.rules)
 * هي اللي بتضمن إنه يوصل لبياناته بس.
 */
import type {
  CollRefLike,
  DbLike,
  DocData,
  DocRefLike,
  DocSnap,
  QueryDocSnap,
  QueryLike,
  QuerySnap,
  TxLike,
} from "../../functions/src/tools.ts";

/** علامة حذف حقل (زي FieldValue.delete()) */
export const DELETE = Symbol("delete");
export const FieldValue = { delete: () => DELETE };

type Value = Record<string, unknown>;
type Fetch = typeof fetch;

// ───────────── تحويل القيم ─────────────

export function encode(v: unknown): Value {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (typeof v === "string") return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  if (typeof v === "object") return { mapValue: { fields: encodeFields(v as DocData) } };
  throw new Error(`unsupported value: ${typeof v}`);
}

export function encodeFields(data: DocData): Record<string, Value> {
  const out: Record<string, Value> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === undefined || v === DELETE) continue;
    out[k] = encode(v);
  }
  return out;
}

export function decode(v: Value): unknown {
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("stringValue" in v) return v.stringValue;
  if ("timestampValue" in v) return Date.parse(String(v.timestampValue));
  if ("arrayValue" in v) {
    const values = ((v.arrayValue as { values?: Value[] }).values ?? []);
    return values.map(decode);
  }
  if ("mapValue" in v) {
    return decodeFields(((v.mapValue as { fields?: Record<string, Value> }).fields ?? {}));
  }
  if ("referenceValue" in v) return v.referenceValue;
  if ("geoPointValue" in v) return v.geoPointValue;
  return null;
}

export function decodeFields(fields: Record<string, Value>): DocData {
  const out: DocData = {};
  for (const [k, v] of Object.entries(fields)) out[k] = decode(v);
  return out;
}

/** جزء من مسار الحقل: لو فيه حروف غير عادية لازم يتحط بين `` */
export function quoteSegment(s: string): string {
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(s) ? s : "`" + s.replace(/[`\\]/g, (c) => "\\" + c) + "`";
}

function isPlainObject(v: unknown): v is DocData {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/** مسارات الأوراق للدمج (merge: true) زي admin SDK */
export function leafPaths(data: DocData, prefix: string[] = []): string[][] {
  const out: string[][] = [];
  for (const [k, v] of Object.entries(data)) {
    if (v === undefined) continue;
    const path = [...prefix, k];
    if (isPlainObject(v) && Object.keys(v).length > 0) out.push(...leafPaths(v, path));
    else out.push(path);
  }
  return out;
}

/** update({ "done.2026-11-23": true }) => حقول متداخلة + مسارات */
export function expandDotted(data: DocData): { fields: DocData; paths: string[][] } {
  const fields: DocData = {};
  const paths: string[][] = [];
  for (const [key, value] of Object.entries(data)) {
    const segs = key.split(".");
    paths.push(segs);
    if (value === DELETE) continue;
    let cur = fields;
    for (const s of segs.slice(0, -1)) {
      if (!isPlainObject(cur[s])) cur[s] = {};
      cur = cur[s] as DocData;
    }
    cur[segs[segs.length - 1]] = value;
  }
  return { fields, paths };
}

// ───────────── قاعدة البيانات ─────────────

export class RestFirestore implements DbLike {
  readonly base: string;
  constructor(
    projectId: string,
    private readonly token: () => Promise<string>,
    // لازم fetch يتنادى من غير this (قيد في Workers)
    private readonly fetcher: Fetch = (input, init) => fetch(input, init),
  ) {
    this.base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  }

  async request(method: string, url: string, body?: unknown): Promise<Response> {
    const res = await this.fetcher(url, {
      method,
      headers: {
        Authorization: `Bearer ${await this.token()}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return res;
  }

  async json<T>(method: string, url: string, body?: unknown): Promise<T> {
    const res = await this.request(method, url, body);
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`firestore ${method} ${res.status}: ${text.slice(0, 300)}`);
    }
    return (await res.json()) as T;
  }

  collection(name: string): CollRefLike {
    return new RestCollection(this, [name]);
  }

  async runTransaction<R>(fn: (tx: TxLike) => Promise<R>): Promise<R> {
    // مستخدم واحد بيكتب في بياناته: قراءة وكتابة عادية تكفي
    const tx: TxLike = {
      get: (ref: DocRefLike) => ref.get(),
      set: (ref: DocRefLike, data: DocData, opts?: { merge?: boolean }) => ref.set(data, opts),
    };
    const writes: Promise<unknown>[] = [];
    const tracked: TxLike = {
      get: tx.get,
      set: (ref, data, opts) => {
        const p = tx.set(ref, data, opts) as Promise<unknown>;
        writes.push(p);
        return p;
      },
    };
    const result = await fn(tracked);
    await Promise.all(writes);
    return result;
  }
}

function docId(name: string): string {
  return name.slice(name.lastIndexOf("/") + 1);
}

class RestDoc implements DocRefLike {
  constructor(
    private readonly db: RestFirestore,
    readonly path: string[],
  ) {}

  get id(): string {
    return this.path[this.path.length - 1];
  }

  private get url(): string {
    return `${this.db.base}/${this.path.map(encodeURIComponent).join("/")}`;
  }

  collection(name: string): CollRefLike {
    return new RestCollection(this.db, [...this.path, name]);
  }

  async get(): Promise<DocSnap> {
    const res = await this.db.request("GET", this.url);
    if (res.status === 404) return { id: this.id, exists: false, data: () => undefined };
    if (!res.ok) throw new Error(`firestore GET ${res.status}: ${(await res.text()).slice(0, 300)}`);
    const doc = (await res.json()) as { fields?: Record<string, Value> };
    const data = decodeFields(doc.fields ?? {});
    return { id: this.id, exists: true, data: () => data };
  }

  async set(data: DocData, opts?: { merge?: boolean }): Promise<unknown> {
    if (!opts?.merge) {
      return this.db.json("PATCH", this.url, { fields: encodeFields(data) });
    }
    const paths = leafPaths(data);
    const mask = paths.map((p) => `updateMask.fieldPaths=${encodeURIComponent(p.map(quoteSegment).join("."))}`);
    return this.db.json("PATCH", `${this.url}?${mask.join("&")}`, { fields: encodeFields(stripDeletes(data)) });
  }

  async update(data: DocData): Promise<unknown> {
    const { fields, paths } = expandDotted(data);
    const mask = paths.map((p) => `updateMask.fieldPaths=${encodeURIComponent(p.map(quoteSegment).join("."))}`);
    return this.db.json(
      "PATCH",
      `${this.url}?${mask.join("&")}&currentDocument.exists=true`,
      { fields: encodeFields(fields) },
    );
  }
}

function stripDeletes(data: DocData): DocData {
  const out: DocData = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === DELETE || v === undefined) continue;
    out[k] = isPlainObject(v) ? stripDeletes(v) : v;
  }
  return out;
}

type Filter = { field: string; op: string; value: unknown };

const OPS: Record<string, string> = {
  "==": "EQUAL",
  "!=": "NOT_EQUAL",
  "<": "LESS_THAN",
  "<=": "LESS_THAN_OR_EQUAL",
  ">": "GREATER_THAN",
  ">=": "GREATER_THAN_OR_EQUAL",
  "array-contains": "ARRAY_CONTAINS",
  in: "IN",
};

class RestQuery implements QueryLike {
  constructor(
    protected readonly db: RestFirestore,
    readonly path: string[],
    private readonly filters: Filter[] = [],
    private readonly order: { field: string; dir: string }[] = [],
    private readonly max?: number,
  ) {}

  where(field: string, op: string, value: unknown): QueryLike {
    if (!OPS[op]) throw new Error(`unsupported op ${op}`);
    return new RestQuery(this.db, this.path, [...this.filters, { field, op, value }], this.order, this.max);
  }

  orderBy(field: string, dir: string = "asc"): QueryLike {
    return new RestQuery(this.db, this.path, this.filters, [...this.order, { field, dir }], this.max);
  }

  limit(n: number): QueryLike {
    return new RestQuery(this.db, this.path, this.filters, this.order, n);
  }

  async get(): Promise<QuerySnap> {
    const parent = this.path.slice(0, -1);
    const collectionId = this.path[this.path.length - 1];
    const url = parent.length
      ? `${this.db.base}/${parent.map(encodeURIComponent).join("/")}:runQuery`
      : `${this.db.base}:runQuery`;
    const fieldFilters = this.filters.map((f) => ({
      fieldFilter: { field: { fieldPath: f.field }, op: OPS[f.op], value: encode(f.value) },
    }));
    const structuredQuery: Record<string, unknown> = { from: [{ collectionId }] };
    if (fieldFilters.length === 1) structuredQuery.where = fieldFilters[0];
    if (fieldFilters.length > 1) {
      structuredQuery.where = { compositeFilter: { op: "AND", filters: fieldFilters } };
    }
    if (this.order.length) {
      structuredQuery.orderBy = this.order.map((o) => ({
        field: { fieldPath: o.field },
        direction: o.dir === "desc" ? "DESCENDING" : "ASCENDING",
      }));
    }
    if (this.max !== undefined) structuredQuery.limit = this.max;
    const rows = await this.db.json<{ document?: { name: string; fields?: Record<string, Value> } }[]>(
      "POST",
      url,
      { structuredQuery },
    );
    const docs: QueryDocSnap[] = rows
      .filter((r) => r.document)
      .map((r) => {
        const data = decodeFields(r.document!.fields ?? {});
        return { id: docId(r.document!.name), exists: true, data: () => data };
      });
    return { docs };
  }
}

class RestCollection extends RestQuery implements CollRefLike {
  doc(id: string): DocRefLike {
    return new RestDoc(this.db, [...this.path, id]);
  }

  async add(data: DocData): Promise<{ id: string }> {
    const url = `${this.db.base}/${this.path.map(encodeURIComponent).join("/")}`;
    const doc = await this.db.json<{ name: string }>("POST", url, { fields: encodeFields(data) });
    return { id: docId(doc.name) };
  }
}
