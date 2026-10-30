-- =====================================================================
-- X Replica: demo data (fictional accounts + posts)
--
-- Run this ONCE in the Supabase SQL editor, after schema.sql, so the
-- feed, Explore, search and "Who to follow" are not empty.
--
--  * Every account here is FICTIONAL. Names, teams, cities, bills and
--    stories are invented; none of it is a real person or real news.
--  * Avatars come from api.dicebear.com. Photos (post pictures, profile
--    headers, community and list pictures) are real photos from Wikimedia
--    Commons, each picked to match the caption it sits under (see seed_img
--    below). Videos are short free stock clips from mixkit.co (H.264 mp4,
--    picked to match the caption). The phone needs internet to show them.
--    The video posts need the posts.video_url column: run schema.sql
--    (section 13) BEFORE this file.
--  * Safe to run again: it first removes the previous demo data (every
--    user whose e-mail ends with @seed.xreplica.test) and creates it
--    fresh, so the post times are "recent" again.
--  * Real accounts are never touched.
--
-- To follow all demo accounts with your own account, see the last lines.
-- =====================================================================

begin;
select setseed(0.4242);

-- ---------------------------------------------------------------------
-- 0. Remove an earlier run (profiles, posts, likes, ... cascade).
-- ---------------------------------------------------------------------
delete from auth.users where email like '%@seed.xreplica.test';

-- ---------------------------------------------------------------------
-- 1. The accounts
-- ---------------------------------------------------------------------
create temp table seed_people (
  handle    text primary key,
  name      text not null,
  bio       text not null,
  verified  text,
  label     text,
  interests text[] not null,
  tier      int  not null   -- 1 (small) .. 5 (huge): how many likes it gets
) on commit drop;

insert into seed_people (handle, name, bio, verified, label, interests, tier) values
-- Athletes
('marcovaldez_',   'Marco Valdez',       $$Point guard, Manila Hoopers. 2x All-Star. Dad. Kape first, basketball second. 🏀$$, 'blue', null, '{sports}', 5),
('sofia_strikes',  'Sofia Lindqvist',    $$Striker for Northgate FC and the national team. Goals, tea and long walks with my dog.$$, 'blue', null, '{sports,travel}', 4),
('kai_okonkwo',    'Kai Okonkwo',        $$Heavyweight boxer. 19-1. Training camp never ends. 🥊$$, 'blue', null, '{sports,health}', 4),
('jasmine_serve',  'Jasmine Tan',        $$Pro tennis player. World No. 14. Chasing the next Grand Slam one point at a time.$$, 'blue', null, '{sports,fashion}', 4),
('rheaplays',      'Rhea Dizon',         $$Pro esports player for Vanta Gaming. Duelist main. Streaming most nights.$$, 'blue', null, '{games,sports}', 3),
-- Musicians
('lunaveil',       'Luna Veil',          $$Singer-songwriter. New album "Paper Lanterns" is out now ✨$$, 'blue', null, '{music,entertainment}', 5),
('nightbloom_mx',  'Nightbloom',         $$Indie band from Cebu. Four friends, too many pedals. Booking: hello@nightbloom.example$$, null, null, '{music}', 3),
('djkaizen',       'DJ Kaizen',          $$Producer / DJ. House, garage and the occasional bad idea. Residency every Friday.$$, 'blue', null, '{music,entertainment}', 3),
('tonyreyes_opm',  'Tony Reyes',         $$OPM singer-songwriter. Mga kantang pang-jeep at pang-heartbreak. 🎸$$, 'blue', null, '{music,entertainment}', 4),
('astralis_hq',    'ASTRALIS',           $$Official account of ASTRALIS, the 7-member group. Comeback "ORBIT" is here.$$, 'gold', null, '{music,entertainment}', 5),
-- Actors, creators, comedians
('diegomontero',   'Diego Montero',      $$Actor. Currently filming. Please stop asking about the ending of the series.$$, 'blue', null, '{movies,entertainment}', 5),
('mikaelasy_film', 'Mikaela Sy',         $$Film director. Making small movies about big feelings. Premiere at the Harbor Film Festival.$$, 'blue', null, '{movies}', 3),
('jokerjules',     'Jules Banner',       $$Stand-up comedian. Touring. Yes, the airport jokes are all true.$$, 'blue', null, '{memes,entertainment}', 4),
('chefandrea',     'Chef Andrea Cruz',   $$Chef and cookbook author. Filipino food, but make it fun. Recipes every week.$$, 'blue', null, '{food}', 3),
('gymwithgabe',    'Gabe Santos',        $$Strength coach. Free workouts here, form checks in the replies. Consistency > motivation.$$, null, null, '{health}', 3),
('wanderlenka',    'Lenka Novak',        $$Travel creator. 61 countries and one very patient backpack. 🌏$$, null, null, '{travel}', 3),
('pixelpaolo',     'Paolo Dela Rosa',    $$Variety streamer. Cozy games, horror games and very loud reactions.$$, null, null, '{games,memes}', 3),
-- Artists
('inkbyisla',      'Isla Moreno',        $$Illustrator. Ink, watercolor and too many cats. Commissions open.$$, null, null, '{entertainment}', 2),
('muralmarcus',    'Marcus Bell',        $$Street artist. If a wall looks empty, I get ideas.$$, null, null, '{entertainment}', 2),
('frames_by_noa',  'Noa Hirsch',         $$Photographer. Light chaser. Prints in bio link.$$, null, null, '{travel,entertainment}', 2),
-- Politics and government (fictional city and country)
('mayor_elena',    'Mayor Elena Ramos',  $$Mayor of Port Alder. Public servant. Office hours every Friday at City Hall.$$, 'gray', null, '{politics,news}', 4),
('sen_marlonvega', 'Sen. Marlon Vega',   $$Senator. Education and transport committees. Posts are my own.$$, 'gray', null, '{politics,news}', 3),
('portalder_gov',  'City of Port Alder', $$Official account of the City of Port Alder. Service advisories, events and updates.$$, 'gray', null, '{politics,news}', 3),
-- Media and organisations
('dailybulletin',  'The Daily Bulletin', $$Independent news. Breaking news, headlines and reports from across the country.$$, 'gold', null, '{news,politics}', 5),
('courtsidenow',   'Courtside Now',      $$Scores, trades and takes. Your home for basketball and football.$$, 'gold', null, '{sports}', 4),
('techbrief_ph',   'TechBrief',          $$Tech news in plain language. Software, gadgets and startups.$$, 'gold', null, '{technology,business}', 3),
-- Experts and commentators
('drnadia_sci',    'Dr. Nadia Rahman',   $$Climate scientist. Explaining the research so you do not have to read 40 pages. Opinions my own.$$, 'blue', null, '{health,technology}', 3),
('startupsam',     'Sam Ortega',         $$Founder, 2 startups (1 survived). Writing about business, finance and building things.$$, 'blue', null, '{business,technology}', 3),
('coinwatchdaily', 'Coin Watch',         $$Daily crypto and market notes. Not financial advice. Do your own research.$$, null, 'commentary', '{crypto,business}', 3),
('memelord_ph',    'Certified Memelord', $$Posting memes until the algorithm gives up. DM for credit removal.$$, null, null, '{memes}', 5),
('bianca_ootd',    'Bianca Ferrer',      $$Fashion and style. Outfit of the day, thrift finds, sustainable brands.$$, null, null, '{fashion}', 3),
('cinemanotes',    'Cinema Notes',       $$Movie and series reviews. Spoilers always tagged. Fan commentary account.$$, null, 'commentary', '{movies}', 3),
('jo_mercado_dev', 'Jo Mercado',         $$Flutter developer. Learning in public: coding, software and a lot of widgets.$$, null, null, '{technology}', 2),
('kpopdaily_ph',   'K-Pop Daily PH',     $$Fan account for K-pop news in the Philippines. Not affiliated with any agency.$$, null, 'fan', '{entertainment,music}', 3);

-- More accounts (second batch): everyday creators, small businesses, a
-- barangay captain, a weather service, and so on.
insert into seed_people (handle, name, bio, verified, label, interests, tier) values
('coachramon', $$Coach Ramon Estrada$$, $$College basketball coach. Fundamentals first, highlights later. Sunday family lunch is non-negotiable.$$, null, null, '{sports}', 2),
('speedyselene', $$Selene Park$$, $$Marathoner. 2:41 PB. Running is cheaper than therapy and the view is better. 🏃‍♀️$$, 'blue', null, '{sports,health}', 3),
('harana_hub', $$Harana Hub$$, $$Acoustic nights and open mics for OPM artists. Every Thursday, every genre, every heartbreak.$$, 'gold', null, '{music,entertainment}', 2),
('beatsbyrio', $$Rio Fernandez$$, $$Beatmaker from Quezon City. Lo-fi, boom bap and sampled jeepney horns.$$, null, null, '{music}', 2),
('violetsessions', $$Violet Sessions$$, $$Live studio sessions from Manila's best new artists. One take, no autotune.$$, 'gold', null, '{music,entertainment}', 3),
('serieswithsam', $$Sam & Series$$, $$Reviewing what you're binge-watching. Spoiler-free until I say so. Fan commentary account.$$, null, 'commentary', '{movies,entertainment}', 3),
('animeatlas', $$Anime Atlas$$, $$Seasonal anime guides, news and memes. Fan account, not affiliated with any studio.$$, null, 'fan', '{entertainment,games}', 3),
('streetfoodmnl', $$Street Food Manila$$, $$Kwek-kwek, isaw, taho and everything in between. Rating Manila one stick at a time. 🍢$$, null, null, '{food,travel}', 3),
('bakerbea', $$Bea Alcantara$$, $$Home baker. Ube everything. Orders open every first Monday of the month.$$, null, null, '{food}', 2),
('roamingrafael', $$Rafael Quiambao$$, $$Weekend hiker. 23 mountains in the Philippines so far. Leave no trace, take lots of photos.$$, null, null, '{travel,health}', 2),
('islandhopper_ph', $$Island Hopper PH$$, $$Budget island itineraries across the Philippines. Boat schedules, fees and honest reviews.$$, null, null, '{travel}', 2),
('devdaniela', $$Daniela Cruz$$, $$Software engineer. Mobile, backend and too many side projects. Posts about code, coffee and imposter syndrome.$$, 'blue', null, '{technology}', 3),
('gadgetgus', $$Gadget Gus$$, $$Phone and gadget reviews. No sponsors can change my score. Battery life is a personality trait.$$, null, null, '{technology}', 3),
('aiweekly_ph', $$AI Weekly PH$$, $$A weekly digest of AI news for Filipino developers and curious humans.$$, 'gold', null, '{technology,news}', 3),
('financewithfe', $$Fe Navarro$$, $$Personal finance for first-jobbers. Budgets, emergency funds and index funds, explained slowly. Not financial advice.$$, 'blue', null, '{business}', 3),
('smallbizsari', $$Sari-Sari Startup$$, $$Helping small stores go digital, one QR code at a time. Tips for tindahan and online sellers.$$, null, null, '{business}', 2),
('dr_miguel_md', $$Dr. Miguel Tan$$, $$Family physician. Plain-language health tips. This is general information, not medical advice for your case.$$, 'blue', null, '{health}', 3),
('yogawithyna', $$Yna Villareal$$, $$Yoga teacher. Slow mornings, deep breaths and stretching videos you can do in a small room. 🧘$$, null, null, '{health}', 2),
('thriftkingjay', $$Jay Aquino$$, $$Ukay-ukay hunter. Hauls, styling and honest price checks. Style is cheaper than you think.$$, null, null, '{fashion}', 2),
('tito_memes', $$Tito Boy Memes$$, $$Memes for people who still send good morning messages. Forwarded as received.$$, null, null, '{memes}', 4),
('relatablerina', $$Rina Relatable$$, $$Posting what you were just thinking. Overthinker, snack collector, part-time napper.$$, null, null, '{memes,entertainment}', 3),
('valorantvince', $$Vince Aguirre$$, $$Ranked grinder and coach. Crosshair placement is free. Streaming on weekends.$$, null, null, '{games,sports}', 3),
('retropixelria', $$Ria Retro$$, $$Retro games, handheld mods and pixel art. If it has a cartridge, I want it.$$, null, null, '{games}', 2),
('kap_lito', $$Kap Lito Domingo$$, $$Barangay captain, Brgy. San Roque. Walang tulog para sa kapitbahay. Posts are my own.$$, 'gray', null, '{politics,news}', 2),
('metroweatherph', $$Metro Weather PH$$, $$Daily forecasts and rain alerts for Metro Manila and nearby provinces. Always bring an umbrella. ☔$$, 'gold', null, '{news}', 4),
('teacherjoy', $$Teacher Joy$$, $$Grade 5 teacher. Chalk on my sleeves, stickers in my bag. Classroom stories and tips for new teachers.$$, null, null, '{entertainment}', 2),
('petsofpasig', $$Pets of Pasig$$, $$Cats, dogs and one very confident parrot. Submit your pet in the replies.$$, null, null, '{entertainment,memes}', 3),
('sketchsir_dan', $$Dan Villanueva$$, $$Art teacher and sketchbook addict. Daily doodles and quick tutorials.$$, null, null, '{entertainment}', 2);

-- Background accounts: they only like, repost and follow so the counts
-- look alive. They are not "onboarded", so they never show up in search
-- or in "Who to follow".
create temp table seed_fans (handle text primary key, name text not null) on commit drop;
insert into seed_fans (handle, name)
select left(lower(f.fn) || lower(l.ln), 12) || lpad((f.i * 10 + l.i)::text, 3, '0'),
       f.fn || ' ' || l.ln
from (values (1,'Ana'),(2,'Ben'),(3,'Carla'),(4,'Dante'),(5,'Ella'),(6,'Felix'),(7,'Gina'),(8,'Hugo'),(9,'Iris'),(10,'Joel'),(11,'Kira'),(12,'Leo')) as f(i, fn)
cross join (values (1,'Cruz'),(2,'Reyes'),(3,'Santos'),(4,'Garcia'),(5,'Lim'),(6,'Bautista'),(7,'Navarro'),(8,'Mendoza'),(9,'Flores'),(10,'Ocampo')) as l(i, ln);

-- Accounts (the trigger on auth.users creates the profile rows).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  md5('seed-user:' || handle)::uuid,
  'authenticated', 'authenticated',
  handle || '@seed.xreplica.test',
  '',                                   -- no password: nobody can sign in
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('username', handle, 'display_name', name),
  now() - interval '120 days', now()
from (select handle, name from seed_people union all select handle, name from seed_fans) a;

-- Some Supabase versions need these token columns to be '' instead of NULL
-- (otherwise the Users page of the dashboard can fail to load).
do $$
declare c text;
begin
  for c in
    select column_name from information_schema.columns
    where table_schema = 'auth' and table_name = 'users'
      and column_name in ('confirmation_token', 'recovery_token',
        'email_change_token_new', 'email_change', 'email_change_token_current',
        'phone_change', 'phone_change_token', 'reauthentication_token')
  loop
    execute format('update auth.users set %I = coalesce(%I, '''') where email like %L',
                   c, c, '%@seed.xreplica.test');
  end loop;
end $$;

-- Seed photos. Every picture is chosen by reading the caption it goes with (food posts get food,
-- the Coron budget plan gets Coron, and so on). Photos come from Wikimedia Commons (free licences);
-- see the credits in README.md. A post with no row here simply has no photo.
create temp table seed_img (key text primary key, urls text[] not null) on commit drop;
insert into seed_img (key, urls) values
('mv1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg/960px-Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg']),
('sl2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Dog_waiting_for_his_owners_to_come.jpg/960px-Dog_waiting_for_his_owners_to_come.jpg']),
('ko1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/US_Navy_081011-N-5345W-057_Cryptologic_Technician_Networks_Seaman_Janea_Arrington_connects_with_a_straight_right_to_the_jaw_of_Aviation_Ordnanceman_Airman_Nakita_Boyd_during_a_sparring_session.jpg/960px-thumbnail.jpg']),
('jt2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/HK_Disneyland_Hotel_Room_AM_Dudson_Fine_China_Tea_cups_220V_boiling_water.JPG/960px-HK_Disneyland_Hotel_Room_AM_Dudson_Fine_China_Tea_cups_220V_boiling_water.JPG']),
('rd2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg/960px-Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg']),
('lv1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f8/Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG/960px-Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG']),
('lv3', array['https://upload.wikimedia.org/wikipedia/commons/2/28/LiquidMolly%27s_home_recording_studio_-_overview.jpg']),
('nb1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Beach-Please-2022-crowd-stage-lights-night-performance.jpg/960px-Beach-Please-2022-crowd-stage-lights-night-performance.jpg']),
('dk1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/DJ_booth_with_DJ-Mixer%2C_two_turntables_and_two_CDJ-players_in_former_Bob_Beaman_nightclub_in_Munich.jpg/960px-DJ_booth_with_DJ-Mixer%2C_two_turntables_and_two_CDJ-players_in_former_Bob_Beaman_nightclub_in_Munich.jpg']),
('tr1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Sheri_Miller_-_live_2011.jpg/960px-Sheri_Miller_-_live_2011.jpg']),
('as1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Tochiotome_25_on_stage_20151107.jpg/960px-Tochiotome_25_on_stage_20151107.jpg']),
('as2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Ground_Forces_Festival_2025_-_0096.jpg/960px-Ground_Forces_Festival_2025_-_0096.jpg']),
('as4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/Duly_Noted_Studio_Outtake.jpg/960px-Duly_Noted_Studio_Outtake.jpg']),
('dm2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Camera_set-up_for_the_indoor_filming.jpg/960px-Camera_set-up_for_the_indoor_filming.jpg']),
('ms1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg/960px-Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg']),
('jj3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d9/Live_rock_concert_featuring_musicians_playing_electric_guitars_on_stage_at_night_with_vibrant_lights_and_an_enthusiastic_crowd_present.jpg/960px-Live_rock_concert_featuring_musicians_playing_electric_guitars_on_stage_at_night_with_vibrant_lights_and_an_enthusiastic_crowd_present.jpg']),
('ca1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Chicken_Adobo_over_rice.jpg/960px-Chicken_Adobo_over_rice.jpg']),
('ca3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/Tested_recipes_cookbook_cover.jpg/960px-Tested_recipes_cookbook_cover.jpg']),
('gg3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/Young_attractive_man_athlete_doing_exercise_with_the_barbell_in_the_gym.jpg/960px-Young_attractive_man_athlete_doing_exercise_with_the_barbell_in_the_gym.jpg']),
('wl1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/EL_NIDO_MINILOC_sunrise.JPG/960px-EL_NIDO_MINILOC_sunrise.JPG']),
('wl3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/04_Palawan_tourism_-_island_hopping_tour_B_visiting_Snake_Island_sandbar.jpg/960px-04_Palawan_tourism_-_island_hopping_tour_B_visiting_Snake_Island_sandbar.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Twin_Lagoon%2C_Coron%2C_Palawan%2C_Philippines_-_panoramio.jpg/960px-Twin_Lagoon%2C_Coron%2C_Palawan%2C_Philippines_-_panoramio.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg/960px-Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/El_Nido_Fishing_Village_-_panoramio.jpg/960px-El_Nido_Fishing_Village_-_panoramio.jpg']),
('pp3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png']),
('ib1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Fox_With_Two_Herons_MET_270303.jpg/960px-Fox_With_Two_Herons_MET_270303.jpg']),
('ib2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Ash_Heap_of_History.jpg/960px-Ash_Heap_of_History.jpg']),
('mm1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg/960px-Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg']),
('mm3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/ARTIST_RON_BLACKBURN_PAINTING_AN_OUTDOOR_WALL_MURAL_AT_THE_CORNER_OF_33RD_AND_GILES_STREET_IN_CHICAGO._HE_IS_ONE_OF..._-_NARA_-_556230.jpg/960px-ARTIST_RON_BLACKBURN_PAINTING_AN_OUTDOOR_WALL_MURAL_AT_THE_CORNER_OF_33RD_AND_GILES_STREET_IN_CHICAGO._HE_IS_ONE_OF..._-_NARA_-_556230.jpg']),
('nh1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Banaue_Philippines_Batad-Rice-Terraces-02.jpg/960px-Banaue_Philippines_Batad-Rice-Terraces-02.jpg']),
('nh2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Malapascua_%28island%29%2C_Rural_village_with_bungalows_and_wooden_boats%2C_Philippines.jpg/960px-Malapascua_%28island%29%2C_Rural_village_with_bungalows_and_wooden_boats%2C_Philippines.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Loay_outrigger_ca._1970.jpg/960px-Loay_outrigger_ca._1970.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/08236jfPampanga_River_Santa_Lucia_Anac_Matua_Boats_Delta_Roadsfvf_28.JPG/960px-08236jfPampanga_River_Santa_Lucia_Anac_Matua_Boats_Delta_Roadsfvf_28.JPG']),
('nh4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Rainy_Night_in_Thailand_-_Flickr_-_kyle_simourd.jpg/960px-Rainy_Night_in_Thailand_-_Flickr_-_kyle_simourd.jpg']),
('me2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg/960px-Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg']),
('po2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Night_Market_food_stall_%281491421152%29.jpg/960px-Night_Market_food_stall_%281491421152%29.jpg']),
('db2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Rain_clouds_over_Bramble_Bay%2C_Sandgate_Pier_IMGP5273.jpg/960px-Rain_clouds_over_Bramble_Bay%2C_Sandgate_Pier_IMGP5273.jpg']),
('cn2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Penn_State_Nittany_Lions_women%27s_soccer.jpg/960px-Penn_State_Nittany_Lions_women%27s_soccer.jpg']),
('tb3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Nokia_3_camera.jpg/960px-Nokia_3_camera.jpg']),
('ml1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg/960px-A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg']),
('ml2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg/960px-Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg']),
('ml4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Inside_domestic_refrigerator.JPG/960px-Inside_domestic_refrigerator.JPG']),
('bf1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/A_woman_stands_with_a_vintage_camera%2C_dressed_in_a_denim_jacket_and_jeans.jpg/960px-A_woman_stands_with_a_vintage_camera%2C_dressed_in_a_denim_jacket_and_jeans.jpg']),
('bf3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Wymiana_ubraniowa_1.jpg/960px-Wymiana_ubraniowa_1.jpg']),
('kp1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/KOCIS_Korea-Japan_Festival_2011_in_Tokyo_%286260062402%29.jpg/960px-KOCIS_Korea-Japan_Festival_2011_in_Tokyo_%286260062402%29.jpg']),
('x_coachr2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Dribbling_down_court_DVIDS164624.jpg/960px-Dribbling_down_court_DVIDS164624.jpg']),
('x_speedy1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Marathon_runners_on_the_A166_-_geograph.org.uk_-_7626427.jpg/960px-Marathon_runners_on_the_A166_-_geograph.org.uk_-_7626427.jpg']),
('x_harana1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg/960px-Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg']),
('x_beatsb2', array['https://upload.wikimedia.org/wikipedia/commons/e/ea/LiquidMorry%27s_home_recording_studio.jpg']),
('x_violet1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/%EC%9D%B4%EC%8A%B9%EC%9C%A4_SBS_Radio.png/960px-%EC%9D%B4%EC%8A%B9%EC%9C%A4_SBS_Radio.png']),
('x_animea1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Anime_Girl_upright_version.jpg/960px-Anime_Girl_upright_version.jpg']),
('x_street1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/fd/Isaw_%28street_food%29.jpg/960px-Isaw_%28street_food%29.jpg']),
('x_street3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/DFC_1637_Night_market_street_food_stall_serving_diners_at_outdoor_tables_as_evening_traffic_passes_by.jpg/960px-DFC_1637_Night_market_street_food_stall_serving_diners_at_outdoor_tables_as_evening_traffic_passes_by.jpg']),
('x_bakerb1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/Ube_Pandesal_%28Filipino_purple_yam_Bread_roll%29.jpg/960px-Ube_Pandesal_%28Filipino_purple_yam_Bread_roll%29.jpg']),
('x_roamin1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Sea_of_Clouds_at_the_Summit_of_Mount_Pulag.jpg/960px-Sea_of_Clouds_at_the_Summit_of_Mount_Pulag.jpg']),
('x_island1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Lagoon_from_Coron_Palawan.jpg/960px-Lagoon_from_Coron_Palawan.jpg']),
('x_gadget1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Nokia_3310_6_5_3.jpg/960px-Nokia_3310_6_5_3.jpg']),
('x_smallb1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Isang_sari-sari_store_sa_Maynila.jpg/960px-Isang_sari-sari_store_sa_Maynila.jpg']),
('x_yogawi1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Yoga_at_Your_Park_-_Bitilasana.jpg/960px-Yoga_at_Your_Park_-_Bitilasana.jpg']),
('x_thrift1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Veste_vintage_en_jeans.jpg/960px-Veste_vintage_en_jeans.jpg']),
('x_thrift3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Uniqlo_2026-09-07_shirt_Philippines.jpg/960px-Uniqlo_2026-09-07_shirt_Philippines.jpg']),
('x_titom1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/EL_NIDO_MINILOC_sunrise.JPG/960px-EL_NIDO_MINILOC_sunrise.JPG']),
('x_relata2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Inside_of_double_sided_refrigerator.jpg/960px-Inside_of_double_sided_refrigerator.jpg']),
('x_valora3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png']),
('x_retrop1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Game-Boy-Color-Yellow.jpg/960px-Game-Boy-Color-Yellow.jpg']),
('x_metrow2', array['https://upload.wikimedia.org/wikipedia/commons/4/4a/Typhoon_Koppu_over_the_Philippines_%2821695256053%29.jpg']),
('x_teache1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/JON_8-31-garden-3_%2832648258574%29.jpg/960px-JON_8-31-garden-3_%2832648258574%29.jpg']),
('x_petsof1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Cat_in_a_chair.jpg/960px-Cat_in_a_chair.jpg']),
('x_petsof2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Brown_dog_with_curly_hair_sitting_and_waiting_at_the_door_with_woman_in_the_background.jpg/960px-Brown_dog_with_curly_hair_sitting_and_waiting_at_the_door_with_woman_in_the_background.jpg']),
('x_sketch3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg/960px-Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg']),
('c_hoops1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Alex_Jackson_basketball_player.jpg/960px-Alex_Jackson_basketball_player.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Dribbling_down_the_court_DVIDS166219.jpg/960px-Dribbling_down_the_court_DVIDS166219.jpg']),
('c_hoops4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Star_%22The_Rock_of_Niue%22_Tauasi_sparring_Owen_Parry.jpg/960px-Star_%22The_Rock_of_Niue%22_Tauasi_sparring_Owen_Parry.jpg']),
('c_flu4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Mobile_World_Congress_2017_%2838277562096%29.jpg/960px-Mobile_World_Congress_2017_%2838277562096%29.jpg']),
('c_food1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Sinigang_na_Baboy.jpg/960px-Sinigang_na_Baboy.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/The_Best_Sinigang_Cuisine.jpg/960px-The_Best_Sinigang_Cuisine.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/37/Sinigang_na_Baka_20161229.jpg/960px-Sinigang_na_Baka_20161229.jpg']),
('c_food2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Isaw_-_Street_Food.jpg/960px-Isaw_-_Street_Food.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/74/Kwek-Kwek_and_fried_isaw.jpg/960px-Kwek-Kwek_and_fried_isaw.jpg']),
('c_food3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Filipino_ensaymada.jpg/960px-Filipino_ensaymada.jpg']),
('c_food5', array['https://upload.wikimedia.org/wikipedia/commons/5/5a/Kare-kare.jpg']),
('c_opm2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/George_McAnthony_live.jpg/960px-George_McAnthony_live.jpg']),
('c_opm5', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f8/Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG/960px-Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG', 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg/960px-Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg']),
('c_cin1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Introduction_of_prefestival_screening_at_Locarno_Film_Festival_2.jpg/960px-Introduction_of_prefestival_screening_at_Locarno_Film_Festival_2.jpg']),
('c_cin3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7d/US_Navy_040615-N-6817C-030_A_camera_crew_sets_up_for_scenes_to_be_taped_on_the_flight_deck_for_the_upcoming_motion_picture_Stealth.jpg/960px-US_Navy_040615-N-6817C-030_A_camera_crew_sets_up_for_scenes_to_be_taped_on_the_flight_deck_for_the_upcoming_motion_picture_Stealth.jpg']),
('c_trav1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/EL_NIDO_MINILOC_sunrise.JPG/960px-EL_NIDO_MINILOC_sunrise.JPG', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/El_Nido_Bay%2C_Desert_tropical_island%2C_Coastline%2C_Palawan_Island%2C_Philippines.jpg/960px-El_Nido_Bay%2C_Desert_tropical_island%2C_Coastline%2C_Palawan_Island%2C_Philippines.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Island_lagoon_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg/960px-Island_lagoon_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg']),
('c_trav2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Twin_Lagoon%2C_Coron%2C_Palawan.jpg/960px-Twin_Lagoon%2C_Coron%2C_Palawan.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Corong_Corong%2C_El_Nido%2C_Palawan_Island%2C_Philippines.jpg/960px-Corong_Corong%2C_El_Nido%2C_Palawan_Island%2C_Philippines.jpg']),
('c_trav3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Banaue_Philippines_Banaue-Rice-Terraces-01.jpg/960px-Banaue_Philippines_Banaue-Rice-Terraces-01.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Banaue_Philippines_Batad-Rice-Terraces-04.jpg/960px-Banaue_Philippines_Batad-Rice-Terraces-04.jpg']),
('c_trav4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/Sea_of_clouds_2024-08-02.jpg/960px-Sea_of_clouds_2024-08-02.jpg']),
('c_biz3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Sari-Sari_Store_Samal_Davao.jpg/960px-Sari-Sari_Store_Samal_Davao.jpg']),
('c_fit1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Fitness_enthusiast_performs_a_single-leg_squat_exercise_in_an_indoor_gym_setting.jpg/960px-Fitness_enthusiast_performs_a_single-leg_squat_exercise_in_an_indoor_gym_setting.jpg']),
('c_fit5', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Runners_exiting_a_road_tunnel_during_the_2024_Sofia_Marathon.jpg/960px-Runners_exiting_a_road_tunnel_during_the_2024_Sofia_Marathon.jpg']),
('c_meme4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Gray-cat-on-chair.jpg/960px-Gray-cat-on-chair.jpg']),
('c_art1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Woman_Vendor_at_Fruit_Stall_-_Thursday_Market_-_Narvarte_-_Mexico_City_-_Mexico.jpg/960px-Woman_Vendor_at_Fruit_Stall_-_Thursday_Market_-_Narvarte_-_Mexico_City_-_Mexico.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Pike_Place_Market_-_sidewalk_craft_vendors_01.jpg/960px-Pike_Place_Market_-_sidewalk_craft_vendors_01.jpg']),
('c_art3', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg/960px-Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Wall_painting_of_Herzl.jpg/960px-Wall_painting_of_Herzl.jpg']),
('c_art4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/El_Nido_Fishing_Village_-_panoramio.jpg/960px-El_Nido_Fishing_Village_-_panoramio.jpg']),
('c_art5', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg/960px-Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg']),
('c_thr1', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Veste_vintage_en_jeans.jpg/960px-Veste_vintage_en_jeans.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/A_woman_stands_with_a_vintage_camera%2C_dressed_in_a_denim_jacket_and_jeans.jpg/960px-A_woman_stands_with_a_vintage_camera%2C_dressed_in_a_denim_jacket_and_jeans.jpg']),
('c_thr2', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Uniqlo_2026-09-07_shirt_Philippines.jpg/960px-Uniqlo_2026-09-07_shirt_Philippines.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Bunny_t_shirt_with_green_shirt.jpg/960px-Bunny_t_shirt_with_green_shirt.jpg']),
('c_thr4', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Clothing_racks_in_second_hand_shop%2C_Prague.jpg/960px-Clothing_racks_in_second_hand_shop%2C_Prague.jpg']),
('hdr:marcovaldez_', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Alex_Jackson_basketball_player.jpg/960px-Alex_Jackson_basketball_player.jpg']),
('hdr:sofia_strikes', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Penn_State_Nittany_Lions_women%27s_soccer.jpg/960px-Penn_State_Nittany_Lions_women%27s_soccer.jpg']),
('hdr:kai_okonkwo', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/US_Navy_081011-N-5345W-057_Cryptologic_Technician_Networks_Seaman_Janea_Arrington_connects_with_a_straight_right_to_the_jaw_of_Aviation_Ordnanceman_Airman_Nakita_Boyd_during_a_sparring_session.jpg/960px-thumbnail.jpg']),
('hdr:jasmine_serve', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/2013_Australian_Open_-_Guillaume_Rufin.jpg/960px-2013_Australian_Open_-_Guillaume_Rufin.jpg']),
('hdr:rheaplays', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg/960px-Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg']),
('hdr:lunaveil', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Beach-Please-2022-crowd-stage-lights-night-performance.jpg/960px-Beach-Please-2022-crowd-stage-lights-night-performance.jpg']),
('hdr:nightbloom_mx', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f8/Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG/960px-Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG']),
('hdr:djkaizen', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/DJ_booth_with_DJ-Mixer%2C_two_turntables_and_two_CDJ-players_in_former_Bob_Beaman_nightclub_in_Munich.jpg/960px-DJ_booth_with_DJ-Mixer%2C_two_turntables_and_two_CDJ-players_in_former_Bob_Beaman_nightclub_in_Munich.jpg']),
('hdr:tonyreyes_opm', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Sheri_Miller_-_live_2011.jpg/960px-Sheri_Miller_-_live_2011.jpg']),
('hdr:astralis_hq', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Tochiotome_25_on_stage_20151107.jpg/960px-Tochiotome_25_on_stage_20151107.jpg']),
('hdr:diegomontero', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Camera_set-up_for_the_indoor_filming.jpg/960px-Camera_set-up_for_the_indoor_filming.jpg']),
('hdr:mikaelasy_film', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg/960px-Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg']),
('hdr:jokerjules', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d9/Live_rock_concert_featuring_musicians_playing_electric_guitars_on_stage_at_night_with_vibrant_lights_and_an_enthusiastic_crowd_present.jpg/960px-Live_rock_concert_featuring_musicians_playing_electric_guitars_on_stage_at_night_with_vibrant_lights_and_an_enthusiastic_crowd_present.jpg']),
('hdr:chefandrea', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/A_Spread_of_Pinoy_Food.jpg/960px-A_Spread_of_Pinoy_Food.jpg']),
('hdr:gymwithgabe', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg/960px-Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg']),
('hdr:wanderlenka', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg/960px-Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg']),
('hdr:pixelpaolo', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png']),
('hdr:inkbyisla', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Ash_Heap_of_History.jpg/960px-Ash_Heap_of_History.jpg']),
('hdr:muralmarcus', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg/960px-Artist_painting_the_mural_of_Paulo_de_Carvalho%2C_Roma_Avenue%2C_Lisbon%2C_Portugal_julesvernex2.jpg']),
('hdr:frames_by_noa', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Banaue_Philippines_Batad-Rice-Terraces-02.jpg/960px-Banaue_Philippines_Batad-Rice-Terraces-02.jpg']),
('hdr:mayor_elena', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/The_Bus_Rapid_transit_Lane_along_King_Street_in_London%2C_Ontario.jpg/960px-The_Bus_Rapid_transit_Lane_along_King_Street_in_London%2C_Ontario.jpg']),
('hdr:sen_marlonvega', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg/960px-Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg']),
('hdr:portalder_gov', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Night_Market_food_stall_%281491421152%29.jpg/960px-Night_Market_food_stall_%281491421152%29.jpg']),
('hdr:dailybulletin', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/Rain_clouds_over_Bramble_Bay%2C_Sandgate_Pier_IMGP5273.jpg/960px-Rain_clouds_over_Bramble_Bay%2C_Sandgate_Pier_IMGP5273.jpg']),
('hdr:courtsidenow', array['https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Dribbling_down_the_court_DVIDS166219.jpg/960px-Dribbling_down_the_court_DVIDS166219.jpg']),
('hdr:techbrief_ph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Nokia_3_camera.jpg/960px-Nokia_3_camera.jpg']),
('hdr:drnadia_sci', array['https://upload.wikimedia.org/wikipedia/commons/4/4a/Typhoon_Koppu_over_the_Philippines_%2821695256053%29.jpg']),
('hdr:startupsam', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Isang_sari-sari_store_sa_Maynila.jpg/960px-Isang_sari-sari_store_sa_Maynila.jpg']),
('hdr:coinwatchdaily', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Nokia_3310_6_5_3.jpg/960px-Nokia_3310_6_5_3.jpg']),
('hdr:memelord_ph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg/960px-A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg']),
('hdr:bianca_ootd', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Uniqlo_2026-09-07_shirt_Philippines.jpg/960px-Uniqlo_2026-09-07_shirt_Philippines.jpg']),
('hdr:cinemanotes', array['https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/Clapperboard%2C_O2_film%2C_September_2008.jpg/960px-Clapperboard%2C_O2_film%2C_September_2008.jpg']),
('hdr:jo_mercado_dev', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png']),
('hdr:kpopdaily_ph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Ground_Forces_Festival_2025_-_0096.jpg/960px-Ground_Forces_Festival_2025_-_0096.jpg']),
('hdr:coachramon', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Dribbling_down_court_DVIDS164624.jpg/960px-Dribbling_down_court_DVIDS164624.jpg']),
('hdr:speedyselene', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Marathon_runners_on_the_A166_-_geograph.org.uk_-_7626427.jpg/960px-Marathon_runners_on_the_A166_-_geograph.org.uk_-_7626427.jpg']),
('hdr:harana_hub', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg/960px-Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg']),
('hdr:beatsbyrio', array['https://upload.wikimedia.org/wikipedia/commons/2/28/LiquidMolly%27s_home_recording_studio_-_overview.jpg']),
('hdr:violetsessions', array['https://upload.wikimedia.org/wikipedia/commons/e/ea/LiquidMorry%27s_home_recording_studio.jpg']),
('hdr:serieswithsam', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7d/US_Navy_040615-N-6817C-030_A_camera_crew_sets_up_for_scenes_to_be_taped_on_the_flight_deck_for_the_upcoming_motion_picture_Stealth.jpg/960px-US_Navy_040615-N-6817C-030_A_camera_crew_sets_up_for_scenes_to_be_taped_on_the_flight_deck_for_the_upcoming_motion_picture_Stealth.jpg']),
('hdr:animeatlas', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Anime_Girl_upright_version.jpg/960px-Anime_Girl_upright_version.jpg']),
('hdr:streetfoodmnl', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/202403_A_street_food_vendor_in_Manila_2_-_his_fishballs.jpg/960px-202403_A_street_food_vendor_in_Manila_2_-_his_fishballs.jpg']),
('hdr:bakerbea', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Pinoy_Pandesal.jpg/960px-Pinoy_Pandesal.jpg']),
('hdr:roamingrafael', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Sea_of_Clouds_at_the_Summit_of_Mount_Pulag.jpg/960px-Sea_of_Clouds_at_the_Summit_of_Mount_Pulag.jpg']),
('hdr:islandhopper_ph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Twin_Lagoon%2C_Coron%2C_Palawan%2C_Philippines_-_panoramio.jpg/960px-Twin_Lagoon%2C_Coron%2C_Palawan%2C_Philippines_-_panoramio.jpg']),
('hdr:devdaniela', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg/960px-Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg']),
('hdr:gadgetgus', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Mobile_World_Congress_2017_%2838277562096%29.jpg/960px-Mobile_World_Congress_2017_%2838277562096%29.jpg']),
('hdr:aiweekly_ph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Nokia_3_camera.jpg/960px-Nokia_3_camera.jpg']),
('hdr:financewithfe', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Sari-Sari_Store_Samal_Davao.jpg/960px-Sari-Sari_Store_Samal_Davao.jpg']),
('hdr:smallbizsari', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Sari-sari_Store.JPG/960px-Sari-sari_Store.JPG']),
('hdr:dr_miguel_md', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Yoga_at_Your_Park_-_Bitilasana.jpg/960px-Yoga_at_Your_Park_-_Bitilasana.jpg']),
('hdr:yogawithyna', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Yoga_at_Your_Park_%28769083a3-0735-4ad9-8248-b6aaf9b95670%29.jpg/960px-Yoga_at_Your_Park_%28769083a3-0735-4ad9-8248-b6aaf9b95670%29.jpg']),
('hdr:thriftkingjay', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Clothing_racks_in_second_hand_shop%2C_Prague.jpg/960px-Clothing_racks_in_second_hand_shop%2C_Prague.jpg']),
('hdr:tito_memes', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Four_domestic_ducks_simultaneously_diving_in_a_pond.jpg/960px-Four_domestic_ducks_simultaneously_diving_in_a_pond.jpg']),
('hdr:relatablerina', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Inside_domestic_refrigerator.JPG/960px-Inside_domestic_refrigerator.JPG']),
('hdr:valorantvince', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png']),
('hdr:retropixelria', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Game-Boy-Color-Yellow.jpg/960px-Game-Boy-Color-Yellow.jpg']),
('hdr:kap_lito', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Isang_sari-sari_store_sa_Maynila.jpg/960px-Isang_sari-sari_store_sa_Maynila.jpg']),
('hdr:metroweatherph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Rain_at_Sea-1149%2C_Tralee_Bay%2C_Co._Kerry%2C_Ireland.jpg/960px-Rain_at_Sea-1149%2C_Tralee_Bay%2C_Co._Kerry%2C_Ireland.jpg']),
('hdr:teacherjoy', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/JON_8-31-garden-3_%2832648258574%29.jpg/960px-JON_8-31-garden-3_%2832648258574%29.jpg']),
('hdr:petsofpasig', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Cat_in_a_chair.jpg/960px-Cat_in_a_chair.jpg']),
('hdr:sketchsir_dan', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Ash_Heap_of_History.jpg/960px-Ash_Heap_of_History.jpg']),
('comm:hoops', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Alex_Jackson_basketball_player.jpg/960px-Alex_Jackson_basketball_player.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Dribbling_down_the_court_DVIDS166219.jpg/960px-Dribbling_down_the_court_DVIDS166219.jpg']),
('comm:flutterph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg/960px-Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png']),
('comm:foodtrip', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/A_Spread_of_Pinoy_Food.jpg/960px-A_Spread_of_Pinoy_Food.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Table_Full_of_Homemade_Filipino_Delicacies.jpg/960px-Table_Full_of_Homemade_Filipino_Delicacies.jpg']),
('comm:opmheads', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f8/Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG/960px-Todd_Wolfe_Live_at_M%C3%B6nchengladbach_Airport.JPG', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Sheri_Miller_-_live_2011.jpg/960px-Sheri_Miller_-_live_2011.jpg']),
('comm:valorantph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg/960px-Dual_monitor_setup_in_a_gaming_room_with_keyboard_and_mouse_in_focus.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3281_RAW-Export.png']),
('comm:cinephiles', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg/960px-Aeronauts_Screening_at_Telluride_Film_Festival_2019.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Introduction_of_prefestival_screening_at_Locarno_Film_Festival_2.jpg/960px-Introduction_of_prefestival_screening_at_Locarno_Film_Festival_2.jpg']),
('comm:travelers', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg/960px-Limestone_island_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/El_Nido_Bay%2C_Desert_tropical_island%2C_Coastline%2C_Palawan_Island%2C_Philippines.jpg/960px-El_Nido_Bay%2C_Desert_tropical_island%2C_Coastline%2C_Palawan_Island%2C_Philippines.jpg']),
('comm:startupph', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Isang_sari-sari_store_sa_Maynila.jpg/960px-Isang_sari-sari_store_sa_Maynila.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Sari-Sari_Store_Samal_Davao.jpg/960px-Sari-Sari_Store_Samal_Davao.jpg']),
('comm:fitpinoy', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg/960px-Woman_doing_squat_workout_in_gym_with_barbell%2C_back_view.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Fitness_enthusiast_performs_a_single-leg_squat_exercise_in_an_indoor_gym_setting.jpg/960px-Fitness_enthusiast_performs_a_single-leg_squat_exercise_in_an_indoor_gym_setting.jpg']),
('comm:memes', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg/960px-A_Duck_pond_and_ducks_in_Howrah%2C_West_Bengal%2C_India.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Four_domestic_ducks_simultaneously_diving_in_a_pond.jpg/960px-Four_domestic_ducks_simultaneously_diving_in_a_pond.jpg']),
('comm:sketchbook', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Ash_Heap_of_History.jpg/960px-Ash_Heap_of_History.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Ash_Heap_of_History.jpg/960px-Ash_Heap_of_History.jpg']),
('comm:civictalk', array['https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/The_Bus_Rapid_transit_Lane_along_King_Street_in_London%2C_Ontario.jpg/960px-The_Bus_Rapid_transit_Lane_along_King_Street_in_London%2C_Ontario.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/The_Bus_Rapid_transit_Lane_in_London%2C_Ontario.jpg/960px-The_Bus_Rapid_transit_Lane_in_London%2C_Ontario.jpg']),
('comm:thrift', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Clothing_racks_in_second_hand_shop%2C_Prague.jpg/960px-Clothing_racks_in_second_hand_shop%2C_Prague.jpg', 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Too_Much_Plaid_%284394365739%29.jpg/960px-Too_Much_Plaid_%284394365739%29.jpg']),
('list:hoops', array['https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Dribbling_down_court_DVIDS164624.jpg/960px-Dribbling_down_court_DVIDS164624.jpg']),
('list:flutter', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png']),
('list:opm', array['https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg/960px-Clare_%28visual_artist%29_%26_Audio_Engineer_Jon_Gilbert_playing_guitar_-_Peggy_Honeywell_in_Room_205%2C_2012-06-20.jpg']),
('list:eats', array['https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/A_Spread_of_Pinoy_Food.jpg/960px-A_Spread_of_Pinoy_Food.jpg']),
('list:tech', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Mobile_World_Congress_2017_%2838277562096%29.jpg/960px-Mobile_World_Congress_2017_%2838277562096%29.jpg']),
('list:gov', array['https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg/960px-Miami_Dade_Main_Library_-_Children%27s_Room_04.jpg']),
('list:funny', array['https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Ducks_on_Pond_at_Bossall_-_geograph.org.uk_-_723735.jpg/960px-Ducks_on_Pond_at_Bossall_-_geograph.org.uk_-_723735.jpg']),
('list:creators', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Wall_painting_of_Herzl.jpg/960px-Wall_painting_of_Herzl.jpg']),
('list:gaming', array['https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png/960px-LFG-Con_2024_in_Hof_%28Saale%29_HOF3309_RAW-Export.png']),
('list:money', array['https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Sari-sari_Store.JPG/960px-Sari-sari_Store.JPG']),
('list:travel', array['https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Island_lagoon_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg/960px-Island_lagoon_in_Bacuit_Bay%2C_El_Nido%2C_Palawan%2C_Philippines.jpg']),
('list:wellness', array['https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Woman_stretches_at_home_office_desk_while_working_on_laptop.jpg/960px-Woman_stretches_at_home_office_desk_while_working_on_laptop.jpg']),
('list:movies', array['https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Public_at_screening_during_the_78th_Locarno_Film_Festival_2.jpg/960px-Public_at_screening_during_the_78th_Locarno_Film_Festival_2.jpg']),
('list:alerts', array['https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/A_car_splashes_up_water_as_it_drives_down_a_flooded_street_in_Calgary%2C_Alberta%2C_Canada.jpg/960px-A_car_splashes_up_water_as_it_drives_down_a_flooded_street_in_Calgary%2C_Alberta%2C_Canada.jpg']),
('list:style', array['https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Veste_vintage_en_jeans.jpg/960px-Veste_vintage_en_jeans.jpg']),
('list:study', array['https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg/960px-Children_modeling_clay_at_desks_and_drawing_on_blackboard_in_Washington%2C_D.C._classroom_LCCN95500443.jpg']);

update public.profiles pr set
  display_name = sp.name,
  bio          = left(sp.bio, 160),
  avatar_url   = 'https://api.dicebear.com/9.x/notionists/png?size=256&seed=' || sp.handle,
  header_url   = (select si.urls[1] from seed_img si where si.key = 'hdr:' || sp.handle),
  interests    = sp.interests,
  onboarded    = true,
  verified     = sp.verified,
  profile_label = sp.label,
  created_at   = now() - interval '120 days'
from seed_people sp
where pr.id = md5('seed-user:' || sp.handle)::uuid;

update public.profiles pr set
  display_name = sf.name,
  avatar_url   = 'https://api.dicebear.com/9.x/notionists/png?size=256&seed=' || sf.handle,
  onboarded    = false,
  created_at   = now() - interval '90 days'
from seed_fans sf
where pr.id = md5('seed-user:' || sf.handle)::uuid;

-- ---------------------------------------------------------------------
-- 2. The posts
--    kind: p = post, q = quote of `ref`, r = reply to `ref`
--    img : number of photos (0 = none)
-- ---------------------------------------------------------------------
create temp table seed_posts (
  key   text primary key,
  handle text not null,
  kind  text not null default 'p',
  ref   text,
  mins  int  not null,          -- minutes ago
  img   int  not null default 0,
  video text,                   -- URL of a video (null = none)
  body  text not null
) on commit drop;

insert into seed_posts (key, handle, kind, ref, mins, img, body) values
-- Marco Valdez
('mv1','marcovaldez_','p',null, 35, 1, $$Back in the gym at 6am. People ask how I stay ready for the playoffs. The answer is boring: show up when it's dark outside. #HoopsSeason$$),
('mv2','marcovaldez_','p',null, 390, 0, $$34 points is nice but the dinner my wife cooked after the game was the real MVP. 🍲 #HoopsSeason$$),
('mv3','marcovaldez_','p',null, 1480, 0, $$To the kids who waited outside the arena in the rain: thank you. I see you. Next home game, first row is yours.$$),
('mv4','marcovaldez_','p',null, 3100, 0, $$Film session at 9, shootaround at 11, nap at 1. This is the glamorous life of a basketball player. #HoopsSeason$$),
('mv5','marcovaldez_','p',null, 6200, 1, $$Off day. Coffee, a long walk and zero screens. Highly recommend.$$),
-- Sofia Lindqvist
('sl1','sofia_strikes','p',null, 70, 0, $$Two goals, one assist and a very sore hamstring. Football gives and football takes. Thank you to everyone in the stands tonight! ⚽$$),
('sl2','sofia_strikes','p',null, 820, 1, $$New season, same dog waiting for me at the door after every match. He does not care about the score and that is why I love him.$$),
('sl3','sofia_strikes','p',null, 2300, 0, $$Training notes: left foot finishing, 200 reps a day. It still feels wrong. That is how you know it is working.$$),
('sl4','sofia_strikes','p',null, 4700, 0, $$International break means a long flight and a cold hotel pillow. See you in the national team camp! 🇳🇴$$),
('sl5','sofia_strikes','p',null, 7600, 0, $$Reminder that nobody ever regretted going for a walk after a bad game.$$),
-- Kai Okonkwo
('ko1','kai_okonkwo','p',null, 120, 1, $$Camp week 6. Sparring was ugly, sleep was worse, mood is great. Fight night is coming. 🥊$$),
('ko2','kai_okonkwo','p',null, 1100, 0, $$Nobody sees the 5am road work. Everybody sees the knockout. Respect the part nobody sees.$$),
('ko3','kai_okonkwo','p',null, 2600, 0, $$Weigh-ins on Thursday. Please stop sending me pizza photos. I will see them in my dreams.$$),
('ko4','kai_okonkwo','p',null, 5200, 0, $$Fighters train for months and fans watch for minutes. I am okay with that trade. It is the best job in the world.$$),
('ko5','kai_okonkwo','p',null, 7900, 0, $$Fitness tip from camp: sleep is a performance enhancer and it is legal. #workout$$),
-- Jasmine Tan
('jt1','jasmine_serve','p',null, 160, 0, $$Won in three sets today and I am so proud of how I handled the pressure in the second. On to the quarterfinal! 🎾$$),
('jt2','jasmine_serve','p',null, 1250, 1, $$Hotel room, tea, two rackets, one very tired shoulder. Tournament life.$$),
('jt3','jasmine_serve','p',null, 3000, 0, $$A tennis match is mostly a conversation with yourself. Today the conversation was kind. Wish me luck for tomorrow.$$),
('jt4','jasmine_serve','p',null, 4900, 0, $$New racket strings, new game plan, same stubborn forehand. Game on.$$),
('jt5','jasmine_serve','p',null, 7000, 0, $$Fashion break! My new outfit for the tournament is finally here. Style is part of the game. ootd$$),
-- Rhea Dizon
('rd1','rheaplays','p',null, 55, 0, $$We are through to the semis at the #GrandCupEsports! Five straight maps without dropping a round. My hands are still shaking.$$),
('rd2','rheaplays','p',null, 700, 1, $$Bootcamp setup. Two monitors, one cat and a keyboard I will not let anyone touch. gaming$$),
('rd3','rheaplays','p',null, 2100, 0, $$Streaming tonight at 8 PM. We are playing ranked and I promise not to rage. (I will rage.)$$),
('rd4','rheaplays','p',null, 4300, 0, $$Pro tip for new players: aim training for 15 minutes before you queue. It is like stretching before sport. esports$$),
('rd5','rheaplays','p',null, 6800, 0, $$Shoutout to everyone who stayed up for the late-night scrim. The chat was funnier than the game. #GrandCupEsports$$),
-- Luna Veil
('lv1','lunaveil','p',null, 25, 1, $$"Paper Lanterns" has been out for 48 hours and I have read every single message. You are the reason I write songs. 🏮 #NewMusicFriday$$),
('lv2','lunaveil','p',null, 540, 0, $$Track 7 is the song I was most scared to release. It is about my grandmother's kitchen. I hope you feel it too. 💛$$),
('lv3','lunaveil','p',null, 1700, 1, $$Soundcheck, rehearsals, a ridiculous amount of tea. The album tour starts next month! #NewMusicFriday$$),
('lv4','lunaveil','p',null, 3900, 0, $$Music is the only language where everyone is allowed to cry in public. See you at the concert.$$),
('lv5','lunaveil','p',null, 7200, 0, $$Writing a song is like emptying a pocket: you find old receipts, lint and sometimes a diamond. #NewMusicFriday$$),
-- Nightbloom
('nb1','nightbloom_mx','p',null, 95, 1, $$Our first show at the new venue sold out in 12 minutes. We are still in shock. Thank you, Cebu. 🌸 #NewMusicFriday$$),
('nb2','nightbloom_mx','p',null, 1400, 0, $$New single is mixed. The drummer says it is perfect, the bassist says it needs more bass. Classic.$$),
('nb3','nightbloom_mx','p',null, 3300, 0, $$If you hear a band rehearsing at 2 AM it is probably us, sorry neighbors. The new song is worth it.$$),
('nb4','nightbloom_mx','p',null, 5400, 0, $$Merch drop on Friday: t-shirts, stickers and one (1) cursed tote bag.$$),
('nb5','nightbloom_mx','p',null, 7400, 0, $$Playing in a tiny bar for 20 people taught us more than any big stage. Stay small sometimes. #OPM$$),
-- DJ Kaizen
('dk1','djkaizen','p',null, 210, 1, $$Friday residency tonight. I have a new edit of a classic that I have never played in public. Come early. 🎧 #NewMusicFriday$$),
('dk2','djkaizen','p',null, 1600, 0, $$The best part of a DJ set is when the whole room sings the same line at the same time.$$),
('dk3','djkaizen','p',null, 3700, 0, $$Producing at 3 AM is easy. Finishing at 3 PM is the hard part. New song soon.$$),
('dk4','djkaizen','p',null, 5900, 0, $$Crate digging today. Found a record with a crack and a bassline that made me forget lunch.$$),
('dk5','djkaizen','p',null, 7700, 0, $$Reminder: a song does not need to be complicated, it needs to be honest. And with a good kick drum.$$),
-- Tony Reyes
('tr1','tonyreyes_opm','p',null, 140, 1, $$Salamat sa lahat ng sumama sa concert kagabi! Kinanta niyo yung buong "Biyahe" kahit hindi pa siya sinasabi sa stage. Naiyak ako. 🎸 #OPM$$),
('tr2','tonyreyes_opm','p',null, 1000, 0, $$Bagong kanta, tungkol sa jeep na laging punuan pero may isang upuan para sa'yo. Ilalabas ko next week. #OPM$$),
('tr3','tonyreyes_opm','p',null, 2900, 0, $$Mga kaibigan, huwag natin kalimutan: ang OPM ay hindi nostalgia lang. Buhay pa ito at lumalaki. Suportahan ang local artists. #OPM$$),
('tr4','tonyreyes_opm','p',null, 4800, 0, $$Kape, gitara at ulan. Yan ang recipe ng bagong album.$$),
('tr5','tonyreyes_opm','p',null, 7100, 0, $$Sino dito nagpapatugtog pa rin ng lumang playlist kapag nalulungkot? Hindi ako nag-iisa, hindi ba? #OPM$$),
-- ASTRALIS
('as1','astralis_hq','p',null, 15, 1, $$[ORBIT] The new album is out now on all platforms. Thank you to every ASTRALIS fan around the world! 🌌 #AstralisComeback$$),
('as2','astralis_hq','p',null, 480, 1, $$[SCHEDULE] ORBIT showcase live from Seoul tomorrow at 8 PM KST. Fan chat opens 30 minutes before. #AstralisComeback$$),
('as3','astralis_hq','p',null, 1500, 0, $$[NOTICE] Please enjoy the concert safely. Do not trade tickets outside official channels. #AstralisComeback$$),
('as4','astralis_hq','p',null, 3600, 1, $$[BEHIND] A few photos from the ORBIT jacket shoot. Which concept is your favorite?$$),
('as5','astralis_hq','p',null, 6900, 0, $$[MESSAGE] To our fans: this comeback is only possible because of you. We will keep working hard. #AstralisComeback$$),
-- Diego Montero
('dm1','diegomontero','p',null, 85, 0, $$Last day on set. I cried in front of the entire crew and I regret nothing. This movie is going to mean a lot to me.$$),
('dm2','diegomontero','p',null, 900, 1, $$Script reading with the best cast I have ever worked with. I'm excited and nervous in equal parts. #NowShowing$$),
('dm3','diegomontero','p',null, 2800, 0, $$People ask what is the hardest part of acting. It is not the crying. It is waiting 6 hours for a 30-second shot.$$),
('dm4','diegomontero','p',null, 4600, 0, $$Thank you for the kind words about the series finale. I did not write it, I just try to survive it. film$$),
('dm5','diegomontero','p',null, 7300, 0, $$Went home and cooked for my family for the first time in 4 months. Best role of my life.$$),
-- Mikaela Sy
('ms1','mikaelasy_film','p',null, 180, 1, $$Our film got selected for the Harbor Film Festival. 8 months of rewrites and a very small budget. I'm so grateful to this crew. 🎬 #NowShowing$$),
('ms2','mikaelasy_film','p',null, 1800, 0, $$A director's job: say "one more take" until everyone loves you a little less and the scene a little more.$$),
('ms3','mikaelasy_film','p',null, 3500, 0, $$Color grading day. I have looked at the same sky for 3 hours. It is perfect now. Maybe. Movie magic.$$),
('ms4','mikaelasy_film','p',null, 5600, 0, $$Support independent cinema. A ticket to a small film is a vote for more small films. #NowShowing$$),
('ms5','mikaelasy_film','p',null, 7800, 0, $$Favorite movie of all time? Mine changes every month. This month: a quiet one about a lighthouse keeper.$$),
-- Jules Banner
('jj1','jokerjules','p',null, 45, 0, $$Airport security took my deodorant but let me keep my anxiety. Priorities. lol$$),
('jj2','jokerjules','p',null, 600, 0, $$My mom asked what I do for a living. I said "I tell strangers about my problems and they pay me." She said "So, a therapist?" I said "No, the opposite."$$),
('jj3','jokerjules','p',null, 2000, 1, $$Sold out in Davao! Thank you! If you laughed at the one about my uncle, he says hi and also wants royalties.$$),
('jj4','jokerjules','p',null, 3800, 0, $$Being an adult is saying "I'll just rest for 5 minutes" and waking up at midnight with a stiff neck and zero regrets. funny$$),
('jj5','jokerjules','p',null, 6500, 0, $$I tried a "silent retreat" for the weekend. I lasted until Saturday lunch. The snacks started it.$$),
-- Chef Andrea
('ca1','chefandrea','p',null, 105, 1, $$Sunday lunch: adobo with garlic rice, pickled papaya and a fried egg. Slow cooked and not rushed. Recipe thread coming up. 🍳 #FoodPH$$),
('ca2','chefandrea','p',null, 1300, 0, $$Cooking tip: season in layers. A pinch of salt at the start, one in the middle and one at the end. Your dinner will thank you. food$$),
('ca3','chefandrea','p',null, 2700, 1, $$New cookbook cover reveal! 120 recipes, 3 years, and about 400 cups of coffee. Pre-orders open Friday. #FoodPH$$),
('ca4','chefandrea','p',null, 5100, 0, $$Please stop rinsing your pasta. Please. The starch is your friend, it is how the sauce sticks. Dinner, saved.$$),
('ca5','chefandrea','p',null, 7500, 0, $$Lunch break at the market: fresh calamansi, native tomatoes and a very long conversation with the fish vendor. Best part of my week. #FoodPH$$),
-- Gabe Santos
('gg1','gymwithgabe','p',null, 65, 0, $$Free 20-minute workout, no equipment: 30 sec squats, 30 sec push-ups, 30 sec plank. Repeat 5 times. Tell me your time. #workout$$),
('gg2','gymwithgabe','p',null, 1200, 0, $$You do not need a perfect plan. You need a boring plan that you actually follow. #fitness$$),
('gg3','gymwithgabe','p',null, 3400, 1, $$Form check Friday: when you squat, push your knees out. Your hips will thank you. Send me your videos. gym$$),
('gg4','gymwithgabe','p',null, 5500, 0, $$Rest days are training days. Your muscles grow while you sleep. Go to bed. #workout$$),
('gg5','gymwithgabe','p',null, 7400, 0, $$Protein does not need to be fancy. Eggs, tuna, chicken, tofu. Cheap and effective. health$$),
-- Lenka Novak
('wl1','wanderlenka','p',null, 130, 1, $$Day 3 in El Nido. Woke up at 5 AM for sunrise, the sky did not disappoint. Travel is just collecting moments. #TravelDiaries$$),
('wl2','wanderlenka','p',null, 1500, 0, $$Cheap flight tip: Tuesday mornings are usually the best time to book. Not always, but often. Save it. travel$$),
('wl3','wanderlenka','p',null, 2900, 4, $$Four days, four islands, one backpack. Highlights from the trip! Which is your favorite? #TravelDiaries$$),
('wl4','wanderlenka','p',null, 4900, 0, $$Pack one less shirt and one more notebook. You will remember the notes more than the outfits. #TravelDiaries$$),
('wl5','wanderlenka','p',null, 7000, 0, $$Missed my flight, caught a ferry, met a family that fed me for 3 days. Travel plans are suggestions. vacation$$),
-- Paolo
('pp1','pixelpaolo','p',null, 40, 0, $$Playing a horror game with the lights off. Please send help. Live now! 👻 #GrandCupEsports$$),
('pp2','pixelpaolo','p',null, 800, 0, $$Chat convinced me to try the hardest difficulty. 4 hours later I have a new respect for gamers everywhere. gaming$$),
('pp3','pixelpaolo','p',null, 2400, 1, $$New streaming setup finally done! My cat has already claimed the second chair. lol$$),
('pp4','pixelpaolo','p',null, 4500, 0, $$Reminder that you can play games for fun and not for rank. Revolutionary, I know.$$),
('pp5','pixelpaolo','p',null, 6700, 0, $$To the person who donated 50 pesos with the message "you got this": I did not got this but your message helped. 💛$$),
-- Isla Moreno
('ib1','inkbyisla','p',null, 200, 1, $$Day 12 of #InktoberPH: "Lantern". A fox who finally found his way home.$$),
('ib2','inkbyisla','p',null, 2200, 2, $$Process shots of my latest commission. Watercolor first, ink on top. Sometimes less is more.$$),
('ib3','inkbyisla','p',null, 3900, 0, $$Artist tip: finish the drawing even if you hate it halfway. The part you hate is usually the part you learn from. #InktoberPH$$),
('ib4','inkbyisla','p',null, 5800, 0, $$My cat sat on a wet painting again. I'm calling the result "abstract collaboration".$$),
('ib5','inkbyisla','p',null, 7600, 1, $$Commissions open for 5 slots this month. Portraits, pets and tiny worlds. DM me. #InktoberPH$$),
-- Marcus Bell
('mm1','muralmarcus','p',null, 300, 1, $$Finished the mural on Rizal Street after 9 days. The kids from the neighborhood painted the sky. Best collaborators ever. 🎨$$),
('mm2','muralmarcus','p',null, 2000, 0, $$Street art is the only gallery where nobody has to buy a ticket.$$),
('mm3','muralmarcus','p',null, 4000, 1, $$Scaffolding, a bucket of yellow and a plan that changed 12 times. Work in progress.$$),
('mm4','muralmarcus','p',null, 5700, 0, $$Someone asked if painting walls is a "real job". My shoulders say yes.$$),
('mm5','muralmarcus','p',null, 7800, 0, $$Looking for walls in the city that need a bit of love. Property owners, my DMs are open.$$),
-- Noa Hirsch
('nh1','frames_by_noa','p',null, 260, 1, $$Golden hour at the rice terraces. I waited 3 hours for 4 minutes of light. Worth it. 📷$$),
('nh2','frames_by_noa','p',null, 1900, 3, $$A short series from the fishing village: faces, boats and one very photogenic dog. #TravelDiaries$$),
('nh3','frames_by_noa','p',null, 3800, 0, $$Photography tip: stop chasing the perfect camera. Chase the light.$$),
('nh4','frames_by_noa','p',null, 5300, 1, $$Rainy streets are the best studio. Everything glows.$$),
('nh5','frames_by_noa','p',null, 7500, 0, $$Prints for the festival exhibit are being shipped today. I still can't believe it.$$),
-- Mayor Elena
('me1','mayor_elena','p',null, 50, 0, $$The new bus lanes on Harbor Avenue open tomorrow morning. Expect smoother commutes for 40,000 daily riders. Thank you for your patience during construction. #PortAlderTransit$$),
('me2','mayor_elena','p',null, 780, 1, $$Visited the new public library branch today. 14,000 books, free Wi-Fi and a reading corner for kids. Public spaces are public goods. #CityHallLive$$),
('me3','mayor_elena','p',null, 2200, 0, $$Reminder: office hours at City Hall this Friday, 9 AM to 12 noon. Walk-ins welcome. Bring your concerns and your questions. #CityHallLive$$),
('me4','mayor_elena','p',null, 4100, 0, $$Heavy rain is expected tonight. Please avoid low-lying areas and check evacuation centers on the city website. Stay safe, Port Alder.$$),
('me5','mayor_elena','p',null, 6400, 0, $$Budget hearing done. Free clinic hours extended and 200 new streetlights approved for the east side. #CityHallLive$$),
-- Sen. Vega
('sv1','sen_marlonvega','p',null, 150, 0, $$Today's committee hearing on the Clean Commute Act: we listened to drivers, cyclists, commuters and engineers. Public transport must be safe, affordable and on time. #PortAlderTransit$$),
('sv2','sen_marlonvega','p',null, 1650, 0, $$Education is the best investment a country can make. Our proposed budget for school repairs prioritizes 1,200 classrooms this year. #CityHallLive$$),
('sv3','sen_marlonvega','p',null, 3300, 0, $$I visited three public schools this week. Teachers are doing amazing work with very little. They deserve more support. senate$$),
('sv4','sen_marlonvega','p',null, 5000, 0, $$Government should be easy to understand. Our office now publishes plain-language summaries of every bill we file. Read them and tell us what to improve.$$),
('sv5','sen_marlonvega','p',null, 7200, 0, $$Election season means more noise. My promise: fewer slogans, more details. politics$$),
-- City of Port Alder
('po1','portalder_gov','p',null, 30, 0, $$ADVISORY: Water service interruption tomorrow, 10 PM to 4 AM, in Barangays 3, 7 and 12 due to pipe repairs. Please store water in advance.$$),
('po2','portalder_gov','p',null, 660, 1, $$The Port Alder Night Market returns this Saturday on Harbor Avenue. 80 local vendors, live music and free parking at the east lot. #PortAlderTransit$$),
('po3','portalder_gov','p',null, 2500, 0, $$Reminder: garbage collection schedules change next week for the holiday. Check the city website for your barangay. #CityHallLive$$),
('po4','portalder_gov','p',null, 4400, 0, $$Free flu vaccines are available at all city health centers for senior citizens and children. Bring a valid ID.$$),
('po5','portalder_gov','p',null, 6600, 0, $$The new bus lanes pilot starts Monday. Maps and route changes are posted at all terminals. #PortAlderTransit$$),
-- Daily Bulletin
('db1','dailybulletin','p',null, 20, 0, $$BREAKING: Port Alder bus lanes open to the public tomorrow after a two-month delay, city officials confirm. Full report to follow. #BreakingNews #PortAlderTransit$$),
('db2','dailybulletin','p',null, 420, 1, $$REPORT: Heavy rains forced the closure of three schools in the northern district. Classes resume Thursday, the education department says. #BreakingNews$$),
('db3','dailybulletin','p',null, 1350, 0, $$HEADLINE: Local startup raises 40 million pesos for flood-prediction technology. Founders say it will help 12 cities by next year. #BreakingNews$$),
('db4','dailybulletin','p',null, 3200, 0, $$EXPLAINER: What is in the Clean Commute Act and who would it affect? Our reporters break it down in 5 points. #PortAlderTransit$$),
('db5','dailybulletin','p',null, 6000, 0, $$FACT CHECK: A viral post claims the city will ban motorcycles downtown. The city government says there is no such plan. #BreakingNews$$),
-- Courtside Now
('cn1','courtsidenow','p',null, 38, 0, $$FINAL: Manila Hoopers 112, Cebu Titans 108. Marco Valdez scored 34 in the fourth-quarter comeback. #HoopsSeason$$),
('cn2','courtsidenow','p',null, 500, 1, $$Northgate FC top the table after a 3-1 win. Sofia Lindqvist scored twice. Football league standings inside. ⚽$$),
('cn3','courtsidenow','p',null, 1750, 0, $$TRADE ALERT: Davao Eagles acquire guard Jerome Dacanay for two first-round picks. #HoopsSeason$$),
('cn4','courtsidenow','p',null, 3700, 0, $$MVP race: five players, one trophy. Who is your pick? Vote below. #HoopsSeason$$),
('cn5','courtsidenow','p',null, 6300, 0, $$Boxing: Kai Okonkwo will defend his title next month. Tickets go on sale Friday.$$),
-- TechBrief
('tb1','techbrief_ph','p',null, 100, 0, $$5 Flutter habits that make mobile apps feel faster: smaller widgets, const constructors, lazy lists and fewer rebuilds. #Flutter software$$),
('tb2','techbrief_ph','p',null, 1100, 0, $$AI assistants are showing up in more workplaces. 5 things to check before you rely on one for real work. technology$$),
('tb3','techbrief_ph','p',null, 2600, 1, $$Review: the new phone has a great screen and a battery that survives two days. The camera is the real upgrade. tech$$),
('tb4','techbrief_ph','p',null, 4400, 0, $$Local startups keep building in fintech and logistics, even in a slow quarter. Three founders on what they changed. startups business$$),
('tb5','techbrief_ph','p',null, 6800, 0, $$How to spot a phishing text in 10 seconds. Short links, urgency, and "your account will be closed" are all red flags. technology$$),
-- Dr. Nadia
('nr1','drnadia_sci','p',null, 240, 0, $$Thread: why does a warmer ocean make storms stronger? Warm water is fuel. More heat means more evaporation, and more evaporation means more energy for a storm. (1/4)$$),
('nr2','drnadia_sci','p',null, 1700, 0, $$Reading about urban heat today: shade from trees makes a street feel noticeably cooler. Plant more trees, folks. health$$),
('nr3','drnadia_sci','p',null, 3100, 0, $$Science tip: "correlation is not causation" is not a magic phrase to dismiss every study. Read the method before you argue.$$),
('nr4','drnadia_sci','p',null, 5200, 0, $$Reading 40 pages of methods so you do not have to. You're welcome. 🔬$$),
('nr5','drnadia_sci','p',null, 7000, 0, $$Question I get a lot: "Is it too late?" No. Every fraction of a degree matters. Start where you are.$$),
-- Sam Ortega
('so1','startupsam','p',null, 110, 0, $$Founder lesson: revenue is a fact, growth is a story, profit is a decision. Know which one you're selling. #StartupLife$$),
('so2','startupsam','p',null, 1050, 0, $$Our startup just hit 10,000 users. It took 14 months, 3 pivots and a lot of coffee. Business is a long game. #StartupLife$$),
('so3','startupsam','p',null, 2700, 0, $$If your investor update only has good news, nobody believes the good news. Share the problems early. market$$),
('so4','startupsam','p',null, 4600, 0, $$Hiring your first employee is scarier than raising your first million. #StartupLife$$),
('so5','startupsam','p',null, 7100, 0, $$Personal finance tip: pay yourself first, even if it is 500 pesos a month. Habit beats amount at the start. finance$$),
-- Coin Watch
('cw1','coinwatchdaily','p',null, 60, 0, $$Quiet day for #Bitcoin: lower volume, tight range. Boring is fine. Not financial advice.$$),
('cw2','coinwatchdaily','p',null, 900, 0, $$Notes on #Ethereum layer-2 networks: why cheaper transactions are changing how apps are built. Not financial advice. crypto$$),
('cw3','coinwatchdaily','p',null, 2300, 0, $$Reminder: if someone promises guaranteed returns, they are selling something. Stay safe. #Bitcoin$$),
('cw4','coinwatchdaily','p',null, 4200, 0, $$Market recap: stocks mixed, crypto quiet, dollar slightly higher. Our daily chart in the thread.$$),
('cw5','coinwatchdaily','p',null, 6700, 0, $$Never invest money you cannot afford to lose. Boring advice. Still the best advice. #Bitcoin$$),
-- Memelord
('ml1','memelord_ph','p',null, 12, 1, $$me: i'll sleep early tonight
also me at 3 AM: what if ducks had hands lol meme$$),
('ml2','memelord_ph','p',null, 350, 1, $$when the group project has 5 people and you are the only one who read the instructions funny$$),
('ml3','memelord_ph','p',null, 1200, 0, $$Monday is just Sunday's evil twin meme$$),
('ml4','memelord_ph','p',null, 2800, 1, $$"We have food at home"
The food at home: memes$$),
('ml5','memelord_ph','p',null, 5400, 0, $$The WiFi disconnected for 5 seconds and I considered going outside lol$$),
-- Bianca
('bf1','bianca_ootd','p',null, 90, 1, $$ootd: oversized blazer, thrifted jeans and white sneakers. Total: 1,200 pesos. Style does not need a big budget. #ootd fashion$$),
('bf2','bianca_ootd','p',null, 1400, 0, $$Capsule wardrobe rule: if you do not have 3 outfits for it, you do not need it. outfit$$),
('bf3','bianca_ootd','p',null, 3000, 1, $$Sustainable brands I'm loving this month, thread below. Quality over quantity every time. style$$),
('bf4','bianca_ootd','p',null, 5000, 0, $$Fashion week recap: big shoulders, soft colors and a lot of denim. #ootd$$),
('bf5','bianca_ootd','p',null, 7300, 0, $$Thrift tip: check the seams and the zippers first. Everything else can be fixed.$$),
-- Cinema Notes
('cin1','cinemanotes','p',null, 75, 0, $$REVIEW: "The Lighthouse Letters" is a quiet, beautiful film about grief. The final scene stayed with me all night. 4.5/5 movie #NowShowing$$),
('cin2','cinemanotes','p',null, 1000, 0, $$The best series on Netflix this week is the one nobody is talking about. Thread, no spoilers. series$$),
('cin3','cinemanotes','p',null, 2500, 0, $$Hot take: a great ending can't save a bad middle, and a bad ending can't erase a great one. film$$),
('cin4','cinemanotes','p',null, 4700, 0, $$Streaming this weekend: 3 comfort movies, 2 thrillers and 1 documentary about the sea. #NowShowing$$),
('cin5','cinemanotes','p',null, 7000, 0, $$Reminder: reviews are opinions. Watch it and make up your own mind. movies$$),
-- Jo Mercado
('jm1','jo_mercado_dev','p',null, 80, 0, $$Day 41 of learning Flutter. Today I finally understood how state works. Sort of. #Flutter coding$$),
('jm2','jo_mercado_dev','p',null, 1150, 0, $$Tip for new developers: read the error message slowly. It is usually telling you exactly what is wrong. #Flutter programming$$),
('jm3','jo_mercado_dev','p',null, 3200, 0, $$Spent 3 hours on a bug. The fix was one missing comma. Programming is humbling. coding$$),
('jm4','jo_mercado_dev','p',null, 5100, 0, $$Built my first app with Flutter and Supabase! Login, posts, likes. It is not pretty yet but it works. #Flutter$$),
('jm5','jo_mercado_dev','p',null, 7300, 0, $$Take breaks. Your best ideas arrive in the shower, not in the 7th hour of staring at the screen. software$$),
-- K-Pop Daily
('kp1','kpopdaily_ph','p',null, 22, 1, $$ASTRALIS "ORBIT" tops the charts in 11 countries in its first day! Congratulations to the members and fans! #AstralisComeback kpop$$),
('kp2','kpopdaily_ph','p',null, 520, 0, $$Fan project: we're streaming ORBIT together tonight at 9 PM. Join the party! kpop #AstralisComeback$$),
('kp3','kpopdaily_ph','p',null, 1650, 0, $$A reminder that fan accounts are not agencies. Please verify news from official sources. celebrity$$),
('kp4','kpopdaily_ph','p',null, 3500, 0, $$Which ASTRALIS member has the best stage presence? You cannot choose only one, but try. kpop$$),
('kp5','kpopdaily_ph','p',null, 6100, 0, $$Concert etiquette: do not block the view, do not push, share your lightstick. kpop concert$$);

-- Quote posts (their `ref` is a post above)
insert into seed_posts (key, handle, kind, ref, mins, body) values
('q1','courtsidenow','q','mv2', 360, $$Valdez with a playoff-level performance AND a home-cooked dinner. Both win. #HoopsSeason$$),
('q2','kpopdaily_ph','q','as1', 14, $$It is finally here!! Streaming it on repeat all night. #AstralisComeback$$),
('q3','memelord_ph','q','jj1', 40, $$the deodorant part is accurate meme$$),
('q4','techbrief_ph','q','jm4', 4900, $$This is the way. Build small, learn fast. Welcome to the Flutter world! #Flutter$$),
('q5','sen_marlonvega','q','me1', 45, $$Good news for commuters. Public transport must reach more neighborhoods. #PortAlderTransit$$),
('q6','mikaelasy_film','q','cin1', 70, $$This review means the world to me. Thank you for watching with such care. #NowShowing$$);

-- Replies
insert into seed_posts (key, handle, kind, ref, mins, body) values
('r1','sofia_strikes','r','mv1', 30, $$6am? I was still sleeping. Respect, Marco. 😂$$),
('r2','courtsidenow','r','mv1', 28, $$The work no one sees. #HoopsSeason$$),
('r3','memelord_ph','r','mv2', 380, $$the dinner arc is better than the game arc$$),
('r4','jokerjules','r','mv2', 370, $$34 points for dinner. I get 34 pesos for a joke.$$),
('r5','tonyreyes_opm','r','lv1', 22, $$Congrats, Luna! Pakinggan ko ang buong album ngayong gabi. 🎶$$),
('r6','astralis_hq','r','lv1', 20, $$Congratulations on the album! We love track 4. 💛$$),
('r7','kpopdaily_ph','r','as1', 13, $$We have been waiting for this! Thank you ASTRALIS!!$$),
('r8','djkaizen','r','as1', 12, $$Congrats on the comeback! The beat on track 2 is wild.$$),
('r9','mayor_elena','r','db1', 15, $$Confirmed. The buses start at 6 AM. Thank you for your patience, Port Alder. #PortAlderTransit$$),
('r10','sen_marlonvega','r','db1', 14, $$Congratulations to the city team. Next, extend the routes to the east side. #PortAlderTransit$$),
('r11','dailybulletin','r','me1', 40, $$Is there a ceiling on the number of buses per lane? Our reporters would like to know. #PortAlderTransit$$),
('r12','portalder_gov','r','me1', 35, $$Maps and schedules are posted at all stops and on our website.$$),
('r13','gymwithgabe','r','ko1', 100, $$Camp life. Respect the grind, champ. 💪$$),
('r14','sofia_strikes','r','ko1', 95, $$Good luck on fight night, Kai!$$),
('r15','diegomontero','r','ms1', 160, $$Proud of you, Mikaela. Cannot wait to watch it.$$),
('r16','cinemanotes','r','ms1', 150, $$Congratulations! Adding it to the must-watch list. #NowShowing$$),
('r17','jo_mercado_dev','r','tb1', 90, $$Smaller app size is the best news today. #Flutter$$),
('r18','startupsam','r','tb1', 85, $$Faster rendering means fewer excuses for me. #Flutter$$),
('r19','jokerjules','r','jt1', 150, $$Three sets? I get tired watching. Congrats!$$),
('r20','marcovaldez_','r','jt1', 140, $$Proud of you, Jasmine. Quarterfinal time!$$),
('r21','chefandrea','r','ca1', 95, $$Adobo that has rested overnight tastes better. Yes, I will fight about it. #FoodPH$$),
('r22','bianca_ootd','r','ca1', 90, $$That plate looks incredible!$$),
('r23','wanderlenka','r','nh1', 240, $$Light chasers unite. That shot is stunning.$$),
('r24','inkbyisla','r','nh1', 235, $$The colors! I need to paint this.$$),
('r25','mayor_elena','r','po1', 25, $$Thank you for the advisory. Please check on your elderly neighbors.$$),
('r26','dailybulletin','r','po1', 22, $$We'll update the list of affected areas as it comes in.$$),
('r27','coinwatchdaily','r','so2', 1000, $$Congrats on the milestone, Sam. #StartupLife$$),
('r28','techbrief_ph','r','so2', 990, $$Great case study. We'd love to feature it. DM us.$$),
('r29','pixelpaolo','r','rd1', 50, $$LET'S GOOOO. See you in the finals! #GrandCupEsports$$),
('r30','courtsidenow','r','rd1', 48, $$Vanta Gaming into the semis. What a run. #GrandCupEsports$$),
('r31','nightbloom_mx','r','tr1', 130, $$Sobrang saya para sa'yo, Tony. Salamat sa mga kanta. #OPM$$),
('r32','lunaveil','r','tr1', 125, $$Biyahe is one of my favorite songs ever. #OPM$$),
('r33','drnadia_sci','r','me5', 6300, $$Streetlights and clinic hours are good public health policy. Thank you.$$),
('r34','kai_okonkwo','r','cn1', 30, $$Great game by Valdez. Respect.$$),
('r35','memelord_ph','r','nr1', 230, $$This is the explanation I needed. Thank you, doctor!$$),
('r36','gymwithgabe','r','jm1', 70, $$Day 41 is when it gets fun. Keep going! #Flutter$$),
('r37','jo_mercado_dev','r','jm1', 68, $$Thank you, coach! 😂$$),
('r38','bianca_ootd','r','jt5', 6900, $$That outfit is a serve! ✨$$),
('r39','muralmarcus','r','ib1', 190, $$The fox is perfect. Great line work.$$),
('r40','frames_by_noa','r','mm1', 290, $$The kids painting the sky is such a good touch.$$),
('r41','mayor_elena','r','mm1', 285, $$Port Alder needs more murals. Let's talk.$$),
('r42','djkaizen','r','nb1', 90, $$Sold out in 12 minutes? Legends. Congrats!$$),
('r43','lunaveil','r','cn2', 480, $$Congrats to Northgate! Sofia is on fire.$$),
('r44','sofia_strikes','r','cn2', 470, $$Thank you! The team earned it.$$),
('r45','mikaelasy_film','r','dm1', 80, $$It was a joy to see your work. Rest well, Diego.$$);

-- Second batch: more posts, the video posts (sample clips from public URLs)
-- and a few replies.
insert into seed_posts (key, handle, kind, ref, mins, img, video, body) values
('x_coachr1','coachramon','p',null,140,0,null,$$Practice rule this week: no one touches the ball until they've set a screen. Ugly drills win games. #HoopsSeason$$),
('x_coachr2','coachramon','p',null,1900,1,null,$$Film room with the boys. We lost by 2 and I can point to 5 possessions that decided it. Learning day, not blame day.$$),
('x_coachr3','coachramon','p',null,4300,0,null,$$Tip for young players: your left hand is a muscle. Dribble with it in the dark, in the car, in line at the canteen.$$),
('x_speedy1','speedyselene','p',null,75,1,null,$$5 AM long run along the bay. The sunrise showed up even though I almost didn't. 32 km done. 🏃‍♀️$$),
('x_speedy2','speedyselene','p',null,1300,0,null,$$Reminder for new runners: slow is not failing. Slow is how everyone starts. Slow is how everyone finishes, too.$$),
('x_speedy3','speedyselene','p',null,3600,0,null,$$Race week. I'm nervous, carbo-loading and pretending I'm calm. Wish me luck on Sunday! #workout$$),
('x_harana1','harana_hub','p',null,160,1,null,$$THIS THURSDAY: Acoustic Night with 6 new artists, free entry, one very good cup of barako. Come early for seats. #OPM$$),
('x_harana2','harana_hub','p',null,1500,0,null,$$Open mic rule: if you're scared, you're in the right place. Sign-up sheet opens at 6 PM. #OPM$$),
('x_harana3','harana_hub','p',null,4000,0,null,$$Throwback to last week's duet that made the whole bar go quiet. Some songs don't need a sound system.$$),
('x_beatsb1','beatsbyrio','p',null,120,0,null,$$Sampled a tricycle horn today. It's in key, somehow. Beat drops tomorrow. #NewMusicFriday$$),
('x_beatsb2','beatsbyrio','p',null,2400,1,null,$$My bedroom studio, shown without cleaning first. Two speakers, one MIDI keyboard, a very supportive pillow fort.$$),
('x_beatsb3','beatsbyrio','p',null,5000,0,null,$$Producer tip: delete your first idea once. If you still remember it tomorrow, it was good.$$),
('x_violet1','violetsessions','p',null,95,1,null,$$NEW SESSION: Nightbloom performs 'Paper Moon' live, one take, no edits. Link in the thread. #NewMusicFriday$$),
('x_violet2','violetsessions','p',null,1700,0,null,$$Our rule: no autotune, no fixing in post, no pretending. Just a room and a song. #OPM$$),
('x_violet3','violetsessions','p',null,4100,0,null,$$Which artist should we invite next? Reply with your pick, we read everything.$$),
('x_series1','serieswithsam','p',null,110,0,null,$$No-spoiler review: the new thriller series is 8 episodes and every one ends on a cliffhanger. My sleep schedule is gone. series$$),
('x_series2','serieswithsam','p',null,2000,0,null,$$Hot take: rewatching a show you love is not wasting time, it's maintaining a relationship. #NowShowing$$),
('x_series3','serieswithsam','p',null,4700,0,null,$$Weekend watchlist: one comedy, one slow drama, one documentary about octopuses. Balance. movies$$),
('x_animea1','animeatlas','p',null,85,1,null,$$SEASON GUIDE: 7 anime worth your time this fall, from cozy slice-of-life to a space opera with a surprisingly good soundtrack. anime$$),
('x_animea2','animeatlas','p',null,1400,0,null,$$Fan note: openings are better when you don't skip them. Prove me wrong. 🎵$$),
('x_animea3','animeatlas','p',null,3900,0,null,$$Streaming schedule updated for the week. Episode times are in PH time, bookmark this thread.$$),
('x_street1','streetfoodmnl','p',null,60,1,null,$$Isaw rating of the night: crispy outside, smoky inside, suka with just enough sili. 9/10, would line up again. 🍢 #FoodPH$$),
('x_street2','streetfoodmnl','p',null,1100,0,null,$$Taho at 6 AM beats any fancy coffee. Fight me. #FoodPH$$),
('x_street3','streetfoodmnl','p',null,3300,1,null,$$Night market haul: kwek-kwek, fishball, fried banana and a very sweet cup of buko juice. Total: 120 pesos. food$$),
('x_bakerb1','bakerbea','p',null,130,1,null,$$Ube cheese pandesal, fresh out of the oven. The purple dough is real, the smell is illegal. Orders open Monday. #FoodPH$$),
('x_bakerb2','bakerbea','p',null,2100,0,null,$$Baking tip: room temperature eggs. It matters. I will not elaborate. I will just say: trust me.$$),
('x_bakerb3','bakerbea','p',null,4800,0,null,$$Someone asked if I get tired of baking. Yes. And then I smell bread and forget I was tired. food$$),
('x_roamin1','roamingrafael','p',null,180,1,null,$$Summit sunrise at Mt. Pulag: 3 degrees, sea of clouds, 40 strangers who became friends in 10 minutes. #TravelDiaries$$),
('x_roamin2','roamingrafael','p',null,2500,0,null,$$Packing list for a day hike: water, a rain jacket, snacks and the trash you'll carry back. travel$$),
('x_roamin3','roamingrafael','p',null,5300,0,null,$$Hiking taught me this: nobody remembers the fast hikers. Everybody remembers the ones who shared their baon.$$),
('x_island1','islandhopper_ph','p',null,100,1,null,$$Budget plan for Coron, 4 days: 6,800 pesos including island hopping, food and a hostel with a view. Details in the thread. #TravelDiaries$$),
('x_island2','islandhopper_ph','p',null,1800,0,null,$$Boat schedule update: last trip from Bantayan is at 4 PM, not 5. Plan your day around it. travel$$),
('x_island3','islandhopper_ph','p',null,4200,0,null,$$Travel tip: bring small bills. Boatmen and market vendors rarely have change for 1,000. vacation$$),
('x_devdan1','devdaniela','p',null,90,0,null,$$Code review rule: comment on the code, never on the coder. Also, 'looks good to me' is not a review. #Flutter coding$$),
('x_devdan2','devdaniela','p',null,1600,0,null,$$Spent the morning deleting 400 lines of code. Best commit of the week. software$$),
('x_devdan3','devdaniela','p',null,3800,0,null,$$Interview tip: say 'I don't know, but here's how I'd find out'. Everyone respects that. programming$$),
('x_devdan4','devdaniela','p',null,6000,0,null,$$Learning a framework is easy. Learning when NOT to use it is the senior part. #Flutter$$),
('x_gadget1','gadgetgus','p',null,70,1,null,$$Review: the new budget phone has a 90 Hz screen, a 5,000 mAh battery and a camera that struggles at night. Worth it at 11,990? tech$$),
('x_gadget2','gadgetgus','p',null,1900,0,null,$$Hot take: nobody needs a phone that charges in 10 minutes if the battery lasts 2 days. technology$$),
('x_gadget3','gadgetgus','p',null,4400,0,null,$$Charger buying tip: check the wattage, not the brand. And please stop using that 50-peso cable overnight.$$),
('x_aiweek1','aiweekly_ph','p',null,55,0,null,$$THIS WEEK IN AI: a new open model for Tagalog, a local startup using AI for crop diseases, and a reminder to double-check what the chatbot says. technology$$),
('x_aiweek2','aiweekly_ph','p',null,1300,0,null,$$Explainer: what is a 'context window' and why your chatbot forgets things? 5 sentences, no jargon. #AI$$),
('x_aiweek3','aiweekly_ph','p',null,3500,0,null,$$Using AI at work? Three rules: never paste secrets, always verify facts, and keep the human decision with the human.$$),
('x_financ1','financewithfe','p',null,125,0,null,$$Emergency fund first: 3 months of expenses in a boring savings account. Investing comes after you can survive a bad month. finance$$),
('x_financ2','financewithfe','p',null,2300,0,null,$$Your first 13th month pay: 50% to savings, 30% to debt, 20% for fun. Fun is allowed. #StartupLife$$),
('x_financ3','financewithfe','p',null,4600,0,null,$$If a coworker says 'guaranteed 20% monthly returns', run. Not walk. Run. Not financial advice, just common sense.$$),
('x_smallb1','smallbizsari','p',null,150,1,null,$$Tindahan owners: a printed QR code beside the cashier increased one store's digital payments from 5% to 40% in a month. business$$),
('x_smallb2','smallbizsari','p',null,2000,0,null,$$Sellers: reply to messages within 10 minutes. Speed beats a fancy logo every time. #StartupLife$$),
('x_smallb3','smallbizsari','p',null,4900,0,null,$$Inventory tip: write down what you sold every night. A notebook is a better business tool than a new phone.$$),
('x_drmig1','dr_miguel_md','p',null,115,0,null,$$Health tip: if your cough lasts more than 3 weeks, see a doctor. Don't just keep buying cough syrup. health$$),
('x_drmig2','dr_miguel_md','p',null,1700,0,null,$$Reminder: drink water, walk daily, sleep 7 hours. Boring, free and still the best medicine. General info only.$$),
('x_drmig3','dr_miguel_md','p',null,4100,0,null,$$Please check expiry dates on your medicine cabinet. A weekend is all it takes.$$),
('x_yogawi1','yogawithyna','p',null,95,1,null,$$10-minute morning stretch for desk workers: neck rolls, cat-cow, forward fold. No mat needed, a towel works. 🧘 #workout$$),
('x_yogawi2','yogawithyna','p',null,1800,0,null,$$You don't have to touch your toes. You have to show up and breathe. Flexibility is a side effect. health$$),
('x_yogawi3','yogawithyna','p',null,4400,0,null,$$Evening ritual: lights low, phone away, five slow breaths. Try it tonight.$$),
('x_thrift1','thriftkingjay','p',null,105,1,null,$$Ukay haul: vintage denim jacket (180), wool scarf (60), leather belt (90). Total: 330 pesos. Style is not about price. #ootd fashion$$),
('x_thrift2','thriftkingjay','p',null,2200,0,null,$$Thrift rule: smell test, seam test, zipper test. Then bargain politely. style$$),
('x_thrift3','thriftkingjay','p',null,4900,1,null,$$Styling one white shirt five ways: tucked, knotted, layered, oversized and as a jacket. outfit$$),
('x_titom1','tito_memes','p',null,30,1,null,$$Good morning! Wishing everyone a blessed Monday and an unlimited WiFi connection. Forwarded as received. meme$$),
('x_titom2','tito_memes','p',null,700,0,null,$$Tito at the family reunion: 'So, when are you getting married?' Me: 'When are you getting your own phone?' lol$$),
('x_titom3','tito_memes','p',null,2600,1,null,$$Pamilya meeting: 1 person talking, 14 people typing 'noted' funny$$),
('x_titom4','tito_memes','p',null,5600,0,null,$$The 'K' reply is the loudest sound in the world. meme$$),
('x_relata1','relatablerina','p',null,45,0,null,$$me: I'll only check my phone for a minute. also me: it's been 3 hours and I'm looking at someone's 2017 trip photos. lol$$),
('x_relata2','relatablerina','p',null,900,1,null,$$Opening the fridge every 10 minutes like new food will appear. It has not. It will not. I will check again. funny$$),
('x_relata3','relatablerina','p',null,3000,0,null,$$My roman empire is the conversation I had in 2019 and still replay in the shower. meme$$),
('x_valora1','valorantvince','p',null,80,0,null,$$Ranked tip: don't peek the same angle twice. Information is a currency, spend it wisely. gaming #GrandCupEsports$$),
('x_valora2','valorantvince','p',null,1500,0,null,$$Aim routine: 10 minutes of range, 5 minutes of deathmatch, then queue. Consistency over grinding for 6 hours. esports$$),
('x_valora3','valorantvince','p',null,4200,1,null,$$Stream setup is back after the move. Cable management: 6/10, vibes: 10/10. gaming$$),
('x_retrop1','retropixelria','p',null,120,1,null,$$Found a Game Boy Color in a box of old toys. Still works. Battery cover is missing but the nostalgia is not. gaming$$),
('x_retrop2','retropixelria','p',null,2300,0,null,$$Pixel art tip: limit yourself to 4 colors. You'll learn more about shape than any tutorial can teach.$$),
('x_retrop3','retropixelria','p',null,5100,0,null,$$Cartridge cleaning 101: cotton swab, a little isopropyl, patience. Blow on it if you must, for old times' sake.$$),
('x_kapli1','kap_lito','p',null,70,0,null,$$Paalala: paglilinis ng estero ngayong Sabado, 7 AM. Magdala ng guwantes at tubig. Maraming salamat, kapitbahay! #CityHallLive$$),
('x_kapli2','kap_lito','p',null,1500,0,null,$$Brgy. San Roque health center will offer free blood pressure checks every Wednesday. Dalhin ang inyong lolo't lola.$$),
('x_kapli3','kap_lito','p',null,3800,0,null,$$Natapos na ang bagong streetlight sa kanto ng Mabini. Salamat sa lahat ng nag-report. Kapag may problema, mag-message lang.$$),
('x_metrow1','metroweatherph','p',null,25,0,null,$$FORECAST: Scattered rain over Metro Manila this afternoon, 70% chance. Bring an umbrella and avoid low-lying areas after 4 PM. ☔$$),
('x_metrow2','metroweatherph','p',null,480,1,null,$$Satellite image: the cloud band over Luzon is moving slowly west. Expect on-and-off rain for the next 24 hours. #BreakingNews$$),
('x_metrow3','metroweatherph','p',null,1900,0,null,$$HEAT INDEX: 41 degrees Celsius expected in several areas tomorrow. Drink water and avoid direct sun from 11 AM to 3 PM.$$),
('x_metrow4','metroweatherph','p',null,4300,0,null,$$Reminder: rain advisories are updated at 5 AM, 11 AM, 5 PM and 11 PM. Turn on notifications.$$),
('x_teache1','teacherjoy','p',null,90,1,null,$$My Grade 5 class made a mini-garden out of recycled bottles. 37 kids, 40 bottles and zero fights over the watering can. 🌱$$),
('x_teache2','teacherjoy','p',null,1700,0,null,$$Teacher tip: write one kind sentence on a returned quiz. Kids remember that longer than the score.$$),
('x_teache3','teacherjoy','p',null,4000,0,null,$$Today a student said 'Ma'am, you're like a second mom' and I cried a little in the faculty room. Teaching is weird and beautiful.$$),
('x_petsof1','petsofpasig','p',null,50,1,null,$$Mochi the cat has claimed the laundry basket as her throne. Fresh clothes are optional. 🐈$$),
('x_petsof2','petsofpasig','p',null,1000,1,null,$$Meet Bantay, a rescue aspin who guards the sari-sari store and takes his job very seriously. #funny$$),
('x_petsof3','petsofpasig','p',null,3100,0,null,$$Reply with your pet's silliest habit. Mine eats paper and sits on keyboards. meme$$),
('x_sketch1','sketchsir_dan','p',null,135,1,null,$$Daily doodle #214: a jeepney full of cats. Pencil first, then ink, then a coffee stain by accident. #InktoberPH$$),
('x_sketch2','sketchsir_dan','p',null,2000,0,null,$$Quick tip: draw for 10 minutes a day instead of 2 hours once a week. Your hand remembers.$$),
('x_sketch3','sketchsir_dan','p',null,4600,1,null,$$Classroom sketchbook day. The kids drew their dreams. One drew a flying carabao. I'm giving him an A+.$$),
('v1','pixelpaolo','p',null,35,0,'https://assets.mixkit.co/videos/51612/51612-720.mp4',$$Clip of the stream: the exact moment chat lost its mind. Sound on. #GrandCupEsports gaming$$),
('v2','wanderlenka','p',null,210,0,'https://assets.mixkit.co/videos/7302/7302-720.mp4',$$Little visitor at the guesthouse garden this morning. Slow travel gives you time for tiny things. #TravelDiaries$$),
('v3','chefandrea','p',null,150,0,'https://assets.mixkit.co/videos/47555/47555-720.mp4',$$30-second stir-fry. The secret is a very hot pan and not crowding it. Recipe in the thread. #FoodPH$$),
('v4','gymwithgabe','p',null,100,0,'https://assets.mixkit.co/videos/40248/40248-720.mp4',$$Form check: push-ups with dumbbells. Elbows at 45 degrees, core tight. Try 3 sets and tell me. #workout$$),
('v5','memelord_ph','p',null,20,0,'https://assets.mixkit.co/videos/4801/4801-720.mp4',$$me trying to stay calm in the group chat after the 47th 'noted' lol meme$$),
('v6','courtsidenow','p',null,28,0,'https://assets.mixkit.co/videos/2285/2285-720.mp4',$$HIGHLIGHT: Valdez's handles and the dunk to finish it. #HoopsSeason$$),
('v7','djkaizen','p',null,130,0,'https://assets.mixkit.co/videos/831/831-720.mp4',$$Booth cam from last Friday's set. When the whole room sings the same line. 🎧 #NewMusicFriday$$),
('v8','frames_by_noa','p',null,400,0,'https://assets.mixkit.co/videos/50635/50635-720.mp4',$$Behind the lens this morning, trying a new 50mm before the light goes. 📷 #TravelDiaries$$),
('v9','speedyselene','p',null,70,0,'https://assets.mixkit.co/videos/609/609-720.mp4',$$Track session this morning, last lap in slow motion. Legs are done, heart is full. #workout$$),
('v10','streetfoodmnl','p',null,55,0,'https://assets.mixkit.co/videos/9278/9278-720.mp4',$$Sound on for the sizzle. Fresh fries straight from the hot oil. #FoodPH$$),
('v11','yogawithyna','p',null,120,0,'https://assets.mixkit.co/videos/42904/42904-720.mp4',$$A 60-second reset: inhale 4, hold 4, exhale 6. Do it three times before your next meeting. health$$),
('v12','roamingrafael','p',null,260,0,'https://assets.mixkit.co/videos/49337/49337-720.mp4',$$Trail to the waterfall at dawn. Birds, running water and my own heavy breathing. #TravelDiaries$$),
('v13','violetsessions','p',null,85,0,'https://assets.mixkit.co/videos/42845/42845-720.mp4',$$TEASER: our next live session drops tomorrow. Guess the artist by the guitar. #NewMusicFriday$$),
('v14','gadgetgus','p',null,190,0,'https://assets.mixkit.co/videos/4915/4915-720.mp4',$$First day with the new budget phone: typing feel and animations are smooth. Full review soon. tech$$),
('v15','petsofpasig','p',null,40,0,'https://assets.mixkit.co/videos/1779/1779-720.mp4',$$Mochi demands playtime and will not accept no for an answer. 🐈 funny$$),
('v16','devdaniela','p',null,170,0,'https://assets.mixkit.co/videos/41652/41652-720.mp4',$$Late-night debugging session, hands on keyboard and coffee nearby. #Flutter coding$$),
('v17','valorantvince','p',null,110,0,'https://assets.mixkit.co/videos/51604/51604-720.mp4',$$Mouse hand during yesterday's ranked clutch. Crosshair placement did the work. gaming #GrandCupEsports$$),
('v18','thriftkingjay','p',null,230,0,'https://assets.mixkit.co/videos/23327/23327-720.mp4',$$Rack hunting at the ukay today. Found three keepers and one 'maybe'. #ootd style$$),
('v19','metroweatherph','p',null,15,0,'https://assets.mixkit.co/videos/4695/4695-720.mp4',$$TIME-LAPSE: cloud cover building over the mountains ahead of tonight's rain. ☔ #BreakingNews$$),
('v20','kai_okonkwo','p',null,90,0,'https://assets.mixkit.co/videos/40948/40948-720.mp4',$$Ring work this morning. 12 rounds, one coach, zero excuses. 🥊$$),
('v21','lunaveil','p',null,60,0,'https://assets.mixkit.co/videos/490/490-720.mp4',$$Snippet from the rehearsal of 'Paper Lanterns', track 7. Please be gentle. 🏮 #NewMusicFriday$$),
('v22','dailybulletin','p',null,45,0,'https://assets.mixkit.co/videos/42574/42574-720.mp4',$$WATCH: Port Alder's new bus lane opens to commuters. Our reporter rides the first trip. #PortAlderTransit$$);

insert into seed_posts (key, handle, kind, ref, mins, img, video, body) values
('rn1','tito_memes','r','ml1',8,0,null,$$Forwarded to 15 groups. Maraming salamat po. 🙏 meme$$),
('rn2','relatablerina','r','ml1',9,0,null,$$the duck thing happens to me every single night lol$$),
('rn3','petsofpasig','r','ca1',90,0,null,$$My dog is staring at this plate through the phone. #FoodPH$$),
('rn4','streetfoodmnl','r','ca1',85,0,null,$$Adobo + garlic rice + egg is peak comfort. #FoodPH$$),
('rn5','devdaniela','r','jm4',4800,0,null,$$Congrats on the first app! Ship it ugly, polish it later. #Flutter$$),
('rn6','aiweekly_ph','r','tb2',1050,0,null,$$Good list. Number 4 saves people the most trouble.$$),
('rn7','metroweatherph','r','me4',4000,0,null,$$Rain bands will be heaviest from 8 PM to midnight. Please stay safe.$$),
('rn8','kap_lito','r','po1',25,0,null,$$Naka-post na po sa aming barangay hall ang schedule. Mag-ipon ng tubig.$$),
('rn9','speedyselene','r','ko1',100,0,null,$$Camp week 6 is the hardest. You've got this, champ. 🥊$$),
('rn10','financewithfe','r','so5',7000,0,null,$$Pay yourself first is the best advice in the thread.$$),
('rn11','yogawithyna','r','gg1',60,0,null,$$Adding a 2-minute stretch at the end makes this perfect. #workout$$),
('rn12','teacherjoy','r','ib1',190,0,null,$$My students would love this fox. Can I print it for the classroom?$$),
('rn13','harana_hub','r','tr1',130,0,null,$$Salamat sa inspirasyon, Tony. Come visit our Thursday night anytime. #OPM$$),
('rn14','animeatlas','r','cin2',950,0,null,$$Adding this to my weekend list. Thank you for the no-spoiler thread!$$),
('rn15','coachramon','r','mv1',28,0,null,$$6 AM sessions build a season. Respect from one coach to a player.$$);

-- Posts: top-level first, then quotes, then replies (they refer to earlier rows).
insert into public.posts (id, user_id, content, image_url, image_urls, video_url, parent_id, quote_id, created_at)
select
  md5('seed-post:' || sp.key)::uuid,
  md5('seed-user:' || sp.handle)::uuid,
  sp.body,
  si.urls[1],
  case when array_length(si.urls, 1) > 1 then si.urls else '{}' end,
  sp.video,
  case when sp.kind = 'r' then md5('seed-post:' || sp.ref)::uuid end,
  case when sp.kind = 'q' then md5('seed-post:' || sp.ref)::uuid end,
  now() - (sp.mins || ' minutes')::interval
from seed_posts sp
left join seed_img si on si.key = sp.key
order by case sp.kind when 'p' then 0 when 'q' then 1 else 2 end, sp.mins desc;

-- ---------------------------------------------------------------------
-- 3. Polls
-- ---------------------------------------------------------------------
with polls(key, handle, mins, body, opts) as (values
  ('poll1', 'courtsidenow', 90,
     $$MVP race: who gets your vote? #HoopsSeason$$,
     array['Marco Valdez','Jerome Dacanay','Andre Whitfield','Someone else']),
  ('poll2', 'memelord_ph', 240,
     $$Be honest: pineapple on pizza?$$,
     array['Yes, always','No, never','I''ll eat it anyway'])
), ins as (
  insert into public.posts (id, user_id, content, created_at, poll_ends_at)
  select md5('seed-post:' || key)::uuid, md5('seed-user:' || handle)::uuid, body,
         now() - (mins || ' minutes')::interval, now() + interval '20 hours'
  from polls
  returning id
)
insert into public.poll_options (id, post_id, label, position)
select md5('seed-option:' || p.key || ':' || o.n)::uuid, md5('seed-post:' || p.key)::uuid, o.label, o.n - 1
from polls p, unnest(p.opts) with ordinality as o(label, n);

-- Votes: put the votes in after the helper table exists (section 4).

-- ---------------------------------------------------------------------
-- 4. Followers, likes, reposts and views
-- ---------------------------------------------------------------------
-- random() that PostgreSQL has to evaluate once per row of the cross join
-- (a bare random() would be evaluated once per post / account instead).
-- It is plpgsql on purpose: a plain SQL function would be inlined again.
create or replace function pg_temp.rnd(anyelement) returns double precision
language plpgsql volatile as $f$ begin return random(); end $f$;

create temp table seed_users on commit drop as
select md5('seed-user:' || handle)::uuid as id, handle, true as is_person,
       (select tier from seed_people sp where sp.handle = x.handle) as tier
from (select handle from seed_people) x
union all
select md5('seed-user:' || handle)::uuid, handle, false, 0 from seed_fans;

-- Votes on the polls: most accounts vote for a random choice.
insert into public.poll_votes (post_id, option_id, user_id, created_at)
select v.post_id,
       (select o.id from public.poll_options o where o.post_id = v.post_id order by random() limit 1),
       v.uid,
       now() - interval '30 minutes'
from (
  select p.id as post_id, u.id as uid
  from public.posts p
  cross join seed_users u
  where p.poll_ends_at is not null
    and p.user_id in (select id from seed_users)
    and u.id <> p.user_id
    and pg_temp.rnd(u.id) < 0.7
) v
on conflict do nothing;

-- Everybody follows the big accounts more often than the small ones.
insert into public.follows (follower_id, following_id, created_at)
select f.id, t.id, now() - (random() * interval '80 days')
from seed_users f
join seed_users t on t.is_person and t.id <> f.id
where pg_temp.rnd(f.id) < case t.tier when 5 then 0.80 when 4 then 0.55 when 3 then 0.32 when 2 then 0.18 else 0.1 end
  and (not f.is_person or pg_temp.rnd(t.id) < 0.35)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 5. Communities (roles, rules, members, posts) and Lists (members,
--    followers). Needs schema.sql section 15.
--    Open communities: anyone can join. "request" ones have pending
--    join requests, so the admin / moderator screens have something to show.
-- ---------------------------------------------------------------------
create temp table seed_comm (
  key      text primary key,
  name     text not null,
  descr    text not null,
  category text not null,
  policy   text not null,
  owner    text not null,
  mods     text[] not null,
  members  text[] not null,
  fan_rate double precision not null
) on commit drop;

insert into seed_comm (key, name, descr, category, policy, owner, mods, members, fan_rate) values
('hoops', 'Hoops Philippines', $$Everything basketball: PBA, UAAP, street ball and your hot takes. Respect the game.$$, 'Sports', 'open',
  'marcovaldez_', '{courtsidenow,coachramon}', '{kai_okonkwo,speedyselene,jasmine_serve,sofia_strikes,rheaplays}', 0.60),
('flutterph', 'Flutter Developers PH', $$Flutter and Dart devs in the Philippines. Ask questions, share apps, post tips and meetups.$$, 'Technology', 'open',
  'devdaniela', '{jo_mercado_dev,techbrief_ph}', '{startupsam,gadgetgus,aiweekly_ph,drnadia_sci}', 0.45),
('foodtrip', 'Pinoy Food Trip', $$From turo-turo to fine dining. Share recipes, street food finds and the best silog in town.$$, 'Food', 'open',
  'chefandrea', '{streetfoodmnl,bakerbea}', '{islandhopper_ph,roamingrafael,wanderlenka,tito_memes}', 0.55),
('opmheads', 'OPM Heads', $$Original Pilipino Music: new releases, throwbacks, gig news and playlists.$$, 'Music', 'open',
  'tonyreyes_opm', '{harana_hub,beatsbyrio}', '{lunaveil,nightbloom_mx,djkaizen,violetsessions,kpopdaily_ph}', 0.50),
('valorantph', 'Valorant PH Ranked', $$Find a squad, talk agents and climb the ladder. Ranked players only, Radiant to Iron.$$, 'Gaming', 'request',
  'valorantvince', '{rheaplays,pixelpaolo}', '{retropixelria,animeatlas}', 0.30),
('cinephiles', 'Cinephiles Club', $$Film lovers talk about what they watched. Spoiler tags are mandatory. Asking to join keeps it civil.$$, 'Entertainment', 'request',
  'cinemanotes', '{serieswithsam,mikaelasy_film}', '{diegomontero,animeatlas,inkbyisla}', 0.35),
('travelers', 'Weekend Travelers', $$Budget trips, hidden beaches and day hikes near Manila. Slow travel welcome.$$, 'Travel', 'open',
  'wanderlenka', '{islandhopper_ph,frames_by_noa}', '{roamingrafael,streetfoodmnl,yogawithyna}', 0.45),
('startupph', 'Startup and Side Hustle PH', $$Founders, freelancers and small business owners trading lessons and leads.$$, 'Business', 'open',
  'startupsam', '{financewithfe,smallbizsari}', '{coinwatchdaily,techbrief_ph,devdaniela}', 0.35),
('fitpinoy', 'Fit Filipino', $$Workouts, healthy eating on a budget and honest progress. No shaming, only support.$$, 'Sports', 'open',
  'gymwithgabe', '{yogawithyna,dr_miguel_md}', '{kai_okonkwo,speedyselene}', 0.40),
('memes', 'Meme Dump PH', $$Pinoy memes, relatable posts and good vibes. Credit the creator.$$, 'Entertainment', 'open',
  'memelord_ph', '{tito_memes,relatablerina}', '{jokerjules,petsofpasig,pixelpaolo}', 0.65),
('sketchbook', 'Art and Sketchbook', $$Show your WIPs, finished pieces and sketchbook pages. Beginners are welcome here.$$, 'Art', 'open',
  'sketchsir_dan', '{inkbyisla,muralmarcus}', '{frames_by_noa,teacherjoy}', 0.30),
('civictalk', 'Port Alder Civic Talk', $$Talk about city services, transport and local issues with respect. Moderated.$$, 'Politics', 'request',
  'portalder_gov', '{mayor_elena,kap_lito}', '{sen_marlonvega,dailybulletin,metroweatherph}', 0.25),
('thrift', 'Thrift and OOTD', $$Ukay-ukay hauls, outfit checks and styling on a budget.$$, 'General', 'open',
  'thriftkingjay', '{bianca_ootd}', '{relatablerina,jasmine_serve}', 0.35);

insert into public.communities
  (id, owner_id, name, description, category, image_url, cover_url, join_policy, created_at)
select md5('seed-community:' || c.key)::uuid,
       md5('seed-user:' || c.owner)::uuid,
       c.name, c.descr, c.category,
       (select si.urls[2] from seed_img si where si.key = 'comm:' || c.key),
       (select si.urls[1] from seed_img si where si.key = 'comm:' || c.key),
       c.policy,
       now() - ((30 + abs(hashtext(c.key)) % 200) || ' days')::interval
from seed_comm c;

insert into public.community_members (community_id, user_id, role, created_at)
select md5('seed-community:' || c.key)::uuid, md5('seed-user:' || c.owner)::uuid, 'admin',
       now() - interval '60 days'
from seed_comm c
union all
select md5('seed-community:' || c.key)::uuid, md5('seed-user:' || m)::uuid, 'moderator',
       now() - interval '45 days'
from seed_comm c, unnest(c.mods) m
union all
select md5('seed-community:' || c.key)::uuid, md5('seed-user:' || m)::uuid, 'member',
       now() - ((1 + abs(hashtext(c.key || m)) % 40) || ' days')::interval
from seed_comm c, unnest(c.members) m
on conflict do nothing;

-- Background fans fill the member counts.
insert into public.community_members (community_id, user_id, role, created_at)
select md5('seed-community:' || c.key)::uuid, f.id, 'member',
       now() - random() * interval '40 days'
from seed_comm c
cross join seed_users f
where not f.is_person and pg_temp.rnd(f.id) < c.fan_rate
on conflict do nothing;

-- Pending join requests for the "ask to join" communities.
insert into public.community_join_requests (community_id, user_id, created_at)
select md5('seed-community:' || c.key)::uuid, u.id, now() - random() * interval '3 days'
from seed_comm c
cross join seed_users u
where c.policy = 'request'
  and u.is_person
  and not exists (
    select 1 from public.community_members m
    where m.community_id = md5('seed-community:' || c.key)::uuid and m.user_id = u.id
  )
  and pg_temp.rnd(u.id) < 0.07
on conflict do nothing;

-- Rules (every community has 3 or 4).
create temp table seed_rules (key text, pos int, title text, descr text) on commit drop;
insert into seed_rules values
('hoops', 0, 'Keep it about basketball', $$Posts should be about the sport, players, teams or leagues.$$),
('hoops', 1, 'Respect players and fans', $$Trash talk the play, not the person. No slurs, no threats.$$),
('hoops', 2, 'Spoiler warning', $$Put "spoiler" in your post when you share a final score of a game that has not aired yet.$$),
('flutterph', 0, 'Be kind', $$Everyone started somewhere. Help, do not mock.$$),
('flutterph', 1, 'Show your code', $$Questions with a short code sample or a screenshot get answered faster.$$),
('flutterph', 2, 'No job spam', $$Hiring posts are fine once a week. Mass DMs are not.$$),
('foodtrip', 0, 'Food only', $$Recipes, restaurants, street food, kitchen tips.$$),
('foodtrip', 1, 'Credit your photos', $$Post your own pictures or say where they come from.$$),
('foodtrip', 2, 'No shaming', $$No comments about what other people eat or how they cook it.$$),
('opmheads', 0, 'Support Filipino artists', $$New and old OPM only. Other genres go to other communities.$$),
('opmheads', 1, 'No piracy links', $$Share Spotify, YouTube or the artist's own page.$$),
('opmheads', 2, 'Be respectful in the comments', $$Taste is personal. Disagree politely.$$),
('valorantph', 0, 'Ranked players only', $$Share your rank when you ask to join. Smurfs are removed.$$),
('valorantph', 1, 'No toxicity', $$Flame in game is bad enough. Not here.$$),
('valorantph', 2, 'No cheating talk', $$No cheats, boosting or account selling.$$),
('valorantph', 3, 'LFG in the LFG thread', $$Looking-for-group posts go in the pinned thread.$$),
('cinephiles', 0, 'Mark spoilers', $$Write "spoiler" at the start of the post and keep plot twists out of the first line.$$),
('cinephiles', 1, 'Talk about films, not people', $$Critique the movie. Do not attack the people who like it.$$),
('cinephiles', 2, 'No pirated links', $$Say where it is streaming. Do not link to copies.$$),
('travelers', 0, 'Real trips, real photos', $$Share places you went to, with honest costs when you can.$$),
('travelers', 1, 'Leave no trace', $$No posts that promote littering or harming wildlife.$$),
('travelers', 2, 'No paid promos without a label', $$Use the paid partnership label when you are sponsored.$$),
('startupph', 0, 'Give before you ask', $$Share a lesson or a result before you pitch.$$),
('startupph', 1, 'No get-rich-quick posts', $$No pyramid schemes, no "DM me to earn".$$),
('startupph', 2, 'Keep numbers honest', $$Do not post fake revenue or fake testimonials.$$),
('fitpinoy', 0, 'Support, not shaming', $$Every body and every pace is welcome.$$),
('fitpinoy', 1, 'No medical advice', $$Share what worked for you, not diagnoses. Ask a doctor.$$),
('fitpinoy', 2, 'No supplement spam', $$Selling posts are removed.$$),
('memes', 0, 'Credit the creator', $$If it is not yours, say who made it.$$),
('memes', 1, 'No hate', $$No jokes that attack people for who they are.$$),
('memes', 2, 'No spam or self-promotion', $$Follow-for-follow and promo posts get hidden.$$),
('sketchbook', 0, 'Only your own art', $$Post your own work. Trace and fan art must say so.$$),
('sketchbook', 1, 'Kind critique only', $$Ask before giving feedback. Say what works first.$$),
('sketchbook', 2, 'Label AI images', $$Do not present made-with-AI images as hand-made.$$),
('civictalk', 0, 'Stay on local topics', $$City services, transport, schools, safety and events.$$),
('civictalk', 1, 'Respect other opinions', $$Argue with facts. No insults.$$),
('civictalk', 2, 'No misinformation', $$Link a source for claims about numbers or laws.$$),
('civictalk', 3, 'No doxxing', $$Never share private information about residents or staff.$$),
('thrift', 0, 'Share prices and places', $$Where did you buy it and how much was it?$$),
('thrift', 1, 'Be kind about style', $$Compliment first. No body comments.$$),
('thrift', 2, 'No reselling spam', $$Selling is allowed on Sundays only, one post each.$$);

insert into public.community_rules (community_id, position, title, description)
select md5('seed-community:' || r.key)::uuid, r.pos, r.title, r.descr from seed_rules r;

-- Posts inside the communities.
create temp table seed_cposts (
  key text primary key, comm text not null, handle text not null,
  mins int not null, img int not null default 0, video text, body text not null
) on commit drop;

insert into seed_cposts (key, comm, handle, mins, img, video, body) values
('c_hoops1','hoops','marcovaldez_',60,2,null,$$Shootaround before tonight's game. Legs feel good, shots feel better. Who is watching? 🏀$$),
('c_hoops2','hoops','courtsidenow',180,0,null,$$Power rankings are in. The top three changed places again after that overtime thriller.$$),
('c_hoops3','hoops','coachramon',420,0,null,$$Reminder to young point guards: pass first, score second. The assist is the best shot in the game.$$),
('c_hoops4','hoops','kai_okonkwo',900,1,null,$$Cross-training day: ropes, boxing and a little hoops. Footwork is footwork.$$),
('c_hoops5','hoops','rheaplays',1700,0,null,$$Hot take: the three-point line is not the problem. The long closeouts are. Fight me nicely.$$),
('c_hoops6','hoops','speedyselene',3300,0,null,$$Who is your pick for Rookie of the Year? Mine is the kid with the left-handed floater.$$),
('c_flu1','flutterph','devdaniela',45,0,'https://assets.mixkit.co/videos/41654/41654-720.mp4',$$Late-night coding session: working on stopping a list from rebuilding with const widgets and keys. #Flutter$$),
('c_flu2','flutterph','jo_mercado_dev',200,0,null,$$Question: do you prefer Riverpod or Bloc for a mid-size app? I will summarise the answers in the thread.$$),
('c_flu3','flutterph','techbrief_ph',500,0,null,$$Dart 3 tip: records and pattern matching clean up a lot of tuple-ish code. Try them in your next PR.$$),
('c_flu4','flutterph','gadgetgus',1200,1,null,$$Testing my app on a 4-year-old budget phone is humbling. Your animations may need a diet.$$),
('c_flu5','flutterph','startupsam',2600,0,null,$$Looking for a Flutter dev for a small delivery app. Two-week contract. Comment, no DMs please.$$),
('c_flu6','flutterph','aiweekly_ph',4100,0,null,$$Free resource: a checklist for publishing your first app to the stores. Reply and I will share the link.$$),
('c_food1','foodtrip','chefandrea',75,3,null,$$Sunday sinigang with extra sampalok and a squeeze of calamansi. Rice is already cooked. 🍲$$),
('c_food2','foodtrip','streetfoodmnl',300,2,null,$$Best isaw in the city? Our top three after a very long night of research.$$),
('c_food3','foodtrip','bakerbea',700,1,null,$$Ensaymada test batch #4: less sugar, more butter. Neighbours are voting.$$),
('c_food4','foodtrip','islandhopper_ph',1500,0,null,$$Cebu lechon vs Luzon lechon. Please be civil. I will go first: both.$$),
('c_food5','foodtrip','roamingrafael',2800,1,null,$$Found a tiny carinderia that sells kare-kare for 90 pesos. Sauce is thick and perfect.$$),
('c_food6','foodtrip','tito_memes',4500,0,null,$$Rice cooker rule: if the rice is warm, the day is warm. #FoodTrip$$),
('c_opm1','opmheads','tonyreyes_opm',90,0,null,$$Writing a new song about jeepney rides in the rain. Chorus is done, bridge is a mess.$$),
('c_opm2','opmheads','harana_hub',350,1,null,$$This week's playlist: 20 OPM songs from the 90s that still hit. Link below.$$),
('c_opm3','opmheads','beatsbyrio',800,0,null,$$Producer tip: leave space in the mix for the vocal. OPM is about the lyrics.$$),
('c_opm4','opmheads','lunaveil',1900,0,null,$$Thank you for the love on "Paper Lanterns". I read every comment, even the 3am ones. ✨$$),
('c_opm5','opmheads','nightbloom_mx',3000,2,null,$$Last Friday's gig: four bands, one small stage, zero chairs.$$),
('c_opm6','opmheads','violetsessions',5200,0,null,$$Which OPM song do you play when you miss home? Mine is a very old harana.$$),
('c_val1','valorantph','valorantvince',100,0,null,$$Weekly ranked thread is up. Post your rank, your main and your lineup question.$$),
('c_val2','valorantph','rheaplays',400,0,null,$$Duelist tip: do not peek the same angle twice. Information wins rounds.$$),
('c_val3','valorantph','pixelpaolo',1100,0,null,$$Clutch of the week: 1v3 on defense with a knife and a dream.$$),
('c_val4','valorantph','retropixelria',2400,0,null,$$Looking for a duo, Gold/Plat, evenings GMT+8. Chill players only.$$),
('c_val5','valorantph','animeatlas',4000,0,null,$$If your team loses because of mute people, remember the mute button exists. Breathe.$$),
('c_cin1','cinephiles','cinemanotes',120,1,null,$$This week: three films, one thread. Spoiler warning is on in the comments.$$),
('c_cin2','cinephiles','serieswithsam',500,0,null,$$Slow cinema is not boring. It is just quiet. Give it twenty minutes.$$),
('c_cin3','cinephiles','mikaelasy_film',1300,1,null,$$Behind the scenes of our short film: one lamp, two actors, a very patient cat.$$),
('c_cin4','cinephiles','diegomontero',2500,0,null,$$Name a movie that made you cry in the cinema and then walk home slowly.$$),
('c_cin5','cinephiles','inkbyisla',4200,1,null,$$Made a poster for a film that does not exist. Please tell me who stars in it.$$),
('c_trav1','travelers','wanderlenka',130,3,null,$$Sunrise at a tiny beach two hours from the city. Tide was low and the coffee was hot.$$),
('c_trav2','travelers','islandhopper_ph',450,2,null,$$Budget guide: 3 days in Palawan under 8,000 pesos including tours.$$),
('c_trav3','travelers','frames_by_noa',950,2,null,$$Golden hour on the rice terraces. No filter, just patience.$$),
('c_trav4','travelers','roamingrafael',2000,1,null,$$Day hike tip: start at 5 AM, pack a rain jacket, and carry out your trash.$$),
('c_trav5','travelers','yogawithyna',3800,0,null,$$Stretch routine for after a long bus ride. Ten minutes, no equipment.$$),
('c_biz1','startupph','startupsam',150,0,null,$$Lesson from our first 100 customers: they do not want features, they want answers on time.$$),
('c_biz2','startupph','financewithfe',600,0,null,$$Freelancers: set aside 20 percent of every invoice for tax. Future you says thanks.$$),
('c_biz3','startupph','smallbizsari',1400,1,null,$$Our sari-sari store now takes QR payments. Customers love it, and so does my coin jar.$$),
('c_biz4','startupph','techbrief_ph',2700,0,null,$$Question for founders: how do you decide when to stop a side project?$$),
('c_biz5','startupph','coinwatchdaily',4400,0,null,$$Reminder: never invest money you cannot afford to lose. That includes your rent.$$),
('c_fit1','fitpinoy','gymwithgabe',70,1,null,$$Beginner full-body routine: squats, push-ups, rows. Three sets, two minutes rest, go.$$),
('c_fit2','fitpinoy','yogawithyna',380,0,null,$$Mobility Monday: ten minutes for stiff shoulders. Your desk job will thank you.$$),
('c_fit3','fitpinoy','dr_miguel_md',1000,0,null,$$Sleep is part of your training plan. Seven hours is not a luxury.$$),
('c_fit4','fitpinoy','kai_okonkwo',2200,0,null,$$Rest day does not mean lazy day. It means the muscles are growing.$$),
('c_fit5','fitpinoy','speedyselene',3600,1,null,$$Morning run along the bay. Slow pace, big sky.$$),
('c_meme1','memes','memelord_ph',50,1,null,$$me: I will sleep early tonight. also me at 2 AM: let me check one more thing$$),
('c_meme2','memes','relatablerina',250,0,null,$$Group chat: "see you at 7". Everyone at 7:45: "otw"$$),
('c_meme3','memes','jokerjules',650,0,null,$$If traffic was an Olympic sport, we would have a lot of gold medals.$$),
('c_meme4','memes','petsofpasig',1600,1,null,$$When the cat sees you open a can of anything. Any can.$$),
('c_meme5','memes','pixelpaolo',3100,0,null,$$Loading screen: 99 percent. My patience: 0 percent$$),
('c_meme6','memes','tito_memes',500,0,null,$$Follow for follow!! DM me for promo codes 🔥🔥 click my profile now$$),
('c_art1','sketchbook','sketchsir_dan',160,2,null,$$Reference photos for sketchbook page #31: market vendors. The umbrellas will take longer than the people.$$),
('c_art2','sketchbook','inkbyisla',700,1,null,$$Practising hands today. They are the final boss of drawing.$$),
('c_art3','sketchbook','muralmarcus',1500,2,null,$$Mural progress: day 5. The wall is bigger than my plan. Coffee count: too many.$$),
('c_art4','sketchbook','frames_by_noa',2900,1,null,$$Not drawing, but here is a photo that inspired my next sketch.$$),
('c_art5','sketchbook','teacherjoy',4300,1,null,$$My students drew their favourite subject. One drew lunch. A+ for honesty.$$),
('c_civ1','civictalk','portalder_gov',110,0,null,$$Public hearing on the new bus lanes is on Thursday, 3 PM at the city hall annex. Everyone is welcome.$$),
('c_civ2','civictalk','mayor_elena',420,0,null,$$Thank you for the feedback on the market renovation. We are adjusting the schedule for vendors.$$),
('c_civ3','civictalk','kap_lito',1200,1,null,$$Barangay clean-up this Saturday. Bring gloves and a sack. Free merienda for volunteers.$$),
('c_civ4','civictalk','metroweatherph',2100,0,null,$$Rain advisory for the coming evening. Please avoid low-lying streets and keep emergency numbers ready.$$),
('c_civ5','civictalk','dailybulletin',3500,0,null,$$Explainer: how the Clean Commute Act would change fares and routes, in five points.$$),
('c_thr1','thrift','thriftkingjay',95,2,null,$$Ukay haul: a vintage denim jacket for 250 pesos and a belt for 60. Win.$$),
('c_thr2','thrift','bianca_ootd',540,2,null,$$Outfit check: thrifted blazer, white tee, wide trousers. Total cost under 700 pesos.$$),
('c_thr3','thrift','relatablerina',1400,0,null,$$The ukay-ukay rule: if you stop and think "maybe", it is already yours.$$),
('c_thr4','thrift','jasmine_serve',2300,1,null,$$Court shoes for 400 pesos, barely worn. I will take care of them like gold.$$);

insert into public.posts
  (id, user_id, content, image_url, image_urls, video_url, community_id, created_at)
select md5('seed-post:' || sp.key)::uuid,
       md5('seed-user:' || sp.handle)::uuid,
       sp.body,
       si.urls[1],
       case when array_length(si.urls, 1) > 1 then si.urls else '{}' end,
       sp.video,
       md5('seed-community:' || sp.comm)::uuid,
       now() - (sp.mins || ' minutes')::interval
from seed_cposts sp
left join seed_img si on si.key = sp.key
order by sp.mins desc;

-- One post the moderators already hid, so "Hidden posts" is not empty.
insert into public.community_hidden_posts (post_id, community_id, hidden_by, reason)
values (md5('seed-post:c_meme6')::uuid, md5('seed-community:memes')::uuid,
        md5('seed-user:memelord_ph')::uuid, 'No spam or self-promotion');

-- Lists.
create temp table seed_lists (
  key text primary key, owner text not null, name text not null, descr text not null,
  private boolean not null, members text[] not null, fan_rate double precision not null
) on commit drop;

insert into seed_lists (key, owner, name, descr, private, members, fan_rate) values
('hoops',   'courtsidenow',   'Hoops Daily',        $$Players, coaches and reporters for your daily basketball fix.$$, false,
  '{marcovaldez_,coachramon,speedyselene,jasmine_serve,kai_okonkwo,sofia_strikes}', 0.45),
('flutter', 'devdaniela',     'Flutter and Dart',   $$People who ship Flutter apps and share what they learn.$$, false,
  '{jo_mercado_dev,techbrief_ph,gadgetgus,aiweekly_ph,startupsam}', 0.35),
('opm',     'harana_hub',     'OPM Playlist',       $$Artists, bands and producers keeping Filipino music alive.$$, false,
  '{tonyreyes_opm,nightbloom_mx,lunaveil,beatsbyrio,djkaizen,violetsessions}', 0.50),
('eats',    'streetfoodmnl',  'Manila Eats',        $$Chefs, bakers and street food explorers. Come hungry.$$, false,
  '{chefandrea,bakerbea,roamingrafael,islandhopper_ph}', 0.40),
('tech',    'techbrief_ph',   'Tech News',          $$Short, useful tech and science updates from people who know.$$, false,
  '{aiweekly_ph,gadgetgus,drnadia_sci,startupsam,coinwatchdaily}', 0.40),
('gov',     'portalder_gov',  'Local Government',   $$Official accounts of Port Alder: city hall, mayor, barangay and weather.$$, false,
  '{mayor_elena,sen_marlonvega,kap_lito,metroweatherph,dailybulletin}', 0.30),
('funny',   'memelord_ph',    'Funny Accounts',     $$The accounts that make the timeline worth scrolling.$$, false,
  '{tito_memes,relatablerina,jokerjules,petsofpasig}', 0.55),
('creators','sketchsir_dan',  'Creators to Watch',  $$Artists, photographers and filmmakers with fresh work.$$, false,
  '{inkbyisla,muralmarcus,frames_by_noa,mikaelasy_film}', 0.25),
('gaming',  'valorantvince',  'Gaming',             $$Pro players, streamers and retro fans.$$, false,
  '{rheaplays,pixelpaolo,retropixelria,animeatlas}', 0.30),
('money',   'financewithfe',  'Money Moves',        $$Founders and finance people explaining money in plain words.$$, false,
  '{startupsam,smallbizsari,coinwatchdaily,techbrief_ph}', 0.25),
('travel',  'wanderlenka',    'Travel Inspo',       $$Trips, trails and photographers worth following.$$, false,
  '{islandhopper_ph,frames_by_noa,roamingrafael,streetfoodmnl}', 0.35),
('wellness','yogawithyna',    'Wellness',           $$Coaches and doctors for movement, food and sleep.$$, false,
  '{gymwithgabe,dr_miguel_md,drnadia_sci,speedyselene}', 0.30),
('movies',  'cinemanotes',    'Movie Night',        $$Reviewers and filmmakers for your next watchlist.$$, false,
  '{serieswithsam,diegomontero,mikaelasy_film,animeatlas}', 0.30),
('alerts',  'metroweatherph', 'Weather and Alerts', $$Weather, traffic and public advisories in one timeline.$$, false,
  '{portalder_gov,dailybulletin,mayor_elena}', 0.20),
('style',   'bianca_ootd',    'Style Watch',        $$Thrift finds and outfit ideas on a budget.$$, false,
  '{thriftkingjay,jasmine_serve}', 0.20),
('study',   'teacherjoy',     'Study Notes',        $$Private: accounts I read when I prepare lessons.$$, true,
  '{sketchsir_dan,drnadia_sci}', 0);

insert into public.lists (id, owner_id, name, description, is_private, banner_url, created_at)
select md5('seed-list:' || l.key)::uuid, md5('seed-user:' || l.owner)::uuid,
       l.name, l.descr, l.private,
       (select si.urls[1] from seed_img si where si.key = 'list:' || l.key),
       now() - ((10 + abs(hashtext(l.key)) % 120) || ' days')::interval
from seed_lists l;

insert into public.list_members (list_id, user_id, created_at)
select md5('seed-list:' || l.key)::uuid, md5('seed-user:' || m)::uuid, now() - interval '5 days'
from seed_lists l, unnest(l.members) m
on conflict do nothing;

insert into public.list_follows (list_id, user_id, created_at)
select md5('seed-list:' || l.key)::uuid, u.id, now() - random() * interval '30 days'
from seed_lists l
cross join seed_users u
where not l.private
  and u.id <> md5('seed-user:' || l.owner)::uuid
  and pg_temp.rnd(u.id) < case when u.is_person then l.fan_rate * 1.4 else l.fan_rate * 0.6 end
on conflict do nothing;

-- Notes (the 24-hour status at the top of the Chat tab). Only people who
-- follow the author see a note, so follow the demo accounts to see them.
insert into public.status_notes (user_id, content, created_at, expires_at)
select pr.id, n.content,
       now() - n.ago,
       now() - n.ago + interval '24 hours'
from (values
  ('marcovaldez_',   'Game day. Pray for my ankles 🏀',            interval '40 minutes'),
  ('lunaveil',       'Writing track 11 at 3am ✨',                  interval '2 hours'),
  ('chefandrea',     'Sinigang weather ☔',                         interval '3 hours'),
  ('jokerjules',     'Airport delayed again. Material +1',         interval '5 hours'),
  ('sofia_strikes',  'Rest day = walk with the dog',               interval '7 hours'),
  ('tonyreyes_opm',  'Anyone up for tropa jam tonight? 🎸',        interval '9 hours'),
  ('diegomontero',   'No spoilers. Pls.',                          interval '11 hours'),
  ('djkaizen',       'Friday set list is locked 🔒',               interval '14 hours'),
  ('rheaplays',      'Ranked grind, send coffee ☕',               interval '17 hours')
) as n(handle, content, ago)
join public.profiles pr on pr.username = n.handle
on conflict (user_id) do nothing;

-- Likes: probability depends on the author's tier and on how fresh the post is.
insert into public.post_likes (post_id, user_id, created_at)
select p.id, u.id,
       least(now() - interval '1 minute', p.created_at + random() * interval '2 days')
from public.posts p
join seed_users a on a.id = p.user_id
cross join seed_users u
where u.id <> p.user_id
  and p.parent_id is null
  and pg_temp.rnd(u.id) < (case a.tier when 5 then 0.72 when 4 then 0.52 when 3 then 0.30 when 2 then 0.16 else 0.08 end)
                  * least(1.0, 0.30 + extract(epoch from (now() - p.created_at)) / 60.0 / 1800.0)
on conflict do nothing;

-- Replies get a few likes too.
insert into public.post_likes (post_id, user_id, created_at)
select p.id, u.id, least(now() - interval '1 minute', p.created_at + random() * interval '1 day')
from public.posts p
cross join seed_users u
where p.parent_id is not null and u.id <> p.user_id and pg_temp.rnd(u.id) < 0.10
on conflict do nothing;

-- Reposts: fewer than likes.
insert into public.reposts (post_id, user_id, created_at)
select p.id, u.id, least(now() - interval '1 minute', p.created_at + random() * interval '1 day')
from public.posts p
join seed_users a on a.id = p.user_id
cross join seed_users u
where u.id <> p.user_id
  and p.parent_id is null
  and pg_temp.rnd(u.id) < (case a.tier when 5 then 0.10 when 4 then 0.07 when 3 then 0.04 when 2 then 0.02 else 0.01 end)
                  * least(1.0, 0.30 + extract(epoch from (now() - p.created_at)) / 60.0 / 1800.0)
on conflict do nothing;

-- Views: a multiple of the likes.
insert into public.post_views (post_id, views)
select p.id,
       greatest(25, (select count(*) from public.post_likes l where l.post_id = p.id) * (14 + (random() * 26)::int)
                   + (random() * 300)::int)
from public.posts p
where p.user_id in (select id from seed_users)
on conflict (post_id) do update set views = excluded.views;

commit;

-- ---------------------------------------------------------------------
-- Optional: make YOUR account follow every demo account, so the
-- "Following" tab is full too. Replace YOUR_USERNAME and run:
--
--   insert into public.follows (follower_id, following_id)
--   select (select id from public.profiles where username = 'YOUR_USERNAME'), pr.id
--   from public.profiles pr
--   join auth.users u on u.id = pr.id
--   where u.email like '%@seed.xreplica.test' and pr.onboarded
--   on conflict do nothing;
--
-- Also join the open communities and follow the public lists:
--
--   insert into public.community_members (community_id, user_id, role)
--   select c.id, (select id from public.profiles where username = 'YOUR_USERNAME'), 'member'
--   from public.communities c
--   join auth.users u on u.id = c.owner_id
--   where u.email like '%@seed.xreplica.test' and c.join_policy = 'open'
--   on conflict do nothing;
--
--   insert into public.list_follows (list_id, user_id)
--   select l.id, (select id from public.profiles where username = 'YOUR_USERNAME')
--   from public.lists l
--   join auth.users u on u.id = l.owner_id
--   where u.email like '%@seed.xreplica.test' and not l.is_private
--   on conflict do nothing;
--
-- To remove all demo data later:
--   delete from auth.users where email like '%@seed.xreplica.test';
-- ---------------------------------------------------------------------
