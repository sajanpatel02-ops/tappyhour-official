-- User favorites: signed-in users mark bars they care about.
-- Required by the in-app filter chip's "Favorites" option and the map pin
-- treatment for saved venues.

create table if not exists user_favorites (
  user_id    uuid not null references auth.users(id) on delete cascade,
  venue_id   uuid not null references venues(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, venue_id)
);

create index if not exists user_favorites_user_idx on user_favorites (user_id);

alter table user_favorites enable row level security;

-- Explicit grants — Supabase's auto-grant on public-schema tables isn't
-- universal, and without these the RLS policies have no effect.
grant select, insert, delete on user_favorites to authenticated;

-- Users can only read/write their own favorites. anon role has no access.
create policy "own favorites select" on user_favorites
  for select using (auth.uid() = user_id);

create policy "own favorites insert" on user_favorites
  for insert with check (auth.uid() = user_id);

create policy "own favorites delete" on user_favorites
  for delete using (auth.uid() = user_id);
