// Salamat — barcode-lookup Edge Function.
//
// Why this exists:
//   The client could call Open Food Facts directly — it is open and needs no
//   key — but going through here means the source can be swapped, cached or
//   augmented without shipping an app update, and the response is normalised
//   to the same shape the photo path already produces.
//
// Contract:
//   POST { barcode: string, lang?: 'ru' | 'en' }
//   → 200 { found: true, product: {
//             barcode, name, brand,
//             kcal_100g, protein_100g, fat_100g, carbs_100g,
//             serving_g,          // null when the product does not state one
//             image_url,          // may be null
//             source: 'openfoodfacts'
//           }, _meta: { duration_ms } }
//   → 200 { found: false, reason: 'not_in_database' | 'no_nutrition' }
//       NOT an error: an unknown barcode is an ordinary outcome and the app
//       offers manual entry. Only real failures get a non-200.
//   → 400 { error: 'invalid_barcode' }
//   → 502 { error: 'upstream_unreachable' | 'upstream_error' }
//
// Scan quota: untouched. A barcode costs no model tokens, so this function
// never calls `consume_scan`. That is deliberate, not an oversight.
//
// Deploy:  supabase functions deploy barcode-lookup
// No secrets required.

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/// Open Food Facts asks every caller to identify itself. Anonymous or spoofed
/// agents get rate-limited.
const USER_AGENT = "Salamat/1.0 (https://kg.salamat.app)";

/// Only the fields we actually use — OFF products are large documents and the
/// full one is hundreds of kilobytes.
const FIELDS = [
  "code",
  "product_name",
  "product_name_en",
  "product_name_ru",
  "brands",
  "serving_size",
  "serving_quantity",
  "image_front_small_url",
  "nutriments",
].join(",");

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function num(v: any): number | null {
  const n = typeof v === "string" ? Number(v) : v;
  return typeof n === "number" && Number.isFinite(n) ? n : null;
}

/// EAN-8, UPC-A and EAN-13 are all digit strings. Anything else is a misread
/// rather than something worth asking OFF about.
function normaliseBarcode(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const digits = raw.trim().replace(/\s+/g, "");
  if (!/^[0-9]{8,14}$/.test(digits)) return null;
  return digits;
}

/// Picks the best available name: the caller's language first, then the
/// product's default, then the brand. OFF fills these inconsistently.
function pickName(p: any, lang: string): string {
  const candidates = [
    lang === "ru" ? p?.product_name_ru : p?.product_name_en,
    p?.product_name,
    lang === "ru" ? p?.product_name_en : p?.product_name_ru,
    p?.brands,
  ];
  for (const c of candidates) {
    if (typeof c === "string" && c.trim().length > 0) return c.trim();
  }
  return "";
}

/// Grams for one serving, when the product states one.
///
/// `serving_quantity` is usually already a number of grams. `serving_size` is
/// free text ("30 g", "1 cup (240 ml)"), so it is only parsed when the numeric
/// field is missing, and only when it clearly reads as grams or millilitres.
function servingGrams(p: any): number | null {
  const direct = num(p?.serving_quantity);
  if (direct !== null && direct > 0 && direct <= 2000) return Math.round(direct);

  const text = typeof p?.serving_size === "string" ? p.serving_size : "";
  const m = text.match(/([\d.,]+)\s*(g|ml|г|мл)\b/i);
  if (m) {
    const v = num(m[1].replace(",", "."));
    if (v !== null && v > 0 && v <= 2000) return Math.round(v);
  }
  return null;
}

serve(async (req: Request) => {
  const startedAt = Date.now();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const barcode = normaliseBarcode(payload?.barcode);
  if (!barcode) {
    return jsonResponse(400, { error: "invalid_barcode" });
  }
  const lang = payload?.lang === "ru" ? "ru" : "en";

  let upstream: Response;
  const url =
    `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=${FIELDS}`;
  try {
    upstream = await fetch(url, {
      headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    });
  } catch (e) {
    console.error("openfoodfacts unreachable", e);
    return jsonResponse(502, { error: "upstream_unreachable" });
  }

  // OFF answers 404 for an unknown barcode. That is a normal outcome for us,
  // not a failure — the app offers manual entry instead.
  if (upstream.status === 404) {
    return jsonResponse(200, { found: false, reason: "not_in_database" });
  }
  if (!upstream.ok) {
    console.error("openfoodfacts non-200", upstream.status);
    return jsonResponse(502, { error: "upstream_error", status: upstream.status });
  }

  let decoded: any;
  try {
    decoded = await upstream.json();
  } catch (_e) {
    return jsonResponse(502, { error: "upstream_error" });
  }

  const p = decoded?.product;
  if (!p || decoded?.status === 0) {
    return jsonResponse(200, { found: false, reason: "not_in_database" });
  }

  const n = p.nutriments ?? {};
  const kcal = num(n["energy-kcal_100g"]) ??
    // Some products carry only kilojoules.
    (num(n["energy_100g"]) !== null
      ? Math.round((num(n["energy_100g"]) as number) / 4.184)
      : null);

  // A product with no energy value cannot be logged as food. Reported as a
  // distinct reason so the app can say something more useful than "not found".
  if (kcal === null || kcal <= 0) {
    return jsonResponse(200, { found: false, reason: "no_nutrition" });
  }

  const name = pickName(p, lang);
  if (name.length === 0) {
    return jsonResponse(200, { found: false, reason: "no_nutrition" });
  }

  return jsonResponse(200, {
    found: true,
    product: {
      barcode,
      name,
      brand: typeof p.brands === "string" ? p.brands.split(",")[0].trim() : null,
      kcal_100g: Math.round(kcal),
      protein_100g: num(n["proteins_100g"]) ?? 0,
      fat_100g: num(n["fat_100g"]) ?? 0,
      carbs_100g: num(n["carbohydrates_100g"]) ?? 0,
      serving_g: servingGrams(p),
      image_url: typeof p.image_front_small_url === "string"
        ? p.image_front_small_url
        : null,
      source: "openfoodfacts",
    },
    _meta: { duration_ms: Date.now() - startedAt },
  });
});
