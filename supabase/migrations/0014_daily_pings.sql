-- Daily Active Users tracking.
--
-- One row per device per day. Insert is idempotent via the composite primary
-- key — clients call upsert on every app launch, but only the first insert of
-- the day per device actually creates a row.
--
-- IDFV (Apple's first-party identifier-for-vendor) is used as device_id.
-- It's stable across launches but resets on uninstall — fine for DAU.
--
-- Run with: supabase db push  (or paste in SQL editor)

-- No FK on user_id — Postgres validates FKs against auth.users via an
-- internal SELECT that's subject to auth.users RLS, which the
-- `authenticated` role can't fully satisfy. The result was 42501
-- on every insert from the iOS app. user_id is just an analytics tag,
-- not authoritative data, so we accept it as a loose UUID.
create table if not exists daily_pings (
  device_id  text not null,
  user_id    uuid,
  day        date not null default current_date,
  primary key (device_id, day)
);

create index if not exists daily_pings_day_idx on daily_pings (day);
create index if not exists daily_pings_user_day_idx on daily_pings (user_id, day) where user_id is not null;

alter table daily_pings enable row level security;

-- Role-level grants come BEFORE RLS in PostgREST's evaluation order.
-- Without these, anon/authenticated requests get 403/42501 even with a
-- permissive RLS policy. Supabase doesn't auto-grant on new public-schema
-- tables in all project configs, so we're explicit.
grant insert on daily_pings to anon, authenticated;

-- Anyone (including unauthenticated users) may insert their own ping. The
-- `do nothing` semantics on conflict mean repeat upserts are no-ops, so a
-- malicious client can't run up our row count by spamming the same key.
create policy "anyone can ping" on daily_pings
  for insert
  with check (true);

-- No SELECT/UPDATE/DELETE policies → only service-role (your SQL editor /
-- dashboard) can read or modify rows. Clients can't poke at other users.
