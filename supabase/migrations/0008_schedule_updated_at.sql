-- Track when a venue's happy hour schedule was last published.
-- Exposed to the client so the app can show "Updated 3 days ago".

alter table venues
  add column if not exists schedule_updated_at timestamptz;

-- Backfill: existing published venues get "now" so they aren't shown as stale.
update venues
   set schedule_updated_at = now()
 where schedule_updated_at is null
   and is_published = true;

-- Stamp schedule_updated_at inside publish_schedule. Keep existing behavior
-- (auth check, wipe-and-replace, flip is_published true).
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
    raise exception 'Not authorized to publish schedule for this venue';
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
     set is_published = true,
         schedule_updated_at = now()
   where id = p_venue_id;
end;
$$;

grant execute on function publish_schedule(uuid, jsonb) to anon, authenticated;
