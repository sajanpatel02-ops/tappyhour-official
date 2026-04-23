-- Rate-limit venue_suggestions inserts: a single user can submit at most
-- 5 suggestions in any rolling 60-minute window. Prevents trivial spam
-- that would bloat the DB on the free tier.
--
-- Enforced server-side so a malicious client can't bypass it by calling
-- PostgREST directly.

create or replace function enforce_suggestion_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count int;
begin
  -- Service-role / admin inserts (suggested_by null or an admin user) skip
  -- the check so you can backfill or bulk-create without tripping it.
  if new.suggested_by is null or is_app_admin() then
    return new;
  end if;

  select count(*) into recent_count
  from venue_suggestions
  where suggested_by = new.suggested_by
    and created_at > now() - interval '1 hour';

  if recent_count >= 5 then
    raise exception 'Too many requests — please wait before submitting more (limit: 5 per hour).'
      using errcode = '42901';  -- custom, maps to 400-ish in PostgREST
  end if;

  return new;
end;
$$;

drop trigger if exists venue_suggestions_rate_limit on venue_suggestions;
create trigger venue_suggestions_rate_limit
  before insert on venue_suggestions
  for each row execute function enforce_suggestion_rate_limit();
