-- Seed: 8 Chicago venues from the iOS sample data.
-- Idempotent enough for a dev environment: truncates first.

truncate table menu_items, venue_schedules, venues restart identity cascade;

-- Helper: insert a venue and return its id
-- We use deterministic UUIDs via md5 so re-seeding produces stable ids.
do $$
declare
  v1 uuid := gen_random_uuid();
  v2 uuid := gen_random_uuid();
  v3 uuid := gen_random_uuid();
  v4 uuid := gen_random_uuid();
  v5 uuid := gen_random_uuid();
  v6 uuid := gen_random_uuid();
  v7 uuid := gen_random_uuid();
  v8 uuid := gen_random_uuid();
  s  uuid;
begin

-- ============================================================
-- v1 The Copper Jug — West Loop
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v1, 'The Copper Jug', 'Copper Jug', 'American', 'Cozy', 'West Loop', 2,
        4.6, 842, array['Cocktails','Beer'],
        st_geogfromtext('POINT(-87.6479 41.8825)'), true);

-- Mon-Thu base + Fri extended
insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v1, 'mon', '15:00', '18:00', '$6 old fashioneds, $4 drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Old Fashioned', 14, 6, 0),
  (s, 'Draft Beer (16oz)', 8, 4, 1),
  (s, 'House Red / White', 13, 7, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v1, 'tue', '15:00', '18:00', '$6 old fashioneds, $4 drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Old Fashioned', 14, 6, 0),
  (s, 'Draft Beer (16oz)', 8, 4, 1),
  (s, 'House Red / White', 13, 7, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v1, 'wed', '15:00', '18:00', 'Whiskey Wednesday — $5 pours') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Rye Pour (1oz)', 12, 5, 0),
  (s, 'Bourbon Pour (1oz)', 13, 5, 1),
  (s, 'Whiskey Sour', 14, 7, 2),
  (s, 'Draft Beer (16oz)', 8, 4, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v1, 'thu', '15:00', '18:00', '$6 old fashioneds, $4 drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Old Fashioned', 14, 6, 0),
  (s, 'House Martini', 15, 8, 1),
  (s, 'Draft Beer (16oz)', 8, 4, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v1, 'fri', '15:00', '19:00', 'Friday happy hour — extra hour') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Old Fashioned', 14, 6, 0),
  (s, 'House Martini', 15, 8, 1),
  (s, 'Draft Beer (16oz)', 8, 4, 2),
  (s, 'House Red / White', 13, 7, 3),
  (s, 'Bourbon Highball', 12, 6, 4);

-- ============================================================
-- v2 Fulton & Fig — Fulton Market
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v2, 'Fulton & Fig', 'Fulton & Fig', 'Mediterranean', 'Date night', 'Fulton Market', 3,
        4.8, 1204, array['Wine','Cocktails'],
        st_geogfromtext('POINT(-87.6498 41.8866)'), true);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v2, 'tue', '16:00', '18:30', 'Half-off wine by the glass') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Natural Wine (glass)', 16, 8, 0),
  (s, 'Spritz of the Day', 14, 9, 1),
  (s, 'Prosecco', 12, 6, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v2, 'wed', '16:00', '18:30', 'Half-off wine by the glass') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Natural Wine (glass)', 16, 8, 0),
  (s, 'Spritz of the Day', 14, 9, 1),
  (s, 'Prosecco', 12, 6, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v2, 'thu', '16:00', '18:30', 'Industry Night — half-off all') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Natural Wine (glass)', 16, 8, 0),
  (s, 'Negroni Bianco', 15, 7, 1),
  (s, 'Prosecco', 12, 6, 2),
  (s, 'Amaro Pour', 11, 5, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v2, 'fri', '16:00', '18:30', 'Half-off wine by the glass') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Natural Wine (glass)', 16, 8, 0),
  (s, 'Spritz of the Day', 14, 9, 1),
  (s, 'Negroni Bianco', 15, 9, 2),
  (s, 'Prosecco', 12, 6, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v2, 'sat', '15:00', '17:00', 'Rosé hour — $7 glasses') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Rosé (glass)', 14, 7, 0),
  (s, 'Prosecco', 12, 6, 1);

-- ============================================================
-- v3 Lower East Tap — River North (every day)
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v3, 'Lower East Tap', 'Lower East Tap', 'Pub', 'Lively', 'River North', 1,
        4.3, 562, array['Beer'],
        st_geogfromtext('POINT(-87.6325 41.8905)'), true);

insert into venue_schedules (venue_id, day, start_time, end_time, headline)
select v3, d::day_key, '16:00'::time, '19:00'::time, '$3 drafts, $5 well drinks'
from unnest(array['mon','tue','wed','thu','fri','sat','sun']) as d;

insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order)
select s.id, m.name, m.normal_price, m.deal_price, m.sort_order
from venue_schedules s
cross join (values
  ('Domestic Draft', 7, 3, 0),
  ('Craft Draft', 9, 5, 1),
  ('Well Cocktail', 10, 5, 2),
  ('Shot & a Beer', 12, 7, 3)
) as m(name, normal_price, deal_price, sort_order)
where s.venue_id = v3;

-- ============================================================
-- v4 Maison Verre — West Loop
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v4, 'Maison Verre', 'Maison Verre', 'French', 'Date night', 'West Loop', 3,
        4.7, 918, array['Wine','Cocktails'],
        st_geogfromtext('POINT(-87.6462 41.8810)'), true);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v4, 'wed', '17:00', '19:00', '$9 champagne, $10 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Champagne (glass)', 18, 9, 0),
  (s, 'Gin Martini', 16, 10, 1),
  (s, 'Vermouth Spritz', 13, 8, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v4, 'thu', '17:00', '19:00', '$9 champagne, $10 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Champagne (glass)', 18, 9, 0),
  (s, 'Gin Martini', 16, 10, 1),
  (s, 'Vermouth Spritz', 13, 8, 2),
  (s, 'Kir Royale', 14, 9, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v4, 'fri', '17:00', '19:00', '$9 champagne, $10 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Champagne (glass)', 18, 9, 0),
  (s, 'Gin Martini', 16, 10, 1),
  (s, 'Vermouth Spritz', 13, 8, 2),
  (s, 'Kir Royale', 14, 9, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v4, 'sat', '17:00', '19:00', '$9 champagne, $10 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Champagne (glass)', 18, 9, 0),
  (s, 'Gin Martini', 16, 10, 1),
  (s, 'Kir Royale', 14, 9, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v4, 'sun', '15:00', '17:00', 'Sunday aperitif — $8 spritzes') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Aperol Spritz', 14, 8, 0),
  (s, 'Vermouth Spritz', 13, 8, 1);

-- ============================================================
-- v5 Smokehouse 312 — Wicker Park
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v5, 'Smokehouse 312', 'Smokehouse', 'BBQ', 'Lively', 'Wicker Park', 2,
        4.5, 1340, array['Beer','Cocktails'],
        st_geogfromtext('POINT(-87.6779 41.9081)'), true);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v5, 'mon', '15:30', '18:00', '$5 whiskey, $4 local drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'House Whiskey', 11, 5, 0),
  (s, 'Local IPA', 8, 4, 1),
  (s, 'Boilermaker', 12, 6, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v5, 'tue', '15:30', '18:00', '$5 whiskey, $4 local drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'House Whiskey', 11, 5, 0),
  (s, 'Local IPA', 8, 4, 1),
  (s, 'Boilermaker', 12, 6, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v5, 'wed', '15:30', '18:00', '$5 whiskey, $4 local drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'House Whiskey', 11, 5, 0),
  (s, 'Local IPA', 8, 4, 1),
  (s, 'Whiskey Sour', 13, 7, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v5, 'thu', '15:30', '18:00', '$5 whiskey, $4 local drafts') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'House Whiskey', 11, 5, 0),
  (s, 'Local IPA', 8, 4, 1),
  (s, 'Whiskey Sour', 13, 7, 2),
  (s, 'Boilermaker', 12, 6, 3);

-- ============================================================
-- v6 Atlas Rooftop — River North (every day)
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v6, 'Atlas Rooftop', 'Atlas', 'New American', 'Rooftop', 'River North', 3,
        4.4, 2107, array['Cocktails','Wine'],
        st_geogfromtext('POINT(-87.6318 41.8928)'), true);

insert into venue_schedules (venue_id, day, start_time, end_time, headline)
select v6, d::day_key, '16:00'::time, '18:00'::time, '$8 signature cocktails'
from unnest(array['mon','tue','wed','thu','fri','sat','sun']) as d;

insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order)
select s.id, m.name, m.normal_price, m.deal_price, m.sort_order
from venue_schedules s
cross join (values
  ('Paloma del Sol', 16, 8, 0),
  ('Smoked Manhattan', 17, 8, 1),
  ('Lychee Martini', 16, 8, 2),
  ('Rosé (glass)', 14, 7, 3)
) as m(name, normal_price, deal_price, sort_order)
where s.venue_id = v6;

-- ============================================================
-- v7 The Green Room — Logan Square
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v7, 'The Green Room', 'Green Room', 'Cocktail bar', 'Cozy', 'Logan Square', 2,
        4.9, 486, array['Cocktails','Beer'],
        st_geogfromtext('POINT(-87.7046 41.9215)'), true);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'tue', '17:00', '19:00', '$7 classics, $5 beer') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Daiquiri', 13, 7, 1), (s, 'Lager', 8, 5, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'wed', '17:00', '19:00', '$7 classics, $5 beer') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Daiquiri', 13, 7, 1), (s, 'Lager', 8, 5, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'thu', '17:00', '19:00', '$7 classics, $5 beer') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Daiquiri', 13, 7, 1),
  (s, 'Tiki Punch', 15, 8, 2), (s, 'Lager', 8, 5, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'fri', '17:00', '19:00', '$7 classics, $5 beer') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Daiquiri', 13, 7, 1),
  (s, 'Tiki Punch', 15, 8, 2), (s, 'Lager', 8, 5, 3);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'sat', '17:00', '19:00', 'Late night — 10pm–midnight') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Lager', 8, 5, 1);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v7, 'sun', '17:00', '19:00', '$7 classics, $5 beer') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Negroni', 14, 7, 0), (s, 'Daiquiri', 13, 7, 1);

-- ============================================================
-- v8 Pier & Pine — Streeterville
-- ============================================================
insert into venues (id, name, short_name, cuisine, vibe, neighborhood, price_tier,
                    rating, reviews_count, tags, location, is_published)
values (v8, 'Pier & Pine', 'Pier & Pine', 'Seafood', 'Date night', 'Streeterville', 3,
        4.5, 773, array['Wine','Cocktails'],
        st_geogfromtext('POINT(-87.6208 41.8918)'), true);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v8, 'mon', '15:00', '18:00', '$6 oysters, $9 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Dirty Martini', 16, 9, 0), (s, 'Sauv Blanc (glass)', 15, 8, 1);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v8, 'tue', '15:00', '18:00', '$6 oysters, $9 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Dirty Martini', 16, 9, 0), (s, 'Aperol Spritz', 14, 8, 1), (s, 'Sauv Blanc (glass)', 15, 8, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v8, 'wed', '15:00', '18:00', '$6 oysters, $9 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Dirty Martini', 16, 9, 0), (s, 'Aperol Spritz', 14, 8, 1), (s, 'Sauv Blanc (glass)', 15, 8, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v8, 'thu', '15:00', '18:00', '$6 oysters, $9 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Dirty Martini', 16, 9, 0), (s, 'Aperol Spritz', 14, 8, 1), (s, 'Sauv Blanc (glass)', 15, 8, 2);

insert into venue_schedules (id, venue_id, day, start_time, end_time, headline)
values (gen_random_uuid(), v8, 'fri', '15:00', '18:00', '$6 oysters, $9 martinis') returning id into s;
insert into menu_items (schedule_id, name, normal_price, deal_price, sort_order) values
  (s, 'Dirty Martini', 16, 9, 0), (s, 'Aperol Spritz', 14, 8, 1), (s, 'Sauv Blanc (glass)', 15, 8, 2);

end $$;
