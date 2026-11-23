/**
 * سيرفر «حياتي» لـ Claude (MCP Connector) على Cloudflare Workers.
 *
 * - /authorize: صفحة تسجيل الدخول بحساب حياتي والموافقة
 * - /mcp: أدوات حياتي (نفس أدوات المساعد في functions/src/tools.ts)
 *
 * السيرفر مش ماسك أي مفتاح لقاعدة البيانات: بيكلّم Firestore بتوكن المستخدم نفسه،
 * فقواعد الحماية هي اللي بتضمن إن كل واحد يوصل لبياناته بس.
 */
import OAuthProvider, {
  AuthorizationError,
  CimdFetchError,
  type OAuthHelpers,
} from "@cloudflare/workers-oauth-provider";
import { buildTools, type ToolDef } from "../../functions/src/tools.ts";
import { idTokenFor, SignInError, signInWithPassword } from "./firebase_auth.ts";
import { FieldValue, RestFirestore } from "./firestore.ts";
import { handleMcp } from "./mcp.ts";
import { escapeHtml, messagePage, signInPage } from "./page.ts";

export interface Env {
  OAUTH_KV: KVNamespace;
  OAUTH_PROVIDER: OAuthHelpers;
  /** إعدادات Firebase للتطبيق (مش سرية بس مش بتتحط في الكود) */
  FIREBASE_API_KEY: string;
  FIREBASE_PROJECT_ID: string;
  /** https://hayati.<subdomain>.workers.dev */
  PUBLIC_URL: string;
}

/** اللي بيتخزن (متشفّر) مع كل توصيل */
export interface Props {
  uid: string;
  email: string;
  refreshToken: string;
}

const SCOPE = "hayati";

function html(body: string, status = 200, headers?: Headers): Response {
  const h = headers ?? new Headers();
  h.set("Content-Type", "text/html; charset=utf-8");
  h.set("X-Frame-Options", "DENY");
  // متحطش form-action: Chrome بيطبّقه على التحويل لـ Claude بعد الدخول وبيوقفه
  h.set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'");
  h.set("Referrer-Policy", "no-referrer");
  return new Response(body, { status, headers: h });
}

/** صفحة /authorize: GET بتعرض الفورم، و POST بتسجّل الدخول وتكمّل التوصيل */
async function authorize(request: Request, env: Env): Promise<Response> {
  const oauth = env.OAUTH_PROVIDER;
  try {
    if (request.method === "GET") {
      const req = await oauth.parseAuthRequest(request);
      const details = await oauth.describeConsent(req);
      const consent = await oauth.beginConsent(req);
      return html(signInPage(details, consent.handle, { query: new URL(request.url).search }), 200, consent.headers);
    }
    if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    const form = await request.formData();
    const handle = String(form.get("handle") ?? "");
    if (form.get("decision") !== "approve") {
      const denied = await oauth.denyConsent(request, handle);
      return new Response(null, { status: 302, headers: denied.headers });
    }
    const email = String(form.get("email") ?? "").trim();
    const password = String(form.get("password") ?? "");
    let user;
    try {
      user = await signInWithPassword(env.FIREBASE_API_KEY, email, password);
    } catch (e) {
      if (!(e instanceof SignInError)) throw e;
      // نبدأ الصفحة من جديد بنفس طلب التوصيل الأصلي (بيتراجع تاني) ونعرض الخطأ
      const query = String(form.get("q") ?? "");
      const again = await oauth.parseAuthRequest(new Request(new URL(`/authorize${query}`, request.url)));
      const details = await oauth.describeConsent(again);
      const consent = await oauth.beginConsent(again);
      return html(signInPage(details, consent.handle, { error: e.arabic, email, query }), 401, consent.headers);
    }
    const approved = await oauth.approveConsent(request, handle, { scope: [SCOPE] });
    const props: Props = { uid: user.uid, email: user.email, refreshToken: user.refreshToken };
    const { redirectTo } = await oauth.completeAuthorization({
      request: approved.request,
      userId: user.uid,
      metadata: { email: user.email },
      scope: [SCOPE],
      props,
    });
    approved.headers.set("Location", redirectTo);
    return new Response(null, { status: 302, headers: approved.headers });
  } catch (error) {
    if (error instanceof AuthorizationError && error.redirectTo) {
      return Response.redirect(error.redirectTo, 302);
    }
    if (error instanceof AuthorizationError || error instanceof CimdFetchError) {
      // رسايل المكتبة بالإنجليزي؛ المستخدم يشوف رسالة عربي واضحة
      const message =
        "الصفحة دي اتستخدمت قبل كده أو وقتها خلص. ارجع لـ Claude ← Settings ← Connectors ودوس Connect جنب «حياتي» تاني.";
      return html(messagePage("حصلت مشكلة", message), 400);
    }
    throw error;
  }
}

/** الأدوات للمستخدم ده بس */
function toolsFor(env: Env, props: Props): () => ToolDef[] {
  let cached: ToolDef[] | undefined;
  return () => {
    if (cached) return cached;
    const db = new RestFirestore(env.FIREBASE_PROJECT_ID, () =>
      idTokenFor(env.FIREBASE_API_KEY, props.uid, props.refreshToken),
    );
    cached = buildTools<ToolDef>(
      { db, FieldValue, defineTool: (d) => d as unknown as ToolDef },
      props.uid,
      [],
    );
    return cached;
  };
}

const mcpHandler = {
  async fetch(request: Request, env: Env, ctx: ExecutionContext & { props: Props }): Promise<Response> {
    return handleMcp(request, toolsFor(env, ctx.props));
  },
};

const defaultHandler = {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/authorize") return authorize(request, env);
    if (url.pathname === "/" || url.pathname === "") {
      return html(
        messagePage(
          "حياتي لـ Claude",
          `ده سيرفر توصيل Claude بتطبيق حياتي. ضيف الرابط ${escapeHtml(env.PUBLIC_URL)}/mcp في Claude ← Settings ← Connectors.`,
        ),
      );
    }
    return new Response("Not Found", { status: 404 });
  },
};

let provider: OAuthProvider<Env> | undefined;

function getProvider(env: Env): OAuthProvider<Env> {
  provider ??= new OAuthProvider<Env>({
    apiRoute: "/mcp",
    apiHandler: mcpHandler as never,
    defaultHandler: defaultHandler as never,
    authorizeEndpoint: "/authorize",
    tokenEndpoint: "/token",
    clientRegistrationEndpoint: "/register",
    scopesSupported: [SCOPE],
    resourceMetadata: {
      resource: `${env.PUBLIC_URL}/mcp`,
      authorization_servers: [env.PUBLIC_URL],
    },
    // التوصيل يفضل شغال طول ما Claude بيستخدمه، ويقع لو اتساب 90 يوم
    refreshTokenIdleTTL: 90 * 24 * 3600,
    clientIdMetadataDocumentEnabled: true,
  });
  return provider;
}

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return getProvider(env).fetch(request, env, ctx);
  },
} satisfies ExportedHandler<Env>;
