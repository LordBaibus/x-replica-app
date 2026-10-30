-- =====================================================================
-- UPDATE: the verified @grok account + Grok answering @grok mentions
-- (section 20 of schema.sql). Paste this whole file in the Supabase SQL
-- editor and press Run. It only adds / replaces functions and one account,
-- so it is safe to run more than once and it does not touch your posts,
-- users or messages. (Needs the older sections of schema.sql first.)
--
-- Then deploy the Edge Function again so it knows the "mention" action:
--   supabase functions deploy ai-assist
-- (the AI_API_KEY secret you already set is reused.)
-- =====================================================================

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
