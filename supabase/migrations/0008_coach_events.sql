-- Salamat schema 0008: coach_events (monthly coach message allowance)
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
--
-- NOT APPLIED BY ME. Nothing in the app depends on it until the `coach`
-- function is deployed; until both exist the chat simply reports that it is
-- unavailable.
--
-- WHY
--   The coach is Pro-only and capped per month even for Pro, because every
--   exchange costs model tokens. Both checks live here rather than in the
--   client: a counter the app can edit is not a limit.
--
-- SHAPE
--   Event-sourced, same as `scan_events` (0006): one row per exchange rather
--   than a counter column. It answers "how much is the coach actually used,
--   and by whom" without a second table, and a miscounted month can be
--   recomputed from the log.
--
-- THE NUMBER
--   `coach_monthly_limit()` returns it, so changing the allowance is one
--   statement and no redeploy:
--       create or replace function public.coach_monthly_limit()
--       returns int language sql immutable as $$ select 300 $$;
--   60 is set for rough parity with what the free scan allowance costs: a
--   Russian exchange runs ~1.2k input + ~210 output tokens, and the system
--   prompt is re-sent every turn. Raise it once real usage says the ceiling is
--   never reached.

-- ============================================================
-- coach_events — one row per completed exchange
-- ============================================================
create table if not exists public.coach_events (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  created_at timestamptz not null default now(),

  -- Correlates with `recognition_usage.request_id` for the same call, so an
  -- exchange can be joined to what it cost.
  request_id uuid,

  -- 'sent' today. Left as text so a later state ('refunded', 'failed') can be
  -- appended without a migration.
  outcome text not null default 'sent'
);

-- The allowance is per calendar month, so every read filters on user + time.
create index if not exists coach_events_user_created_idx
  on public.coach_events (user_id, created_at desc);

-- ============================================================
-- RLS: read your own, write nothing
-- ============================================================
-- Same rule as scan_events: the client may read its own usage to paint the UI,
-- but only `consume_coach_message` (SECURITY DEFINER) may add a row.
alter table public.coach_events enable row level security;

drop policy if exists "coach_events_select_own" on public.coach_events;
create policy "coach_events_select_own" on public.coach_events
  for select using (auth.uid() = user_id);

-- ============================================================
-- The allowance, in one place
-- ============================================================
create or replace function public.coach_monthly_limit()
returns int
language sql
immutable
as $$ select 60 $$;

-- ============================================================
-- coach_status() — what the client renders
-- ============================================================
-- Read-only. Reports both gates separately so the app can tell "you need a
-- subscription" apart from "you have used this month's messages".
create or replace function public.coach_status()
returns table (is_pro boolean, used int, remaining int, monthly_limit int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pro boolean;
  v_used int;
  v_limit int := public.coach_monthly_limit();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(p.is_pro, false) into v_pro
    from public.profiles p where p.id = v_uid;
  v_pro := coalesce(v_pro, false);

  -- Calendar month in UTC. Deliberately not the user's local month: the
  -- allowance would otherwise reset twice for somebody who travels.
  select count(*)::int into v_used
    from public.coach_events e
   where e.user_id = v_uid
     and e.outcome = 'sent'
     and e.created_at >= date_trunc('month', now());

  return query select v_pro, v_used, greatest(v_limit - v_used, 0), v_limit;
end;
$$;

-- ============================================================
-- consume_coach_message() — atomic check-and-take
-- ============================================================
-- Called by the `coach` Edge Function BEFORE the model call, with the caller's
-- JWT so `auth.uid()` is the user. Unlike a photo scan there is nothing to
-- verify after the fact — the tokens are spent the moment the request goes
-- upstream — so the message is claimed first and the call only proceeds if the
-- claim succeeded.
--
-- Returns `allowed = false` and writes nothing when the caller is not Pro or
-- the month is spent. `reason` says which, so the app can show the right screen.
create or replace function public.consume_coach_message(
  p_request_id uuid default null
)
returns table (allowed boolean, reason text, used int, remaining int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pro boolean;
  v_used int;
  v_limit int := public.coach_monthly_limit();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('coach:' || v_uid::text, 0));

  select coalesce(p.is_pro, false) into v_pro
    from public.profiles p where p.id = v_uid;
  v_pro := coalesce(v_pro, false);

  if not v_pro then
    return query select false, 'not_subscribed', 0, 0;
    return;
  end if;

  select count(*)::int into v_used
    from public.coach_events e
   where e.user_id = v_uid
     and e.outcome = 'sent'
     and e.created_at >= date_trunc('month', now());

  if v_used >= v_limit then
    return query select false, 'monthly_limit', v_used, 0;
    return;
  end if;

  insert into public.coach_events (user_id, request_id, outcome)
  values (v_uid, p_request_id, 'sent');

  v_used := v_used + 1;
  return query select true, null::text, v_used, greatest(v_limit - v_used, 0);
end;
$$;

grant execute on function public.coach_monthly_limit() to authenticated;
grant execute on function public.coach_status() to authenticated;
grant execute on function public.consume_coach_message(uuid) to authenticated;
