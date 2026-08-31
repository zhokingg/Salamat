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
//
// Cost telemetry:
//   Every call records the Anthropic token usage plus the shape of the image
//   that produced it, so the real price of one scan is measurable instead of
//   guessed. Rows go to `public.recognition_usage` (migration 0005). If that
//   table does not exist yet the row is only written to the function log and
//   the request still succeeds — telemetry never fails a scan.
//
//   Nothing identifying is recorded: no image bytes, no user id. Each row
//   carries a random per-request id only.
//
// Model override:
//   RECOGNIZE_MODEL picks the model; the default is unchanged.
//   supabase secrets set RECOGNIZE_MODEL=claude-haiku-4-5-20251001

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Default is deliberately the same model this function has always used.
// Override per-deploy with the RECOGNIZE_MODEL secret (see header).
const DEFAULT_MODEL = "claude-sonnet-4-6";
const MODEL = Deno.env.get("RECOGNIZE_MODEL") || DEFAULT_MODEL;
const ANTHROPIC_VERSION = "2023-06-01";

/// THE confidence threshold. A result at or below this is not shown to the
/// user as a dish, and therefore must not cost a scan.
///
/// This is the only place it is defined. The client used to carry its own copy
/// and check `confidence <= 0.5` itself, which is exactly how the two drifted
/// apart: the server charged for anything parseable while the client told the
/// user it had failed. The client now trusts the 200 / 422 answer and does not
/// know the number at all.
const MIN_CONFIDENCE = 0.5;
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

/// Reads pixel dimensions straight out of the encoded bytes.
///
/// Only the header is walked, so this stays cheap and never decodes the image.
/// Returns nulls for anything unrecognised rather than throwing — telemetry is
/// not allowed to break a scan.
function imageSize(
  bytes: Uint8Array,
  mediaType: string,
): { width: number | null; height: number | null } {
  try {
    if (mediaType === "image/png") {
      // PNG: 8-byte signature, then IHDR length+type, then width/height BE32.
      if (bytes.length < 24) return { width: null, height: null };
      const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      return { width: dv.getUint32(16), height: dv.getUint32(20) };
    }
    // JPEG: walk segment markers to the first SOFn, which carries the size.
    // Phone JPEGs put a large EXIF/APP1 block (often with a thumbnail) before
    // SOF, so the walk has to skip segments properly rather than scan bytes.
    if (bytes[0] !== 0xff || bytes[1] !== 0xd8) {
      return { width: null, height: null };
    }
    let i = 2; // past SOI
    while (i + 9 < bytes.length) {
      if (bytes[i] !== 0xff) return { width: null, height: null };
      // 0xFF is a legal fill byte before a marker; consume runs of it.
      let m = i + 1;
      while (m < bytes.length && bytes[m] === 0xff) m++;
      const marker = bytes[m];

      // SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15 carry dimensions.
      // 0xC4 (DHT), 0xC8 (JPG), 0xCC (DAC) sit in the range but do not.
      const isSof = marker >= 0xc0 && marker <= 0xcf &&
        marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
      if (isSof) {
        // segment: FF marker len(2) precision(1) height(2) width(2)
        const height = (bytes[m + 4] << 8) | bytes[m + 5];
        const width = (bytes[m + 6] << 8) | bytes[m + 7];
        return { width, height };
      }
      // Standalone markers (no length payload).
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd9)) {
        i = m + 1;
        continue;
      }
      // Start of scan — pixel data follows, SOF must already have appeared.
      if (marker === 0xda) return { width: null, height: null };
      const len = (bytes[m + 1] << 8) | bytes[m + 2];
      if (len < 2) return { width: null, height: null };
      i = m + 1 + len;
    }
  } catch (_e) {
    // fall through
  }
  return { width: null, height: null };
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

/// Writes one telemetry row.
///
/// Best-effort by design: a missing table (migration 0005 not applied yet), a
/// missing service key, or any REST failure degrades to a console line. The
/// caller never awaits a failure path that could surface to the user.
/// Calls a Postgres function AS THE CALLER, forwarding their JWT so
/// `auth.uid()` inside the function is the signed-in user. The service role is
/// deliberately not used here: the allowance is per-user, and a service-role
/// call would have no user to attribute it to.
///
/// Returns null when the call could not be made or the function is absent
/// (migration 0006 not applied yet). Callers treat null as "no opinion" and
/// fail open, exactly like `recordUsage` does for its table.
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
      // 404 = function absent (migration pending). Log the rest.
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

async function recordUsage(row: UsageRow): Promise<void> {
  // Always log — this is the fallback that works with no migration at all.
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
      // 404 = table absent (migration pending). Anything else is worth seeing.
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

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

serve(async (req: Request) => {
  const startedAt = Date.now();
  // Random, unlinkable to the user or the photo — just enough to correlate a
  // log line with a stored row.
  const requestId = crypto.randomUUID();

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
  // Guard against absurdly large payloads.
  //
  // CHECKED against docs.claude.com (Vision -> Image limits and costs,
  // 2026-08-30). The old comment here said the limit was 5 MB; that number is
  // the Amazon Bedrock / Google Cloud one. Calling the Claude API directly, as
  // this function does, the documented ceiling is:
  //     "The maximum size per image is: 10 MB (base64-encoded) when using the
  //      Claude API directly."
  // So 8,000,000 base64 characters is BELOW the real limit, not above it — the
  // guard is conservative, which is the right direction, and it stays.
  //
  // Note it is measured on the base64 string, which is what the documented
  // limit is measured on too. No conversion needed.
  if (imageBase64.length > 8_000_000) {
    return jsonResponse(413, { error: "image_too_large" });
  }
  const mediaType =
    payload.mediaType === "image/png" ? "image/png" : "image/jpeg";

  // Decode only to read the header dimensions; the bytes are not retained
  // beyond this scope and never leave the function.
  let width: number | null = null;
  let height: number | null = null;
  try {
    const raw = Uint8Array.from(atob(// 256 KB of base64 (~192 KB decoded) clears even a fat EXIF
    // thumbnail; the rest of a multi-MB payload is never decoded.
      imageBase64.slice(0, 262144)), (ch) =>
      ch.charCodeAt(0)
    );
    ({ width, height } = imageSize(raw, mediaType));
  } catch (_e) {
    // leave dimensions null
  }
  // Bytes actually put on the wire to Anthropic: the base64 payload, which is
  // what the request costs us in bandwidth.
  const requestBytes = imageBase64.length;

  const telemetry = (
    ok: boolean,
    outcome: string,
    usage?: { input_tokens?: number; output_tokens?: number },
  ) =>
    recordUsage({
      request_id: requestId,
      model: MODEL,
      ok,
      outcome,
      input_tokens: usage?.input_tokens ?? null,
      output_tokens: usage?.output_tokens ?? null,
      image_width: width,
      image_height: height,
      request_bytes: requestBytes,
      duration_ms: Date.now() - startedAt,
    });

  // ── allowance gate ──────────────────────────────────────────────────
  // Free accounts get three scans for the lifetime of the account. The check
  // is here, on the server, because the client counter is only a render cache
  // and a reinstall wipes it.
  //
  // Fails OPEN when the RPC is unavailable (migration 0006 not applied): a
  // missing table must not make the camera unusable.
  const authHeader = req.headers.get("Authorization");
  const status = await rpc(authHeader, "scan_status", {});
  if (status && status.is_pro === false && (status.remaining ?? 0) <= 0) {
    await telemetry(false, "quota_exhausted");
    return jsonResponse(402, {
      error: "scan_quota_exhausted",
      used: status.used ?? null,
      allowance: status.allowance ?? null,
    });
  }

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

  // The only place the real cost of this call is knowable.
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
  // Strip possible ```json fences if the model added them despite the prompt.
  const cleaned = text
    .replace(/^\s*```(?:json)?\s*/, "")
    .replace(/\s*```\s*$/, "")
    .trim();

  try {
    const parsed = JSON.parse(cleaned);

    // Confidence gate comes BEFORE the charge. Parseable JSON is not the same
    // as a usable answer: the model happily returns a well-formed guess with
    // confidence 0.3, which the app shows as "couldn't recognise the dish".
    // Charging for that means the user pays a scan for an error message.
    const rawConfidence = parsed?.confidence;
    const confidence = typeof rawConfidence === "number" &&
        Number.isFinite(rawConfidence)
      ? rawConfidence
      : 0;
    if (!(confidence > MIN_CONFIDENCE)) {
      await telemetry(false, "low_confidence", usage);
      return jsonResponse(422, {
        error: "low_confidence",
        confidence,
        min_confidence: MIN_CONFIDENCE,
        // Reported so the caller can show the count unchanged rather than
        // guessing whether anything was spent. Nothing was.
        _usage: {
          input_tokens: usage.input_tokens ?? null,
          output_tokens: usage.output_tokens ?? null,
        },
      });
    }

    // Quota is spent ONLY here: past the confidence gate, i.e. only for a
    // result the user is actually given. Atomic in Postgres, so two concurrent
    // scans cannot both take the last one.
    const consumed = await rpc(authHeader, "consume_scan", {
      p_request_id: requestId,
    });
    if (consumed && consumed.allowed === false) {
      await telemetry(false, "quota_exhausted", usage);
      return jsonResponse(402, {
        error: "scan_quota_exhausted",
        used: consumed.used ?? null,
        remaining: 0,
      });
    }

    await telemetry(true, "ok", usage);
    // `_usage` and `_meta` are additive: the mobile client reads named
    // nutrition fields and ignores the rest. The resolution experiment in
    // scripts/ reads them to attribute cost per run.
    return jsonResponse(200, {
      ...parsed,
      // What the client renders on the camera button. Null when the
      // allowance RPC was unavailable, in which case the client keeps
      // whatever it last knew.
      _scan: consumed
        ? { used: consumed.used ?? null, remaining: consumed.remaining ?? null }
        : null,
      _usage: {
        input_tokens: usage.input_tokens ?? null,
        output_tokens: usage.output_tokens ?? null,
      },
      _meta: {
        model: MODEL,
        image_width: width,
        image_height: height,
        request_bytes: requestBytes,
        duration_ms: Date.now() - startedAt,
        request_id: requestId,
      },
    });
  } catch (_e) {
    await telemetry(false, "model_returned_non_json", usage);
    return jsonResponse(502, { error: "model_returned_non_json", raw: cleaned });
  }
});
