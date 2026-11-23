/** تسجيل الدخول بحساب حياتي (Firebase Auth REST) وتجديد التوكن */

type Fetch = typeof fetch;

export interface SignInResult {
  uid: string;
  email: string;
  idToken: string;
  refreshToken: string;
  expiresAt: number;
}

export class SignInError extends Error {
  constructor(
    readonly code: string,
    readonly arabic: string,
  ) {
    super(code);
  }
}

const MESSAGES: Record<string, string> = {
  EMAIL_NOT_FOUND: "الإيميل أو كلمة السر غلط",
  INVALID_PASSWORD: "الإيميل أو كلمة السر غلط",
  INVALID_LOGIN_CREDENTIALS: "الإيميل أو كلمة السر غلط",
  INVALID_EMAIL: "الإيميل مكتوب غلط",
  USER_DISABLED: "الحساب ده متوقف",
  TOO_MANY_ATTEMPTS_TRY_LATER: "محاولات كتير، استنى شوية وجرّب تاني",
  MISSING_PASSWORD: "اكتب كلمة السر",
};

export async function signInWithPassword(
  apiKey: string,
  email: string,
  password: string,
  fetcher: Fetch = fetch,
): Promise<SignInResult> {
  const res = await fetcher(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = (await res.json()) as {
    localId?: string;
    email?: string;
    idToken?: string;
    refreshToken?: string;
    expiresIn?: string;
    error?: { message?: string };
  };
  if (!res.ok || !body.idToken || !body.localId || !body.refreshToken) {
    const code = (body.error?.message ?? "UNKNOWN").split(" ")[0].split(":")[0];
    throw new SignInError(code, MESSAGES[code] ?? "معرفتش أسجّل دخولك، جرّب تاني");
  }
  return {
    uid: body.localId,
    email: body.email ?? email,
    idToken: body.idToken,
    refreshToken: body.refreshToken,
    expiresAt: Date.now() + Number(body.expiresIn ?? 3600) * 1000,
  };
}

/** توكنات متخزنة في ذاكرة الـ Worker (بتتمسح لوحدها لما يقوم من جديد) */
const cache = new Map<string, { token: string; expiresAt: number }>();

export async function idTokenFor(
  apiKey: string,
  uid: string,
  refreshToken: string,
  fetcher: Fetch = fetch,
): Promise<string> {
  const hit = cache.get(uid);
  if (hit && hit.expiresAt - 60_000 > Date.now()) return hit.token;
  const res = await fetcher(
    `https://securetoken.googleapis.com/v1/token?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: refreshToken }),
    },
  );
  const body = (await res.json()) as { id_token?: string; expires_in?: string; user_id?: string };
  if (!res.ok || !body.id_token) throw new Error("session_expired");
  if (body.user_id && body.user_id !== uid) throw new Error("uid_mismatch");
  cache.set(uid, { token: body.id_token, expiresAt: Date.now() + Number(body.expires_in ?? 3600) * 1000 });
  return body.id_token;
}
