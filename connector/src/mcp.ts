/**
 * MCP (Streamable HTTP) من غير حالة: initialize و tools/list و tools/call.
 * كل طلب POST فيه رسالة JSON-RPC (أو مجموعة) والرد JSON عادي.
 */
import { z } from "zod";
import type { ToolDef } from "../../functions/src/tools.ts";

export const SUPPORTED_VERSIONS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];

export const INSTRUCTIONS = `These tools read and write the signed-in user's data in «حياتي» (Hayati), an Arabic personal-life app: tasks, habits, prayers, Quran reading, money, journal, goals, occasions and family contacts.
- The user lives in Egypt (Africa/Cairo time). Pass their local date (YYYY-MM-DD) for any day parameter.
- Reply in Egyptian colloquial Arabic, short and warm.
- To plan or review the user's day, call get_day_overview first.
- Never invent Quran verses or hadith; cite surah:ayah when quoting, or don't quote.
- Editing: use the update_* tools; pass null for fields that stay the same.
- Deleting is two steps and always needs the user's explicit yes: call prepare_delete, show the user exactly what will be deleted, wait for their reply, and only if they clearly agree call confirm_delete with the code. Never call confirm_delete in the same turn as prepare_delete.
- Deleted items stay in the trash for 30 days: list_trash and restore_deleted bring them back.`;

const READ_ONLY = new Set([
  "list_tasks",
  "get_prayer_log",
  "get_quran_progress",
  "list_habits",
  "get_money_summary",
  "get_journal",
  "list_occasions_and_people",
  "get_day_overview",
  "get_week_summary",
  "get_focus_stats",
  "list_transactions",
  "list_trash",
  "prepare_delete",
]);

const DESTRUCTIVE = new Set(["confirm_delete"]);

type Json = Record<string, unknown>;
interface RpcRequest {
  jsonrpc: "2.0";
  id?: string | number | null;
  method: string;
  params?: Json;
}

const rpcError = (id: RpcRequest["id"], code: number, message: string) => ({
  jsonrpc: "2.0",
  id: id ?? null,
  error: { code, message },
});

export function toolList(tools: ToolDef[]) {
  return tools.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: z.toJSONSchema(t.inputSchema, { io: "input", target: "draft-2020-12" }),
    annotations: {
      readOnlyHint: READ_ONLY.has(t.name),
      destructiveHint: DESTRUCTIVE.has(t.name),
      openWorldHint: false,
    },
  }));
}

async function handleOne(msg: RpcRequest, tools: () => ToolDef[]): Promise<Json | null> {
  const isNotification = msg.id === undefined;
  if (msg.jsonrpc !== "2.0" || typeof msg.method !== "string") {
    return rpcError(msg.id, -32600, "Invalid Request");
  }
  if (isNotification) return null;

  switch (msg.method) {
    case "initialize": {
      const asked = String(msg.params?.protocolVersion ?? "");
      return {
        jsonrpc: "2.0",
        id: msg.id,
        result: {
          protocolVersion: SUPPORTED_VERSIONS.includes(asked) ? asked : SUPPORTED_VERSIONS[0],
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "hayati", title: "حياتي", version: "1.0.0" },
          instructions: INSTRUCTIONS,
        },
      };
    }
    case "ping":
      return { jsonrpc: "2.0", id: msg.id, result: {} };
    case "tools/list":
      return { jsonrpc: "2.0", id: msg.id, result: { tools: toolList(tools()) } };
    case "tools/call": {
      const name = String(msg.params?.name ?? "");
      const tool = tools().find((t) => t.name === name);
      if (!tool) return rpcError(msg.id, -32602, `Unknown tool: ${name}`);
      const parsed = tool.inputSchema.safeParse(msg.params?.arguments ?? {});
      if (!parsed.success) {
        return {
          jsonrpc: "2.0",
          id: msg.id,
          result: {
            isError: true,
            content: [{ type: "text", text: `Invalid arguments: ${z.prettifyError(parsed.error)}` }],
          },
        };
      }
      try {
        const text = await tool.run(parsed.data);
        return { jsonrpc: "2.0", id: msg.id, result: { content: [{ type: "text", text }] } };
      } catch (e) {
        const message = e instanceof Error ? e.message : String(e);
        if (message === "session_expired") {
          return rpcError(msg.id, -32001, "Hayati session expired; reconnect the connector.");
        }
        return {
          jsonrpc: "2.0",
          id: msg.id,
          result: { isError: true, content: [{ type: "text", text: `Error: ${message.slice(0, 300)}` }] },
        };
      }
    }
    default:
      return rpcError(msg.id, -32601, `Method not found: ${msg.method}`);
  }
}

/** بيرد على طلب HTTP واحد على /mcp */
export async function handleMcp(request: Request, tools: () => ToolDef[]): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "POST" } });
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json(rpcError(null, -32700, "Parse error"), { status: 400 });
  }
  const batch = Array.isArray(body);
  const messages = (batch ? body : [body]) as RpcRequest[];
  const replies = (await Promise.all(messages.map((m) => handleOne(m, tools)))).filter(
    (r): r is Json => r !== null,
  );
  if (replies.length === 0) return new Response(null, { status: 202 });
  return Response.json(batch ? replies : replies[0], {
    headers: { "Cache-Control": "no-store" },
  });
}
