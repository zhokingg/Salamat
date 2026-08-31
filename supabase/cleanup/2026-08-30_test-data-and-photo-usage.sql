-- ============================================================================
-- Salamat — cleanup, 2026-08-30
--
-- NOT APPLIED. Written to be pasted into Supabase dashboard → SQL Editor.
--
-- Three independent blocks. Read the header of each before running it; they do
-- different kinds of damage if run at the wrong moment. Blocks 1 and 2 delete
-- data, block 3 changes the schema.
--
-- Run them in order, or run only the ones you want — nothing here depends on
-- anything else here.
-- ============================================================================


-- ============================================================================
-- BLOCK 1 — free up the coach quota on the test subscriber
--
-- WHAT IT DOES
--   Deletes the 60 `coach_events` rows on
--   02834398-e06c-4108-b3e3-42b51f3faf5b. Those rows are mine: 7 came from
--   real chat messages during verification, 53 were claimed straight through
--   `consume_coach_message` to wind the counter to the cap and prove the 61st
--   message is refused.
--
-- WHAT HAPPENS IF YOU RUN IT
--   That account's month resets to 0 of 60 and it can chat again. The account
--   itself, and its `is_pro = true`, are untouched. No other user has rows in
--   this table yet, so nothing else moves.
--
-- WHEN NOT TO RUN IT
--   If you are going to run BLOCK 2 anyway, skip this — deleting the auth user
--   there removes these rows by cascade. This block exists for the case where
--   you want to KEEP the account usable (for example so the coach prompt can
--   be re-measured against a live call).
-- ============================================================================

delete from public.coach_events
 where user_id = '02834398-e06c-4108-b3e3-42b51f3faf5b';

-- Expect: DELETE 60
-- Check:
--   select count(*) from public.coach_events
--    where user_id = '02834398-e06c-4108-b3e3-42b51f3faf5b';   -- 0


-- ============================================================================
-- BLOCK 2 — remove the throwaway test accounts
--
-- WHAT IT DOES
--   Deletes three anonymous auth users created during verification work.
--   Deleting from `auth.users` cascades: every user table (profiles, meals,
--   weight_logs, water_logs, photo_usage, scan_events, coach_events) declares
--   `references auth.users(id) on delete cascade`, so this removes the account
--   and everything hanging off it in one statement.
--
--   02834398-e06c-4108-b3e3-42b51f3faf5b  is_pro = true, 60 coach_events.
--                                         The coach verification subscriber.
--   83742aae-1bbb-4cc0-ac77-3877c5225373  free. Used to prove a non-subscriber
--                                         gets 402 not_subscribed.
--   b3397867-c907-4e45-a489-6b1e877abe73  is_pro = true. The oldest one —
--                                         created to demonstrate that the
--                                         client could grant itself Pro, which
--                                         is the hole migration 0007 closes.
--                                         THIS ONE MATTERS MOST: it is a live
--                                         account with a paid flag nobody paid
--                                         for.
--
-- WHAT HAPPENS IF YOU RUN IT
--   Three anonymous accounts disappear. None has a purchase, a RevenueCat
--   subscriber record, or any real data. Nothing in the app references them.
--
-- WHAT HAPPENS IF YOU DON'T
--   Two accounts keep `is_pro = true` forever. Harmless while they are
--   unreachable — nobody has their session — but they will quietly skew any
--   "how many Pro users do we have" query you write later.
--
-- BEFORE YOU RUN IT, LOOK:
--   select id, is_pro, created_at from public.profiles
--    where id in ('02834398-e06c-4108-b3e3-42b51f3faf5b',
--                 '83742aae-1bbb-4cc0-ac77-3877c5225373',
--                 'b3397867-c907-4e45-a489-6b1e877abe73');
-- ============================================================================

delete from auth.users
 where id in ('02834398-e06c-4108-b3e3-42b51f3faf5b',
              '83742aae-1bbb-4cc0-ac77-3877c5225373',
              'b3397867-c907-4e45-a489-6b1e877abe73');

-- Expect: DELETE 3
--
-- NOTE — accounts NOT in this list, deliberately:
--   7ecb173f-a192-4666-804c-9f13c2fb7627  created today, free, still needed:
--     it is the account waiting on `is_pro = true` so the trimmed coach prompt
--     can be measured against a live call. Delete it once that is done.
--   Every simulator screenshot run also signs in anonymously and leaves a
--   profile row behind. They are free, empty and harmless. To find them:
--       select p.id, p.created_at from public.profiles p
--         left join public.meals m on m.user_id = p.id
--        where p.name = '' and m.id is null
--        order by p.created_at desc;
--     Read the list before deleting anything from it.


-- ============================================================================
-- BLOCK 3 — drop the orphaned daily photo counter (SCHEMA CHANGE)
--
-- WHAT IT DOES
--   Drops `public.photo_usage` and `public.increment_photo_usage()`, both from
--   migration 0001.
--
-- WHY THEY ARE ORPHANS
--   They implemented the ORIGINAL scan limit: one free photo scan per day,
--   counted per user per date. That model is gone. Migration 0006 replaced it
--   with `scan_events` — three scans for the LIFETIME of the account, spent
--   inside the `recognize-food` Edge Function through `consume_scan()`.
--
--   Nothing reads the table and nothing calls the function:
--     - no Dart code references either (`grep -rn photo_usage lib/` is empty);
--     - no Edge Function calls `increment_photo_usage` — `recognize-food` uses
--       `consume_scan`;
--     - the only surviving mention is a COMMENT in `delete-account/index.ts`
--       listing the tables that cascade. That comment is updated in the same
--       change as this file.
--
-- WHAT HAPPENS IF YOU RUN IT
--   Two objects disappear. No running code path changes, because none of them
--   touches these. Any rows still in `photo_usage` go with the table — they
--   are counts from the old daily model and have no meaning under the current
--   one, so nothing is lost that could be used.
--
-- WHAT HAPPENS IF YOU DON'T
--   Nothing breaks. You keep a table and a SECURITY DEFINER function that
--   nobody calls — which is a small standing risk, because a function granted
--   to `authenticated` that writes a counter is exactly the sort of thing that
--   gets rediscovered later and wired to the wrong place.
--
-- LOOK FIRST, IF YOU WANT TO KEEP THE NUMBERS
--   select count(*) as rows, min(day) as first_day, max(day) as last_day,
--          count(distinct user_id) as users, sum(count) as total_scans
--     from public.photo_usage;
--
-- REVERSIBILITY
--   Not reversible. The definitions are in
--   `supabase/migrations/0001_init.sql` if you ever need them back, but the
--   rows are gone for good.
--
-- IF YOU TRACK SCHEMA IN MIGRATIONS
--   This block is the only part of this file that is a schema change. Copy it
--   into `supabase/migrations/0010_drop_photo_usage.sql` so the migration
--   history stays a complete description of the database. Blocks 1 and 2 are
--   one-off data cleanup and do not belong there.
-- ============================================================================

drop function if exists public.increment_photo_usage();
drop table if exists public.photo_usage;

-- Check — both should return no rows:
--   select to_regclass('public.photo_usage');            -- null
--   select proname from pg_proc
--    where proname = 'increment_photo_usage';            -- 0 rows
