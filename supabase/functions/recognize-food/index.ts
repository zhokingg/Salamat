// Salamat — recognize-food Edge Function.
//
// Why this exists:
//   The Anthropic API key cannot live in the mobile client. An attacker who
//   decompiles the APK can extract it and bill us. This function proxies
//   image-recognition calls so the key only ever exists in Supabase secrets.
//
// Contract:
//   POST { imageBase64: string, mediaType?: 'image/jpeg' | 'image/png' }
//   → 200 { name, calories_per_100g, protein_per_100g, carbs_per_100g,
//           fat_per_100g, portion_g, confidence }
//   → 400 { error } — bad input
//   → 401 { error } — missing JWT (Supabase enforces this when verify_jwt=true)
//   → 500 { error } — server-side misconfig (e.g. missing secret)
//   → 502 { error } — Anthropic upstream failure
//
// Deploy:        supabase functions deploy recognize-food
// Set secret:    supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// Tail logs:     supabase functions logs recognize-food --tail

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODEL = "claude-sonnet-4-6";
const ANTHROPIC_VERSION = "2023-06-01";
const SYSTEM_PROMPT = [
  "Ты эксперт по центральноазиатской кухне.",
  "Пользователь сфотографировал еду.",
  "Определи блюдо и верни ТОЛЬКО JSON без markdown:",
  "{",
  '  "name": название блюда на русском,',
  '  "calories_per_100g": калории на 100г,',
  '  "protein_per_100g": белки на 100г,',
  '  "carbs_per_100g": углеводы на 100г,',
  '  "fat_per_100g": жиры на 100г,',
  '  "portion_g": рекомендуемая порция в граммах,',
  '  "confidence": уверенность от 0 до 1',
  "}",
  "Если не можешь определить еду — верни confidence: 0",
].join("\n");

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    // Misconfig — secret not set. Log so we notice in production.
    console.error("ANTHROPIC_API_KEY secret not set");
    return jsonResponse(500, { error: "server_misconfigured" });
  }

  let payload: { imageBase64?: string; mediaType?: string };
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const imageBase64 = payload.imageBase64;
  if (!imageBase64 || typeof imageBase64 !== "string") {
    return jsonResponse(400, { error: "missing_image" });
  }
  // Guard against absurdly large payloads. Anthropic accepts up to 5MB
  // images base64-encoded; 8MB of base64 ≈ 6MB binary — generous ceiling.
  if (imageBase64.length > 8_000_000) {
    return jsonResponse(413, { error: "image_too_large" });
  }
  const mediaType =
    payload.mediaType === "image/png" ? "image/png" : "image/jpeg";

  let upstream: Response;
  try {
    upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: mediaType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      }),
    });
  } catch (e) {
    console.error("anthropic fetch failed", e);
    return jsonResponse(502, { error: "upstream_unreachable" });
  }

  if (!upstream.ok) {
    const body = await upstream.text();
    console.error("anthropic non-200", upstream.status, body);
    return jsonResponse(502, {
      error: "upstream_error",
      status: upstream.status,
    });
  }

  let decoded: any;
  try {
    decoded = await upstream.json();
  } catch (_e) {
    return jsonResponse(502, { error: "upstream_invalid_json" });
  }

  const content: any[] = Array.isArray(decoded?.content) ? decoded.content : [];
  const text = content
    .filter((b) => b?.type === "text")
    .map((b) => (typeof b?.text === "string" ? b.text : ""))
    .join("");
  // Strip possible ```json fences if the model added them despite the prompt.
  const cleaned = text
    .replace(/^\s*```(?:json)?\s*/, "")
    .replace(/\s*```\s*$/, "")
    .trim();

  try {
    const parsed = JSON.parse(cleaned);
    return jsonResponse(200, parsed);
  } catch (_e) {
    return jsonResponse(502, { error: "model_returned_non_json", raw: cleaned });
  }
});
