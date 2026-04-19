-- create_venue: inserts a new venue (unpublished) and returns its id.
-- The venue is flipped to is_published = true the first time publish_schedule
-- writes at least one day to it.
--
-- SECURITY DEFINER during dev so the app can create without auth.
-- TODO(auth): restrict to authenticated users, and record created_by.

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
  return v;
end;
$$;

grant execute on function create_venue(
  text, text, text, text, text, int, text, text, text, double precision, double precision
) to anon, authenticated;

-- Make publish_schedule also flip is_published so new venues appear after first publish.
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
