-- =====================================================================
-- UPDATE: group chats, chat options, support tickets (sections 17-19 of
-- schema.sql). Paste this whole file in the Supabase SQL editor and press
-- Run. It only adds things, so it is safe to run more than once, and it does
-- not touch your posts, users or messages.
-- (Needs the older sections of schema.sql to have been run before.)
-- =====================================================================

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
