-- Allow menu items to express non-numeric deals like "50% off" or "$6-$12".
-- Previously we forced normal_price + deal_price to be numbers; now items
-- can have a free-form label INSTEAD of prices.

alter table menu_items
  alter column normal_price drop not null,
  alter column deal_price   drop not null,
  add column if not exists label text;

-- Rewrite publish_schedule to pass label through + accept nullable prices.
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
      insert into menu_items (schedule_id, name, normal_price, deal_price, label, sort_order)
      values (
        s_id,
        item_row->>'name',
        nullif(item_row->>'normal','')::numeric,
        nullif(item_row->>'deal','')::numeric,
        nullif(trim(coalesce(item_row->>'label','')), ''),
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
