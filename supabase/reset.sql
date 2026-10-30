-- =====================================================================
--  X Replica — FULL RESET of the Supabase project
--  Deletes every user and all app data, tables, views and functions.
--  Run in: Supabase Dashboard → SQL Editor → New query.
--  Then run supabase/schema.sql again to rebuild everything.
--
--  BEFORE running: Dashboard → Storage → open avatars, post-images and
--  myday → select all files → Delete (SQL cannot delete stored files).
-- =====================================================================

drop trigger  if exists on_auth_user_created on auth.users;

drop view     if exists public.posts_feed;
drop view     if exists public.community_stats;
drop view     if exists public.list_stats;
drop view     if exists public.profile_stats;

drop function if exists public.my_conversations();
drop function if exists public.poll_results(uuid);
drop function if exists public.enforce_reply_setting() cascade;
drop function if exists public.username_available(text);
drop function if exists public.email_registered(text);
drop function if exists public.bump_views(uuid[]);
drop function if exists public.handle_new_user();

drop table    if exists public.poll_votes cascade;
drop table    if exists public.poll_options cascade;
drop table    if exists public.list_follows cascade;
drop table    if exists public.list_members cascade;
drop table    if exists public.lists cascade;
drop table    if exists public.community_members cascade;
drop table    if exists public.communities cascade;
drop table    if exists public.profile_private cascade;
drop table    if exists public.post_views cascade;
drop table    if exists public.reposts    cascade;
drop table    if exists public.bookmarks  cascade;
drop table    if exists public.messages   cascade;
drop table    if exists public.stories    cascade;
drop table    if exists public.follows    cascade;
drop table    if exists public.post_likes cascade;
drop table    if exists public.posts      cascade;
drop table    if exists public.profiles   cascade;

-- Remove every account (also clears their sessions and identities).
delete from auth.users;
