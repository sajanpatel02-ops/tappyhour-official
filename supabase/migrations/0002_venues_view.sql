-- View that exposes lat/lng as plain columns so the Swift client can decode them.
-- PostGIS geography columns return as binary; this unwraps them.
create or replace view venues_with_latlng as
select
  v.*,
  st_y(v.location::geometry) as lat,
  st_x(v.location::geometry) as lng
from venues v;

-- The view inherits RLS from the underlying table.
alter view venues_with_latlng set (security_invoker = true);
