-- Salamat foods catalog (core dataset)
-- Apply in Supabase dashboard → SQL Editor → paste → Run
--
-- This table is a PUBLIC, READ-ONLY catalog: every client (anon or
-- authenticated) may SELECT from it, but there is intentionally NO
-- insert/update/delete policy. Writes happen only via service_role (CSV
-- import / seed scripts), which bypasses RLS.

-- ============================================================
-- Extensions: trigram search for fast ILIKE '%term%'
-- ============================================================
create extension if not exists pg_trgm;

-- ============================================================
-- foods: name + per-100g macros, grouped by category
-- ============================================================
create table if not exists public.foods (
  id              bigint generated always as identity primary key,
  name            text not null unique,
  kcal_per_100g   int not null check (kcal_per_100g >= 0),
  protein_per_100g numeric not null default 0 check (protein_per_100g >= 0),
  fat_per_100g     numeric not null default 0 check (fat_per_100g >= 0),
  carbs_per_100g   numeric not null default 0 check (carbs_per_100g >= 0),
  category        text,
  created_at      timestamptz not null default now()
);

-- Fast case-insensitive substring search on name (ILIKE '%term%').
create index if not exists foods_name_trgm_idx
  on public.foods using gin (name gin_trgm_ops);

-- ============================================================
-- RLS: public read, no client writes
-- ============================================================
alter table public.foods enable row level security;

drop policy if exists "foods_select_all" on public.foods;
create policy "foods_select_all" on public.foods
  for select
  to anon, authenticated
  using (true);

-- NOTE: no insert/update/delete policies on purpose.
-- service_role (used by the CSV import / seed) bypasses RLS, so it can write
-- while every normal client key remains read-only.
