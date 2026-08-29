-- Salamat schema 0004: water_logs
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
-- Builds on 0001_init.sql (auth.users + auth.uid() RLS) and follows the same
-- shape as 0002_schema.sql / weight_logs: one row per event, RLS scoped to the
-- owner, an index on (user_id, time desc) for the per-day read.
--
-- Why a table and not a column on a daily row: the prototype's water card logs
-- +250 ml at a time and shows how many pips are filled. Append-only events let
-- the UI undo the last sip and let analytics bucket by day later, exactly like
-- meals and weight already do. A single "ml today" column would lose that and
-- would need an upsert-per-tap.

create table if not exists public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- One logged portion in millilitres. The UI logs 250 ml per tap; the check
  -- keeps a stray client from writing nonsense while still allowing a custom
  -- amount later.
  amount_ml integer not null check (amount_ml > 0 and amount_ml <= 5000),
  logged_at timestamptz not null default now()
);

create index if not exists water_logs_user_logged_idx
  on public.water_logs (user_id, logged_at desc);

alter table public.water_logs enable row level security;

drop policy if exists "water_logs_all_own" on public.water_logs;
create policy "water_logs_all_own" on public.water_logs
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Optional daily goal on the profile, so the pip count is not hardcoded in the
-- client. Nullable: when it is null the app falls back to its own default and
-- keeps working, which is what it does today before this migration is applied.
alter table public.profiles
  add column if not exists water_goal_ml integer
  check (water_goal_ml is null or (water_goal_ml > 0 and water_goal_ml <= 10000));
