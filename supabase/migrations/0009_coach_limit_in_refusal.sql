-- Salamat schema 0009: return the monthly limit when refusing a coach message
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
--
-- SAFE TO APPLY AT ANY TIME. It only replaces one function body; no data is
-- touched, no grants change, and the coach keeps working either way.
--
-- WHY
--   `consume_coach_message` returned (allowed, reason, used, remaining) and
--   nothing else, so on refusal the Edge Function had no limit to report and
--   answered:
--       429 {"error":"monthly_limit","used":60,"monthly_limit":null}
--   Nothing broke — the client reads the limit from `coach_status()` — but a
--   field that is always null is a field that lies about being available.
--
--   The function now falls back to calling `coach_monthly_limit()` when this
--   column is missing, so the null is already gone in production. Applying
--   this removes that extra round trip.

create or replace function public.consume_coach_message(
  p_request_id uuid default null
)
returns table (
  allowed boolean,
  reason text,
  used int,
  remaining int,
  monthly_limit int          -- added in 0009
)
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
    -- The limit is reported here too: a free user asking "how many do I get
    -- with Pro" is a fair question and the answer is not a secret.
    return query select false, 'not_subscribed', 0, 0, v_limit;
    return;
  end if;

  select count(*)::int into v_used
    from public.coach_events e
   where e.user_id = v_uid
     and e.outcome = 'sent'
     and e.created_at >= date_trunc('month', now());

  if v_used >= v_limit then
    return query select false, 'monthly_limit', v_used, 0, v_limit;
    return;
  end if;

  insert into public.coach_events (user_id, request_id, outcome)
  values (v_uid, p_request_id, 'sent');

  v_used := v_used + 1;
  return query
    select true, null::text, v_used, greatest(v_limit - v_used, 0), v_limit;
end;
$$;

grant execute on function public.consume_coach_message(uuid) to authenticated;

-- Verify:
--   select * from public.consume_coach_message();
--   -- expect a monthly_limit column with 60 in it
