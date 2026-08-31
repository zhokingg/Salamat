-- Salamat schema 0006: scan_events (lifetime free scan allowance)
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
--
-- WHY
--   The free tier is THREE PHOTO SCANS FOR THE LIFETIME of the account, not a
--   daily quota. The old counter lived in the client (`SubscriptionState`) with
--   a per-day `photo_usage` backstop, so reinstalling the app reset it and the
--   model did not hold. The count now lives here, and the Edge Function is the
--   only thing that may write it.
--
-- SHAPE
--   Event-sourced on purpose: one row per consumed scan rather than a counter
--   column. That keeps the analytics ("when do people burn their three?",
--   "how many convert after the third?") available without a second table, and
--   makes the count auditable — a counter that drifts cannot be reconstructed,
--   a log of events can.
--
-- EXISTING USERS
--   Nothing is backfilled. `photo_usage` (migration 0001) is left untouched and
--   is NOT read by the new rule. Every account that exists today therefore has
--   zero rows here and starts with a full three scans. Nobody loses anything
--   they had; some people effectively gain scans. That is deliberate — this is
--   a policy change, and taking scans away from people retroactively would be
--   the wrong side to err on.
--
-- MANUAL LOGGING
--   Not affected. It never touched the quota and still does not.

-- ============================================================
-- profiles.is_pro — server-visible entitlement
-- ============================================================
-- The allowance check runs on the server, so the server needs to know whether
-- the caller is subscribed. RevenueCat is the source of truth and the client
-- mirrors it here.
--
-- NOTE (known gap, see report): `profiles_update_own` lets the client write
-- this column, so it is spoofable by a determined user. Closing it properly
-- means a RevenueCat webhook writing this column with the service role, after
-- which the client grant can be revoked:
--     revoke update (is_pro) on public.profiles from authenticated;
-- That webhook does not exist yet, so the grant stays for now — otherwise
-- paying users would be capped at three scans.
alter table public.profiles
  add column if not exists is_pro boolean not null default false;

-- ============================================================
-- scan_events — one row per consumed photo scan
-- ============================================================
create table if not exists public.scan_events (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  created_at timestamptz not null default now(),

  -- Correlates with `recognition_usage.request_id` from the same call, so a
  -- consumed scan can be joined to what it actually cost. Nullable: the event
  -- is what matters, the correlation is a convenience.
  request_id uuid,

  -- 'consumed' today. Left as text so a later state ('refunded', 'voided')
  -- can be appended without a migration.
  outcome text not null default 'consumed',

  -- 'photo' today. Manual entry and cook suggestions never write here.
  source text not null default 'photo'
);

create index if not exists scan_events_user_created_idx
  on public.scan_events (user_id, created_at desc);

-- ============================================================
-- RLS: read your own, write nothing
-- ============================================================
-- The client may read its own events (it renders "2 of 3 left" from the
-- server's answer) but may not insert, update or delete: the count is only
-- ever moved by `consume_scan`, which is SECURITY DEFINER.
alter table public.scan_events enable row level security;

drop policy if exists "scan_events_select_own" on public.scan_events;
create policy "scan_events_select_own" on public.scan_events
  for select using (auth.uid() = user_id);

-- ============================================================
-- The allowance, in one place
-- ============================================================
create or replace function public.free_scan_allowance()
returns int
language sql
immutable
as $$ select 3 $$;

-- ============================================================
-- scan_status() — what the client renders
-- ============================================================
-- Read-only. Safe to call as often as the UI likes.
create or replace function public.scan_status()
returns table (is_pro boolean, used int, remaining int, allowance int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pro boolean;
  v_used int;
  v_allow int := public.free_scan_allowance();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(p.is_pro, false) into v_pro
    from public.profiles p where p.id = v_uid;
  v_pro := coalesce(v_pro, false);

  select count(*)::int into v_used
    from public.scan_events e
   where e.user_id = v_uid and e.outcome = 'consumed';

  return query select
    v_pro,
    v_used,
    case when v_pro then 2147483647 else greatest(v_allow - v_used, 0) end,
    v_allow;
end;
$$;

-- ============================================================
-- consume_scan() — atomic check-and-take
-- ============================================================
-- Called by the `recognize-food` Edge Function ONLY after a successful,
-- confident recognition, with the caller's JWT so `auth.uid()` is the user.
--
-- Atomicity: the advisory lock is held for the transaction and keyed on the
-- user, so two scans fired at once cannot both read `used = 2` and both
-- insert. Without it the check and the insert are two statements and the
-- third scan could be given away twice.
--
-- Returns `allowed = false` and writes nothing when the allowance is spent.
create or replace function public.consume_scan(p_request_id uuid default null)
returns table (allowed boolean, used int, remaining int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pro boolean;
  v_used int;
  v_allow int := public.free_scan_allowance();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select coalesce(p.is_pro, false) into v_pro
    from public.profiles p where p.id = v_uid;
  v_pro := coalesce(v_pro, false);

  select count(*)::int into v_used
    from public.scan_events e
   where e.user_id = v_uid and e.outcome = 'consumed';

  if not v_pro and v_used >= v_allow then
    return query select false, v_used, 0;
    return;
  end if;

  insert into public.scan_events (user_id, request_id, outcome, source)
  values (v_uid, p_request_id, 'consumed', 'photo');

  v_used := v_used + 1;

  return query select
    true,
    v_used,
    case when v_pro then 2147483647 else greatest(v_allow - v_used, 0) end;
end;
$$;

grant execute on function public.free_scan_allowance() to authenticated;
grant execute on function public.scan_status() to authenticated;
grant execute on function public.consume_scan(uuid) to authenticated;
