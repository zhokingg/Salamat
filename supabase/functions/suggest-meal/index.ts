// Salamat — suggest-meal Edge Function.
//
// Why this exists:
//   Same reason as recognize-food: the Anthropic key cannot live in the mobile
//   client. This function proxies "what can I cook from what I have, that fits
//   what is left of my day" so the key only ever exists in Supabase secrets.
//
// Contract:
//   POST {
//     ingredients: string[],          // free-form, as the user typed them
//     remaining: { kcal, protein_g, fat_g, carbs_g },
//     goal?: 'lose' | 'gain' | 'maintain' | 'healthy',
//     lang?: 'ru' | 'en'
//   }
//   → 200 {
//       suggestions: [{
//         name, time_minutes,
//         ingredients: [{ name, amount }],
//         kcal: { min, max },
//         protein_g: { min, max }, fat_g: {...}, carbs_g: {...},
//         steps: string[]
//       } x3],
//       _usage: { input_tokens, output_tokens },
//       _meta:  { model, request_bytes, duration_ms, request_id }
//     }
//   → 400 { error } — bad input
//   → 401 { error } — missing JWT (Supabase enforces this when verify_jwt=true)
//   → 500 { error } — server-side misconfig (e.g. missing secret)
//   → 502 { error } — Anthropic upstream failure
//
// Deploy:        supabase functions deploy suggest-meal
// Secret:        reuses ANTHROPIC_API_KEY, already set for recognize-food
// Model:         reuses the SUGGEST_MODEL override, defaulting to the same
//                model recognize-food uses
// Tail logs:     supabase functions logs suggest-meal --tail
//
// Cost telemetry:
//   Token usage is recorded exactly as in recognize-food, into the same
//   `recognition_usage` table (migration 0005) — no new table. Rows from this
//   function carry null image dimensions and an `outcome` prefixed `suggest_`,
//   so the two callers stay distinguishable in one place. If the table does
//   not exist the row only reaches the function log and the request succeeds.
//
//   Nothing identifying is stored: no user id, no ingredient list, no dish
//   names. Only a random per-request id.

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Same default as recognize-food. Override per-deploy with SUGGEST_MODEL.
const DEFAULT_MODEL = "claude-sonnet-4-6";
const MODEL = Deno.env.get("SUGGEST_MODEL") || DEFAULT_MODEL;
const ANTHROPIC_VERSION = "2023-06-01";

// Keep a hard ceiling on how much the caller can make us send upstream.
const MAX_INGREDIENTS = 40;
const MAX_INGREDIENT_LEN = 60;

/// The prompt is explicit about uncertainty: the model must widen the range
/// when it cannot pin a number down, rather than inventing precision. That is
/// the whole reason the client renders a range instead of a single value.
function systemPrompt(lang: string): string {
  const ru = lang !== "en";
  return [
    ru
      ? "Ты повар и нутрициолог, знаешь центральноазиатскую кухню."
      : "You are a cook and nutritionist who knows Central Asian cooking.",
    ru
      ? "Пользователь перечислил продукты, которые у него есть, и остаток дневной нормы."
      : "The user lists the ingredients they have and what is left of their daily target.",
    ru
      ? "Предложи РОВНО 3 блюда, которые можно приготовить преимущественно из этих продуктов."
      : "Suggest EXACTLY 3 dishes that can be made mostly from those ingredients.",
    "",
    ru ? "Правила:" : "Rules:",
    ru
      ? "- Блюдо должно укладываться в остаток по калориям и по возможности по БЖУ."
      : "- A dish should fit the remaining calories, and the macros where possible.",
    ru
      ? "- Соль, перец, специи, масло и воду считай доступными всегда."
      : "- Salt, pepper, spices, oil and water are always available.",
    ru
      ? "- Можно допустить 1-2 обычных дополнительных продукта, но основа — из списка."
      : "- One or two common extras are acceptable, but the base comes from the list.",
    ru
      ? "- Калории и БЖУ давай ДИАПАЗОНОМ (min-max), а не точным числом."
      : "- Give calories and macros as a RANGE (min-max), never a single number.",
    ru
      ? "- Чем меньше определённости (размер порции, жирность, способ готовки) — тем ШИРЕ диапазон. Не выдумывай точность."
      : "- The less certain you are (portion size, fat content, cooking method), the WIDER the range. Do not invent precision.",
    ru
      ? "- min строго меньше max. Значения на всю порцию блюда, не на 100 г."
      : "- min strictly below max. Values are for the whole serving, not per 100 g.",
    ru
      ? "- Названия блюд, ингредиентов и шаги — на русском."
      : "- Dish names, ingredients and steps in English.",
    "",
    ru ? "Верни ТОЛЬКО JSON без markdown:" : "Return ONLY JSON, no markdown:",
    "{",
    '  "suggestions": [',
    "    {",
    ru ? '      "name": название блюда,' : '      "name": dish name,',
    ru
      ? '      "time_minutes": время приготовления в минутах (целое),'
      : '      "time_minutes": cooking time in minutes (integer),',
    '      "ingredients": [{ "name": ' +
      (ru ? "продукт" : "item") +
      ', "amount": ' +
      (ru ? '"120 г" или "2 шт"' : '"120 g" or "2 pcs"') +
      " }],",
    '      "kcal": { "min": число, "max": число },',
    '      "protein_g": { "min": число, "max": число },',
    '      "fat_g": { "min": число, "max": число },',
    '      "carbs_g": { "min": число, "max": число },',
    ru
      ? '      "steps": [шаги приготовления, 3-6 коротких пунктов]'
      : '      "steps": [cooking steps, 3-6 short items]',
    "    }",
    "  ]",
    "}",
  ].join("\n");
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

interface UsageRow {
  request_id: string;
  model: string;
  ok: boolean;
  outcome: string;
  input_tokens: number | null;
  output_tokens: number | null;
  image_width: number | null;
  image_height: number | null;
  request_bytes: number;
  duration_ms: number;
}

/// Same best-effort sink as recognize-food, same table. A missing table
/// (migration pending) degrades to a console line; telemetry never fails a
/// user-facing request.
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
    if (!res.ok) {
      console.log(
        "recognition_usage insert skipped",
        res.status,
        res.status === 404 ? "table_missing" : await res.text(),
      );
    }
  } catch (e) {
    console.log("recognition_usage insert failed", String(e));
  }
}

function num(v: any): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

/// Normalises one {min,max} pair. Returns null when the model gave nothing
/// usable, so the caller can drop the whole suggestion rather than render a
/// half-empty card.
function range(v: any): { min: number; max: number } | null {
  if (!v || typeof v !== "object") return null;
  let lo = num(v.min);
  let hi = num(v.max);
  if (lo === null && hi === null) return null;
  lo ??= hi!;
  hi ??= lo!;
  if (lo > hi) [lo, hi] = [hi, lo];
  if (lo < 0) lo = 0;
  // A collapsed range would present invented precision as certainty. Widen it
  // by 10% either way so the UI never shows min == max.
  if (hi - lo < 1) {
    const pad = Math.max(1, Math.round(lo * 0.1));
    lo = Math.max(0, lo - pad);
    hi = hi + pad;
  }
  return { min: Math.round(lo), max: Math.round(hi) };
}

/// Reshapes whatever the model returned into the response contract, dropping
/// anything that does not carry at least a name and a calorie range.
function normalise(parsed: any): any[] {
  const raw = Array.isArray(parsed?.suggestions) ? parsed.suggestions : [];
  const out: any[] = [];
  for (const s of raw) {
    const name = typeof s?.name === "string" ? s.name.trim() : "";
    const kcal = range(s?.kcal);
    if (!name || !kcal) continue;
    const ingredients = (Array.isArray(s?.ingredients) ? s.ingredients : [])
      .map((i: any) => ({
        name: typeof i?.name === "string" ? i.name.trim() : "",
        amount: typeof i?.amount === "string" ? i.amount.trim() : "",
      }))
      .filter((i: any) => i.name);
    const steps = (Array.isArray(s?.steps) ? s.steps : [])
      .map((t: any) => (typeof t === "string" ? t.trim() : ""))
      .filter(Boolean);
    out.push({
      name,
      time_minutes: num(s?.time_minutes) ?? null,
      ingredients,
      kcal,
      protein_g: range(s?.protein_g),
      fat_g: range(s?.fat_g),
      carbs_g: range(s?.carbs_g),
      steps,
    });
    if (out.length === 3) break;
  }
  return out;
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

  const ingredients: string[] = (Array.isArray(payload?.ingredients)
    ? payload.ingredients
    : [])
    .filter((s: any) => typeof s === "string")
    .map((s: string) => s.trim().slice(0, MAX_INGREDIENT_LEN))
    .filter(Boolean)
    .slice(0, MAX_INGREDIENTS);
  if (ingredients.length === 0) {
    return jsonResponse(400, { error: "no_ingredients" });
  }

  const rem = payload?.remaining ?? {};
  const remKcal = num(rem.kcal) ?? 0;
  const remP = num(rem.protein_g);
  const remF = num(rem.fat_g);
  const remC = num(rem.carbs_g);
  const lang = payload?.lang === "en" ? "en" : "ru";
  const goal = typeof payload?.goal === "string" ? payload.goal : "";

  const ru = lang === "ru";
  const userMessage = [
    (ru ? "Продукты: " : "Ingredients: ") + ingredients.join(", "),
    (ru ? "Остаток на сегодня: " : "Remaining today: ") +
      `${Math.round(remKcal)} ${ru ? "ккал" : "kcal"}` +
      (remP !== null ? `, ${ru ? "белки" : "protein"} ${Math.round(remP)} g` : "") +
      (remF !== null ? `, ${ru ? "жиры" : "fat"} ${Math.round(remF)} g` : "") +
      (remC !== null ? `, ${ru ? "углеводы" : "carbs"} ${Math.round(remC)} g` : ""),
    goal ? (ru ? "Цель: " : "Goal: ") + goal : "",
  ].filter(Boolean).join("\n");

  const requestBody = JSON.stringify({
    model: MODEL,
    max_tokens: 2048,
    system: systemPrompt(lang),
    messages: [{ role: "user", content: [{ type: "text", text: userMessage }] }],
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
      // Prefixed so suggest rows are separable from recognition rows in the
      // shared table.
      outcome: `suggest_${outcome}`,
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
    return jsonResponse(502, {
      error: "upstream_error",
      status: upstream.status,
    });
  }

  let decoded: any;
  try {
    decoded = await upstream.json();
  } catch (_e) {
    await telemetry(false, "upstream_invalid_json");
    return jsonResponse(502, { error: "upstream_invalid_json" });
  }

  const usage = {
    input_tokens: typeof decoded?.usage?.input_tokens === "number"
      ? decoded.usage.input_tokens
      : undefined,
    output_tokens: typeof decoded?.usage?.output_tokens === "number"
      ? decoded.usage.output_tokens
      : undefined,
  };

  const content: any[] = Array.isArray(decoded?.content) ? decoded.content : [];
  const text = content
    .filter((b) => b?.type === "text")
    .map((b) => (typeof b?.text === "string" ? b.text : ""))
    .join("");
  const cleaned = text
    .replace(/^\s*```(?:json)?\s*/, "")
    .replace(/\s*```\s*$/, "")
    .trim();

  let parsed: any;
  try {
    parsed = JSON.parse(cleaned);
  } catch (_e) {
    await telemetry(false, "model_returned_non_json", usage);
    return jsonResponse(502, { error: "model_returned_non_json" });
  }

  const suggestions = normalise(parsed);
  if (suggestions.length === 0) {
    await telemetry(false, "no_usable_suggestions", usage);
    return jsonResponse(502, { error: "no_usable_suggestions" });
  }

  await telemetry(true, "ok", usage);
  return jsonResponse(200, {
    suggestions,
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
