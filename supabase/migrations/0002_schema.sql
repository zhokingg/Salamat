-- Salamat schema 0002: weight_logs
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
-- Builds on 0001_init.sql (auth.users + auth.uid() RLS).

create table if not exists public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 0),
  logged_at timestamptz not null default now()
);

create index if not exists weight_logs_user_logged_idx
  on public.weight_logs (user_id, logged_at desc);

alter table public.weight_logs enable row level security;

drop policy if exists "weight_logs_all_own" on public.weight_logs;
create policy "weight_logs_all_own" on public.weight_logs
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
