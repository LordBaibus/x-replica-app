-- =====================================================================
-- UPDATE: photos, videos and voice messages in chats (section 21 of
-- schema.sql). Paste this whole file in the Supabase SQL editor and press
-- Run. It only adds columns, a private storage bucket and policies, so it is
-- safe to run more than once and it does not touch your messages.
-- (Needs the older sections of schema.sql, including the group chats, first.)
-- =====================================================================

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
