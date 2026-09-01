-- 0010 — the parts of a plan that only lived on the phone.
--
-- WHY
--   `profiles` stored name, gender, age, height, weight, goal and the calorie
--   norm — but not the TARGET weight, the activity level or the self-reported
--   experience, even though onboarding asks for all three and the plan screen
--   is built out of them. They existed only in `userProvider`, which is
--   memory. Reinstall the app, or sign into the account from another phone,
--   and the target weight came back as a dash: the progress screen had no
--   finish line to draw and the plan could not be recomputed.
--
--   Nullable on purpose. Every existing row keeps working with these unset,
--   and the app treats null the same way it treated a missing value before.
--
-- The client tolerates this migration NOT being applied: `upsertUser` retries
-- without these three columns if PostgREST reports them missing, so nothing
-- breaks in the window before you run it. Read/write of the target weight
-- simply starts working once it lands.
--
-- Apply from the dashboard SQL editor.

alter table public.profiles
  add column if not exists target_weight numeric,
  add column if not exists activity_level text,
  add column if not exists familiarity text;

comment on column public.profiles.target_weight is
  'Goal weight in kg, as entered in onboarding. Null when never set.';
comment on column public.profiles.activity_level is
  'sedentary | light | moderate | high — matches ActivityLevel in the app.';
comment on column public.profiles.familiarity is
  'novice | intermediate | expert — matches Familiarity in the app.';
