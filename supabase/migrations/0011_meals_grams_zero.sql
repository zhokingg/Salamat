-- A meal may have an unknown portion.
--
-- `grams > 0` dated from when every row came from the camera, which always has
-- a weight. "What to cook" suggestions do not: the model lists ingredient
-- amounts, and when none of them is in grams or millilitres there is no honest
-- mass to write. The client already treats grams <= 0 as "portion unknown"
-- (the detail screen does not scale such an entry); the constraint was the
-- only thing rejecting it — every "Add to diary" on such a dish failed with
-- 23514 and the entry was rolled back.
--
-- Negative masses stay forbidden.
alter table public.meals drop constraint if exists meals_grams_check;
alter table public.meals add constraint meals_grams_check check (grams >= 0);
