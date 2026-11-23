/** صفحة تسجيل الدخول والموافقة (عربي، نفس ألوان حياتي الغامقة) */
import type { ConsentDescription } from "@cloudflare/workers-oauth-provider";

export const escapeHtml = (value: string) =>
  value.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

const STYLE = `
:root{--bg:#0b2a21;--bg2:#06170f;--card:#123a2e;--line:#2a5a48;--text:#f1ede2;--muted:#b9c4bc;--gold:#d4af5a;--danger:#ff8a80}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;font-family:system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif;color:var(--text);
background:radial-gradient(circle at 50% 0,var(--bg) 0,var(--bg2) 70%);display:flex;align-items:center;justify-content:center;padding:16px}
.card{width:100%;max-width:420px;background:var(--card);border:1px solid var(--line);border-radius:24px;padding:28px 22px;box-shadow:0 20px 60px #0008}
.logo{width:64px;height:64px;border-radius:18px;margin:0 auto 12px;display:flex;align-items:center;justify-content:center;
background:linear-gradient(135deg,#1f6b52,#0e3b2e);border:1.5px solid var(--gold);font-size:30px}
h1{font-size:22px;text-align:center;margin:0 0 6px}
p{line-height:1.7;color:var(--muted);margin:6px 0;font-size:15px}
.who{background:#0d2f25;border:1px solid var(--line);border-radius:14px;padding:12px;margin:14px 0;font-size:14px}
.who b{color:var(--text)}
.warn{color:var(--gold)}
label{display:block;font-size:14px;margin:12px 0 6px;color:var(--muted)}
input{width:100%;padding:13px 14px;border-radius:14px;border:1px solid var(--line);background:#0a251d;color:var(--text);font-size:16px}
input:focus{outline:2px solid var(--gold);border-color:transparent}
.btns{display:flex;gap:10px;margin-top:18px}
button{flex:1;padding:14px;border-radius:14px;border:0;font-size:16px;font-weight:700;cursor:pointer}
.ok{background:var(--gold);color:#1b1405}
.no{background:transparent;color:var(--muted);border:1px solid var(--line)}
.err{background:#3a1512;border:1px solid #7a2a24;color:var(--danger);border-radius:12px;padding:10px 12px;font-size:14px;margin-top:12px}
ul{margin:8px 0 0;padding-inline-start:20px;color:var(--muted);font-size:14px;line-height:1.8}
.small{font-size:13px;text-align:center;margin-top:16px}
`;

function shell(title: string, body: string): string {
  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<title>${escapeHtml(title)}</title><style>${STYLE}</style></head>
<body><main class="card">${body}</main></body></html>`;
}

export function signInPage(
  details: ConsentDescription,
  handle: string,
  opts: { error?: string; email?: string; query?: string } = {},
): string {
  const name = escapeHtml(details.clientName || "تطبيق");
  const host = escapeHtml(details.redirectHost);
  const verified = details.clientDomain
    ? `من <b>${escapeHtml(details.clientDomain)}</b>`
    : `<span class="warn">(الاسم ده كتبه التطبيق بنفسه، اتأكد إنك انت اللي بدأت التوصيل)</span>`;
  return shell(
    "وصّل حياتي",
    `<div class="logo">🌙</div>
<h1>وصّل «${name}» بحياتي</h1>
<p style="text-align:center">سجّل الدخول بحساب حياتي عشان تسمح له يشوف بياناتك ويسجّل فيها.</p>
<div class="who">
  التطبيق: <b>${name}</b> ${verified}<br>
  هيوصله التصريح على: <b>${host}</b>
  ${details.redirectIsLoopback ? '<br><span class="warn">⚠️ التصريح رايح لبرنامج على جهازك. كمّل بس لو انت اللي بدأت ده دلوقتي.</span>' : ""}
  <ul>
    <li>يقرا ويضيف: المهام، والعادات، والصلوات، والقرآن، والفلوس، والأهداف، والمناسبات</li>
    <li>يقرا ويكتب في اليوميات</li>
    <li>مش هيقدر يمسح أي حاجة</li>
  </ul>
</div>
<form method="post" action="/authorize">
  <input type="hidden" name="handle" value="${escapeHtml(handle)}">
  <input type="hidden" name="q" value="${escapeHtml(opts.query ?? "")}">
  <label for="email">الإيميل</label>
  <input id="email" name="email" type="email" autocomplete="username" required dir="ltr" value="${escapeHtml(opts.email ?? "")}">
  <label for="password">كلمة السر</label>
  <input id="password" name="password" type="password" autocomplete="current-password" dir="ltr">
  ${opts.error ? `<div class="err">${escapeHtml(opts.error)}</div>` : ""}
  <div class="btns">
    <button class="ok" name="decision" value="approve">دخول وسماح</button>
    <button class="no" name="decision" value="deny" formnovalidate>لأ</button>
  </div>
</form>
<p class="small">مالكش حساب؟ اعمل حساب من تطبيق حياتي الأول (المزيد ← الإعدادات).</p>
<p class="small">تقدر تلغي التوصيل في أي وقت من إعدادات Claude.</p>`,
  );
}

export function messagePage(title: string, message: string): string {
  return shell(title, `<div class="logo">🌙</div><h1>${escapeHtml(title)}</h1><p style="text-align:center">${escapeHtml(message)}</p>`);
}
