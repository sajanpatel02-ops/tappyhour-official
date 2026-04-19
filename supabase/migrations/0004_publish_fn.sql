-- publish_schedule(venue_id, payload)
-- Replaces all schedules + menu items for a venue atomically.
--
-- payload shape:
-- [
--   { "day":"fri", "start":"15:00", "end":"19:00", "headline":"…",
--     "items":[ {"name":"…","normal":14,"deal":6}, ... ] },
--   ...
-- ]
--
-- SECURITY DEFINER so we can do a single transactional wipe-and-replace.
-- TODO(auth): once Sign in with Apple/Google is wired, uncomment the manager
-- check below so only assigned managers can publish.

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
  -- TODO(auth):
  -- if not is_venue_manager(p_venue_id) then
  --   raise exception 'Not a manager of this venue';
  -- end if;

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
end;
$$;

grant execute on function publish_schedule(uuid, jsonb) to anon, authenticated;
