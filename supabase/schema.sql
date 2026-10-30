-- =====================================================================
--  X Replica (replica of the X social app) — Supabase schema
--  Run this whole file once in: Supabase Dashboard → SQL Editor → New query
--  Safe to re-run: uses IF NOT EXISTS / OR REPLACE / DROP POLICY IF EXISTS.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      text not null unique
                  check (username ~ '^[A-Za-z0-9_]{3,15}$'),
  display_name  text not null default '',
  bio           text not null default '' check (char_length(bio) <= 160),
  avatar_url    text,
  interests     text[] not null default '{}',
  -- false until the user finishes the sign-up steps (birthday, name, ...)
  onboarded     boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Upgrades for projects created with an older version of this file.
alter table public.profiles add column if not exists interests text[] not null default '{}';
alter table public.profiles add column if not exists onboarded boolean not null default true;
alter table public.profiles alter column onboarded set default false;
alter table public.profiles drop constraint if exists profiles_username_check;
alter table public.profiles add constraint profiles_username_check
  check (username ~ '^[A-Za-z0-9_]{3,15}$');
-- Usernames are unique regardless of capital letters (like on X).
create unique index if not exists profiles_username_lower_idx
  on public.profiles (lower(username));

-- Birthday is private: only its owner can read or change it.
create table if not exists public.profile_private (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  birthday  date
);

create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  content     text not null default '' check (char_length(content) <= 280),
  image_url   text,
  -- set when this post is a reply to another post
  parent_id   uuid references public.posts (id) on delete cascade,
  created_at  timestamptz not null default now(),
  check (char_length(btrim(content)) > 0 or image_url is not null)
);
alter table public.posts
  add column if not exists parent_id uuid references public.posts (id) on delete cascade;
create index if not exists posts_parent_idx  on public.posts (parent_id, created_at);
create index if not exists posts_created_idx on public.posts (created_at desc);
create index if not exists posts_user_idx    on public.posts (user_id, created_at desc);

create table if not exists public.post_likes (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- Reposts
create table if not exists public.reposts (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists reposts_user_idx on public.reposts (user_id, created_at desc);

-- View counters live in their own table (not in `posts`) so that counting a
-- view does not fire the realtime "posts changed" event.
create table if not exists public.post_views (
  post_id  uuid primary key references public.posts (id) on delete cascade,
  views    bigint not null default 0
);

-- Bookmarks: private list of saved posts
create table if not exists public.bookmarks (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists bookmarks_user_idx on public.bookmarks (user_id, created_at desc);

-- Follow mechanism: follower_id follows following_id
create table if not exists public.follows (
  follower_id   uuid not null references public.profiles (id) on delete cascade,
  following_id  uuid not null references public.profiles (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index if not exists follows_following_idx on public.follows (following_id);

-- Direct messages (1-to-1)
create table if not exists public.messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles (id) on delete cascade,
  receiver_id  uuid not null references public.profiles (id) on delete cascade,
  content      text not null check (char_length(btrim(content)) > 0
                                    and char_length(content) <= 2000),
  created_at   timestamptz not null default now(),
  read_at      timestamptz,
  check (sender_id <> receiver_id)
);
create index if not exists messages_pair_idx
  on public.messages (sender_id, receiver_id, created_at desc);
create index if not exists messages_receiver_idx
  on public.messages (receiver_id, created_at desc);

-- ---------------------------------------------------------------------
-- 2. AUTO-CREATE A PROFILE WHEN A USER SIGNS UP
--    The app signs up with just an email code; a temporary username is made
--    from the email and replaced during the onboarding steps.
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
begin
  v_username := coalesce(new.raw_user_meta_data ->> 'username',
                         split_part(new.email, '@', 1));
  -- keep only allowed characters, pad/trim to 3..15 chars
  v_username := regexp_replace(v_username, '[^A-Za-z0-9_]', '', 'g');
  if char_length(v_username) < 3 then
    v_username := v_username || substr(md5(new.id::text), 1, 3);
  end if;
  v_username := left(v_username, 15);

  -- make unique if taken
  while exists (select 1 from public.profiles
                where lower(username) = lower(v_username)) loop
    v_username := left(v_username, 10) || substr(md5(random()::text), 1, 5);
  end loop;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    v_username,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), v_username)
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 3. VIEWS / FUNCTIONS USED BY THE APP
-- ---------------------------------------------------------------------

-- Lets the sign-up screen check a username BEFORE the account exists
-- (anonymous users cannot read the profiles table directly).
create or replace function public.username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
    where lower(username) = lower(btrim(p_username))
  );
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- True when the email already belongs to a finished account. (An address that
-- verified its code but never finished the steps can simply start again.)
create or replace function public.email_registered(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from auth.users u
    join public.profiles p on p.id = u.id
    where lower(u.email) = lower(btrim(p_email)) and p.onboarded
  );
$$;
grant execute on function public.email_registered(text) to anon, authenticated;

-- Counts one view for each of the given posts.
create or replace function public.bump_views(p_ids uuid[])
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.post_views (post_id, views)
  select p.id, 1 from public.posts p where p.id = any(p_ids)
  on conflict (post_id) do update set views = public.post_views.views + 1;
$$;
grant execute on function public.bump_views(uuid[]) to authenticated;

-- ---------------------------------------------------------------------
-- Profile header image, Communities and Lists
-- ---------------------------------------------------------------------

alter table public.profiles add column if not exists header_url text;

create table if not exists public.communities (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 50),
  description text not null default '' check (char_length(description) <= 200),
  category    text not null default 'General',
  image_url   text,
  created_at  timestamptz not null default now()
);
create unique index if not exists communities_name_idx on public.communities (lower(name));

create table if not exists public.community_members (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index if not exists community_members_user_idx on public.community_members (user_id);

alter table public.posts
  add column if not exists community_id uuid references public.communities (id) on delete set null;
create index if not exists posts_community_idx on public.posts (community_id, created_at desc);

create table if not exists public.lists (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 25),
  description text not null default '' check (char_length(description) <= 100),
  is_private  boolean not null default false,
  banner_url  text,
  created_at  timestamptz not null default now()
);
create index if not exists lists_owner_idx on public.lists (owner_id, created_at desc);

create table if not exists public.list_members (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create table if not exists public.list_follows (
  list_id    uuid not null references public.lists (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index if not exists list_follows_user_idx on public.list_follows (user_id);

-- Feed rows with author info and like / reply / repost / view counts
-- (dropped first so this file can be run again after section 8 added columns)
drop view if exists public.posts_feed;
create or replace view public.posts_feed
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.content,
  p.image_url,
  p.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  (select count(*) from public.post_likes l where l.post_id = p.id)::int as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  exists (
    select 1 from public.bookmarks b
    where b.post_id = p.id and b.user_id = auth.uid()
  ) as bookmarked_by_me,
  p.parent_id,
  (select count(*) from public.posts r where r.parent_id = p.id)::int as reply_count,
  (select count(*) from public.reposts x where x.post_id = p.id)::int as repost_count,
  exists (
    select 1 from public.reposts x
    where x.post_id = p.id and x.user_id = auth.uid()
  ) as reposted_by_me,
  coalesce((select v.views from public.post_views v where v.post_id = p.id), 0)::int as views,
  p.community_id,
  c.name as community_name
from public.posts p
join public.profiles pr on pr.id = p.user_id
left join public.communities c on c.id = p.community_id;

-- Profile with follower / following / post counts and "am I following"
-- (dropped first so this file can be run again after section 9 added columns)
drop view if exists public.profile_stats;
create view public.profile_stats
with (security_invoker = true) as
select
  pr.id,
  pr.username,
  pr.display_name,
  pr.bio,
  pr.avatar_url,
  pr.created_at,
  (select count(*) from public.follows f where f.following_id = pr.id)::int as follower_count,
  (select count(*) from public.follows f where f.follower_id  = pr.id)::int as following_count,
  (select count(*) from public.posts   p where p.user_id     = pr.id)::int as post_count,
  exists (
    select 1 from public.follows f
    where f.follower_id = auth.uid() and f.following_id = pr.id
  ) as followed_by_me,
  pr.interests,
  pr.onboarded,
  pr.header_url
from public.profiles pr;

-- One row per conversation partner: last message + unread count
create or replace function public.my_conversations()
returns table (
  partner_id    uuid,
  username      text,
  display_name  text,
  avatar_url    text,
  last_message  text,
  last_at       timestamptz,
  last_from_me  boolean,
  unread_count  int
)
language sql
stable
security invoker
set search_path = public
as $$
  with mine as (
    select
      case when m.sender_id = auth.uid() then m.receiver_id else m.sender_id end as partner_id,
      m.content, m.created_at, m.sender_id, m.receiver_id, m.read_at
    from public.messages m
    where m.sender_id = auth.uid() or m.receiver_id = auth.uid()
  ),
  last_msg as (
    select distinct on (partner_id)
      partner_id, content, created_at, (sender_id = auth.uid()) as from_me
    from mine
    order by partner_id, created_at desc
  ),
  unread as (
    select sender_id as partner_id, count(*)::int as n
    from public.messages
    where receiver_id = auth.uid() and read_at is null
    group by sender_id
  )
  select
    l.partner_id,
    p.username,
    p.display_name,
    p.avatar_url,
    l.content,
    l.created_at,
    l.from_me,
    coalesce(u.n, 0)
  from last_msg l
  join public.profiles p on p.id = l.partner_id
  left join unread u on u.partner_id = l.partner_id
  order by l.created_at desc;
$$;

-- ---------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------

alter table public.profiles   enable row level security;
alter table public.posts      enable row level security;
alter table public.post_likes enable row level security;
alter table public.bookmarks  enable row level security;
alter table public.reposts    enable row level security;
alter table public.post_views enable row level security;
alter table public.profile_private enable row level security;
alter table public.follows    enable row level security;
alter table public.messages   enable row level security;

-- profiles
drop policy if exists "profiles readable by signed-in users" on public.profiles;
create policy "profiles readable by signed-in users"
  on public.profiles for select to authenticated using (true);
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- posts
drop policy if exists "posts readable" on public.posts;
create policy "posts readable"
  on public.posts for select to authenticated using (true);
drop policy if exists "users create own posts" on public.posts;
create policy "users create own posts"
  on public.posts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users delete own posts" on public.posts;
create policy "users delete own posts"
  on public.posts for delete to authenticated using (user_id = auth.uid());

-- likes
drop policy if exists "likes readable" on public.post_likes;
create policy "likes readable"
  on public.post_likes for select to authenticated using (true);
drop policy if exists "users like as themselves" on public.post_likes;
create policy "users like as themselves"
  on public.post_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users remove own like" on public.post_likes;
create policy "users remove own like"
  on public.post_likes for delete to authenticated using (user_id = auth.uid());

-- reposts
drop policy if exists "reposts readable" on public.reposts;
create policy "reposts readable"
  on public.reposts for select to authenticated using (true);
drop policy if exists "users repost as themselves" on public.reposts;
create policy "users repost as themselves"
  on public.reposts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users remove own repost" on public.reposts;
create policy "users remove own repost"
  on public.reposts for delete to authenticated using (user_id = auth.uid());

-- view counters: everyone can read, only bump_views() writes
drop policy if exists "views readable" on public.post_views;
create policy "views readable"
  on public.post_views for select to authenticated using (true);

-- birthday (private)
drop policy if exists "own birthday readable" on public.profile_private;
create policy "own birthday readable"
  on public.profile_private for select to authenticated using (user_id = auth.uid());
drop policy if exists "own birthday insert" on public.profile_private;
create policy "own birthday insert"
  on public.profile_private for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "own birthday update" on public.profile_private;
create policy "own birthday update"
  on public.profile_private for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- bookmarks (private: only the owner can see or change them)
drop policy if exists "bookmarks readable by owner" on public.bookmarks;
create policy "bookmarks readable by owner"
  on public.bookmarks for select to authenticated using (user_id = auth.uid());
drop policy if exists "users bookmark as themselves" on public.bookmarks;
create policy "users bookmark as themselves"
  on public.bookmarks for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users remove own bookmark" on public.bookmarks;
create policy "users remove own bookmark"
  on public.bookmarks for delete to authenticated using (user_id = auth.uid());

-- follows
drop policy if exists "follows readable" on public.follows;
create policy "follows readable"
  on public.follows for select to authenticated using (true);
drop policy if exists "users follow as themselves" on public.follows;
create policy "users follow as themselves"
  on public.follows for insert to authenticated with check (follower_id = auth.uid());
drop policy if exists "users unfollow" on public.follows;
create policy "users unfollow"
  on public.follows for delete to authenticated using (follower_id = auth.uid());

-- messages: only the two participants can see them
drop policy if exists "participants read messages" on public.messages;
create policy "participants read messages"
  on public.messages for select to authenticated
  using (sender_id = auth.uid() or receiver_id = auth.uid());
drop policy if exists "users send as themselves" on public.messages;
create policy "users send as themselves"
  on public.messages for insert to authenticated with check (sender_id = auth.uid());
drop policy if exists "receiver marks read" on public.messages;
create policy "receiver marks read"
  on public.messages for update to authenticated
  using (receiver_id = auth.uid()) with check (receiver_id = auth.uid());

-- ---------------------------------------------------------------------
-- 5. REALTIME (feed, likes, follows, direct messages)
-- ---------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['posts','post_likes','reposts','follows','messages']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null; -- already published
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 6. STORAGE (images)  — public-read buckets, writes only into your own folder
--    Files are stored as  <user-id>/<timestamp>.<ext>
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true),
       ('post-images', 'post-images', true)
on conflict (id) do nothing;

drop policy if exists "public read app images" on storage.objects;
create policy "public read app images"
  on storage.objects for select
  using (bucket_id in ('avatars', 'post-images'));

drop policy if exists "users upload to own folder" on storage.objects;
create policy "users upload to own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id in ('avatars', 'post-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users update own files" on storage.objects;
create policy "users update own files"
  on storage.objects for update to authenticated
  using (
    bucket_id in ('avatars', 'post-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete own files" on storage.objects;
create policy "users delete own files"
  on storage.objects for delete to authenticated
  using (
    bucket_id in ('avatars', 'post-images')
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ---------------------------------------------------------------------
-- 7. COMMUNITIES and LISTS — row level security and stats views
-- ---------------------------------------------------------------------

alter table public.communities       enable row level security;
alter table public.community_members enable row level security;
alter table public.lists             enable row level security;
alter table public.list_members      enable row level security;
alter table public.list_follows      enable row level security;

drop policy if exists "communities readable" on public.communities;
create policy "communities readable"
  on public.communities for select to authenticated using (true);
drop policy if exists "users create communities" on public.communities;
create policy "users create communities"
  on public.communities for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "owners edit communities" on public.communities;
create policy "owners edit communities"
  on public.communities for update to authenticated using (owner_id = auth.uid());
drop policy if exists "owners delete communities" on public.communities;
create policy "owners delete communities"
  on public.communities for delete to authenticated using (owner_id = auth.uid());

drop policy if exists "memberships readable" on public.community_members;
create policy "memberships readable"
  on public.community_members for select to authenticated using (true);
drop policy if exists "users join as themselves" on public.community_members;
create policy "users join as themselves"
  on public.community_members for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users leave communities" on public.community_members;
create policy "users leave communities"
  on public.community_members for delete to authenticated using (user_id = auth.uid());

drop policy if exists "lists readable" on public.lists;
create policy "lists readable"
  on public.lists for select to authenticated
  using (not is_private or owner_id = auth.uid());
drop policy if exists "users create lists" on public.lists;
create policy "users create lists"
  on public.lists for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "owners edit lists" on public.lists;
create policy "owners edit lists"
  on public.lists for update to authenticated using (owner_id = auth.uid());
drop policy if exists "owners delete lists" on public.lists;
create policy "owners delete lists"
  on public.lists for delete to authenticated using (owner_id = auth.uid());

drop policy if exists "list members readable" on public.list_members;
create policy "list members readable"
  on public.list_members for select to authenticated
  using (exists (select 1 from public.lists l where l.id = list_id));
drop policy if exists "owners add list members" on public.list_members;
create policy "owners add list members"
  on public.list_members for insert to authenticated
  with check (exists (select 1 from public.lists l where l.id = list_id and l.owner_id = auth.uid()));
drop policy if exists "owners remove list members" on public.list_members;
create policy "owners remove list members"
  on public.list_members for delete to authenticated
  using (exists (select 1 from public.lists l where l.id = list_id and l.owner_id = auth.uid()));

drop policy if exists "list follows readable" on public.list_follows;
create policy "list follows readable"
  on public.list_follows for select to authenticated using (true);
drop policy if exists "users follow lists as themselves" on public.list_follows;
create policy "users follow lists as themselves"
  on public.list_follows for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "users unfollow lists" on public.list_follows;
create policy "users unfollow lists"
  on public.list_follows for delete to authenticated using (user_id = auth.uid());

drop view if exists public.community_stats;
create view public.community_stats
with (security_invoker = true) as
select
  c.id,
  c.owner_id,
  c.name,
  c.description,
  c.category,
  c.image_url,
  c.created_at,
  (select count(*) from public.community_members m where m.community_id = c.id)::int as member_count,
  exists (
    select 1 from public.community_members m
    where m.community_id = c.id and m.user_id = auth.uid()
  ) as joined_by_me
from public.communities c;

drop view if exists public.list_stats;
create view public.list_stats
with (security_invoker = true) as
select
  l.id,
  l.owner_id,
  pr.username   as owner_username,
  pr.display_name as owner_display_name,
  l.name,
  l.description,
  l.is_private,
  l.banner_url,
  l.created_at,
  (select count(*) from public.list_members m where m.list_id = l.id)::int as member_count,
  (select count(*) from public.list_follows f where f.list_id = l.id)::int as follower_count,
  exists (
    select 1 from public.list_follows f
    where f.list_id = l.id and f.user_id = auth.uid()
  ) as followed_by_me
from public.lists l
join public.profiles pr on pr.id = l.owner_id;

-- ---------------------------------------------------------------------
-- 8. POST EXTRAS — reply settings, scheduled posts, quote posts, polls,
--    location and the content disclosures (paid partnership / made with AI).
--    Safe to run again.
-- ---------------------------------------------------------------------

-- The view is rebuilt at the end of this section; it has to go first so
-- columns can be dropped and its column list can change.
drop view if exists public.posts_feed;

alter table public.posts drop column if exists sensitive;

alter table public.posts
  add column if not exists reply_setting text not null default 'everyone',
  add column if not exists location      text,
  add column if not exists paid_partnership boolean not null default false,
  add column if not exists made_with_ai     boolean not null default false,
  add column if not exists scheduled_at  timestamptz,
  add column if not exists quote_id      uuid references public.posts (id) on delete set null,
  add column if not exists poll_ends_at  timestamptz;

alter table public.posts drop constraint if exists posts_reply_setting_check;
alter table public.posts add constraint posts_reply_setting_check
  check (reply_setting in ('everyone', 'following', 'verified', 'mentioned'));

-- A post may now be empty when it only quotes another post.
alter table public.posts drop constraint if exists posts_check;
alter table public.posts drop constraint if exists posts_has_content;
alter table public.posts add constraint posts_has_content
  check (char_length(btrim(content)) > 0 or image_url is not null or quote_id is not null);

create index if not exists posts_scheduled_idx on public.posts (scheduled_at)
  where scheduled_at is not null;
create index if not exists posts_quote_idx on public.posts (quote_id);

create table if not exists public.poll_options (
  id        uuid primary key default gen_random_uuid(),
  post_id   uuid not null references public.posts (id) on delete cascade,
  label     text not null check (char_length(btrim(label)) > 0 and char_length(label) <= 25),
  position  int  not null default 0
);
create index if not exists poll_options_post_idx on public.poll_options (post_id, position);

create table if not exists public.poll_votes (
  post_id    uuid not null references public.posts (id) on delete cascade,
  option_id  uuid not null references public.poll_options (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists poll_votes_option_idx on public.poll_votes (option_id);

alter table public.poll_options enable row level security;
alter table public.poll_votes   enable row level security;

drop policy if exists "poll options readable" on public.poll_options;
create policy "poll options readable"
  on public.poll_options for select to authenticated using (true);
drop policy if exists "authors add poll options" on public.poll_options;
create policy "authors add poll options"
  on public.poll_options for insert to authenticated
  with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

drop policy if exists "poll votes readable" on public.poll_votes;
create policy "poll votes readable"
  on public.poll_votes for select to authenticated using (true);
drop policy if exists "users vote once while open" on public.poll_votes;
create policy "users vote once while open"
  on public.poll_votes for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.posts p
      where p.id = post_id and p.poll_ends_at is not null and p.poll_ends_at > now()
    )
    and exists (
      select 1 from public.poll_options o
      where o.id = option_id and o.post_id = poll_votes.post_id
    )
  );

-- Results of one poll: every option with its votes and whether I chose it.
create or replace function public.poll_results(p_post uuid)
returns table (
  option_id   uuid,
  label       text,
  votes       int,
  voted_by_me boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    o.id,
    o.label,
    (select count(*) from public.poll_votes v where v.option_id = o.id)::int,
    exists (
      select 1 from public.poll_votes v
      where v.option_id = o.id and v.user_id = auth.uid()
    )
  from public.poll_options o
  where o.post_id = p_post
  order by o.position, o.id;
$$;

-- "Who can reply": enforced when a reply is inserted.
create or replace function public.enforce_reply_setting()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_author  uuid;
  parent_setting text;
  parent_text    text;
  my_username    text;
begin
  if new.parent_id is null then
    return new;
  end if;
  select user_id, reply_setting, content
    into parent_author, parent_setting, parent_text
    from public.posts where id = new.parent_id;
  if parent_author is null or parent_author = new.user_id or parent_setting = 'everyone' then
    return new;
  end if;
  if parent_setting = 'following' then
    if exists (select 1 from public.follows f
               where f.follower_id = parent_author and f.following_id = new.user_id) then
      return new;
    end if;
    raise exception 'Only accounts the author follows can reply to this post.';
  elsif parent_setting = 'mentioned' then
    select username into my_username from public.profiles where id = new.user_id;
    if position(lower('@' || my_username) in lower(parent_text)) > 0 then
      return new;
    end if;
    raise exception 'Only accounts the author mentioned can reply to this post.';
  else
    raise exception 'Only verified accounts can reply to this post.';
  end if;
end;
$$;

drop trigger if exists enforce_reply_setting_trg on public.posts;
create trigger enforce_reply_setting_trg
  before insert on public.posts
  for each row execute function public.enforce_reply_setting();

-- Feed view again, with the new columns added at the end. Posts whose
-- scheduled time has not come yet stay hidden.
create view public.posts_feed
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.content,
  p.image_url,
  p.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  (select count(*) from public.post_likes l where l.post_id = p.id)::int as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  exists (
    select 1 from public.bookmarks b
    where b.post_id = p.id and b.user_id = auth.uid()
  ) as bookmarked_by_me,
  p.parent_id,
  (select count(*) from public.posts r where r.parent_id = p.id)::int as reply_count,
  (select count(*) from public.reposts x where x.post_id = p.id)::int as repost_count,
  exists (
    select 1 from public.reposts x
    where x.post_id = p.id and x.user_id = auth.uid()
  ) as reposted_by_me,
  coalesce((select v.views from public.post_views v where v.post_id = p.id), 0)::int as views,
  p.community_id,
  c.name as community_name,
  p.reply_setting,
  p.location,
  p.paid_partnership,
  p.made_with_ai,
  p.scheduled_at,
  p.poll_ends_at,
  p.quote_id,
  q.content       as quote_content,
  q.image_url     as quote_image_url,
  qpr.username    as quote_username,
  qpr.display_name as quote_display_name,
  qpr.avatar_url  as quote_avatar_url
from public.posts p
join public.profiles pr on pr.id = p.user_id
left join public.communities c on c.id = p.community_id
left join public.posts q on q.id = p.quote_id
left join public.profiles qpr on qpr.id = q.user_id
where p.scheduled_at is null or p.scheduled_at <= now();


-- ---------------------------------------------------------------------
-- 9. SETTINGS AND PRIVACY
--    country, profile labels, automation, deactivation, protected posts,
--    message requests, blocks, mutes, sessions and per-user settings.
-- ---------------------------------------------------------------------

alter table public.profiles
  add column if not exists country text,
  add column if not exists profile_label text,
  add column if not exists label_updated_at timestamptz,
  add column if not exists automated boolean not null default false,
  add column if not exists managed_by uuid references public.profiles (id) on delete set null,
  add column if not exists deactivated_at timestamptz,
  add column if not exists protected boolean not null default false,
  add column if not exists dm_setting text not null default 'everyone';

alter table public.profiles drop constraint if exists profiles_profile_label_check;
alter table public.profiles add constraint profiles_profile_label_check
  check (profile_label is null or profile_label in ('commentary', 'fan', 'parody'));
alter table public.profiles drop constraint if exists profiles_dm_setting_check;
alter table public.profiles add constraint profiles_dm_setting_check
  check (dm_setting in ('everyone', 'verified', 'none'));

-- Phone number (private, never shown to others; not verified by SMS).
alter table public.profile_private add column if not exists phone text;

-- A profile label can only change once every 48 hours.
create or replace function public.lock_profile_label()
returns trigger
language plpgsql
as $$
begin
  if new.profile_label is distinct from old.profile_label then
    if old.label_updated_at is not null
       and old.label_updated_at > now() - interval '48 hours' then
      raise exception 'Your profile label can only be changed once every 48 hours.';
    end if;
    new.label_updated_at := now();
  end if;
  return new;
end;
$$;
drop trigger if exists lock_profile_label_trg on public.profiles;
create trigger lock_profile_label_trg
  before update on public.profiles
  for each row execute function public.lock_profile_label();

-- Settings that belong to one account (toggles, muted words, ...).
create table if not exists public.user_prefs (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  prefs      jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Devices that are (or were) signed in: "Apps and sessions".
create table if not exists public.user_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  device      text not null default 'Unknown device',
  platform    text,
  location    text,
  created_at  timestamptz not null default now(),
  last_active timestamptz not null default now(),
  ended_at    timestamptz
);
create index if not exists user_sessions_user_idx
  on public.user_sessions (user_id, created_at desc);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.user_mutes (
  muter_id   uuid not null references public.profiles (id) on delete cascade,
  muted_id   uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  check (muter_id <> muted_id)
);

alter table public.user_prefs    enable row level security;
alter table public.user_sessions enable row level security;
alter table public.user_blocks   enable row level security;
alter table public.user_mutes    enable row level security;

drop policy if exists "own prefs" on public.user_prefs;
create policy "own prefs" on public.user_prefs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own sessions" on public.user_sessions;
create policy "own sessions" on public.user_sessions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own blocks read" on public.user_blocks;
create policy "own blocks read" on public.user_blocks for select to authenticated
  using (blocker_id = auth.uid());
drop policy if exists "own blocks delete" on public.user_blocks;
create policy "own blocks delete" on public.user_blocks for delete to authenticated
  using (blocker_id = auth.uid());

drop policy if exists "own mutes" on public.user_mutes;
create policy "own mutes" on public.user_mutes for all to authenticated
  using (muter_id = auth.uid()) with check (muter_id = auth.uid());

-- True when either account blocked the other. SECURITY DEFINER so a blocked
-- person's request can still be checked without exposing the blocks table.
create or replace function public.blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

-- Block: also removes the follow in both directions.
create or replace function public.block_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_target = auth.uid() then
    raise exception 'You cannot block yourself.';
  end if;
  insert into public.user_blocks (blocker_id, blocked_id)
    values (auth.uid(), p_target)
    on conflict do nothing;
  delete from public.follows
    where (follower_id = auth.uid() and following_id = p_target)
       or (follower_id = p_target and following_id = auth.uid());
end;
$$;

-- "Message Requests": who may start a chat with me. People I follow can
-- always write to me; everybody else depends on my setting. (There is no
-- verification badge in this app, so "Verified users" works like "No one".)
create or replace function public.can_message(p_sender uuid, p_receiver uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.blocked_between(p_sender, p_receiver)
    and (
      coalesce((select dm_setting from public.profiles where id = p_receiver), 'everyone') = 'everyone'
      or exists (
        select 1 from public.follows f
        where f.follower_id = p_receiver and f.following_id = p_sender
      )
      or exists (
        select 1 from public.messages m
        where m.sender_id = p_receiver and m.receiver_id = p_sender
      )
    );
$$;

drop policy if exists "users send as themselves" on public.messages;
create policy "users send as themselves"
  on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.can_message(sender_id, receiver_id));

drop policy if exists "users follow as themselves" on public.follows;
create policy "users follow as themselves"
  on public.follows for insert to authenticated
  with check (follower_id = auth.uid()
              and not public.blocked_between(follower_id, following_id));

-- Deactivated accounts disappear for everybody except their owner (the next
-- sign-in reactivates them).
drop policy if exists "profiles readable by signed-in users" on public.profiles;
create policy "profiles readable by signed-in users"
  on public.profiles for select to authenticated
  using (deactivated_at is null or id = auth.uid());

-- Protected posts: only the author and the author's followers can read them.
drop policy if exists "posts readable" on public.posts;
create policy "posts readable"
  on public.posts for select to authenticated
  using (
    user_id = auth.uid()
    or not exists (
      select 1 from public.profiles pr
      where pr.id = posts.user_id and pr.protected
    )
    or exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = posts.user_id
    )
  );

-- Profile view again, with the new columns at the end.
drop view if exists public.profile_stats;
create view public.profile_stats
with (security_invoker = true) as
select
  pr.id,
  pr.username,
  pr.display_name,
  pr.bio,
  pr.avatar_url,
  pr.created_at,
  (select count(*) from public.follows f where f.following_id = pr.id)::int as follower_count,
  (select count(*) from public.follows f where f.follower_id  = pr.id)::int as following_count,
  (select count(*) from public.posts   p where p.user_id     = pr.id)::int as post_count,
  exists (
    select 1 from public.follows f
    where f.follower_id = auth.uid() and f.following_id = pr.id
  ) as followed_by_me,
  pr.interests,
  pr.onboarded,
  pr.header_url,
  pr.country,
  pr.profile_label,
  pr.automated,
  pr.protected,
  mp.username as managed_by_username
from public.profiles pr
left join public.profiles mp on mp.id = pr.managed_by;

-- Feed view again: author label / automated / protected flags at the end.
drop view if exists public.posts_feed;
create view public.posts_feed
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.content,
  p.image_url,
  p.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  (select count(*) from public.post_likes l where l.post_id = p.id)::int as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  exists (
    select 1 from public.bookmarks b
    where b.post_id = p.id and b.user_id = auth.uid()
  ) as bookmarked_by_me,
  p.parent_id,
  (select count(*) from public.posts r where r.parent_id = p.id)::int as reply_count,
  (select count(*) from public.reposts x where x.post_id = p.id)::int as repost_count,
  exists (
    select 1 from public.reposts x
    where x.post_id = p.id and x.user_id = auth.uid()
  ) as reposted_by_me,
  coalesce((select v.views from public.post_views v where v.post_id = p.id), 0)::int as views,
  p.community_id,
  c.name as community_name,
  p.reply_setting,
  p.location,
  p.paid_partnership,
  p.made_with_ai,
  p.scheduled_at,
  p.poll_ends_at,
  p.quote_id,
  q.content       as quote_content,
  q.image_url     as quote_image_url,
  qpr.username    as quote_username,
  qpr.display_name as quote_display_name,
  qpr.avatar_url  as quote_avatar_url,
  pr.profile_label as author_label,
  pr.automated     as author_automated,
  pr.protected     as author_protected
from public.posts p
join public.profiles pr on pr.id = p.user_id
left join public.communities c on c.id = p.community_id
left join public.posts q on q.id = p.quote_id
left join public.profiles qpr on qpr.id = q.user_id
where p.scheduled_at is null or p.scheduled_at <= now();

-- ---------------------------------------------------------------------
-- 10. POST LAYOUT: several photos per post, bookmark counts, verified badge
-- ---------------------------------------------------------------------

-- Up to four photos per post (image_url keeps the first one, so older
-- screens and the quote card keep working).
alter table public.posts
  add column if not exists image_urls text[] not null default '{}';

-- Verification badge shown next to a name: blue (person), gold
-- (organisation; the avatar becomes a rounded square) or grey. It can only
-- be set from the Supabase dashboard / SQL editor, never from the app:
--   update public.profiles set verified = 'blue' where username = 'sam';
alter table public.profiles add column if not exists verified text;
alter table public.profiles drop constraint if exists profiles_verified_check;
alter table public.profiles add constraint profiles_verified_check
  check (verified is null or verified in ('blue', 'gold', 'gray'));

create or replace function public.lock_verified()
returns trigger
language plpgsql
as $$
begin
  -- Requests from the app carry a user id; the dashboard / SQL editor do not.
  if auth.uid() is not null then
    if tg_op = 'INSERT' then
      new.verified := null;
    else
      new.verified := old.verified;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists lock_verified_trg on public.profiles;
create trigger lock_verified_trg
  before insert or update on public.profiles
  for each row execute function public.lock_verified();

-- Bookmarks are private, so the count under a post needs a definer function.
create or replace function public.bookmark_count(p_post uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public.bookmarks where post_id = p_post;
$$;
grant execute on function public.bookmark_count(uuid) to authenticated;

-- Profile view again, with the badge at the end.
drop view if exists public.profile_stats;
create view public.profile_stats
with (security_invoker = true) as
select
  pr.id,
  pr.username,
  pr.display_name,
  pr.bio,
  pr.avatar_url,
  pr.created_at,
  (select count(*) from public.follows f where f.following_id = pr.id)::int as follower_count,
  (select count(*) from public.follows f where f.follower_id  = pr.id)::int as following_count,
  (select count(*) from public.posts   p where p.user_id     = pr.id)::int as post_count,
  exists (
    select 1 from public.follows f
    where f.follower_id = auth.uid() and f.following_id = pr.id
  ) as followed_by_me,
  pr.interests,
  pr.onboarded,
  pr.header_url,
  pr.country,
  pr.profile_label,
  pr.automated,
  pr.protected,
  mp.username as managed_by_username,
  pr.verified
from public.profiles pr
left join public.profiles mp on mp.id = pr.managed_by;

-- Edit post: the author may change the TEXT of a post for one hour.
-- Everything else stays as it was; the dashboard / SQL editor is not limited.
alter table public.posts add column if not exists edited_at timestamptz;

drop policy if exists "users edit own posts" on public.posts;
create policy "users edit own posts"
  on public.posts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.guard_post_edit()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null then
    if new.content is distinct from old.content then
      if now() - coalesce(old.scheduled_at, old.created_at) > interval '1 hour' then
        raise exception 'Posts can only be edited within one hour.';
      end if;
      new.edited_at := now();
    end if;
    new.user_id      := old.user_id;
    new.created_at   := old.created_at;
    new.parent_id    := old.parent_id;
    new.quote_id     := old.quote_id;
    new.image_url    := old.image_url;
    new.image_urls   := old.image_urls;
    new.community_id := old.community_id;
    new.poll_ends_at := old.poll_ends_at;
    new.scheduled_at := old.scheduled_at;
    new.location     := old.location;
    if old.edited_at is not null and new.content is not distinct from old.content then
      new.edited_at := old.edited_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_post_edit_trg on public.posts;
create trigger guard_post_edit_trg
  before update on public.posts
  for each row execute function public.guard_post_edit();

-- =====================================================================
-- 11. DM replies and reactions, post analytics, reports, Community Notes
-- =====================================================================

-- 11a. Direct messages: reply to a message, and one emoji reaction per
--      person per message.
alter table public.messages
  add column if not exists reply_to uuid references public.messages (id) on delete set null;

create or replace function public.check_message_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.reply_to is not null and not exists (
    select 1 from public.messages m
    where m.id = new.reply_to
      and ((m.sender_id = new.sender_id and m.receiver_id = new.receiver_id)
        or (m.sender_id = new.receiver_id and m.receiver_id = new.sender_id))
  ) then
    raise exception 'You can only reply to a message of this conversation.';
  end if;
  return new;
end;
$$;

drop trigger if exists check_message_reply_trg on public.messages;
create trigger check_message_reply_trg
  before insert on public.messages
  for each row execute function public.check_message_reply();

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
alter table public.message_reactions enable row level security;

drop policy if exists "participants read reactions" on public.message_reactions;
create policy "participants read reactions"
  on public.message_reactions for select to authenticated
  using (exists (select 1 from public.messages m
                 where m.id = message_id and auth.uid() in (m.sender_id, m.receiver_id)));
drop policy if exists "participants react" on public.message_reactions;
create policy "participants react"
  on public.message_reactions for insert to authenticated
  with check (user_id = auth.uid()
              and exists (select 1 from public.messages m
                          where m.id = message_id and auth.uid() in (m.sender_id, m.receiver_id)));
drop policy if exists "change own reaction" on public.message_reactions;
create policy "change own reaction"
  on public.message_reactions for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "remove own reaction" on public.message_reactions;
create policy "remove own reaction"
  on public.message_reactions for delete to authenticated
  using (user_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.message_reactions;
exception when duplicate_object then
  null; -- already published
end $$;

-- 11b. Post analytics: what people did with a post. Only the author sees it.
create table if not exists public.post_events (
  id         bigint generated always as identity primary key,
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('detail', 'profile', 'share', 'link')),
  created_at timestamptz not null default now()
);
create index if not exists post_events_post_idx on public.post_events (post_id, kind);
alter table public.post_events enable row level security;

drop policy if exists "log own events" on public.post_events;
create policy "log own events"
  on public.post_events for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "author reads events" on public.post_events;
create policy "author reads events"
  on public.post_events for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

create or replace function public.post_analytics(p_post uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_result jsonb;
begin
  select user_id into v_owner from public.posts where id = p_post;
  if v_owner is null or v_owner is distinct from auth.uid() then
    raise exception 'Only the author can see the analytics of a post.';
  end if;

  select jsonb_build_object(
    'views',          coalesce((select v.views from public.post_views v where v.post_id = p_post), 0),
    'likes',          (select count(*) from public.post_likes where post_id = p_post),
    'reposts',        (select count(*) from public.reposts where post_id = p_post),
    'quotes',         (select count(*) from public.posts where quote_id = p_post),
    'replies',        (select count(*) from public.posts where parent_id = p_post),
    'bookmarks',      (select count(*) from public.bookmarks where post_id = p_post),
    'detail_expands', (select count(*) from public.post_events where post_id = p_post and kind = 'detail'),
    'profile_visits', (select count(*) from public.post_events where post_id = p_post and kind = 'profile'),
    'shares',         (select count(*) from public.post_events where post_id = p_post and kind = 'share'),
    'link_clicks',    (select count(*) from public.post_events where post_id = p_post and kind = 'link'),
    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'day',     to_char(d, 'YYYY-MM-DD'),
               'likes',   (select count(*) from public.post_likes l
                           where l.post_id = p_post and l.created_at >= d and l.created_at < d + interval '1 day'),
               'reposts', (select count(*) from public.reposts x
                           where x.post_id = p_post and x.created_at >= d and x.created_at < d + interval '1 day'),
               'replies', (select count(*) from public.posts r
                           where r.parent_id = p_post and r.created_at >= d and r.created_at < d + interval '1 day')
             ) order by d), '[]'::jsonb)
      from generate_series(date_trunc('day', now()) - interval '6 days',
                           date_trunc('day', now()), interval '1 day') d
    )
  ) into v_result;
  return v_result;
end;
$$;
grant execute on function public.post_analytics(uuid) to authenticated;

-- 11c. Reports (the team reads them in the dashboard: Table Editor > reports)
create table if not exists public.reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null references public.profiles (id) on delete cascade,
  post_id          uuid references public.posts (id) on delete set null,
  reported_user_id uuid references public.profiles (id) on delete set null,
  reason           text not null check (char_length(reason) between 1 and 80),
  details          text check (details is null or char_length(details) <= 500),
  status           text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at       timestamptz not null default now(),
  unique (reporter_id, post_id, reason)
);
alter table public.reports enable row level security;
drop policy if exists "send own reports" on public.reports;
create policy "send own reports"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
drop policy if exists "read own reports" on public.reports;
create policy "read own reports"
  on public.reports for select to authenticated
  using (reporter_id = auth.uid());

-- 11d. Community Notes: people ask for a note, others write notes, everybody
--      rates them. A note appears under the post once at least 2 people
--      found it helpful and more found it helpful than not helpful.
create table if not exists public.note_requests (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  source_url text check (source_url is null or char_length(source_url) <= 300),
  reason     text check (reason is null or char_length(reason) <= 500),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.community_notes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(btrim(body)) between 1 and 280),
  source_url text check (source_url is null or char_length(source_url) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists community_notes_post_idx on public.community_notes (post_id);

create table if not exists public.note_ratings (
  note_id    uuid not null references public.community_notes (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  helpful    boolean not null,
  created_at timestamptz not null default now(),
  primary key (note_id, user_id)
);

alter table public.note_requests   enable row level security;
alter table public.community_notes enable row level security;
alter table public.note_ratings    enable row level security;

drop policy if exists "note requests readable" on public.note_requests;
create policy "note requests readable" on public.note_requests
  for select to authenticated using (true);
drop policy if exists "request notes as myself" on public.note_requests;
create policy "request notes as myself" on public.note_requests
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "notes readable" on public.community_notes;
create policy "notes readable" on public.community_notes
  for select to authenticated using (true);
drop policy if exists "write notes as myself" on public.community_notes;
create policy "write notes as myself" on public.community_notes
  for insert to authenticated with check (author_id = auth.uid());
drop policy if exists "delete my notes" on public.community_notes;
create policy "delete my notes" on public.community_notes
  for delete to authenticated using (author_id = auth.uid());

drop policy if exists "ratings readable" on public.note_ratings;
create policy "ratings readable" on public.note_ratings
  for select to authenticated using (true);
drop policy if exists "rate other people's notes" on public.note_ratings;
create policy "rate other people's notes" on public.note_ratings
  for insert to authenticated
  with check (user_id = auth.uid()
              and not exists (select 1 from public.community_notes n
                              where n.id = note_id and n.author_id = auth.uid()));
drop policy if exists "change my rating" on public.note_ratings;
create policy "change my rating" on public.note_ratings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "remove my rating" on public.note_ratings;
create policy "remove my rating" on public.note_ratings
  for delete to authenticated using (user_id = auth.uid());

drop view if exists public.community_notes_view;
create view public.community_notes_view
with (security_invoker = true) as
select
  n.id,
  n.post_id,
  n.author_id,
  pr.username as author_username,
  n.body,
  n.source_url,
  n.created_at,
  c.helpful_count,
  c.not_helpful_count,
  (select r.helpful from public.note_ratings r
   where r.note_id = n.id and r.user_id = auth.uid()) as my_rating,
  (c.helpful_count >= 2 and c.helpful_count > c.not_helpful_count) as shown
from public.community_notes n
join public.profiles pr on pr.id = n.author_id
cross join lateral (
  select count(*) filter (where r.helpful)::int     as helpful_count,
         count(*) filter (where not r.helpful)::int as not_helpful_count
  from public.note_ratings r where r.note_id = n.id
) c;

-- Feed view again: photos, bookmark count, badge, quote details, edited time.
drop view if exists public.posts_feed;
create view public.posts_feed
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.content,
  p.image_url,
  p.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  (select count(*) from public.post_likes l where l.post_id = p.id)::int as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  exists (
    select 1 from public.bookmarks b
    where b.post_id = p.id and b.user_id = auth.uid()
  ) as bookmarked_by_me,
  p.parent_id,
  (select count(*) from public.posts r where r.parent_id = p.id)::int as reply_count,
  (select count(*) from public.reposts x where x.post_id = p.id)::int as repost_count,
  exists (
    select 1 from public.reposts x
    where x.post_id = p.id and x.user_id = auth.uid()
  ) as reposted_by_me,
  coalesce((select v.views from public.post_views v where v.post_id = p.id), 0)::int as views,
  p.community_id,
  c.name as community_name,
  p.reply_setting,
  p.location,
  p.paid_partnership,
  p.made_with_ai,
  p.scheduled_at,
  p.poll_ends_at,
  p.quote_id,
  q.content       as quote_content,
  q.image_url     as quote_image_url,
  qpr.username    as quote_username,
  qpr.display_name as quote_display_name,
  qpr.avatar_url  as quote_avatar_url,
  pr.profile_label as author_label,
  pr.automated     as author_automated,
  pr.protected     as author_protected,
  p.image_urls,
  pr.verified      as author_verified,
  public.bookmark_count(p.id) as bookmark_count,
  q.created_at as quote_created_at,
  qpr.verified as quote_verified,
  p.edited_at,
  cn.id as note_id,
  cn.body as note_body,
  cn.source_url as note_source
from public.posts p
join public.profiles pr on pr.id = p.user_id
left join public.communities c on c.id = p.community_id
left join public.posts q on q.id = p.quote_id
left join public.profiles qpr on qpr.id = q.user_id
left join lateral (
  select v.id, v.body, v.source_url
  from public.community_notes_view v
  where v.post_id = p.id and v.shown
  order by v.helpful_count desc, v.created_at
  limit 1
) cn on true
where p.scheduled_at is null or p.scheduled_at <= now();

-- =====================================================================
-- 12. PROTECTED ACCOUNTS: follow requests
--
-- "Protect your posts" (Settings > Privacy > Audience and tagging) makes an
-- account private: only confirmed followers can read its posts (policy
-- "posts readable", section 9), and nobody can follow it directly any more.
-- Instead they send a follow request, which the account owner accepts or
-- declines in "Follower requests". Messaging a protected account needs the
-- same confirmed follow. Turning protection off approves every request that
-- is still waiting.
-- =====================================================================
create table if not exists public.follow_requests (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  target_id    uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (requester_id, target_id),
  check (requester_id <> target_id)
);
create index if not exists follow_requests_target_idx
  on public.follow_requests (target_id, created_at desc);

alter table public.follow_requests enable row level security;

drop policy if exists "requests visible to both sides" on public.follow_requests;
create policy "requests visible to both sides"
  on public.follow_requests for select to authenticated
  using (requester_id = auth.uid() or target_id = auth.uid());

-- Only towards a protected account, never towards someone I blocked / who
-- blocked me, and never when I already follow them.
drop policy if exists "users request to follow" on public.follow_requests;
create policy "users request to follow"
  on public.follow_requests for insert to authenticated
  with check (
    requester_id = auth.uid()
    and not public.blocked_between(requester_id, target_id)
    and exists (select 1 from public.profiles pr
                where pr.id = target_id and pr.protected)
    and not exists (select 1 from public.follows f
                    where f.follower_id = requester_id
                      and f.following_id = target_id)
  );

-- The requester cancels, or the account owner declines.
drop policy if exists "requests can be removed by both sides" on public.follow_requests;
create policy "requests can be removed by both sides"
  on public.follow_requests for delete to authenticated
  using (requester_id = auth.uid() or target_id = auth.uid());

-- Nobody can follow a protected account directly (only through accept_follow_request).
drop policy if exists "users follow as themselves" on public.follows;
create policy "users follow as themselves"
  on public.follows for insert to authenticated
  with check (
    follower_id = auth.uid()
    and not public.blocked_between(follower_id, following_id)
    and not exists (select 1 from public.profiles pr
                    where pr.id = following_id and pr.protected)
  );

-- The account owner accepts a request: the requester becomes a follower.
create or replace function public.accept_follow_request(p_requester uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  removed int;
begin
  delete from public.follow_requests
    where requester_id = p_requester and target_id = auth.uid();
  get diagnostics removed = row_count;
  if removed = 0 then
    raise exception 'This follow request is no longer there.';
  end if;
  if not public.blocked_between(p_requester, auth.uid()) then
    insert into public.follows (follower_id, following_id)
      values (p_requester, auth.uid())
      on conflict do nothing;
  end if;
end;
$$;
grant execute on function public.accept_follow_request(uuid) to authenticated;

-- Accepts everybody who is waiting (the "Accept all" button).
create or replace function public.accept_all_follow_requests()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  insert into public.follows (follower_id, following_id)
    select r.requester_id, r.target_id
    from public.follow_requests r
    where r.target_id = auth.uid()
      and not public.blocked_between(r.requester_id, r.target_id)
    on conflict do nothing;
  get diagnostics n = row_count;
  delete from public.follow_requests where target_id = auth.uid();
  return n;
end;
$$;
grant execute on function public.accept_all_follow_requests() to authenticated;

-- Protection switched off: every waiting request is approved.
create or replace function public.approve_requests_when_public()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.protected and not new.protected then
    insert into public.follows (follower_id, following_id)
      select r.requester_id, r.target_id
      from public.follow_requests r
      where r.target_id = new.id
        and not public.blocked_between(r.requester_id, r.target_id)
      on conflict do nothing;
    delete from public.follow_requests where target_id = new.id;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_approve_requests on public.profiles;
create trigger profiles_approve_requests
  after update of protected on public.profiles
  for each row execute function public.approve_requests_when_public();

-- Blocking removes pending requests in both directions.
create or replace function public.drop_requests_on_block()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.follow_requests
    where (requester_id = new.blocker_id and target_id = new.blocked_id)
       or (requester_id = new.blocked_id and target_id = new.blocker_id);
  return new;
end;
$$;
drop trigger if exists user_blocks_drop_requests on public.user_blocks;
create trigger user_blocks_drop_requests
  after insert on public.user_blocks
  for each row execute function public.drop_requests_on_block();

-- Messages: a protected account can only be written to by its confirmed
-- followers (or by people it follows / already wrote to itself).
create or replace function public.can_message(p_sender uuid, p_receiver uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not public.blocked_between(p_sender, p_receiver)
    and (
      (
        coalesce((select dm_setting from public.profiles where id = p_receiver), 'everyone') = 'everyone'
        and (
          not coalesce((select protected from public.profiles where id = p_receiver), false)
          or exists (
            select 1 from public.follows f
            where f.follower_id = p_sender and f.following_id = p_receiver
          )
        )
      )
      or exists (
        select 1 from public.follows f
        where f.follower_id = p_receiver and f.following_id = p_sender
      )
      or exists (
        select 1 from public.messages m
        where m.sender_id = p_receiver and m.receiver_id = p_sender
      )
    );
$$;

-- Posts of a protected account cannot be reposted by anybody else.
drop policy if exists "users repost as themselves" on public.reposts;
create policy "users repost as themselves"
  on public.reposts for insert to authenticated
  with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.posts p
      join public.profiles pr on pr.id = p.user_id
      where p.id = reposts.post_id and pr.protected
    )
  );

-- Profile view once more, now with "I asked to follow this account".
drop view if exists public.profile_stats;
create view public.profile_stats
with (security_invoker = true) as
select
  pr.id,
  pr.username,
  pr.display_name,
  pr.bio,
  pr.avatar_url,
  pr.created_at,
  (select count(*) from public.follows f where f.following_id = pr.id)::int as follower_count,
  (select count(*) from public.follows f where f.follower_id  = pr.id)::int as following_count,
  (select count(*) from public.posts   p where p.user_id     = pr.id)::int as post_count,
  exists (
    select 1 from public.follows f
    where f.follower_id = auth.uid() and f.following_id = pr.id
  ) as followed_by_me,
  pr.interests,
  pr.onboarded,
  pr.header_url,
  pr.country,
  pr.profile_label,
  pr.automated,
  pr.protected,
  mp.username as managed_by_username,
  pr.verified,
  exists (
    select 1 from public.follow_requests r
    where r.requester_id = auth.uid() and r.target_id = pr.id
  ) as requested_by_me
from public.profiles pr
left join public.profiles mp on mp.id = pr.managed_by;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'follow_requests') then
    begin
      alter publication supabase_realtime add table public.follow_requests;
    exception when undefined_object then null;
    end;
  end if;
end $$;


-- =====================================================================
-- 13. VIDEO POSTS
--
-- A post holds up to 4 photos / GIFs *or* one video. The video file goes to
-- the public "post-videos" bucket (50 MB per file, the free-plan limit), in
-- the uploader's own folder like the images; posts.video_url keeps its URL.
-- =====================================================================
alter table public.posts
  add column if not exists video_url text;

insert into storage.buckets (id, name, public, file_size_limit)
values ('post-videos', 'post-videos', true, 52428800)
on conflict (id) do update set file_size_limit = excluded.file_size_limit;

drop policy if exists "public read post videos" on storage.objects;
create policy "public read post videos"
  on storage.objects for select
  using (bucket_id = 'post-videos');

drop policy if exists "users upload own post videos" on storage.objects;
create policy "users upload own post videos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete own post videos" on storage.objects;
create policy "users delete own post videos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'post-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- The video can not be swapped when a post is edited (same as the photos).
create or replace function public.guard_post_edit()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null then
    if new.content is distinct from old.content then
      if now() - coalesce(old.scheduled_at, old.created_at) > interval '1 hour' then
        raise exception 'Posts can only be edited within one hour.';
      end if;
      new.edited_at := now();
    end if;
    new.user_id      := old.user_id;
    new.created_at   := old.created_at;
    new.parent_id    := old.parent_id;
    new.quote_id     := old.quote_id;
    new.image_url    := old.image_url;
    new.image_urls   := old.image_urls;
    new.video_url    := old.video_url;
    new.community_id := old.community_id;
    new.poll_ends_at := old.poll_ends_at;
    new.scheduled_at := old.scheduled_at;
    new.location     := old.location;
    if old.edited_at is not null and new.content is not distinct from old.content then
      new.edited_at := old.edited_at;
    end if;
  end if;
  return new;
end;
$$;

-- Feed view again, now with the video of the post.
drop view if exists public.posts_feed;
create view public.posts_feed
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.content,
  p.image_url,
  p.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  (select count(*) from public.post_likes l where l.post_id = p.id)::int as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  exists (
    select 1 from public.bookmarks b
    where b.post_id = p.id and b.user_id = auth.uid()
  ) as bookmarked_by_me,
  p.parent_id,
  (select count(*) from public.posts r where r.parent_id = p.id)::int as reply_count,
  (select count(*) from public.reposts x where x.post_id = p.id)::int as repost_count,
  exists (
    select 1 from public.reposts x
    where x.post_id = p.id and x.user_id = auth.uid()
  ) as reposted_by_me,
  coalesce((select v.views from public.post_views v where v.post_id = p.id), 0)::int as views,
  p.community_id,
  c.name as community_name,
  p.reply_setting,
  p.location,
  p.paid_partnership,
  p.made_with_ai,
  p.scheduled_at,
  p.poll_ends_at,
  p.quote_id,
  q.content       as quote_content,
  q.image_url     as quote_image_url,
  qpr.username    as quote_username,
  qpr.display_name as quote_display_name,
  qpr.avatar_url  as quote_avatar_url,
  pr.profile_label as author_label,
  pr.automated     as author_automated,
  pr.protected     as author_protected,
  p.image_urls,
  p.video_url,
  pr.verified      as author_verified,
  public.bookmark_count(p.id) as bookmark_count,
  q.created_at as quote_created_at,
  qpr.verified as quote_verified,
  p.edited_at,
  cn.id as note_id,
  cn.body as note_body,
  cn.source_url as note_source
from public.posts p
join public.profiles pr on pr.id = p.user_id
left join public.communities c on c.id = p.community_id
left join public.posts q on q.id = p.quote_id
left join public.profiles qpr on qpr.id = q.user_id
left join lateral (
  select v.id, v.body, v.source_url
  from public.community_notes_view v
  where v.post_id = p.id and v.shown
  order by v.helpful_count desc, v.created_at
  limit 1
) cn on true
where p.scheduled_at is null or p.scheduled_at <= now();


-- =====================================================================
-- 14. NOTES  (short status that disappears after 24 hours)
--
-- One note per account, up to 60 characters, shown at the top of the Chat
-- tab to the people who follow the author. A new note replaces the old one
-- and restarts the 24 hours. Only the functions below write to the table, so
-- the app cannot choose its own expiry time.
-- =====================================================================
create table if not exists public.status_notes (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  content    text not null check (char_length(btrim(content)) between 1 and 60),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists status_notes_expires_idx
  on public.status_notes (expires_at);

alter table public.status_notes enable row level security;

-- Readable while active: my own note, or the note of someone I follow (and
-- have no block with, and who has not deactivated).
drop policy if exists "notes readable" on public.status_notes;
create policy "notes readable"
  on public.status_notes for select to authenticated
  using (
    expires_at > now()
    and (
      user_id = auth.uid()
      or (
        exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = status_notes.user_id
        )
        and not public.blocked_between(auth.uid(), status_notes.user_id)
        and not exists (
          select 1 from public.profiles pr
          where pr.id = status_notes.user_id and pr.deactivated_at is not null
        )
      )
    )
  );

-- Create or replace my note (restarts the 24 hours).
create or replace function public.set_status_note(p_content text)
returns public.status_notes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_text text := btrim(coalesce(p_content, ''));
  v_row  public.status_notes;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if char_length(v_text) = 0 then
    raise exception 'Write something first.';
  end if;
  if char_length(v_text) > 60 then
    raise exception 'A note can have at most 60 characters.';
  end if;

  delete from public.status_notes where expires_at <= now();

  insert into public.status_notes (user_id, content, created_at, expires_at)
  values (auth.uid(), v_text, now(), now() + interval '24 hours')
  on conflict (user_id) do update
    set content    = excluded.content,
        created_at = excluded.created_at,
        expires_at = excluded.expires_at
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.delete_status_note()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.status_notes where user_id = auth.uid();
$$;

-- Active notes I may see, newest first, with the author's profile.
drop view if exists public.status_notes_feed;
create view public.status_notes_feed
with (security_invoker = true) as
select
  n.user_id,
  n.content,
  n.created_at,
  n.expires_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  pr.verified
from public.status_notes n
join public.profiles pr on pr.id = n.user_id
where n.expires_at > now();

grant select on public.status_notes to authenticated;
grant select on public.status_notes_feed to authenticated;
grant execute on function public.set_status_note(text) to authenticated;
grant execute on function public.delete_status_note() to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.status_notes;
exception when duplicate_object then
  null;
end $$;


-- =====================================================================
-- 15. COMMUNITIES like X (roles, rules, join requests, hidden posts)
--     and LISTS like X (pinned lists, limits)
--
-- Communities
--   * roles: admin (the creator), moderator, member
--   * membership: "open" (tap Join, agree to the rules) or "request" (ask to
--     join; admin / moderators approve or deny)
--   * 1 to 10 rules per community, a cover photo, an About tab
--   * moderators hide posts that break a rule; admin sets roles
--   * only members can post inside a community; protected accounts cannot join
-- Lists
--   * up to 10 pinned lists, 1000 lists per account, 5000 members per list
-- All changes to roles / membership go through the functions below.
-- =====================================================================

-- ---- Communities: columns ------------------------------------------------
alter table public.communities
  add column if not exists cover_url   text,
  add column if not exists join_policy text not null default 'open';

do $$
begin
  alter table public.communities
    add constraint communities_join_policy_check
    check (join_policy in ('open', 'request'));
exception when duplicate_object then null;
end $$;

alter table public.community_members
  add column if not exists role text not null default 'member';

do $$
begin
  alter table public.community_members
    add constraint community_members_role_check
    check (role in ('admin', 'moderator', 'member'));
exception when duplicate_object then null;
end $$;

-- Communities made before this section: the creator is the admin.
insert into public.community_members (community_id, user_id, role)
select c.id, c.owner_id, 'admin' from public.communities c
on conflict (community_id, user_id) do update set role = 'admin';

create table if not exists public.community_rules (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  position     int  not null,
  title        text not null check (char_length(btrim(title)) between 1 and 100),
  description  text not null default '' check (char_length(description) <= 500),
  unique (community_id, position)
);

create table if not exists public.community_join_requests (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index if not exists community_requests_user_idx
  on public.community_join_requests (user_id);

create table if not exists public.community_hidden_posts (
  post_id      uuid primary key references public.posts (id) on delete cascade,
  community_id uuid not null references public.communities (id) on delete cascade,
  hidden_by    uuid references public.profiles (id) on delete set null,
  reason       text check (reason is null or char_length(reason) <= 100),
  created_at   timestamptz not null default now()
);

alter table public.community_rules          enable row level security;
alter table public.community_join_requests  enable row level security;
alter table public.community_hidden_posts   enable row level security;

-- ---- Communities: helpers ------------------------------------------------
create or replace function public.community_role(p_community uuid, p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.community_members
  where community_id = p_community and user_id = p_user;
$$;

create or replace function public.is_community_mod(p_community uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.community_role(p_community, auth.uid())
                  in ('admin', 'moderator'), false);
$$;

-- ---- Communities: policies (writes go through the functions) ------------
drop policy if exists "users create communities" on public.communities;
drop policy if exists "users join as themselves" on public.community_members;
drop policy if exists "users leave communities" on public.community_members;

drop policy if exists "community rules readable" on public.community_rules;
create policy "community rules readable"
  on public.community_rules for select to authenticated using (true);

drop policy if exists "join requests visible" on public.community_join_requests;
create policy "join requests visible"
  on public.community_join_requests for select to authenticated
  using (user_id = auth.uid() or public.is_community_mod(community_id));

drop policy if exists "hidden posts readable" on public.community_hidden_posts;
create policy "hidden posts readable"
  on public.community_hidden_posts for select to authenticated using (true);

-- ---- Communities: functions ---------------------------------------------
create or replace function public.set_community_rules(p_community uuid, p_rules jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if coalesce(public.community_role(p_community, auth.uid()), '') <> 'admin' then
    raise exception 'Only the admin can change the rules.';
  end if;
  if p_rules is null or jsonb_typeof(p_rules) <> 'array' then
    raise exception 'A Community needs 1 to 10 rules.';
  end if;
  n := jsonb_array_length(p_rules);
  if n < 1 or n > 10 then
    raise exception 'A Community needs 1 to 10 rules.';
  end if;
  delete from public.community_rules where community_id = p_community;
  insert into public.community_rules (community_id, position, title, description)
  select p_community, (e.ord - 1)::int,
         btrim(e.val ->> 'title'),
         coalesce(btrim(e.val ->> 'description'), '')
  from jsonb_array_elements(p_rules) with ordinality as e(val, ord);
end;
$$;

create or replace function public.create_community(
  p_name        text,
  p_description text,
  p_category    text,
  p_join_policy text,
  p_cover_url   text,
  p_image_url   text,
  p_rules       jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  if coalesce((select protected from public.profiles where id = auth.uid()), false) then
    raise exception 'Protected accounts can’t create Communities.';
  end if;
  begin
    insert into public.communities
      (owner_id, name, description, category, join_policy, cover_url, image_url)
    values
      (auth.uid(), btrim(p_name), btrim(coalesce(p_description, '')),
       coalesce(nullif(btrim(p_category), ''), 'General'),
       coalesce(nullif(p_join_policy, ''), 'open'), p_cover_url, p_image_url)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'A Community with that name already exists.';
  end;
  insert into public.community_members (community_id, user_id, role)
  values (v_id, auth.uid(), 'admin');
  perform public.set_community_rules(v_id, p_rules);
  return v_id;
end;
$$;

-- Returns 'joined' or 'requested'.
create or replace function public.join_community(p_community uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_policy text;
begin
  if auth.uid() is null then
    raise exception 'Not signed in.';
  end if;
  select join_policy into v_policy from public.communities where id = p_community;
  if not found then
    raise exception 'This Community doesn’t exist.';
  end if;
  if exists (select 1 from public.community_members
             where community_id = p_community and user_id = auth.uid()) then
    return 'joined';
  end if;
  if coalesce((select protected from public.profiles where id = auth.uid()), false) then
    raise exception 'Protected accounts can’t join Communities.';
  end if;
  if exists (
    select 1 from public.community_members m
    where m.community_id = p_community
      and m.role in ('admin', 'moderator')
      and public.blocked_between(auth.uid(), m.user_id)
  ) then
    raise exception 'You can’t join this Community.';
  end if;

  if v_policy = 'open' then
    insert into public.community_members (community_id, user_id, role)
    values (p_community, auth.uid(), 'member')
    on conflict do nothing;
    delete from public.community_join_requests
      where community_id = p_community and user_id = auth.uid();
    return 'joined';
  end if;

  insert into public.community_join_requests (community_id, user_id)
  values (p_community, auth.uid())
  on conflict do nothing;
  return 'requested';
end;
$$;

create or replace function public.cancel_join_request(p_community uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.community_join_requests
  where community_id = p_community and user_id = auth.uid();
$$;

create or replace function public.leave_community(p_community uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.community_role(p_community, auth.uid()) = 'admin' then
    raise exception 'The admin can’t leave. Delete the Community instead.';
  end if;
  delete from public.community_members
  where community_id = p_community and user_id = auth.uid();
end;
$$;

create or replace function public.review_join_request(
  p_community uuid,
  p_user      uuid,
  p_approve   boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_community_mod(p_community) then
    raise exception 'Only moderators can answer join requests.';
  end if;
  if p_approve then
    insert into public.community_members (community_id, user_id, role)
    values (p_community, p_user, 'member')
    on conflict do nothing;
  end if;
  delete from public.community_join_requests
  where community_id = p_community and user_id = p_user;
end;
$$;

create or replace function public.set_community_role(
  p_community uuid,
  p_user      uuid,
  p_role      text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.community_role(p_community, auth.uid()) <> 'admin' then
    raise exception 'Only the admin can add or remove moderators.';
  end if;
  if p_role not in ('moderator', 'member') then
    raise exception 'Unknown role.';
  end if;
  if public.community_role(p_community, p_user) is null then
    raise exception 'That person is not a member.';
  end if;
  if public.community_role(p_community, p_user) = 'admin' then
    raise exception 'The admin’s role can’t be changed.';
  end if;
  update public.community_members set role = p_role
  where community_id = p_community and user_id = p_user;
end;
$$;

create or replace function public.remove_community_member(p_community uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me     text := public.community_role(p_community, auth.uid());
  target text := public.community_role(p_community, p_user);
begin
  if me is null or me not in ('admin', 'moderator') then
    raise exception 'Only moderators can remove members.';
  end if;
  if target is null then
    return;
  end if;
  if target = 'admin' or (target = 'moderator' and me <> 'admin') then
    raise exception 'You can’t remove this person.';
  end if;
  delete from public.community_members
  where community_id = p_community and user_id = p_user;
end;
$$;

create or replace function public.hide_community_post(p_post uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comm uuid;
begin
  select community_id into v_comm from public.posts where id = p_post;
  if v_comm is null or not public.is_community_mod(v_comm) then
    raise exception 'Only moderators can hide posts in this Community.';
  end if;
  insert into public.community_hidden_posts (post_id, community_id, hidden_by, reason)
  values (p_post, v_comm, auth.uid(), left(p_reason, 100))
  on conflict (post_id) do update
    set hidden_by = excluded.hidden_by, reason = excluded.reason;
end;
$$;

create or replace function public.unhide_community_post(p_post uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comm uuid;
begin
  select community_id into v_comm from public.community_hidden_posts where post_id = p_post;
  if v_comm is null or not public.is_community_mod(v_comm) then
    raise exception 'Only moderators can do that.';
  end if;
  delete from public.community_hidden_posts where post_id = p_post;
end;
$$;

-- Only members can post inside a community.
create or replace function public.posts_community_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.community_id is not null and not exists (
    select 1 from public.community_members
    where community_id = new.community_id and user_id = new.user_id
  ) then
    raise exception 'Join this Community to post in it.';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_community_guard on public.posts;
create trigger posts_community_guard
  before insert on public.posts
  for each row execute function public.posts_community_guard();

-- ---- Communities: views --------------------------------------------------
drop view if exists public.community_stats;
create view public.community_stats
with (security_invoker = true) as
select
  c.id,
  c.owner_id,
  c.name,
  c.description,
  c.category,
  c.image_url,
  c.created_at,
  (select count(*) from public.community_members m where m.community_id = c.id)::int as member_count,
  exists (
    select 1 from public.community_members m
    where m.community_id = c.id and m.user_id = auth.uid()
  ) as joined_by_me,
  c.cover_url,
  c.join_policy,
  public.community_role(c.id, auth.uid()) as my_role,
  exists (
    select 1 from public.community_join_requests r
    where r.community_id = c.id and r.user_id = auth.uid()
  ) as requested_by_me,
  (select count(*) from public.community_rules r where r.community_id = c.id)::int as rule_count,
  (select count(*) from public.community_join_requests r
    where r.community_id = c.id and public.is_community_mod(c.id))::int as pending_requests,
  pr.username     as owner_username,
  pr.display_name as owner_display_name
from public.communities c
join public.profiles pr on pr.id = c.owner_id;

drop view if exists public.community_member_list;
create view public.community_member_list
with (security_invoker = true) as
select
  m.community_id,
  m.user_id,
  m.role,
  m.created_at as joined_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  pr.verified,
  pr.bio
from public.community_members m
join public.profiles pr on pr.id = m.user_id;

drop view if exists public.community_request_list;
create view public.community_request_list
with (security_invoker = true) as
select
  r.community_id,
  r.user_id,
  r.created_at,
  pr.username,
  pr.display_name,
  pr.avatar_url,
  pr.verified,
  pr.bio
from public.community_join_requests r
join public.profiles pr on pr.id = r.user_id;

-- ---- Lists: pinned lists and limits --------------------------------------
create table if not exists public.list_pins (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  list_id    uuid not null references public.lists (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, list_id)
);

alter table public.list_pins enable row level security;
drop policy if exists "own pins on read" on public.list_pins;
create policy "own pins on read" on public.list_pins for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "own pins insert" on public.list_pins;
create policy "own pins insert" on public.list_pins for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.lists l where l.id = list_id)
  );
drop policy if exists "own pins delete" on public.list_pins;
create policy "own pins delete" on public.list_pins for delete to authenticated
  using (user_id = auth.uid());

create or replace function public.list_limits_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'list_pins' then
    if (select count(*) from public.list_pins where user_id = new.user_id) >= 10 then
      raise exception 'You can pin up to 10 Lists.';
    end if;
  elsif tg_table_name = 'lists' then
    if (select count(*) from public.lists where owner_id = new.owner_id) >= 1000 then
      raise exception 'You can have up to 1,000 Lists.';
    end if;
  elsif tg_table_name = 'list_members' then
    if (select count(*) from public.list_members where list_id = new.list_id) >= 5000 then
      raise exception 'A List can have up to 5,000 members.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists list_pins_limit on public.list_pins;
create trigger list_pins_limit before insert on public.list_pins
  for each row execute function public.list_limits_guard();
drop trigger if exists lists_limit on public.lists;
create trigger lists_limit before insert on public.lists
  for each row execute function public.list_limits_guard();
drop trigger if exists list_members_limit on public.list_members;
create trigger list_members_limit before insert on public.list_members
  for each row execute function public.list_limits_guard();

drop view if exists public.list_stats;
create view public.list_stats
with (security_invoker = true) as
select
  l.id,
  l.owner_id,
  pr.username     as owner_username,
  pr.display_name as owner_display_name,
  l.name,
  l.description,
  l.is_private,
  l.banner_url,
  l.created_at,
  (select count(*) from public.list_members m where m.list_id = l.id)::int as member_count,
  (select count(*) from public.list_follows f where f.list_id = l.id)::int as follower_count,
  exists (
    select 1 from public.list_follows f
    where f.list_id = l.id and f.user_id = auth.uid()
  ) as followed_by_me,
  exists (
    select 1 from public.list_pins pn
    where pn.list_id = l.id and pn.user_id = auth.uid()
  ) as pinned_by_me,
  pr.avatar_url   as owner_avatar_url,
  pr.verified     as owner_verified
from public.lists l
join public.profiles pr on pr.id = l.owner_id;

grant select on public.community_stats, public.community_member_list,
  public.community_request_list, public.list_stats to authenticated;
grant select on public.community_rules, public.community_join_requests,
  public.community_hidden_posts, public.list_pins to authenticated;
grant execute on function
  public.create_community(text, text, text, text, text, text, jsonb),
  public.set_community_rules(uuid, jsonb),
  public.join_community(uuid),
  public.cancel_join_request(uuid),
  public.leave_community(uuid),
  public.review_join_request(uuid, uuid, boolean),
  public.set_community_role(uuid, uuid, text),
  public.remove_community_member(uuid, uuid),
  public.hide_community_post(uuid, text),
  public.unhide_community_post(uuid),
  public.community_role(uuid, uuid),
  public.is_community_mod(uuid)
  to authenticated;


-- =====================================================================
-- 16. POLLS: at least 5 minutes (like X)
--     The composer already stops people from choosing less. This trigger
--     makes the database say no too, so a modified app cannot post a
--     1-minute poll. A little slack (4 min) covers phones whose clock is
--     a bit off. Rows written without a signed-in user (this seed file)
--     are not checked.
-- =====================================================================
create or replace function public.enforce_poll_minimum()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.poll_ends_at is not null
     and auth.uid() is not null
     and new.poll_ends_at < now() + interval '4 minutes' then
    raise exception 'A poll must stay open for at least 5 minutes.';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_poll_minimum on public.posts;
create trigger posts_poll_minimum
  before insert on public.posts
  for each row execute function public.enforce_poll_minimum();


-- =====================================================================
-- 17. GROUP CHATS
--     Separate tables so the 1-to-1 messages above stay untouched.
--     Only members can read a group; groups and members are changed
--     through the functions below (never by direct inserts), so nobody can
--     add themselves to somebody else's group.
-- =====================================================================
create table if not exists public.group_chats (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) between 1 and 50),
  created_by  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id      uuid not null references public.group_chats (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  role          text not null default 'member' check (role in ('admin', 'member')),
  joined_at     timestamptz not null default now(),
  last_read_at  timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index if not exists group_members_user_idx on public.group_members (user_id);

create table if not exists public.group_messages (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.group_chats (id) on delete cascade,
  sender_id   uuid not null references public.profiles (id) on delete cascade,
  content     text not null check (char_length(btrim(content)) > 0
                                   and char_length(content) <= 2000),
  created_at  timestamptz not null default now()
);
create index if not exists group_messages_group_idx
  on public.group_messages (group_id, created_at desc);

alter table public.group_chats    enable row level security;
alter table public.group_members  enable row level security;
alter table public.group_messages enable row level security;

-- Membership checks run as the table owner so the policies below do not
-- depend on each other (no recursion).
create or replace function public.is_group_member(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group and user_id = auth.uid()
  );
$$;

create or replace function public.is_group_admin(p_group uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group and user_id = auth.uid() and role = 'admin'
  );
$$;

drop policy if exists "members read group" on public.group_chats;
create policy "members read group"
  on public.group_chats for select to authenticated
  using (public.is_group_member(id));

drop policy if exists "members read members" on public.group_members;
create policy "members read members"
  on public.group_members for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "members read group messages" on public.group_messages;
create policy "members read group messages"
  on public.group_messages for select to authenticated
  using (public.is_group_member(group_id));

drop policy if exists "members write group messages" on public.group_messages;
create policy "members write group messages"
  on public.group_messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_group_member(group_id));

-- Create a group. The creator becomes its admin. People who blocked me (or
-- whom I blocked) are skipped. Needs at least one other person; max 50 total.
create or replace function public.create_group(p_name text, p_members uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me  uuid := auth.uid();
  gid uuid;
  nm  text := btrim(coalesce(p_name, ''));
  n   int;
  ids uuid[];
begin
  if me is null then raise exception 'Sign in first.'; end if;
  if char_length(nm) = 0 then raise exception 'Give the group a name.'; end if;
  if char_length(nm) > 50 then raise exception 'The group name is too long (50 characters max).'; end if;

  select coalesce(array_agg(distinct u), '{}'::uuid[]) into ids
  from unnest(coalesce(p_members, '{}'::uuid[])) as u
  where u <> me
    and exists (select 1 from public.profiles pr where pr.id = u)
    and not public.blocked_between(me, u);
  n := coalesce(array_length(ids, 1), 0);
  if n < 1 then raise exception 'Pick at least one person to add.'; end if;
  if n > 49 then raise exception 'A group can have up to 50 people.'; end if;

  insert into public.group_chats (name, created_by) values (nm, me) returning id into gid;
  insert into public.group_members (group_id, user_id, role) values (gid, me, 'admin');
  insert into public.group_members (group_id, user_id)
    select gid, u from unnest(ids) as u;
  return gid;
end;
$$;

create or replace function public.add_group_members(p_group uuid, p_members uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  have int;
  added int;
begin
  if not public.is_group_admin(p_group) then
    raise exception 'Only a group admin can add people.';
  end if;
  with ins as (
    insert into public.group_members (group_id, user_id)
    select p_group, u
    from (select distinct unnest(coalesce(p_members, '{}'::uuid[])) as u) x
    where u <> me
      and exists (select 1 from public.profiles pr where pr.id = u)
      and not public.blocked_between(me, u)
    on conflict do nothing
    returning 1
  )
  select count(*) into added from ins;
  select count(*) into have from public.group_members where group_id = p_group;
  if have > 50 then
    raise exception 'A group can have up to 50 people.';
  end if;
  return added;
end;
$$;

create or replace function public.rename_group(p_group uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare nm text := btrim(coalesce(p_name, ''));
begin
  if not public.is_group_admin(p_group) then
    raise exception 'Only a group admin can rename the group.';
  end if;
  if char_length(nm) = 0 or char_length(nm) > 50 then
    raise exception 'The group name must be 1 to 50 characters.';
  end if;
  update public.group_chats set name = nm where id = p_group;
end;
$$;

create or replace function public.remove_group_member(p_group uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_group_admin(p_group) then
    raise exception 'Only a group admin can remove people.';
  end if;
  if p_user = auth.uid() then
    raise exception 'Use Leave group to leave.';
  end if;
  delete from public.group_members where group_id = p_group and user_id = p_user;
end;
$$;

-- Leave a group. The oldest member becomes admin when the last admin leaves;
-- an empty group is deleted.
create or replace function public.leave_group(p_group uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare me uuid := auth.uid();
begin
  delete from public.group_members where group_id = p_group and user_id = me;
  if not found then return; end if;
  if not exists (select 1 from public.group_members where group_id = p_group) then
    delete from public.group_chats where id = p_group;
  elsif not exists (select 1 from public.group_members
                    where group_id = p_group and role = 'admin') then
    update public.group_members set role = 'admin'
    where group_id = p_group
      and user_id = (select user_id from public.group_members
                     where group_id = p_group order by joined_at, user_id limit 1);
  end if;
end;
$$;

create or replace function public.mark_group_read(p_group uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.group_members set last_read_at = now()
  where group_id = p_group and user_id = auth.uid();
$$;

create or replace function public.mark_all_groups_read()
returns void
language sql
security definer
set search_path = public
as $$
  update public.group_members set last_read_at = now()
  where user_id = auth.uid();
$$;

-- Inbox rows for my groups: last message + unread count.
create or replace function public.my_groups()
returns table (
  group_id         uuid,
  name             text,
  member_count     int,
  last_message     text,
  last_at          timestamptz,
  last_from_me     boolean,
  last_sender_name text,
  unread_count     int
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    g.id,
    g.name,
    (select count(*)::int from public.group_members x where x.group_id = g.id),
    lm.content,
    coalesce(lm.created_at, g.created_at),
    coalesce(lm.sender_id = auth.uid(), false),
    case when lm.sender_id is null then null
         else coalesce(nullif(btrim(pr.display_name), ''), pr.username) end,
    (select count(*)::int from public.group_messages m
      where m.group_id = g.id
        and m.sender_id <> auth.uid()
        and m.created_at > gm.last_read_at)
  from public.group_members gm
  join public.group_chats g on g.id = gm.group_id
  left join lateral (
    select m.content, m.created_at, m.sender_id
    from public.group_messages m
    where m.group_id = g.id
    order by m.created_at desc
    limit 1
  ) lm on true
  left join public.profiles pr on pr.id = lm.sender_id
  where gm.user_id = auth.uid()
  order by coalesce(lm.created_at, g.created_at) desc;
$$;

-- Members of one group (empty unless I am in it: group_members has RLS).
create or replace function public.group_member_list(p_group uuid)
returns table (
  user_id       uuid,
  username      text,
  display_name  text,
  avatar_url    text,
  role          text
)
language sql
stable
security invoker
set search_path = public
as $$
  select gm.user_id, p.username, p.display_name, p.avatar_url, gm.role
  from public.group_members gm
  join public.profiles p on p.id = gm.user_id
  where gm.group_id = p_group
  order by (gm.role = 'admin') desc, gm.joined_at, p.username;
$$;

grant select on public.group_chats, public.group_members to authenticated;
grant select, insert on public.group_messages to authenticated;
grant execute on function
  public.is_group_member(uuid),
  public.is_group_admin(uuid),
  public.create_group(text, uuid[]),
  public.add_group_members(uuid, uuid[]),
  public.rename_group(uuid, text),
  public.remove_group_member(uuid, uuid),
  public.leave_group(uuid),
  public.mark_group_read(uuid),
  public.mark_all_groups_read(),
  public.my_groups(),
  public.group_member_list(uuid)
  to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.group_messages;
exception when duplicate_object then
  null;
end;
$$;


-- =====================================================================
-- 18. CHAT LIST OPTIONS (long-press a chat): pin, mute, archive,
--     mark as unread and "delete conversation". One row per person and
--     chat; chat_id is the other person's id (1-to-1) or the group's id.
--     "Delete conversation" only hides the older messages for ME
--     (cleared_at) - the other person keeps theirs.
-- =====================================================================
create table if not exists public.chat_prefs (
  user_id        uuid not null references public.profiles (id) on delete cascade,
  chat_id        uuid not null,
  pinned         boolean not null default false,
  muted          boolean not null default false,
  archived       boolean not null default false,
  marked_unread  boolean not null default false,
  cleared_at     timestamptz,
  primary key (user_id, chat_id)
);

alter table public.chat_prefs enable row level security;

drop policy if exists "own chat prefs" on public.chat_prefs;
create policy "own chat prefs"
  on public.chat_prefs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.chat_prefs to authenticated;


-- =====================================================================
-- 19. SUPPORT: Contact us, Report a problem, ID verification requests,
--     and "Download an archive of your data".
--     The team reads and answers the tickets in the dashboard
--     (Table Editor > support_tickets: change `status`, write `reply`);
--     the person sees status and reply in the app.
-- =====================================================================
create table if not exists public.support_tickets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
              references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('contact', 'problem', 'verification')),
  subject     text not null default '' check (char_length(subject) <= 120),
  message     text not null check (char_length(btrim(message)) between 1 and 2000),
  status      text not null default 'open'
              check (status in ('open', 'in_review', 'resolved', 'rejected')),
  reply       text check (reply is null or char_length(reply) <= 2000),
  created_at  timestamptz not null default now()
);
create index if not exists support_tickets_user_idx
  on public.support_tickets (user_id, created_at desc);

alter table public.support_tickets enable row level security;

drop policy if exists "read own tickets" on public.support_tickets;
create policy "read own tickets"
  on public.support_tickets for select to authenticated
  using (user_id = auth.uid());

-- People can only create tickets in the "open" state, as themselves.
drop policy if exists "create own tickets" on public.support_tickets;
create policy "create own tickets"
  on public.support_tickets for insert to authenticated
  with check (user_id = auth.uid() and status = 'open' and reply is null);

-- At most 5 tickets per hour per person (stops spam from a modified app).
create or replace function public.limit_support_tickets()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and (
       select count(*) from public.support_tickets
       where user_id = new.user_id and created_at > now() - interval '1 hour'
     ) >= 5 then
    raise exception 'You sent a lot of requests. Please try again in a while.';
  end if;
  -- Only one verification request can wait at a time.
  if new.kind = 'verification' and exists (
       select 1 from public.support_tickets
       where user_id = new.user_id and kind = 'verification'
         and status in ('open', 'in_review')
     ) then
    raise exception 'You already have a verification request waiting for review.';
  end if;
  return new;
end;
$$;

drop trigger if exists support_tickets_limit on public.support_tickets;
create trigger support_tickets_limit
  before insert on public.support_tickets
  for each row execute function public.limit_support_tickets();

-- Everything this app stores about me, as one JSON document. Runs as the
-- caller, so row level security only lets it read my own rows.
create or replace function public.export_my_data()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  me uuid := auth.uid();
  out jsonb;
begin
  if me is null then raise exception 'Sign in first.'; end if;
  select jsonb_build_object(
    'generated_at', now(),
    'account', (select to_jsonb(p) from public.profiles p where p.id = me),
    'posts', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at)
                       from public.posts x where x.user_id = me), '[]'),
    'likes', coalesce((select jsonb_agg(to_jsonb(x)) from public.post_likes x
                       where x.user_id = me), '[]'),
    'bookmarks', coalesce((select jsonb_agg(to_jsonb(x)) from public.bookmarks x
                           where x.user_id = me), '[]'),
    'reposts', coalesce((select jsonb_agg(to_jsonb(x)) from public.reposts x
                         where x.user_id = me), '[]'),
    'following', coalesce((select jsonb_agg(to_jsonb(x)) from public.follows x
                           where x.follower_id = me), '[]'),
    'followers_count', (select count(*) from public.follows x where x.following_id = me),
    'messages_sent', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at)
                               from public.messages x where x.sender_id = me), '[]'),
    'group_messages_sent', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at)
                                     from public.group_messages x where x.sender_id = me), '[]'),
    'settings', coalesce((select to_jsonb(x.prefs) from public.user_prefs x
                          where x.user_id = me), '{}'),
    'chat_options', coalesce((select jsonb_agg(to_jsonb(x)) from public.chat_prefs x
                              where x.user_id = me), '[]'),
    'support_requests', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at)
                                  from public.support_tickets x where x.user_id = me), '[]')
  ) into out;
  return out;
end;
$$;

grant select, insert on public.support_tickets to authenticated;
grant execute on function public.export_my_data() to authenticated;

-- Tell the API (PostgREST) about the new tables and functions right away.
notify pgrst, 'reload schema';

-- =====================================================================
-- 20. GROK: the verified @grok account and its answers to @grok mentions
--     * @grok is a real (password-less) account with a gold badge, made here
--       so it also exists when the demo seed is not used. Nobody can sign in
--       as it. If a normal account already uses the username "grok" it is
--       renamed (grok_xxxxx) so the real name is free.
--     * When a post or reply mentions @grok, the app asks the Edge Function
--       `ai-assist` (action "mention"). The function checks the caller,
--       reads the post and its thread through grok_mention_context(), asks
--       the AI and then writes the answer with grok_post_reply(). Both
--       functions can only be called by the function's service role, so an
--       app user can never make Grok say something.
-- =====================================================================
create or replace function public.grok_id()
returns uuid
language sql
immutable
as $$ select md5('system-user:grok')::uuid $$;

do $$
declare
  gid uuid := public.grok_id();
begin
  update public.profiles
     set username = left('grok_' || substr(md5(id::text), 1, 5), 15)
   where lower(username) = 'grok' and id <> gid;

  if not exists (select 1 from auth.users where id = gid) then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', gid,
      'authenticated', 'authenticated', 'grok@system.xreplica.test',
      '',                               -- no password: nobody can sign in
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('username', 'grok', 'display_name', 'Grok'),
      now(), now()
    );
  end if;

  update public.profiles set
    username     = 'grok',
    display_name = 'Grok',
    bio          = 'The built-in AI assistant of X Replica. Mention @grok in a post or reply and ask me anything about it.',
    avatar_url   = 'https://api.dicebear.com/9.x/initials/png?size=256&seed=G&backgroundColor=000000&textColor=ffffff&fontWeight=700',
    onboarded    = true,
    verified     = 'gold',
    automated    = true,
    dm_setting   = 'none'
  where id = gid;
end $$;

-- Some Supabase versions need these token columns to be '' instead of NULL.
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
    execute format('update auth.users set %I = coalesce(%I, '''') where id = %L',
                   c, c, public.grok_id());
  end loop;
end $$;

-- "Who can reply" rules do not apply to Grok answering a mention (it only
-- ever answers the post that mentions it, and sets the flag itself).
create or replace function public.enforce_reply_setting()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_author  uuid;
  parent_setting text;
  parent_text    text;
  my_username    text;
begin
  if new.parent_id is null then
    return new;
  end if;
  if current_setting('app.grok_reply', true) = '1'
     and new.user_id = public.grok_id() then
    return new;
  end if;
  select user_id, reply_setting, content
    into parent_author, parent_setting, parent_text
    from public.posts where id = new.parent_id;
  if parent_author is null or parent_author = new.user_id or parent_setting = 'everyone' then
    return new;
  end if;
  if parent_setting = 'following' then
    if exists (select 1 from public.follows f
               where f.follower_id = parent_author and f.following_id = new.user_id) then
      return new;
    end if;
    raise exception 'Only accounts the author follows can reply to this post.';
  elsif parent_setting = 'mentioned' then
    select username into my_username from public.profiles where id = new.user_id;
    if position(lower('@' || my_username) in lower(parent_text)) > 0 then
      return new;
    end if;
    raise exception 'Only accounts the author mentioned can reply to this post.';
  else
    raise exception 'Only verified accounts can reply to this post.';
  end if;
end;
$$;

-- Does this text call @grok? (not part of an e-mail address or a longer name)
create or replace function public.mentions_grok(p_text text)
returns boolean
language sql
immutable
as $$ select coalesce(p_text, '') ~* '(^|[^a-z0-9_])@grok($|[^a-z0-9_])' $$;

-- What Grok may read to answer [p_post], written by [p_user]. Raises when
-- Grok should not answer (not the author's post, no mention, already
-- answered, too old, too many answers this hour).
create or replace function public.grok_mention_context(p_post uuid, p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  m      record;
  par    record;
  gpar   record;
  q      record;
  ctx_parent jsonb;
  ctx_grand  jsonb;
  ctx_quote  jsonb;
begin
  select p.id, p.user_id, p.content, p.parent_id, p.quote_id, p.image_url,
         p.created_at, pr.username, pr.display_name
    into m
    from public.posts p join public.profiles pr on pr.id = p.user_id
   where p.id = p_post;
  if not found or m.user_id <> p_user then
    raise exception 'That is not your post.';
  end if;
  if p_user = public.grok_id() then
    raise exception 'Grok does not answer itself.';
  end if;
  if not public.mentions_grok(m.content) then
    raise exception 'The post does not mention @grok.';
  end if;
  if m.created_at < now() - interval '15 minutes' then
    raise exception 'This post is too old for Grok to answer.';
  end if;
  if exists (select 1 from public.posts r
             where r.parent_id = p_post and r.user_id = public.grok_id()) then
    raise exception 'Grok already answered this post.';
  end if;
  if (select count(*) from public.posts r
        join public.posts o on o.id = r.parent_id
       where r.user_id = public.grok_id() and o.user_id = p_user
         and r.created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Grok has answered a lot of your posts this hour. Try again later.';
  end if;

  -- The post being answered (when the mention is a reply), only if the
  -- asker may see it.
  if m.parent_id is not null then
    select p.id, p.content, p.parent_id, p.image_url, pr.username, pr.display_name
      into par
      from public.posts p join public.profiles pr on pr.id = p.user_id
     where p.id = m.parent_id
       and not public.blocked_between(p_user, p.user_id)
       and (not pr.protected or pr.id = p_user or exists (
             select 1 from public.follows f
              where f.follower_id = p_user and f.following_id = pr.id));
    if found then
      ctx_parent := jsonb_build_object(
        'author', par.username, 'name', par.display_name,
        'text', par.content, 'image', par.image_url);
      if par.parent_id is not null then
        select p.content, pr.username, pr.display_name
          into gpar
          from public.posts p join public.profiles pr on pr.id = p.user_id
         where p.id = par.parent_id
           and not public.blocked_between(p_user, p.user_id)
           and (not pr.protected or pr.id = p_user or exists (
                 select 1 from public.follows f
                  where f.follower_id = p_user and f.following_id = pr.id));
        if found then
          ctx_grand := jsonb_build_object(
            'author', gpar.username, 'name', gpar.display_name, 'text', gpar.content);
        end if;
      end if;
    end if;
  end if;

  if m.quote_id is not null then
    select p.content, p.image_url, pr.username, pr.display_name
      into q
      from public.posts p join public.profiles pr on pr.id = p.user_id
     where p.id = m.quote_id
       and not public.blocked_between(p_user, p.user_id)
       and (not pr.protected or pr.id = p_user or exists (
             select 1 from public.follows f
              where f.follower_id = p_user and f.following_id = pr.id));
    if found then
      ctx_quote := jsonb_build_object(
        'author', q.username, 'name', q.display_name,
        'text', q.content, 'image', q.image_url);
    end if;
  end if;

  return jsonb_build_object(
    'asker', m.username,
    'text', m.content,
    'image', m.image_url,
    'parent', ctx_parent,
    'grandparent', ctx_grand,
    'quote', ctx_quote
  );
end;
$$;

-- Writes Grok's answer as a reply to [p_post] (always "@asker answer",
-- at most 280 characters). Returns the new post's id.
create or replace function public.grok_post_reply(p_post uuid, p_user uuid, p_text text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_asker text;
  v_text  text;
  v_id    uuid;
begin
  perform public.grok_mention_context(p_post, p_user);  -- same checks
  perform pg_advisory_xact_lock(hashtext('grok:' || p_post::text));
  if exists (select 1 from public.posts r
             where r.parent_id = p_post and r.user_id = public.grok_id()) then
    raise exception 'Grok already answered this post.';
  end if;
  select username into v_asker from public.profiles where id = p_user;
  v_text := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
  if v_text = '' then
    raise exception 'Grok has nothing to say.';
  end if;
  v_text := left('@' || v_asker || ' ' || v_text, 280);

  perform set_config('app.grok_reply', '1', true);
  insert into public.posts (user_id, content, parent_id)
  values (public.grok_id(), v_text, p_post)
  returning id into v_id;
  perform set_config('app.grok_reply', '0', true);
  return v_id;
end;
$$;

revoke all on function public.grok_mention_context(uuid, uuid) from public, anon, authenticated;
revoke all on function public.grok_post_reply(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.grok_mention_context(uuid, uuid) to service_role;
grant execute on function public.grok_post_reply(uuid, uuid, text) to service_role;
grant execute on function public.mentions_grok(text) to authenticated;
grant execute on function public.grok_id() to authenticated;

notify pgrst, 'reload schema';

-- =====================================================================
-- 21. CHAT MEDIA: photos, videos and voice messages in chats
--     * `chat-media` is a PRIVATE bucket (files are stored as
--       <sender-id>/<name>); the app opens them with short-lived signed
--       links. Only the sender can upload / delete their files.
--     * A file can be read by the people who can read a message that points
--       to it (the other person of a 1-to-1 chat, the members of a group):
--       the policy simply looks the file up in `messages` /
--       `group_messages`, whose own row level security does the rest.
--     * A message may only point to a file in the SENDER's own folder, so
--       nobody can "borrow" somebody else's file by naming its path.
--     * `content` keeps a short label ("📷 Photo", "🎥 Video",
--       "🎤 Voice message") so the inbox list and previews need no changes.
-- =====================================================================
alter table public.messages
  add column if not exists media_path text,
  add column if not exists media_kind text,
  add column if not exists media_ms   integer;

alter table public.group_messages
  add column if not exists media_path text,
  add column if not exists media_kind text,
  add column if not exists media_ms   integer;

alter table public.messages drop constraint if exists messages_media_check;
alter table public.messages add constraint messages_media_check check (
  (media_path is null and media_kind is null)
  or (media_kind in ('image', 'video', 'voice')
      and media_path is not null
      and media_path like sender_id::text || '/%'
      and char_length(media_path) <= 300)
);

alter table public.group_messages drop constraint if exists group_messages_media_check;
alter table public.group_messages add constraint group_messages_media_check check (
  (media_path is null and media_kind is null)
  or (media_kind in ('image', 'video', 'voice')
      and media_path is not null
      and media_path like sender_id::text || '/%'
      and char_length(media_path) <= 300)
);

create index if not exists messages_media_idx
  on public.messages (media_path) where media_path is not null;
create index if not exists group_messages_media_idx
  on public.group_messages (media_path) where media_path is not null;

insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-media', 'chat-media', false, 52428800)
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit;

drop policy if exists "upload own chat media" on storage.objects;
create policy "upload own chat media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "delete own chat media" on storage.objects;
create policy "delete own chat media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "read chat media" on storage.objects;
create policy "read chat media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from public.messages m
                 where m.media_path = storage.objects.name)
      or exists (select 1 from public.group_messages g
                 where g.media_path = storage.objects.name)
    )
  );

notify pgrst, 'reload schema';
