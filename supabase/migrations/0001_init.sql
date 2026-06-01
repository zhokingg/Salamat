-- Salamat initial schema
-- Apply in Supabase dashboard → SQL Editor → paste → Run

-- ============================================================
-- profiles: extends auth.users 1-to-1
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  last_name text not null default '',
  gender text check (gender in ('male','female')),
  goal text check (goal in ('lose','gain','maintain','healthy')),
  age int check (age > 0 and age < 120),
  height numeric check (height > 0),
  weight numeric check (weight > 0),
  calorie_norm int,
  is_pro boolean not null default false,
  pro_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- meals: diary entries
-- ============================================================
create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  name text not null,
  grams numeric not null check (grams > 0),
  kcal int not null check (kcal >= 0),
  protein numeric not null default 0,
  fat numeric not null default 0,
  carbs numeric not null default 0,
  eaten_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists meals_user_eaten_idx
  on public.meals (user_id, eaten_at desc);

-- ============================================================
-- photo_usage: daily counter per user (for free/pro limits)
-- ============================================================
create table if not exists public.photo_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  count int not null default 0,
  primary key (user_id, day)
);

-- ============================================================
-- RLS: users can only access their own rows
-- ============================================================
alter table public.profiles enable row level security;
alter table public.meals enable row level security;
alter table public.photo_usage enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "meals_all_own" on public.meals;
create policy "meals_all_own" on public.meals
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "photo_usage_all_own" on public.photo_usage;
create policy "photo_usage_all_own" on public.photo_usage
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- Auto-create empty profile row when a new user signs up
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Keep profiles.updated_at fresh
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ============================================================
-- Helper RPC: increment daily photo count atomically
-- ============================================================
create or replace function public.increment_photo_usage()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  new_count int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.photo_usage (user_id, day, count)
  values (auth.uid(), current_date, 1)
  on conflict (user_id, day)
    do update set count = photo_usage.count + 1
  returning count into new_count;

  return new_count;
end;
$$;

grant execute on function public.increment_photo_usage() to authenticated;
