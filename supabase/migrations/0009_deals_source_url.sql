-- Store the URL that an admin used to extract happy hour info.
-- Shown as a "View menu online" link on the venue detail so users can
-- verify the source themselves.

alter table venues add column if not exists deals_source_url text;

create or replace function set_deals_source_url(p_venue_id uuid, p_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_app_admin() or is_venue_manager(p_venue_id)) then
    raise exception 'Not authorized to set deals source for this venue';
  end if;
  update venues set deals_source_url = nullif(trim(p_url), '') where id = p_venue_id;
end;
$$;

grant execute on function set_deals_source_url(uuid, text) to anon, authenticated;
