-- App-wide config / kill switch.
--
-- A single-row table the iOS client reads on launch. Lets us disable the
-- whole app (maintenance mode) or individual features without shipping a
-- new build. Edit via the Supabase dashboard's table editor.

create table if not exists app_config (
  id int primary key default 1,

  -- Hard kill. iOS shows a maintenance screen instead of the main UI.
  is_killed         boolean not null default false,
  kill_message      text    not null default 'TappyHour is temporarily unavailable. Please try again soon.',

  -- Per-feature soft gates. App still runs; specific UI is hidden/disabled.
  allow_suggestions boolean not null default true,
  allow_reports     boolean not null default true,

  updated_at        timestamptz not null default now(),

  -- Force singleton: only id=1 ever exists.
  constraint app_config_singleton check (id = 1)
);

-- Seed the single row.
insert into app_config (id) values (1)
on conflict (id) do nothing;

-- Public read so unauthenticated launches still get the kill switch.
-- (A killed app should kill *everyone*, including users who haven't logged in.)
alter table app_config enable row level security;

drop policy if exists "app_config readable by anyone" on app_config;
create policy "app_config readable by anyone"
  on app_config
  for select
  using (true);

-- No insert/update/delete policy. Writes go through the dashboard or
-- service-role only — never from the app.
