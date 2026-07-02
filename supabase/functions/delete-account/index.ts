// Salamat — delete-account Edge Function.
//
// Why this exists:
//   Google Play requires any app that creates accounts to let users delete
//   their account and data. The client cannot delete an auth user (the anon
//   key has no admin rights), so this function does it server-side with the
//   service-role key. Every user table (profiles, meals, weight_logs,
//   photo_usage) references auth.users(id) ON DELETE CASCADE, so removing the
//   auth user wipes all of their data in one shot.
//
// Security:
//   The user id is NEVER taken from the request body. It is derived from the
//   caller's verified JWT, so a user can only ever delete THEMSELVES.
//
// Contract:
//   POST (no body needed; auth via Bearer JWT)
//   → 200 { ok: true }
//   → 401 { error } — missing/invalid JWT
//   → 500 { error } — server-side misconfig (service role / url missing)
//   → 502 { error } — delete failed upstream
//
// Deploy:    supabase functions deploy delete-account
//   SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are auto-injected by Supabase —
//   no manual secret needs to be set.
// Tail logs: supabase functions logs delete-account --tail

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not available");
    return jsonResponse(500, { error: "server_misconfigured" });
  }

  // Extract the caller's bearer token and resolve their identity from it.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return jsonResponse(401, { error: "missing_token" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Verify the token and get the user it belongs to. The id used for deletion
  // comes from here, never from client-supplied data.
  const { data: userData, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !userData?.user) {
    console.error("getUser failed", userErr);
    return jsonResponse(401, { error: "invalid_token" });
  }

  const uid = userData.user.id;

  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) {
    console.error("deleteUser failed", delErr);
    return jsonResponse(502, { error: "delete_failed" });
  }

  return jsonResponse(200, { ok: true });
});
