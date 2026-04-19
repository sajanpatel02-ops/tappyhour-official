-- Role model:
--   app_admin (is_admin=true on profiles): can add any venue, manage any venue
--   venue_manager (row in venue_managers): can edit/publish their assigned venues
--   everyone else: read-only
--
-- To promote yourself:
--   update profiles set is_admin = true where id = '<your auth uid>';
-- Find your uid under Supabase → Authentication → Users.

alter table profiles add column if not exists is_admin boolean default false;

create or replace function is_app_admin()
returns boolean language sql stable security definer as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false);
$$;

-- Tighten create_venue: only admins can add venues.
-- (Managers don't self-service — they're assigned to existing venues.)
create or replace function create_venue(
  p_name         text,
  p_short_name   text,
  p_cuisine      text,
  p_vibe         text,
  p_neighborhood text,
  p_price_tier   int,
  p_address      text,
  p_phone        text,
  p_website      text,
  p_lat          double precision,
  p_lng          double precision
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v uuid;
begin
  if not is_app_admin() then
    raise exception 'Only app admins can add venues';
  end if;

  insert into venues (
    name, short_name, cuisine, vibe, neighborhood,
    price_tier, address, phone, website,
    location, is_published
  ) values (
    p_name, coalesce(nullif(p_short_name,''), p_name),
    nullif(p_cuisine,''), nullif(p_vibe,''), nullif(p_neighborhood,''),
    coalesce(p_price_tier, 2),
    nullif(p_address,''), nullif(p_phone,''), nullif(p_website,''),
    st_geogfromtext('POINT(' || p_lng || ' ' || p_lat || ')'),
    false
  ) returning id into v;

  -- Auto-assign the creating admin as owner of the new venue so they can publish its first schedule.
  insert into venue_managers (venue_id, user_id, role)
  values (v, auth.uid(), 'owner')
  on conflict do nothing;

  return v;
end;
$$;

-- Tighten publish_schedule: only admins or assigned managers of this venue.
create or replace function publish_schedule(p_venue_id uuid, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  day_row  jsonb;
  item_row jsonb;
  s_id     uuid;
  i        int;
begin
  if not (is_app_admin() or is_venue_manager(p_venue_id)) then
    raise exception 'Not authorized to publish this venue';
  end if;

  delete from venue_schedules where venue_id = p_venue_id;

  for day_row in select * from jsonb_array_elements(p_payload) loop
    insert into venue_schedules (venue_id, day, start_time, end_time, headline)
    values (
      p_venue_id,
      (day_row->>'day')::day_key,
      (day_row->>'start')::time,
      (day_row->>'end')::time,
      day_row->>'headline'
    )
    returning id into s_id;

    i := 0;
    for item_row in select * from jsonb_array_elements(coalesce(day_row->'items','[]'::jsonb)) loop
      insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order)
      values (
        s_id,
        item_row->>'name',
        (item_row->>'normal')::numeric,
        (item_row->>'deal')::numeric,
        i
      );
      i := i + 1;
    end loop;
  end loop;

  update venues
     set is_published = (select count(*) > 0 from venue_schedules where venue_id = p_venue_id),
         updated_at = now()
   where id = p_venue_id;
end;
$$;

-- Convenience: returns the venue ids the current user can manage
-- (all of them if admin, else just their assignments).
create or replace function my_managed_venue_ids()
returns setof uuid
language sql stable security definer
set search_path = public
as $$
  select id from venues where is_app_admin()
  union
  select venue_id from venue_managers where user_id = auth.uid();
$$;

grant execute on function my_managed_venue_ids() to anon, authenticated;
grant execute on function is_app_admin() to anon, authenticated;
