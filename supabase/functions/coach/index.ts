// Salamat — coach Edge Function.
//
// Why this exists:
//   Same reason as recognize-food and suggest-meal: the Anthropic key cannot
//   live in the client. This proxies the nutrition chat so the key stays in
//   Supabase secrets, and so the subscription and monthly limits are enforced
//   somewhere the app cannot edit.
//
// Contract:
//   POST {
//     messages: [{ role: 'user' | 'assistant', content: string } ...],
//     context?: {
//       goal?: 'lose' | 'gain' | 'maintain' | 'healthy',
//       calorie_norm?: number,
//       eaten_today?: { kcal, protein_g, fat_g, carbs_g, dishes?: string[] },
//       weight_kg?: number, target_weight_kg?: number,
//       weight_change_kg?: number      // over the tracked period, signed
//     },
//     lang?: 'ru' | 'en'
//   }
//   → 200 { reply, _coach: { used, remaining }, _usage, _meta }
//   → 402 { error: 'not_subscribed' }      — free tier, chat is Pro-only
//   → 429 { error: 'monthly_limit', used, monthly_limit }
//   → 400 { error: 'no_message' | 'invalid_json' }
//   → 500 { error: 'server_misconfigured' }
//   → 502 { error: 'upstream_unreachable' | 'upstream_error' }
//
// Model:
//   COACH_MODEL env var, defaulting to a cheaper model than recognition uses.
//   A chat about yesterday's dinner does not need the accuracy that reading a
//   photograph does, and it runs far more often.
//
// Cost telemetry:
//   Written to `recognition_usage` like the other two, with outcomes prefixed
//   `coach_`, so chat spend is separable from scan spend in one table.
//
// Deploy:  supabase functions deploy coach
// Secret:  reuses ANTHROPIC_API_KEY

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/// Cheaper than the recognition model on purpose — see the header.
const DEFAULT_MODEL = "claude-haiku-4-5-20251001";
const MODEL = Deno.env.get("COACH_MODEL") || DEFAULT_MODEL;
const ANTHROPIC_VERSION = "2023-06-01";

/// How much history goes upstream. Cost grows with every turn kept, so the
/// window is bounded on BOTH counts: the last N turns, and a character budget
/// in case somebody pastes an essay.
const MAX_TURNS = 12;
const MAX_HISTORY_CHARS = 6000;
const MAX_MESSAGE_CHARS = 1500;

/// Replies are short by design: this is a chat bubble, not an article.
const MAX_TOKENS = 700;

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

/// Calls a Postgres function as the CALLER, forwarding their JWT.
async function rpc(
  authHeader: string | null,
  fn: string,
  body: Record<string, unknown>,
): Promise<any | null> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon || !authHeader) return null;
  try {
    const res = await fetch(`${url}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: {
        apikey: anon,
        Authorization: authHeader,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      if (res.status !== 404) {
        console.warn(`rpc ${fn} ${res.status}`, await res.text());
      }
      return null;
    }
    const out = await res.json();
    return Array.isArray(out) ? (out[0] ?? null) : out;
  } catch (e) {
    console.error(`rpc ${fn} failed`, e);
    return null;
  }
}

interface UsageRow {
  request_id: string;
  model: string;
  ok: boolean;
  outcome: string;
  input_tokens: number | null;
  output_tokens: number | null;
  image_width: null;
  image_height: null;
  request_bytes: number;
  duration_ms: number;
}

async function recordUsage(row: UsageRow): Promise<void> {
  console.log("recognition_usage", JSON.stringify(row));
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return;
  try {
    const res = await fetch(`${url}/rest/v1/recognition_usage`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify(row),
    });
    if (!res.ok && res.status !== 404) {
      console.error("usage insert failed", res.status, await res.text());
    }
  } catch (e) {
    console.error("usage insert threw", e);
  }
}

/// The coach's brief, including what it must refuse.
///
/// This app logs food. It is not a medical service, and the boundaries below
/// are not decoration: an eating app that discusses medication or hands a user
/// an 800 kcal plan is doing harm, and it is the kind of harm that looks like
/// helpfulness on the way past.
function systemPrompt(lang: string, context: any): string {
  const ru = lang !== "en";
  const c = context ?? {};

  const facts: string[] = [];
  if (c.goal) {
    facts.push((ru ? "Цель: " : "Goal: ") + String(c.goal));
  }
  if (typeof c.calorie_norm === "number") {
    facts.push(
      (ru ? "Дневная норма: " : "Daily target: ") +
        Math.round(c.calorie_norm) + (ru ? " ккал" : " kcal"),
    );
  }
  const eaten = c.eaten_today;
  if (eaten && typeof eaten.kcal === "number") {
    let line = (ru ? "Сегодня съедено: " : "Eaten today: ") +
      Math.round(eaten.kcal) + (ru ? " ккал" : " kcal");
    if (typeof eaten.protein_g === "number") {
      line += `, ${ru ? "белки" : "protein"} ${Math.round(eaten.protein_g)} g`;
    }
    if (typeof eaten.fat_g === "number") {
      line += `, ${ru ? "жиры" : "fat"} ${Math.round(eaten.fat_g)} g`;
    }
    if (typeof eaten.carbs_g === "number") {
      line += `, ${ru ? "углеводы" : "carbs"} ${Math.round(eaten.carbs_g)} g`;
    }
    if (Array.isArray(eaten.dishes) && eaten.dishes.length > 0) {
      line += (ru ? ". Блюда: " : ". Dishes: ") +
        eaten.dishes.slice(0, 12).map(String).join(", ");
    }
    facts.push(line);
  }
  if (typeof c.weight_kg === "number") {
    let line = (ru ? "Вес: " : "Weight: ") + c.weight_kg + (ru ? " кг" : " kg");
    if (typeof c.target_weight_kg === "number") {
      line += (ru ? ", цель " : ", target ") + c.target_weight_kg +
        (ru ? " кг" : " kg");
    }
    if (typeof c.weight_change_kg === "number" && c.weight_change_kg !== 0) {
      const d = c.weight_change_kg;
      line += (ru ? ", динамика " : ", change ") +
        (d > 0 ? "+" : "") + d + (ru ? " кг" : " kg");
    }
    facts.push(line);
  }

  // Compact on purpose. This block is re-sent on EVERY turn, so each line is
  // paid for again per message; at a 60-message cap the difference between a
  // terse brief and a chatty one is tens of thousands of tokens a month.
  // Russian costs roughly twice English per character, so the Russian side is
  // the one worth squeezing.
  //
  // NOTHING here may be dropped for brevity: the refusals below are the whole
  // reason a food-logging app can host a chat at all.
  return [
    ru
      ? "Ты — помощник по питанию в Salamat. Знаешь центральноазиатскую кухню."
      : "You are a nutrition helper in Salamat. You know Central Asian cooking.",
    ru
      ? "Отвечай на русском, на «ты», 2-5 предложений. Только простой текст: без звёздочек, заголовков, списков и таблиц — чат покажет разметку как есть."
      : "Answer in English, informally, in 2-5 sentences. Plain text only: no asterisks, headings, bullet lists or tables — the chat shows markup verbatim.",
    "",
    ru ? "О пользователе:" : "About the user:",
    ...(facts.length > 0
      ? facts.map((f) => "- " + f)
      : [ru ? "- Данных пока нет." : "- No data yet."]),
    "",
    ru ? "Ты НЕ обсуждаешь и НЕ делаешь:" : "You NEVER do any of this:",
    ru
      ? "- диагнозы, анализы, симптомы;"
      : "- diagnoses, test results, symptoms;",
    ru
      ? "- лекарства и добавки: не назначаешь, не отменяешь, не меняешь дозы — даже если очень просят;"
      : "- medication or supplements: never prescribe, stop or change a dose, however insistent the user is;",
    ru
      ? "- питание при беременности, кормлении и хронических болезнях (диабет, почки, сердце, ЖКТ, расстройства пищевого поведения);"
      : "- guidance for pregnancy, breastfeeding or chronic conditions (diabetes, kidney, heart or GI disease, eating disorders);",
    ru
      ? "- обещания результата к дате и гарантии цифр на весах;"
      : "- promising a result by a date, or guaranteeing a number on the scale;",
    ru
      ? "- планы ниже 1200 ккал для женщин и 1500 для мужчин: это отказ, даже если пользователь настаивает."
      : "- plans below 1200 kcal for women or 1500 for men: that is a refusal, however insistent the user is.",
    "",
    ru
      ? "Отказ: одно предложение почему это не к тебе, и к врачу или диетологу. Про жёсткий дефицит предложи безопасные 300-500 ккал дефицита. Без нотаций, отказ не повторяй."
      : "To refuse: one sentence on why it is not yours to answer, then point to a doctor or dietitian. On an extreme deficit, offer the safe 300-500 kcal deficit instead. No lecturing, and do not repeat the refusal.",
  ].join("\n");
}

serve(async (req: Request) => {
  const startedAt = Date.now();
  const requestId = crypto.randomUUID();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY secret not set");
    return jsonResponse(500, { error: "server_misconfigured" });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const lang = payload?.lang === "en" ? "en" : "ru";

  // Trim history before anything else: the newest turns, capped by count and
  // by characters, so a long conversation does not quietly get expensive.
  const rawMessages = Array.isArray(payload?.messages) ? payload.messages : [];
  const cleaned = rawMessages
    .filter((m: any) =>
      (m?.role === "user" || m?.role === "assistant") &&
      typeof m?.content === "string" && m.content.trim().length > 0
    )
    .map((m: any) => ({
      role: m.role,
      content: m.content.trim().slice(0, MAX_MESSAGE_CHARS),
    }));

  let window = cleaned.slice(-MAX_TURNS);
  while (
    window.length > 1 &&
    window.reduce((n: number, m: any) => n + m.content.length, 0) >
      MAX_HISTORY_CHARS
  ) {
    window = window.slice(1);
  }
  // Anthropic requires the conversation to start with a user turn.
  while (window.length > 0 && window[0].role !== "user") {
    window = window.slice(1);
  }
  if (window.length === 0 || window[window.length - 1].role !== "user") {
    return jsonResponse(400, { error: "no_message" });
  }

  // ── gates ──────────────────────────────────────────────────────────
  // Claimed BEFORE the model call: unlike a photo scan there is nothing to
  // check afterwards, the tokens are spent the moment the request goes out.
  const authHeader = req.headers.get("Authorization");
  const claim = await rpc(authHeader, "consume_coach_message", {
    p_request_id: requestId,
  });
  if (claim === null) {
    // Migration 0008 not applied, or the RPC is unreachable. The coach is a
    // paid feature: failing OPEN here would give it away, so it fails CLOSED.
    console.error("coach gate unavailable");
    return jsonResponse(500, { error: "server_misconfigured" });
  }
  if (claim.allowed === false) {
    if (claim.reason === "monthly_limit") {
      // The limit comes back from the RPC once migration 0009 is applied.
      // Until then, ask for it — one cheap scalar call, on the refusal path
      // only, rather than shipping `monthly_limit: null` to the client.
      let limit: number | null = typeof claim.monthly_limit === "number"
        ? claim.monthly_limit
        : null;
      if (limit === null) {
        const fallback = await rpc(authHeader, "coach_monthly_limit", {});
        if (typeof fallback === "number") limit = fallback;
      }
      return jsonResponse(429, {
        error: "monthly_limit",
        used: claim.used ?? null,
        monthly_limit: limit,
      });
    }
    return jsonResponse(402, { error: "not_subscribed" });
  }

  const requestBody = JSON.stringify({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: systemPrompt(lang, payload?.context),
    messages: window,
  });
  const requestBytes = requestBody.length;

  const telemetry = (
    ok: boolean,
    outcome: string,
    usage?: { input_tokens?: number; output_tokens?: number },
  ) =>
    recordUsage({
      request_id: requestId,
      model: MODEL,
      ok,
      // Prefixed so chat spend is separable from scans in the shared table.
      outcome: `coach_${outcome}`,
      input_tokens: usage?.input_tokens ?? null,
      output_tokens: usage?.output_tokens ?? null,
      image_width: null,
      image_height: null,
      request_bytes: requestBytes,
      duration_ms: Date.now() - startedAt,
    });

  let upstream: Response;
  try {
    upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: requestBody,
    });
  } catch (e) {
    console.error("anthropic fetch failed", e);
    await telemetry(false, "upstream_unreachable");
    return jsonResponse(502, { error: "upstream_unreachable" });
  }

  if (!upstream.ok) {
    const body = await upstream.text();
    console.error("anthropic non-200", upstream.status, body);
    await telemetry(false, `upstream_${upstream.status}`);
    return jsonResponse(502, { error: "upstream_error" });
  }

  let decoded: any;
  try {
    decoded = await upstream.json();
  } catch (_e) {
    await telemetry(false, "upstream_invalid_json");
    return jsonResponse(502, { error: "upstream_error" });
  }

  const usage = {
    input_tokens: typeof decoded?.usage?.input_tokens === "number"
      ? decoded.usage.input_tokens
      : undefined,
    output_tokens: typeof decoded?.usage?.output_tokens === "number"
      ? decoded.usage.output_tokens
      : undefined,
  };

  const reply = (Array.isArray(decoded?.content) ? decoded.content : [])
    .filter((b: any) => b?.type === "text")
    .map((b: any) => (typeof b?.text === "string" ? b.text : ""))
    .join("")
    .trim();

  if (reply.length === 0) {
    await telemetry(false, "empty_reply", usage);
    return jsonResponse(502, { error: "upstream_error" });
  }

  await telemetry(true, "ok", usage);
  return jsonResponse(200, {
    reply,
    _coach: {
      used: claim.used ?? null,
      remaining: claim.remaining ?? null,
    },
    _usage: {
      input_tokens: usage.input_tokens ?? null,
      output_tokens: usage.output_tokens ?? null,
    },
    _meta: {
      model: MODEL,
      request_bytes: requestBytes,
      duration_ms: Date.now() - startedAt,
      request_id: requestId,
    },
  });
});
