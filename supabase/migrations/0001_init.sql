-- TappyHour initial schema
-- Run in Supabase SQL editor (or `supabase db push` once CLI is wired up)

-- =========================================================
-- Extensions
-- =========================================================
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- =========================================================
-- Enums
-- =========================================================
create type day_key as enum ('mon','tue','wed','thu','fri','sat','sun');
create type manager_role as enum ('owner','editor');
create type claim_status as enum ('pending','approved','rejected');

-- =========================================================
-- Profiles (public mirror of auth.users)
-- =========================================================
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz default now()
);

-- Auto-create a profile row when a new auth user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =========================================================
-- Venues
-- =========================================================
create table venues (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  short_name    text not null,
  slug          text unique,
  cuisine       text,
  vibe          text,
  neighborhood  text,
  price_tier    smallint check (price_tier between 1 and 4),
  phone         text,
  website       text,
  photo_url     text,
  address       text,
  location      geography(point, 4326) not null,
  rating        numeric(2,1),
  reviews_count int default 0,
  tags          text[] default '{}',
  is_published  boolean default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
create index venues_location_idx on venues using gist(location);
create index venues_published_idx on venues(is_published) where is_published;
create index venues_search_idx on venues using gin (
  to_tsvector('english', coalesce(name,'') || ' ' || coalesce(neighborhood,'') || ' ' || coalesce(cuisine,''))
);

-- =========================================================
-- Schedules (one row per venue × day; missing = no happy hour)
-- =========================================================
create table venue_schedules (
  id         uuid primary key default gen_random_uuid(),
  venue_id   uuid not null references venues(id) on delete cascade,
  day        day_key not null,
  start_time time not null,
  end_time   time not null,
  headline   text,
  is_active  boolean default true,
  unique(venue_id, day)
);
create index schedules_venue_idx on venue_schedules(venue_id);

-- =========================================================
-- Menu items
-- =========================================================
create table menu_items (
  id           uuid primary key default gen_random_uuid(),
  schedule_id  uuid not null references venue_schedules(id) on delete cascade,
  name         text not null,
  normal_price numeric(6,2) not null,
  deal_price   numeric(6,2) not null,
  sort_order   int default 0
);
create index menu_schedule_idx on menu_items(schedule_id);

-- =========================================================
-- Manager assignments
-- =========================================================
create table venue_managers (
  venue_id  uuid references venues(id) on delete cascade,
  user_id   uuid references auth.users(id) on delete cascade,
  role      manager_role default 'editor',
  added_at  timestamptz default now(),
  primary key (venue_id, user_id)
);
create index venue_managers_user_idx on venue_managers(user_id);

-- =========================================================
-- Claim requests
-- =========================================================
create table claim_requests (
  id          uuid primary key default gen_random_uuid(),
  venue_id    uuid references venues(id) on delete cascade,
  user_id     uuid references auth.users(id) on delete cascade,
  status      claim_status default 'pending',
  evidence    text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at  timestamptz default now()
);
create index claims_status_idx on claim_requests(status);

-- =========================================================
-- User saves
-- =========================================================
create table saves (
  user_id    uuid references auth.users(id) on delete cascade,
  venue_id   uuid references venues(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, venue_id)
);

-- =========================================================
-- Venue suggestions (users nominate missing bars)
-- =========================================================
create table venue_suggestions (
  id           uuid primary key default gen_random_uuid(),
  suggested_by uuid references auth.users(id),
  name         text not null,
  address      text,
  location     geography(point, 4326),
  notes        text,
  status       text default 'new',
  created_at   timestamptz default now()
);

-- =========================================================
-- Helper: is the current user a manager of this venue?
-- =========================================================
create or replace function is_venue_manager(v uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from venue_managers
    where venue_id = v and user_id = auth.uid()
  );
$$;

-- =========================================================
-- RLS
-- =========================================================
alter table profiles          enable row level security;
alter table venues            enable row level security;
alter table venue_schedules   enable row level security;
alter table menu_items        enable row level security;
alter table venue_managers    enable row level security;
alter table claim_requests    enable row level security;
alter table saves             enable row level security;
alter table venue_suggestions enable row level security;

-- profiles: anyone can read; you can only edit your own
create policy "profiles read"   on profiles for select using (true);
create policy "profiles update" on profiles for update using (auth.uid() = id);

-- venues: public can read published; managers can read+update theirs
create policy "venues public read" on venues for select
  using (is_published or is_venue_manager(id));
create policy "venues manager update" on venues for update
  using (is_venue_manager(id));
-- (inserts handled by admin/seed; no public insert policy)

-- schedules: public can read schedules for published venues; managers full control
create policy "schedules public read" on venue_schedules for select
  using (
    is_venue_manager(venue_id)
    or exists (select 1 from venues v where v.id = venue_id and v.is_published)
  );
create policy "schedules manager write" on venue_schedules for all
  using (is_venue_manager(venue_id))
  with check (is_venue_manager(venue_id));

-- menu items: same logic, gated through schedule -> venue
create policy "menu public read" on menu_items for select
  using (
    exists (
      select 1 from venue_schedules s
      join venues v on v.id = s.venue_id
      where s.id = schedule_id and (v.is_published or is_venue_manager(v.id))
    )
  );
create policy "menu manager write" on menu_items for all
  using (
    exists (
      select 1 from venue_schedules s
      where s.id = schedule_id and is_venue_manager(s.venue_id)
    )
  )
  with check (
    exists (
      select 1 from venue_schedules s
      where s.id = schedule_id and is_venue_manager(s.venue_id)
    )
  );

-- venue_managers: a user can see their own assignments
create policy "managers read own" on venue_managers for select
  using (user_id = auth.uid());

-- claim_requests: user can create + view their own; admin review handled out-of-band
create policy "claims insert own" on claim_requests for insert
  with check (user_id = auth.uid());
create policy "claims read own" on claim_requests for select
  using (user_id = auth.uid());

-- saves: full control over own rows only
create policy "saves read own"   on saves for select using (user_id = auth.uid());
create policy "saves insert own" on saves for insert with check (user_id = auth.uid());
create policy "saves delete own" on saves for delete using (user_id = auth.uid());

-- suggestions: anyone signed in can submit; only the submitter can read theirs
create policy "suggestions insert own" on venue_suggestions for insert
  with check (suggested_by = auth.uid());
create policy "suggestions read own" on venue_suggestions for select
  using (suggested_by = auth.uid());

-- =========================================================
-- updated_at trigger for venues
-- =========================================================
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger venues_touch
  before update on venues
  for each row execute function touch_updated_at();
