-- User-submitted "this venue's happy hour looks outdated" reports.
-- Lets signed-in users flag stale data so admins know what to refresh.

create table if not exists venue_reports (
  id           uuid primary key default gen_random_uuid(),
  venue_id     uuid not null references venues(id) on delete cascade,
  reported_by  uuid not null references auth.users(id),
  note         text,
  resolved     boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists venue_reports_venue_idx on venue_reports (venue_id);
create index if not exists venue_reports_reporter_idx on venue_reports (reported_by);

alter table venue_reports enable row level security;

-- A user may insert a report as themselves.
create policy "venue_reports insert own" on venue_reports for insert
  with check (reported_by = auth.uid());

-- A user may read their own reports. Admins may read all.
create policy "venue_reports read own" on venue_reports for select
  using (reported_by = auth.uid() or is_app_admin());

-- Only admins may mark reports resolved / delete them.
create policy "venue_reports admin update" on venue_reports for update
  using (is_app_admin());
create policy "venue_reports admin delete" on venue_reports for delete
  using (is_app_admin());

-- One report per (user, venue) per 24 hours. Prevents spam and accidental
-- double-taps from flooding the table.
create or replace function enforce_venue_report_dedupe()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count int;
begin
  if is_app_admin() then
    return new;
  end if;
  select count(*) into recent_count
  from venue_reports
  where reported_by = new.reported_by
    and venue_id = new.venue_id
    and created_at > now() - interval '24 hours';
  if recent_count >= 1 then
    raise exception 'You already reported this venue recently.'
      using errcode = '42901';
  end if;
  return new;
end;
$$;

drop trigger if exists venue_reports_dedupe on venue_reports;
create trigger venue_reports_dedupe
  before insert on venue_reports
  for each row execute function enforce_venue_report_dedupe();
