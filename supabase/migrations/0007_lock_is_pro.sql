-- Salamat schema 0007: take `profiles.is_pro` away from the client
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
--
-- ============================================================================
--  DO NOT APPLY THIS UNTIL THE REVENUECAT WEBHOOK IS DEPLOYED AND VERIFIED.
--
--  After this runs, the app can no longer set `is_pro`. The ONLY thing that
--  can is `revenuecat-webhook`, using the service role. If that function is
--  not live and confirmed working, every paying user is stuck on the free
--  three-scan allowance with no way back — the client cannot repair itself.
--
--  ALL FOUR must be true before this file is run:
--    1. `revenuecat-webhook` is deployed            (done — version 1)
--    2. REVENUECAT_WEBHOOK_SECRET is set, and the SAME string is in the
--       RevenueCat dashboard                        (yours to do)
--    3. RevenueCat points at
--       https://cpqidxmqydleadbinaon.supabase.co/functions/v1/revenuecat-webhook
--    4. ONE REAL PURCHASE has flipped `profiles.is_pro` to true by itself
--
--  Step 4 is the one that cannot be skipped. A test event proves the endpoint
--  answers; only a real purchase proves the whole chain — app user id, event
--  type, entitlement name, service-role write — actually lines up.
-- ============================================================================
--
-- WHY
--   `is_pro` gates the server-side scan allowance (migration 0006). The policy
--   `profiles_update_own` grants the signed-in user UPDATE over their own row,
--   which includes this column — so anyone could grant themselves Pro without
--   paying. RLS decides WHICH ROWS a role may touch; it does not decide which
--   COLUMNS. That is a grant, and it has to be narrowed here.
--
-- HOW
--   A column-level REVOKE does nothing while a table-level UPDATE grant exists
--   (Postgres checks the table grant first and stops). So the table-wide grant
--   is dropped and re-issued column by column, omitting `is_pro`.
--
--   `pro_until` is omitted for the same reason: it describes the same paid
--   state and should follow the same authority.
--
--   SELECT is untouched — the client still reads its own `is_pro` to paint the
--   UI. Only writing is removed.

-- ---------------------------------------------------------------------------
-- 1. Drop the blanket UPDATE grant
-- ---------------------------------------------------------------------------
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;

-- ---------------------------------------------------------------------------
-- 2. Re-grant UPDATE on everything the user legitimately edits
-- ---------------------------------------------------------------------------
-- Every column of `profiles` except `is_pro` and `pro_until`.
-- `id` and `created_at` are included for completeness; RLS
-- (`profiles_update_own`) still confines the user to their own row, and the
-- primary key is not something the app rewrites.
--
-- NOTE: `water_goal_ml` comes from migration 0004. If 0004 has not been applied
-- yet, delete that one name from the list below, run this file, and add it back
-- with a follow-up `grant update (water_goal_ml) ...` once 0004 lands.
grant update (
  id,
  name,
  last_name,
  gender,
  goal,
  age,
  height,
  weight,
  calorie_norm,
  water_goal_ml,
  created_at,
  updated_at
) on public.profiles to authenticated;

-- Anonymous sign-in issues the `authenticated` role, so `anon` needs no write
-- grant here. It is left with SELECT only.

-- ---------------------------------------------------------------------------
-- 3. Verify
-- ---------------------------------------------------------------------------
-- Expect: rows for every column above, and NO row for is_pro / pro_until.
--
--   select grantee, column_name, privilege_type
--     from information_schema.column_privileges
--    where table_schema = 'public'
--      and table_name   = 'profiles'
--      and privilege_type = 'UPDATE'
--      and grantee in ('authenticated','anon')
--    order by grantee, column_name;
--
-- And from the app, signed in as a normal user, this must now fail:
--
--   update public.profiles set is_pro = true where id = auth.uid();
--   -- ERROR: permission denied for column is_pro
