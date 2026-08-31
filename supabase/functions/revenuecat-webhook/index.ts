// Salamat — revenuecat-webhook Edge Function.
//
// Why this exists:
//   `profiles.is_pro` gates the server-side scan allowance (migration 0006).
//   Until now the CLIENT wrote that column, which meant anyone could grant
//   themselves Pro without paying. This function is the only thing that should
//   ever write it: RevenueCat tells us what actually happened at the store, and
//   the row is updated with the service role.
//
// Contract:
//   POST  (RevenueCat webhook payload)
//     { "api_version": "1.0", "event": { "type": ..., "app_user_id": ..., ... } }
//   → 200 { ok: true, action: 'granted' | 'revoked' | 'ignored', reason? }
//   → 400 { error: 'invalid_json' | 'malformed_event' }
//   → 401 { error: 'unauthorized' }      — bad or missing shared secret
//   → 405 { error: 'method_not_allowed' }
//   → 500 { error: 'server_misconfigured' } — secret or service key not set
//   → 502 { error: 'profile_update_failed' }
//
// AUTHENTICATION
//   RevenueCat does not sign webhooks with an HMAC. It sends whatever value you
//   put in the webhook's Authorization header field, verbatim, on every request.
//   So verification here is a constant-time comparison against
//   REVENUECAT_WEBHOOK_SECRET. Set that secret to a long random string and put
//   the SAME string in the RevenueCat dashboard. Nothing is hardcoded.
//
//   Deploy with JWT verification OFF — RevenueCat cannot present a Supabase JWT:
//     supabase functions deploy revenuecat-webhook --no-verify-jwt
//   The Authorization header is the only thing standing between this endpoint
//   and the internet, which is why a missing secret is a hard 500 rather than
//   a fail-open.
//
// Secrets (set in the dashboard, never in code):
//   REVENUECAT_WEBHOOK_SECRET   shared secret, must match the dashboard
//   SUPABASE_URL                injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY   injected by Supabase

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

/// Entitlement that marks a paying user. Mirrors
/// `RevenueCatConfig.proEntitlement` in the Flutter client.
const PRO_ENTITLEMENT = "pro";

/// Events that mean "this user is entitled right now".
const GRANT = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "PRODUCT_CHANGE",
  "SUBSCRIPTION_EXTENDED",
]);

/// Events that mean "this user is no longer entitled".
///
/// CANCELLATION is deliberately NOT here: in RevenueCat it means auto-renew was
/// switched off, and the user keeps access until the period ends. Revoking on
/// it would take away time somebody already paid for. EXPIRATION arrives when
/// that period actually ends.
const REVOKE = new Set([
  "EXPIRATION",
  "REFUND",
  "SUBSCRIPTION_PAUSED",
]);

/// Seen, understood, and deliberately no state change.
const NO_CHANGE = new Set([
  "CANCELLATION",      // auto-renew off; still entitled until EXPIRATION
  "BILLING_ISSUE",     // grace period; EXPIRATION follows if it is not resolved
  "SUBSCRIBER_ALIAS",  // identity bookkeeping
  "TEST",              // dashboard "send test event"
]);

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/// Length-independent, constant-time string compare.
function secretMatches(given: string, expected: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  // Compare a fixed number of bytes so the loop count does not leak the length.
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

/// Supabase user ids are uuids. RevenueCat anonymous ids look like
/// `$RCAnonymousID:abc...` and map to no profile, so they are skipped rather
/// than written blindly.
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isSupabaseUid(v: unknown): v is string {
  return typeof v === "string" && UUID_RE.test(v);
}

/// Writes `is_pro` with the service role, which bypasses RLS. Returns false on
/// any non-2xx so the caller can answer 502 and let RevenueCat retry.
async function setIsPro(userId: string, isPro: boolean): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return false;

  try {
    const res = await fetch(
      `${url}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`,
      {
        method: "PATCH",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "content-type": "application/json",
          Prefer: "return=minimal",
        },
        body: JSON.stringify({ is_pro: isPro }),
      },
    );
    if (!res.ok) {
      console.error("profile patch failed", res.status, await res.text());
      return false;
    }
    return true;
  } catch (e) {
    console.error("profile patch threw", e);
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) {
    // Never fail open: without the secret this endpoint would accept anything.
    console.error("REVENUECAT_WEBHOOK_SECRET not set");
    return json(500, { error: "server_misconfigured" });
  }

  const given = req.headers.get("Authorization") ?? "";
  if (!secretMatches(given, secret)) {
    console.warn("webhook rejected: bad Authorization header");
    return json(401, { error: "unauthorized" });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return json(400, { error: "invalid_json" });
  }

  const event = payload?.event;
  const type = typeof event?.type === "string" ? event.type : null;
  if (!event || !type) {
    return json(400, { error: "malformed_event" });
  }

  // Correlation id for the log line; RevenueCat retries carry the same one.
  const eventId = typeof event.id === "string" ? event.id : "unknown";

  // Only this app's Pro entitlement is interesting. Some event types carry no
  // entitlement list at all, in which case we do not filter on it.
  const ents: unknown = event.entitlement_ids ?? event.entitlement_id;
  const entitlements = Array.isArray(ents)
    ? ents
    : (typeof ents === "string" ? [ents] : null);
  if (entitlements && !entitlements.includes(PRO_ENTITLEMENT)) {
    console.log(`ignored ${type} ${eventId}: other entitlement`, entitlements);
    return json(200, { ok: true, action: "ignored", reason: "other_entitlement" });
  }

  // TRANSFER moves an entitlement between app user ids: revoke from the old
  // ones, grant to the new ones. Handled before the plain grant/revoke sets
  // because it touches two sides.
  if (type === "TRANSFER") {
    const from: unknown[] = Array.isArray(event.transferred_from)
      ? event.transferred_from
      : [];
    const to: unknown[] = Array.isArray(event.transferred_to)
      ? event.transferred_to
      : [];
    let ok = true;
    for (const id of from) {
      if (isSupabaseUid(id)) ok = (await setIsPro(id, false)) && ok;
    }
    for (const id of to) {
      if (isSupabaseUid(id)) ok = (await setIsPro(id, true)) && ok;
    }
    if (!ok) return json(502, { error: "profile_update_failed" });
    console.log(`TRANSFER ${eventId}: ${from.length} -> ${to.length}`);
    return json(200, { ok: true, action: "transferred" });
  }

  if (NO_CHANGE.has(type)) {
    console.log(`ignored ${type} ${eventId}: no entitlement change`);
    return json(200, { ok: true, action: "ignored", reason: "no_change" });
  }

  let grant: boolean;
  if (GRANT.has(type)) {
    grant = true;
  } else if (REVOKE.has(type)) {
    grant = false;
  } else {
    // Unknown type: acknowledge so RevenueCat stops retrying, but say plainly
    // that nothing was done and log it so a new event type gets noticed.
    console.warn(`unhandled event type ${type} ${eventId}`);
    return json(200, { ok: true, action: "ignored", reason: "unhandled_type" });
  }

  // A grant whose expiry is already in the past is not a grant. Guards against
  // a delayed or replayed RENEWAL reviving a lapsed subscription.
  const expiresMs = Number(event.expiration_at_ms);
  if (grant && Number.isFinite(expiresMs) && expiresMs > 0) {
    if (expiresMs < Date.now()) {
      grant = false;
      console.log(`${type} ${eventId}: expiry in the past, treating as revoke`);
    }
  }

  const userId = isSupabaseUid(event.app_user_id)
    ? event.app_user_id
    : (isSupabaseUid(event.original_app_user_id)
      ? event.original_app_user_id
      : null);

  if (!userId) {
    // Anonymous RevenueCat id — no profile row to update. Acknowledged, not
    // an error: it simply is not one of our signed-in users.
    console.log(`ignored ${type} ${eventId}: no supabase uid`);
    return json(200, { ok: true, action: "ignored", reason: "no_supabase_uid" });
  }

  const ok = await setIsPro(userId, grant);
  if (!ok) {
    // 502 so RevenueCat retries — a dropped write here silently removes
    // someone's paid access.
    return json(502, { error: "profile_update_failed" });
  }

  console.log(`${type} ${eventId}: is_pro=${grant} for ${userId}`);
  return json(200, { ok: true, action: grant ? "granted" : "revoked" });
});
