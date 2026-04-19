-- Make the new-user trigger defensive:
-- 1) Coalesce all optional fields so null email/meta doesn't crash.
-- 2) Swallow any downstream error so auth signup never fails because of a profile insert.
--    (Profile can be backfilled later; what matters is the auth.users row gets created.)

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into profiles (id, display_name)
    values (
      new.id,
      coalesce(
        new.raw_user_meta_data->>'name',
        new.raw_user_meta_data->>'full_name',
        nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
        'User'
      )
    )
    on conflict (id) do nothing;
  exception when others then
    raise warning 'handle_new_user failed for %: %', new.id, sqlerrm;
  end;
  return new;
end;
$$;
