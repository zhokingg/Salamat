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
//   Second mode — macros for one already-known dish (used by manual entry,
//   which knows the dish name and its calories but not the breakdown):
//   POST {
//     mode: 'macros',
//     dish: string,                   // as the user typed it
//     kcal: number,                   // calories the user entered
//     lang?: 'ru' | 'en'
//   }
//   → 200 {
//       macros: { protein_g, fat_g, carbs_g },   // grams, whole serving
//       _usage: { input_tokens, output_tokens },
//       _meta:  { model, request_bytes, duration_ms, request_id }
//     }
//   Requests without `mode` (or with mode:'suggest') keep the original
//   three-dish behaviour unchanged.
//
//   Third mode — split a spoken sentence into dishes (used by voice entry,
//   which has words but neither portions nor calories):
//   POST {
//     mode: 'parse',
//     text: string,                   // "съел шаурму и колу"
//     lang?: 'ru' | 'en'
//   }
//   → 200 {
//       items: [{ name, grams, kcal, protein_g, fat_g, carbs_g } ...],
//       _usage, _meta
//     }
//   Each item's macros are reconciled to its own calories by the same
//   normaliser the 'macros' mode uses, so every row adds up.
//   An empty `items` array means nothing food-like was recognised.
//
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
const MAX_DISH_LEN = 80;
const MAX_DISH_KCAL = 5000;
const MAX_SPEECH_LEN = 300;
const MAX_PARSED_ITEMS = 6;

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

/// Macro breakdown for one named dish at a known calorie count.
///
/// Unlike the three-dish prompt this returns single numbers, not ranges: the
/// caller stores them as ordinary macros. The calorie total is fixed by the
/// user, so the only job is splitting it plausibly for that dish; the prompt
/// therefore pins the arithmetic (4/9/4 kcal per gram) rather than leaving the
/// model free to return a split that does not add up.
function macrosSystemPrompt(lang: string): string {
  const ru = lang !== "en";
  return [
    ru
      ? "Ты нутрициолог, знаешь центральноазиатскую кухню."
      : "You are a nutritionist who knows Central Asian cooking.",
    ru
      ? "Тебе дают название блюда и его калорийность. Оцени БЖУ этой порции."
      : "You are given a dish name and its calories. Estimate the macros of that serving.",
    "",
    ru ? "Правила:" : "Rules:",
    ru
      ? "- Белки и углеводы — 4 ккал/г, жиры — 9 ккал/г."
      : "- Protein and carbs are 4 kcal/g, fat is 9 kcal/g.",
    ru
      ? "- Сумма 4*белки + 9*жиры + 4*углеводы должна сходиться с калорийностью в пределах 5%."
      : "- 4*protein + 9*fat + 4*carbs must match the calories within 5%.",
    ru
      ? "- Пропорции бери типичные для этого блюда, а не среднее по больнице."
      : "- Use proportions typical for that dish, not a generic average.",
    ru
      ? "- Числа целые, в граммах, на всю указанную порцию."
      : "- Whole numbers, in grams, for the whole stated serving.",
    ru
      ? "- Если блюдо непонятно, дай разумную оценку для блюда с таким названием."
      : "- If the dish is unclear, give a reasonable estimate for a dish of that name.",
    "",
    ru
      ? "- Никаких пояснений и текста вокруг — только JSON."
      : "- No explanation and no surrounding prose — JSON only.",
    "",
    ru ? "Верни ТОЛЬКО JSON без markdown:" : "Return ONLY JSON, no markdown:",
    ru
      ? '{ "protein_g": число, "fat_g": число, "carbs_g": число }'
      : '{ "protein_g": number, "fat_g": number, "carbs_g": number }',
  ].join("\n");
}

type Macros = { protein_g: number; fat_g: number; carbs_g: number };

type MacroResult =
  | { ok: true; macros: Macros; raw: Macros; modelKcal: number; scale: number }
  | { ok: false; reason: string };

const KCAL_PER_G = { protein: 4, fat: 9, carbs: 4 };

function kcalOf(m: Macros): number {
  return m.protein_g * KCAL_PER_G.protein +
    m.fat_g * KCAL_PER_G.fat +
    m.carbs_g * KCAL_PER_G.carbs;
}

/// How far the model's own arithmetic may be off before its answer is treated
/// as nonsense rather than something to rescale. The observed drift is 2-8%;
/// anything beyond a third in either direction is not a rounding problem.
const MAX_MODEL_DRIFT = 0.35;

/// Wider bar for the 'parse' mode — see [normaliseMacros].
const PARSE_MAX_DRIFT = 1.0;

/// Accepts the macros object and makes it add up.
///
/// The model does not do the arithmetic reliably — measured live, its splits
/// came in 2.5-7.5% under the calories the user actually entered, four of six
/// outside the 5% the prompt asks for. Prompting harder does not fix that, so
/// the numbers are reconciled here instead.
///
/// Two stages:
///   1. Scale all three grams by statedKcal / modelKcal, so the proportions the
///      model chose are kept but the total lands on the user's figure.
///   2. Round to whole grams, then spend the rounding residual in 1 g steps
///      until the total is within 1 kcal. Fat is 9 kcal/g and protein/carbs are
///      4, and gcd(4,9)=1, so an exact landing is always reachable: pick the fat
///      step that makes the remainder divisible by 4, then put the rest on
///      carbs (falling back to protein if carbs would go negative).
///
/// Refuses rather than forces: if the model's own total is more than
/// MAX_MODEL_DRIFT away from the stated calories it answered nonsense, and if
/// the residual still cannot be closed to 1 kcal the result is rejected.
///
/// [maxDrift] is how far the model's own arithmetic may be off before its
/// answer is refused. The two modes differ on purpose: in 'macros' mode the
/// calories are the USER's figure and a wildly different split means the model
/// misunderstood the dish, so the bar is tight. In 'parse' mode both the
/// calories and the split come from the model, so there is no ground truth
/// being violated by rescaling and a tight bar just throws away usable macros.
function normaliseMacros(
  parsed: any,
  statedKcal: number,
  maxDrift: number = MAX_MODEL_DRIFT,
): MacroResult {
  const p = num(parsed?.protein_g);
  const f = num(parsed?.fat_g);
  const c = num(parsed?.carbs_g);
  if (p === null || f === null || c === null) return { ok: false, reason: "no_usable_macros" };
  if (p < 0 || f < 0 || c < 0) return { ok: false, reason: "no_usable_macros" };

  const raw: Macros = { protein_g: p, fat_g: f, carbs_g: c };
  const modelKcal = kcalOf(raw);
  if (!(modelKcal > 0)) return { ok: false, reason: "no_usable_macros" };

  const scale = statedKcal / modelKcal;
  if (Math.abs(scale - 1) > maxDrift) {
    return { ok: false, reason: "macros_implausible" };
  }

  // 1. scale, 2. round
  const out: Macros = {
    protein_g: Math.round(p * scale),
    fat_g: Math.round(f * scale),
    carbs_g: Math.round(c * scale),
  };

  // 3. spend the rounding residual
  //
  // Carbs and protein first, in 4 kcal steps. Only if that cannot get within
  // the 1 kcal budget is the 9 kcal fat step used — otherwise reconciling a
  // fat-free drink invents grams of fat in it, which is worse than being 1 kcal
  // out. (Observed: Coca-Cola came back P0 F3 C28 instead of P0 F0 C35.)
  let diff = Math.round(statedKcal) - kcalOf(out);
  if (diff !== 0) {
    const q = Math.round(diff / KCAL_PER_G.carbs);
    const carrier = out.carbs_g + q >= 0
      ? "carbs"
      : (out.protein_g + q >= 0 ? "protein" : null);
    if (carrier !== null && Math.abs(diff - q * KCAL_PER_G.carbs) <= 1) {
      if (carrier === "carbs") {
        out.carbs_g += q;
      } else {
        out.protein_g += q;
      }
      diff -= q * KCAL_PER_G.carbs;
    }
  }
  if (diff !== 0 && Math.abs(diff) > 1) {
    // 9*df ≡ diff (mod 4), and 9 ≡ 1 (mod 4), so df ≡ diff (mod 4). Every
    // candidate 4 apart is equally valid, so walk outwards from the smallest
    // until one keeps fat non-negative: a low-fat dish must not be refused
    // just because the neatest step would drive fat below zero.
    let df0 = ((diff % 4) + 4) % 4;
    if (df0 > 2) df0 -= 4;
    const candidates = [df0, df0 + 4, df0 - 4, df0 + 8, df0 - 8, df0 + 12];
    const df = candidates.find((d) => out.fat_g + d >= 0);
    if (df !== undefined) {
      out.fat_g += df;
      diff -= df * KCAL_PER_G.fat;
    }
    // What is left is now divisible by 4. Put it on carbs, spilling onto
    // protein for whatever carbs cannot absorb without going negative.
    let grams = diff / KCAL_PER_G.carbs;
    if (Number.isInteger(grams)) {
      const fromCarbs = Math.max(grams, -out.carbs_g);
      out.carbs_g += fromCarbs;
      grams -= fromCarbs;
      if (grams !== 0 && out.protein_g + grams >= 0) {
        out.protein_g += grams;
      }
    }
  }

  const finalDiff = Math.abs(kcalOf(out) - Math.round(statedKcal));
  if (finalDiff > 1) return { ok: false, reason: "macros_unbalanced" };
  if (out.protein_g < 0 || out.fat_g < 0 || out.carbs_g < 0) {
    return { ok: false, reason: "macros_unbalanced" };
  }

  return { ok: true, macros: out, raw, modelKcal, scale };
}

/// Splits one spoken sentence into dishes, with a plausible portion for each.
///
/// Speech gives words and nothing else: no weight, no calories. So unlike the
/// 'macros' mode, the model has to propose the portion too. It is told to use
/// an ordinary serving rather than hedge, because the user adjusts grams in the
/// confirmation sheet anyway — a number they can correct beats a blank field.
function parseSystemPrompt(lang: string): string {
  const ru = lang !== "en";
  return [
    ru
      ? "Ты нутрициолог, знаешь центральноазиатскую кухню."
      : "You are a nutritionist who knows Central Asian cooking.",
    ru
      ? "Пользователь надиктовал, что он съел. Раздели фразу на отдельные блюда."
      : "The user dictated what they ate. Split the sentence into separate dishes.",
    "",
    ru ? "Правила:" : "Rules:",
    ru
      ? "- Каждое блюдо — отдельный элемент списка."
      : "- One list item per dish.",
    ru
      ? "- Если количество не названо, возьми обычную порцию для этого блюда."
      : "- When no amount is given, assume an ordinary serving of that dish.",
    ru
      ? "- Если количество названо (два, половина, стакан) — учти его."
      : "- When an amount is given (two, half, a glass), honour it.",
    ru
      ? "- Калории и БЖУ — на указанную порцию целиком, не на 100 г."
      : "- Calories and macros are for the whole stated portion, not per 100 g.",
    ru
      ? "- Белки и углеводы 4 ккал/г, жиры 9 ккал/г; сумма должна сходиться с калориями."
      : "- Protein and carbs 4 kcal/g, fat 9 kcal/g; the sum must match the calories.",
    ru
      ? "- Названия блюд — на русском, коротко, как в дневнике питания."
      : "- Dish names in English, short, as they would read in a food diary.",
    ru
      ? "- Каждый элемент ОБЯЗАН содержать все шесть полей: name, grams, kcal, protein_g, fat_g, carbs_g. Ни одно поле не пропускай."
      : "- Every item MUST contain all six fields: name, grams, kcal, protein_g, fat_g, carbs_g. Never omit one.",
    ru
      ? "- Если во фразе нет еды, верни пустой список."
      : "- If the sentence names no food, return an empty list.",
    ru
      ? "- Никаких пояснений вокруг — только JSON."
      : "- No surrounding prose — JSON only.",
    "",
    ru ? "Верни ТОЛЬКО JSON без markdown:" : "Return ONLY JSON, no markdown:",
    ru
      ? '{ "items": [ { "name": название, "grams": число, "kcal": число, "protein_g": число, "fat_g": число, "carbs_g": число } ] }'
      : '{ "items": [ { "name": dish name, "grams": number, "kcal": number, "protein_g": number, "fat_g": number, "carbs_g": number } ] }',
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

  const lang = payload?.lang === "en" ? "en" : "ru";
  const ru = lang === "ru";
  const isMacrosMode = payload?.mode === "macros";
  const isParseMode = payload?.mode === "parse";

  let systemText: string;
  let userMessage: string;
  let maxTokens: number;
  // Calories the user stated, needed again when reconciling the model's split.
  let macrosKcal = 0;

  if (isParseMode) {
    const text = typeof payload?.text === "string"
      ? payload.text.trim().slice(0, MAX_SPEECH_LEN)
      : "";
    if (!text) {
      return jsonResponse(400, { error: "no_text" });
    }
    systemText = parseSystemPrompt(lang);
    userMessage = (ru ? "Фраза: " : "Sentence: ") + text;
    // A handful of small objects.
    maxTokens = 1024;
  } else if (isMacrosMode) {
    // Macro breakdown for one dish the user already named and priced in kcal.
    const dish = typeof payload?.dish === "string"
      ? payload.dish.trim().slice(0, MAX_DISH_LEN)
      : "";
    if (!dish) {
      return jsonResponse(400, { error: "no_dish" });
    }
    const kcal = num(payload?.kcal);
    if (kcal === null || kcal <= 0 || kcal > MAX_DISH_KCAL) {
      return jsonResponse(400, { error: "bad_kcal" });
    }
    macrosKcal = kcal;
    systemText = macrosSystemPrompt(lang);
    userMessage = [
      (ru ? "Блюдо: " : "Dish: ") + dish,
      (ru ? "Калорийность порции: " : "Calories of the serving: ") +
        `${Math.round(kcal)} ${ru ? "ккал" : "kcal"}`,
    ].join("\n");
    // One small JSON object; nothing here needs the 2048 the dish list does.
    maxTokens = 256;
  } else {
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
    const goal = typeof payload?.goal === "string" ? payload.goal : "";

    systemText = systemPrompt(lang);
    userMessage = [
      (ru ? "Продукты: " : "Ingredients: ") + ingredients.join(", "),
      (ru ? "Остаток на сегодня: " : "Remaining today: ") +
        `${Math.round(remKcal)} ${ru ? "ккал" : "kcal"}` +
        (remP !== null ? `, ${ru ? "белки" : "protein"} ${Math.round(remP)} g` : "") +
        (remF !== null ? `, ${ru ? "жиры" : "fat"} ${Math.round(remF)} g` : "") +
        (remC !== null ? `, ${ru ? "углеводы" : "carbs"} ${Math.round(remC)} g` : ""),
      goal ? (ru ? "Цель: " : "Goal: ") + goal : "",
    ].filter(Boolean).join("\n");
    maxTokens = 2048;
  }

  const requestBody = JSON.stringify({
    model: MODEL,
    max_tokens: maxTokens,
    system: systemText,
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
      outcome: `suggest_${
        isMacrosMode ? "macros_" : (isParseMode ? "parse_" : "")
      }${outcome}`,
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

  const usage: { input_tokens?: number; output_tokens?: number } = {
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
  const stripped = text
    .replace(/^\s*```(?:json)?\s*/, "")
    .replace(/\s*```\s*$/, "")
    .trim();
  // The model occasionally wraps the object in a sentence. Rather than fail
  // the whole request, take the outermost {...} if one is present.
  const braced = stripped.indexOf("{") >= 0 && stripped.lastIndexOf("}") > 0
    ? stripped.slice(stripped.indexOf("{"), stripped.lastIndexOf("}") + 1)
    : stripped;
  const cleaned = braced;

  let parsed: any;
  try {
    parsed = JSON.parse(cleaned);
  } catch (_e) {
    // The parse mode asks the model to split a spoken sentence, and it answers
    // with prose instead of JSON often enough to matter (measured: roughly one
    // call in six). One retry costs a few hundred tokens and turns most of
    // those into a usable answer, which is much better than telling somebody
    // their sentence was not understood when it plainly was.
    let recovered: any = null;
    if (isParseMode) {
      try {
        const retry = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "x-api-key": apiKey,
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
          },
          body: requestBody,
        });
        if (retry.ok) {
          const rd = await retry.json();
          const rt = (Array.isArray(rd?.content) ? rd.content : [])
            .filter((b: any) => b?.type === "text")
            .map((b: any) => (typeof b?.text === "string" ? b.text : ""))
            .join("")
            .replace(/^\s*```(?:json)?\s*/, "")
            .replace(/\s*```\s*$/, "")
            .trim();
          const rb = rt.indexOf("{") >= 0 && rt.lastIndexOf("}") > 0
            ? rt.slice(rt.indexOf("{"), rt.lastIndexOf("}") + 1)
            : rt;
          recovered = JSON.parse(rb);
          // Bill the retry honestly rather than reporting only the first call.
          if (typeof rd?.usage?.input_tokens === "number") {
            usage.input_tokens = (usage.input_tokens ?? 0) +
              rd.usage.input_tokens;
          }
          if (typeof rd?.usage?.output_tokens === "number") {
            usage.output_tokens = (usage.output_tokens ?? 0) +
              rd.usage.output_tokens;
          }
        }
      } catch (_retryErr) {
        recovered = null;
      }
    }
    if (recovered === null) {
      await telemetry(false, "model_returned_non_json", usage);
      return jsonResponse(502, { error: "model_returned_non_json" });
    }
    parsed = recovered;
  }

  if (isParseMode) {
    const raw = Array.isArray(parsed?.items) ? parsed.items : [];
    const items: any[] = [];
    for (const it of raw.slice(0, MAX_PARSED_ITEMS)) {
      const name = typeof it?.name === "string" ? it.name.trim() : "";
      const kcal = num(it?.kcal);
      const grams = num(it?.grams);
      if (!name || kcal === null || kcal <= 0 || kcal > MAX_DISH_KCAL) continue;

      // Same reconciliation as the 'macros' mode: the split is scaled onto the
      // calories for that item so every row adds up.
      //
      // When it cannot be reconciled the item is still kept, with its macros
      // zeroed — the app renders those as a dash. Dropping the row entirely
      // would silently lose food the user said they ate, which is worse than
      // showing it with calories but no breakdown.
      const r = normaliseMacros(it, kcal, PARSE_MAX_DRIFT);

      items.push({
        name,
        grams: grams !== null && grams > 0 && grams <= 5000
          ? Math.round(grams)
          : null,
        kcal: Math.round(kcal),
        protein_g: r.ok ? r.macros.protein_g : 0,
        fat_g: r.ok ? r.macros.fat_g : 0,
        carbs_g: r.ok ? r.macros.carbs_g : 0,
        macros_known: r.ok,
        // Present only when reconciliation failed, so a regression is
        // diagnosable from the response instead of guessed at.
        macros_reason: r.ok ? null : r.reason,
      });
    }

    await telemetry(true, "ok", usage);
    return jsonResponse(200, {
      items,
      _usage: {
        input_tokens: usage.input_tokens ?? null,
        output_tokens: usage.output_tokens ?? null,
      },
      _meta: {
        model: MODEL,
        request_bytes: requestBytes,
        duration_ms: Date.now() - startedAt,
        request_id: requestId,
        // How many the model produced vs how many survived validation, so a
        // parsing regression is visible in the response rather than guessed at.
        parsed_raw: raw.length,
        parsed_kept: items.length,
      },
    });
  }

  if (isMacrosMode) {
    const result = normaliseMacros(parsed, macrosKcal);
    if (!result.ok) {
      await telemetry(false, result.reason, usage);
      return jsonResponse(502, { error: result.reason });
    }
    const { macros, raw, modelKcal, scale } = result;
    await telemetry(true, "ok", usage);
    return jsonResponse(200, {
      macros,
      // What the model actually said, before reconciliation. Kept so a drift
      // regression is visible in the response rather than only in a log.
      _normalisation: {
        raw,
        model_kcal: modelKcal,
        stated_kcal: Math.round(macrosKcal),
        scale: Number(scale.toFixed(4)),
        final_kcal: macros.protein_g * 4 + macros.fat_g * 9 + macros.carbs_g * 4,
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
