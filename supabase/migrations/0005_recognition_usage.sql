-- Salamat schema 0005: recognition_usage (cost telemetry)
-- Apply in Supabase dashboard → SQL Editor → paste → Run.
--
-- Records what one photo recognition actually cost. Written by the
-- `recognize-food` Edge Function with the service role key, one row per call.
--
-- Deliberately NOT linked to a user:
--   * no user_id, no auth.uid(), no image bytes, no dish name;
--   * `request_id` is a random uuid minted per call, so a log line can be
--     matched to a row and nothing else.
--   That is why there is no owner policy below — there is no owner. The table
--   is service-role only: RLS is enabled with no policy, which denies every
--   anon/authenticated request while the service role bypasses RLS entirely.
--
-- The function works fine before this migration is applied: it logs the same
-- row to the function log and skips the insert on a 404.

create table if not exists public.recognition_usage (
  id uuid primary key default gen_random_uuid(),

  -- Random per-request correlation id. Not derived from anything.
  request_id uuid not null,

  -- Model that served the call, so a model swap is visible in the data.
  model text not null,

  ok boolean not null,
  -- 'ok' | 'upstream_unreachable' | 'upstream_<status>'
  -- | 'upstream_invalid_json' | 'model_returned_non_json'
  outcome text not null,

  -- Straight from the Anthropic response `usage` block. Null when the call
  -- never reached the model (e.g. network failure).
  input_tokens integer check (input_tokens is null or input_tokens >= 0),
  output_tokens integer check (output_tokens is null or output_tokens >= 0),

  -- Pixel size of the image as sent, read from the JPEG/PNG header. Null when
  -- the header could not be parsed.
  image_width integer check (image_width is null or image_width > 0),
  image_height integer check (image_height is null or image_height > 0),

  -- Length of the base64 payload forwarded upstream, i.e. bandwidth cost.
  request_bytes integer not null check (request_bytes >= 0),

  duration_ms integer not null check (duration_ms >= 0),

  created_at timestamptz not null default now()
);

-- Time-ordered reads for "what did last week cost", and a model filter for
-- comparing tiers.
create index if not exists recognition_usage_created_idx
  on public.recognition_usage (created_at desc);
create index if not exists recognition_usage_model_created_idx
  on public.recognition_usage (model, created_at desc);

-- RLS on with no policy: clients get nothing, the service role bypasses it.
alter table public.recognition_usage enable row level security;

-- Handy roll-up. Query it instead of writing the aggregation by hand:
--   select * from public.recognition_usage_by_size;
create or replace view public.recognition_usage_by_size as
select
  model,
  greatest(image_width, image_height)          as long_side,
  count(*)                                     as calls,
  count(*) filter (where ok)                   as ok_calls,
  round(avg(input_tokens))                     as avg_input_tokens,
  round(avg(output_tokens))                    as avg_output_tokens,
  round(avg(request_bytes))                    as avg_request_bytes,
  round(avg(duration_ms))                      as avg_duration_ms
from public.recognition_usage
where image_width is not null and image_height is not null
group by model, greatest(image_width, image_height)
order by model, long_side desc;
