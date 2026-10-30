# X Replica — a replica of the X social app (Flutter + Supabase)

Educational final project: a cross-platform replica of an X-style social network for **iOS and Android**.

- **UI:** Flutter with [`adaptive_platform_ui`](https://pub.dev/packages/adaptive_platform_ui) + Cupertino only — native Cupertino / iOS 26 Liquid Glass on iOS; on Android the package renders its own platform widgets. The app code never imports `package:flutter/material.dart` (icons are `CupertinoIcons`, routes are `CupertinoPageRoute` / `PageRouteBuilder`).
- **Backend:** Supabase only — Auth, Postgres, Storage (images) and Realtime.
- Named **X Replica**. It copies the *layout and behaviour* of the X mobile app; the logo is a plain placeholder mark, not X's official logo.

## Features (assignment checklist)

| Requirement | Where |
|---|---|
| Register / log in | `auth_screen.dart` (saved-account picker, log-in, "Create your account" with email) → `otp_screen.dart` (6-digit email code) → `onboarding_flow.dart` |
| Sign-up steps like X | `onboarding_flow.dart`: birthday → name → username → password → find friends (UI only) → profile picture → interests → suggested accounts → try searching. Each step saves to Supabase; quitting midway resumes where you stopped (`profiles.onboarded`) |
| Forgot password (6-digit code) / change password | `otp_screen.dart` (reset purpose), `change_password_screen.dart` |
| Profile: info, bio, picture | `profile_view.dart` (banner, Joined, stats, Posts / Replies / Reposts / Media tabs, empty states), `edit_profile_screen.dart` |
| Newsfeed with image posts | `feed_view.dart` ("For you", "Following", one tab per interest), `compose_post_screen.dart`, `post_card.dart` / `post_tile.dart` (reply, repost popup, like, views, bookmark, share sheet, post menu), `post_detail_screen.dart`, `widgets/{post_menus,share_post_sheet,grok_post_sheet,post_media,anchored_popup,badges,avatar}.dart`, `post_extra_screens.dart` (quotes, interactions) |
| Explore / Search | `explore_view.dart` (Explore, Trending, News, Sports, Entertainment), `search_screen.dart` (People / Posts) |
| Follow | profile screen, `suggested_list.dart`, `connect_screen.dart` |
| Real-time direct messages | `conversations_view.dart`, `chat_view.dart` (header, "Joined / Followers / View profile" intro, closed-inbox panel) — Supabase Realtime |
| **Notes** (short temporary status, the "Myday" requirement) | `widgets/notes_strip.dart`, `widgets/note_sheets.dart`, `conversations_view.dart` (top of the Chat tab), `Api.*StatusNote*`, `StatusNote` model — table `status_notes`, `schema.sql` section 14 |
| Collapsible sidebar | `side_drawer.dart` (push-over drawer), `drawer_menu.dart` |
| Developer Info in Settings | `developer_info_screen.dart` — **edit `lib/core/developers.dart`** |
| History (Bookmarks / Videos / Articles / Likes) / Notifications | `bookmarks_screen.dart` (sidebar → **History**), `notifications_view.dart` |
| Composer (photo, camera, AI helper, GIF search, schedule calendar, quote picker, poll builder, tag location, content disclosures, threads, who-can-reply) | `compose_post_screen.dart`, `scheduled_posts_screen.dart`, `widgets/{dialog_card,schedule_dialog,gif_picker_dialog,ai_dialogs,quote_picker,location_picker,poll_view,quote_card,reply_guard}.dart`, `services/{gif,ai,location}_service.dart`, `supabase/functions/ai-assist`, `supabase/schema.sql` section 8 |
| Chat (Welcome → passcode → inbox, filter menu, New chat) | `chat_tab.dart`, `conversations_view.dart`, `chat_view.dart`, `services/chat_passcode.dart`, `widgets/new_chat_dialog.dart`, `widgets/popover_menu.dart` |
| Settings and privacy (all sections, search, Account, Security, Apps and sessions, Delegate, Privacy, Mute and block, Chat, Notifications, Accessibility, Display, Languages, Data usage, Storage) / Subscription plans | `settings_screen.dart` (menu + search), `account_screens.dart`, `security_screens.dart`, `privacy_screens.dart`, `data_screens.dart`, `chat_settings_screens.dart`, `prefs_screens.dart`, `timeline_panel.dart`, `settings_extra_screens.dart`, `subscription_screen.dart`, `widgets/{settings_kit,settings_parts,settings_fields,communities_welcome}.dart`, `services/{user_prefs,display_prefs,moderation,session_tracker}.dart`, `core/countries.dart` |
| Creator Studio / Follower requests | `creator_studio_screen.dart` (Analytics and Inspiration use your own posts), `follower_requests_screen.dart` |
| Profile "Set Up" (picture with emoji avatars, header, bio) and Share Profile sheet | `profile_setup_flow.dart`, `widgets/share_profile_sheet.dart` |
| Communities (Home / Explore, join or ask to join, roles, rules, moderation, post inside a community) | `communities_screen.dart`, `community_detail_screen.dart`, `community_manage_screens.dart`, `create_community_screen.dart`, `widgets/community_join_sheet.dart` — tables `communities`, `community_members`, `community_rules`, `community_join_requests`, `community_hidden_posts`, `posts.community_id`, `schema.sql` section 15 |
| Lists (discover, follow, pin, create / edit, members' posts, private lists) | `lists_screen.dart`, `manage_lists_screen.dart`, `create_list_screen.dart`, `edit_list_screen.dart`, `list_detail_screen.dart` — tables `lists`, `list_members`, `list_follows`, `schema.sql` section 15 |

**Placeholders (UI only):** "Find friends" contact sync, Subscription purchase, the switches listed under *Settings: what is real* below, group chats, Creator Studio programs, Help Center, the Videos tab (images only), "Finish Verification". They open an info page or dialog; the original X services are not part of the project.

## 1. Create the Supabase project

1. Create a project at <https://supabase.com>.
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and run it. (The file is safe to re-run. To wipe everything first, empty the three storage buckets, run `supabase/reset.sql`, then run `schema.sql` again and clear the app's data on the phone.)
   It creates the tables, row level security policies, views, the `my_conversations()` function, Realtime publication and the two storage buckets (`avatars`, `post-images`).
3. **Authentication → Providers → Email:** keep **Confirm email ON** (the app asks for the emailed 6-digit code after sign-up) and check that **Email OTP length** is **6**.
4. **Authentication → Emails (Email Templates):** switch every email from a link to a 6-digit code — see [Email codes](#email-codes-6-digit-otp) below.
5. **Authentication → SMTP Settings:** set up a custom SMTP provider — see [Email codes](#email-codes-6-digit-otp) below.
6. **Project Settings → API:** copy the **Project URL** and the **publishable key** (`sb_publishable_…`).

### Email codes (6-digit OTP)

The app never uses confirmation links; every email carries a 6-digit code that the user types into the app.

**Templates.** In **Authentication → Emails**, open each template, paste the matching file from `supabase/email_templates/` into the *Message body* and save. Each one prints `{{ .Token }}` (the 6-digit code) instead of `{{ .ConfirmationURL }}`.

| Dashboard template | File | Subject suggestion |
|---|---|---|
| Confirm sign up | `confirm_signup.html` | `Your X Replica confirmation code` |
| Reset password | `reset_password.html` | `Your X Replica password reset code` |
| Magic link | `magic_link.html` | `Your X Replica log-in code` |
| Change email address | `change_email.html` | `Confirm your new email` |
| Reauthentication | `reauthentication.html` | `Confirm it's you` |

(The *Invite user* template can only contain a link; the app does not use it.)

**Flows.**
- *Sign up:* Create account → code screen → correct code confirms the email and signs in. Logging in with an address that was never confirmed sends a new code and opens the same screen.
- *Forgot password:* type your email on the log-in screen → **Forgot password?** → enter the code → choose a new password.
- Codes can be re-sent after 60 seconds (Supabase's default minimum interval).

**Use a custom SMTP provider.** Supabase's built-in email sender is for testing only: it delivers just to addresses of your own Supabase organization's team and is limited to about 2 emails per hour ([docs](https://supabase.com/docs/guides/auth/auth-smtp)). Anyone else who signs up will never get a code. For the demo, add a free custom SMTP provider under **Authentication → SMTP Settings** (e.g. Resend, Brevo, or Gmail with an app password), then you can raise the email rate limit under **Authentication → Rate Limits**.

## 2. Run the app

The project URL and publishable key are already set as defaults in `lib/core/config.dart`, so a plain `flutter run` connects to the project. To point at another Supabase project, override them with `--dart-define`:

```powershell
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

If the values are blank or still placeholders the app opens a setup screen instead of crashing.
In VS Code / Android Studio add the same two `--dart-define` values to the run configuration's additional arguments.

## 3. Platform setup (already applied to this project)

- **iOS:** deployment target **15.0** (required by `adaptive_platform_ui`), and `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` for choosing photos.
- **Android:** `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`.

## 4. Install on a phone (no Play Store)

The app is installed directly on devices, not published to a store. `codemagic.yaml` defines three workflows; no secrets are needed because the Supabase URL and publishable key are built into `lib/core/config.dart`.

| Workflow | Output | When to use it |
| --- | --- | --- |
| `ios-unsigned-ipa` | `x_replica-unsigned.ipa` | iPhone with a **free** Apple ID (Sideloadly / AltStore) |
| `android-apk` | `x_replica.apk` (debug key) | Quick Android install, no setup |
| `android-signed-apk` | `x_replica.apk` (your keystore) | Android installs that must update over the old one |

Every workflow runs `flutter pub get`, `flutter analyze` and `flutter test` (these two never block the build), numbers the build with Codemagic's `BUILD_NUMBER`, and passes `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `GIPHY_API_KEY` as `--dart-define` when you set them in an environment variable group called `app_config` (uncomment the `groups:` lines in `codemagic.yaml`; the Giphy key turns on GIF search).

**Before the first launch** run `supabase/schema.sql` and then `supabase/seed.sql` (optional fake accounts and posts) in the Supabase SQL editor. Run `schema.sql` again whenever it changes; it is safe to re-run.

**Android** — build `android-apk` (or run `flutter build apk --release` locally), download `x_replica.apk`, copy it to the phone and open it (allow "install unknown apps" when asked). Codemagic creates a new debug key on every build, so a newer `android-apk` cannot be installed over an older one: uninstall first, or use `android-signed-apk`. For that one, create a keystore once (`keytool -genkeypair -v -keystore x_replica.jks -alias x_replica -keyalg RSA -keysize 2048 -validity 10000`), upload it in Codemagic under *Teams → Code signing identities → Android keystores* with the reference name `x_replica_keystore`, and start the workflow by hand. Keep the `.jks` and its passwords safe. `android/app/build.gradle.kts` uses `android/key.properties` (written by the workflow) when it exists and the debug key otherwise.

**iOS with a free Apple developer account** — build `ios-unsigned-ipa` on [codemagic.io](https://codemagic.io):

1. Push the project to GitHub / GitLab / Bitbucket and add it to Codemagic (Add application → choose the repo → "Flutter App" with `codemagic.yaml`).
2. Start a build and select the **ios-unsigned-ipa** workflow. It generates the iOS project, sets the Podfile to iOS 15, runs `pod install`, builds with `--no-codesign` and zips `Runner.app` into `x_replica-unsigned.ipa` (Artifacts).
3. Download the `.ipa` to your PC and install it with **Sideloadly** or **AltStore**, signing in with your free Apple ID. Those tools replace the bundle id with one that belongs to your Apple ID; that is expected.
4. On the iPhone trust your Apple ID under *Settings → General → VPN & Device Management* and enable *Developer Mode* (iOS 16+).

Free Apple ID limits: the installed app expires after 7 days (re-install or refresh it; AltStore can refresh it for you), you can have 3 sideloaded apps at a time, and there is no TestFlight or push notifications. Codemagic cannot sign with a free account, which is why the `.ipa` is delivered unsigned. A commented `ios-signed-ipa` template for the paid program is at the bottom of `codemagic.yaml`.

## Features worth knowing about

- **Messages:** press and hold a message for ❤️ 😂 😮 😢 🙏 👍 reactions, *Reply* or *Copy text*; double-tap to ❤️. Replies show a quote of the original inside the bubble. Stored in `messages.reply_to` and `message_reactions` (live via realtime).
- **Post analytics:** "View post analytics" on your own post shows views, engagements, likes, reposts, quotes, replies, bookmarks, shares, detail expands, profile visits and a 7-day chart. Numbers come from the `post_analytics()` function; detail expands, profile visits and shares are logged in `post_events` when *other* people open the post, tap your name on it or share it. Only the author can read them.
- **Reports:** *Report post* and *Mark as spam* save a row in the `reports` table (one per reporter, post and reason). Read them in the Supabase table editor.
- **Community Notes:** *Request Community Note* saves a row in `note_requests`. Anyone can write a note and rate notes *Helpful* / *Not helpful* (not their own). A note appears under the post once it has at least 2 helpful ratings and more helpful than not helpful (`community_notes_view.shown`).
- **Multiple accounts:** the account switcher (drawer → the person-with-plus icon next to your picture) lists the accounts logged in on this phone. Tapping one switches without a password, using the refresh token that account's session was given. The tokens are kept in the app's local storage (`shared_preferences`), the same place the Supabase library keeps the current session, and the password is never stored. Use *Log out* to forget that session; use the ✕ (press and hold) in the switcher to remove an account from the phone.

## 5. Tests

```powershell
flutter test
```

`test/validators_test.dart` covers the input validation rules, `test/widget_test.dart` and `test/features_test.dart` cover model parsing (community notes, post analytics, message replies, saved accounts).

## Project layout

```
lib/
  main.dart                  app + auth gate (login ⇄ app)
  core/                      config, colours, per-platform icons, validators, helpers, developers list
  models/models.dart         Profile, Post, Message, Conversation
  services/                  api.dart (all Supabase calls), image_picker_service.dart
  widgets/                   avatar, post card, person tile, states, fold-aware layout
  screens/                   auth, email-code (OTP), home shell (bottom nav + side drawer), feed, compose,
                             people, notifications, profile, messages, settings, change password, developer info
supabase/schema.sql          database, RLS, storage, realtime
supabase/email_templates/    6-digit-code email templates to paste into the Supabase dashboard
codemagic.yaml               CI builds
```

## Notes

- Dark mode works on both iOS and Android: it follows the phone's setting, or Settings > Accessibility, display and languages > Display can force Light/Dark. Android gets a small Material theme (imported with `show` only) so system widgets match.
- Posts are limited to 280 characters and bios to 160.
- Row level security guarantees users can only edit their own data and only read their own messages.
- Ideas to extend: replies, reposts, notifications, hashtag search, dark/light toggle in Settings.


## Composer extras: setup

* **Database:** re-run `supabase/schema.sql` (section 8 adds the post columns, poll tables, reply rule and the new `posts_feed`).
* **GIF search:** make a free key at developers.giphy.com (beta keys allow 100 calls/hour) and run with `--dart-define=GIPHY_API_KEY=your_key`. Without it the GIF dialog only accepts a pasted GIF link. GIPHY asks apps to show "Powered by GIPHY" (the dialog does).
* **AI helper ("Generate image", "Enhance your post"):** the app calls the Supabase Edge Function `ai-assist`, which keeps the API key on the server:
  ```
  supabase functions deploy ai-assist
  supabase secrets set AI_API_KEY=sk-your-openai-key
  ```
  Optional secrets: `AI_BASE_URL` (default `https://api.openai.com/v1`; any OpenAI-compatible API such as xAI works), `AI_CHAT_MODEL`, `AI_IMAGE_MODEL`. These APIs are paid per use.
* **Grok tab:** modelled on X's Grok screen: avatar + history on top, a dismissible "Try for free" card, and a row of cards: *Link your Grok account* (tests the AI connection), *Hire A Bot* (role picker), *Create Images*, *Edit Image* (OpenAI image edits) and *Try Voice Mode*. The input box has a paperclip (send a photo and ask about it), a mic (dictation) and a **Speak** button (voice mode: you talk, Grok answers out loud). It uses the same `ai-assist` function and `AI_API_KEY`, so **redeploy the function** after updating (new `edit` action, personas, photo input). Voice needs `flutter pub get` (speech_to_text, flutter_tts) and microphone/speech permission on the device.
* **Tag location:** uses the phone's GPS and built-in geocoder (`geolocator`, `geocoding`); no key needed. Permissions are already in `Info.plist` and `AndroidManifest.xml`.


## Posts, badges and messages: setup

* **Database:** re-run `supabase/schema.sql` (section 10). It adds `posts.image_urls` (up to 4 photos per post), `profiles.verified`, the `bookmark_count()` function and the new `profile_stats` / `posts_feed` views. Without it the app still posts and reads, but extra photos, badges and the bookmark number do not show.
* **Verification badges** cannot be set from the app (a trigger keeps the value for every signed-in user). Give one from the Supabase SQL Editor: `update public.profiles set verified = 'blue' where username = 'someone';` (`blue` = person, `gold` = organisation with a rounded-square picture, `gray` = government/official). Use `null` to remove it.
* **Post layout:** the feed, replies and the post page follow X's iPad screens: one line for name, badge, @handle and time; a small "X" at the top right of a post that opens the menu; Grok button and "..." on replies; a repost popup (Repost / Quote / React with Video); a bookmark that turns blue and counts; a share sheet (search, people, Copy Link, Share via..., Messages); and a Grok sheet that explains the post (long-press a post or tap the Grok icon on a reply). A shared post is sent as a link such as `xreplica://post/<id>`; tapping it in the chat opens the post.
* **Direct messages:** the chat page shows who you are talking to ("Joined ...", follower count, View profile). If the other person's inbox is closed for you (their Message Requests setting, or a block), the box is replaced by "has a closed inbox" with *Not Now* / *Use X Number*.
* **UI only here:** React with Video, voice/video call buttons, X Number, Report post (nothing is sent). Third-party share targets (other apps) are not included; "Share via..." copies the link.


## Settings and privacy: setup

* **Database:** re-run `supabase/schema.sql` (section 9). It adds the profile columns (country, profile label, automation, deactivation, protected posts, DM setting), the tables `user_prefs`, `user_sessions`, `user_blocks`, `user_mutes`, the 48-hour lock on profile labels, the `can_message` rule for message requests and the new `profile_stats` / `posts_feed` views. If you skip it the settings pages still open and save on the phone, but blocks, sessions, labels and message requests need the new tables.
* **Change email** sends a 6-digit code to the new address. In the Supabase dashboard open **Authentication → Email Templates → Change Email Address** and paste `supabase/email_templates/change_email.html` (it shows `{{ .Token }}`), and switch **Secure email change** off, otherwise Supabase asks for a code from both addresses.
* **Deactivate:** hides the profile and posts; signing in again brings the account back (the 30-day limit of the real app is not enforced).
* **Display** (System / Day / Night and font size) belongs to the device, not the account, and works on iOS and Android.

### Settings: what is real

| Real (works end to end) | Where it is stored / enforced |
|---|---|
| Update username (live availability check, suggestions), Country, Phone (saved, not verified by SMS), Email change with emailed code | profiles / `profile_private` / Supabase Auth |
| Update password, "Forgot password?" from inside Settings, Confirm-your-password gate | Supabase Auth |
| Automation (managing account) and Parody / commentary / fan label (48-hour lock, shown on profile and under posts) | profiles + trigger `lock_profile_label_trg` |
| Deactivate your account | `profiles.deactivated_at`, hidden by RLS |
| Sessions / Account access history / Logged-in devices, "Log out of all other sessions" | `user_sessions` + Supabase "sign out other sessions" |
| Protect your posts | `profiles.protected` + posts RLS + `follow_requests` (see "Private accounts" below) |
| Block / mute accounts (also from the post menu), Muted words, Muted notifications filters | `user_blocks`, `user_mutes`, `user_prefs`, filtered in the feed and notifications |
| Message Requests (Everyone / No one; "Verified users" behaves like No one) | `profiles.dm_setting` + `can_message()` RLS on messages |
| Chat passcode (create / change), Reset Chat, Clear Media | `ChatPasscode`, image cache |
| Display: theme and font size | `DisplayPrefs` (whole app) |
| Timelines panel (pin topics = extra Home tabs) | `profiles.interests` |
| Grok: delete conversation history, "remember conversation history" | `GrokHistory` |
| Communities welcome dialog (first visit) | `user_prefs` |

Everything else (two-factor, ID verification, passkey, password-reset protect, Delegate lists, Connected apps / third-party integrations, Spaces pages, calls, chat data usage and history, discoverability and contacts, ads / inferred identity / data-sharing / location / Grok-training switches, SMS / email / push notification choices, accessibility switches, languages, network data usage, Explore settings, photo tagging, protect videos) is a replica of the screen: the choice is saved per account in `user_prefs`, but no feature reads it yet.

`flutter test` also runs `test/settings_helpers_test.dart` (email masking, phone and country helpers, muted-word matching).

### Post menu, Post activity and reports

- Every post in the feed has the **Grok** button and the **"…"** menu at the top right (no X mark). The menu shows *Not interested in this post*, *View Post Interactions*, *Report post*, *Mark as spam*, *Request Community Note* and an *@username ›* submenu (Follow / Unfollow, Add/remove from Lists, Mute, Block). On your own posts: View Post Interactions, Copy link, Delete post.
- *Not interested* replaces the post with a small card (Undo, "Show fewer posts from…", "This post isn't relevant"). It is stored on the device (`hidden_posts`), Undo removes it again.
- *Post activity* (Quotes / Reposts) reads the `reposts` table and the `posts_feed` view. Re-run `supabase/schema.sql` once: section 10 now also exposes `quote_created_at` and `quote_verified` in `posts_feed`.
- UI only (nothing is sent to a server): Report post, Mark as spam, Request Community Note, "Show fewer posts" / "This post isn't relevant".


### Drafts, editing, mentions and demo data

- **Drafts:** closing the composer with text offers *Save draft / Discard post*. The *Drafts* button appears at the top of an empty composer. Only text (and the thread) is kept, not photos or polls. Drafts are stored in the account's preferences (`post_drafts`), so they follow you to another phone.
- **Edit post:** "Edit post" in the "…" menu of your own post for one hour (not for polls or scheduled posts). The database enforces it (`guard_post_edit` trigger: only the text can change, `edited_at` is set) and the post shows *Edited* / *Last edited …*. Re-run `supabase/schema.sql` for this.
- **Threads:** the "+" in the composer adds another post; on a reply, *Show this thread* / *Show earlier posts* shows the posts above it.
- **Recent searches:** the search screen remembers the last 10 searches (`recent_searches` in the preferences), *Clear all* removes them.
- **@ suggestions:** typing `@` in the composer lists matching accounts; tapping one inserts the username.
- **Demo data:** run `supabase/seed.sql` once (after `schema.sql`) to create 34 FICTIONAL accounts (athletes, musicians, actors, artists, a mayor and a senator of an invented city, news and tech accounts, ...) with about 220 posts, replies, quotes, 2 polls, likes, reposts and followers, plus 120 background "fan" accounts that only like / repost / follow. Nothing in it is a real person or real news. It can be run again (it replaces its own data) and removed with `delete from auth.users where email like '%@seed.xreplica.test';`. The last lines of the file show how to make your own account follow everyone.

## Private accounts (Protect your posts), follower requests, account picker

* **Database:** re-run `supabase/schema.sql` (section 12). It adds `follow_requests`, stops direct follows of protected accounts, `accept_follow_request` / `accept_all_follow_requests`, auto-approval when an account goes public again, request clean-up on block, a stricter `can_message`, no reposting of protected posts, and `requested_by_me` in `profile_stats`.
* **How it behaves:** turn on Settings > Privacy and safety > Audience and tagging > Protect your posts. A padlock appears beside the name (profile, posts, chat, people lists). Others see "Follow" -> "Pending" and the panel "These posts are protected." until you accept in the side menu > Follower requests (the count shows as a badge). Only accepted followers can read posts or message you; anyone else gets the closed-chat panel. Following a protected account is a request, not a follow.
* **Login picker:** logging out now returns to "Log in to X" with the saved accounts (tap to switch, trash icon to remove) and "Add another account". The Google/Apple/phone chips there are visual only; the app signs in with email and password.
* **Tests:** `test/features_test.dart` covers the Follow / Pending / Following states.

## X look: logo, icons, tab bar, AI helper fixes

* **Logo and icons:** `lib/core/x_icons.dart` draws the X logo and the main icons (home, search, Grok, bell, chat, reply, repost, like, views, bookmark, share, compose) as vectors, so they follow the light / dark colour. `BrandMark`, the post's top-right mark, the app icons (Android `mipmap-*`, iOS `AppIcon.appiconset`) all use the real X logo shape. Other, minor icons (settings rows etc.) are still Cupertino icons.
* **Bottom bar:** the normal `AdaptiveBottomNavigationBar` again, but flat (`useNativeBottomBar: false`, so iOS 26 gets the plain Cupertino bar, no liquid glass). Its icons are the X vectors: outline when not selected, filled / bolder when selected, black in light mode and white in dark mode. On Android the labels are hidden (`navigationBarTheme` in `main.dart`), which also fixes "Notifications" wrapping onto two lines. The compose button is the scaffold's floating button and hides while the keyboard is open.
* **Notification badge:** the Notifications tab shows a blue badge with the number of notifications newer than the last time that tab was opened (checked at start, every 45 s and whenever the tab loads; saved per account as `notif_seen_at` in `UserPrefs`). Opening the tab clears it; more than 99 shows `99+`.
* **Composer media:** like on X, a post holds up to 4 media in total. The gallery picker accepts several photos at once, and a GIF is added next to the photos already chosen (before, picking a GIF removed them). Photos are uploaded, GIFs are saved as links; both go into `image_urls`.
* **Feed:** the "For you" tab (and the topic tabs) show a different mix every time: `Api.fetchForYouPage` takes the 300 newest posts and draws 20 at random, favouring fresh posts, posts with likes / reposts / replies, accounts you follow and your own posts. **Pull to refresh = a new mix.** Scroll to the bottom and the next 20 (never repeating one already on screen) load automatically; when nothing is left it says "You're all caught up". "Following" stays newest-first and pages by time. New posts that arrive live (or that you just posted) are added on top without reshuffling the list.
* **Loading skeletons:** while posts load, the list shows grey placeholder posts like X (round picture, name, text lines, sometimes a picture, four action marks) that pulse softly (`widgets/post_skeleton.dart`): in the feed (first load and under the last post), Explore, profile posts, replies under a post, Bookmarks / Likes, scheduled posts and lists; notifications use a smaller row version. It is a small custom widget, not the `skeletonizer` package, so there is nothing to install.
* **Seed:** `supabase/seed.sql` now has 28 more fictional accounts (62 searchable accounts in total), about 90 more posts, 15 replies and **22 video posts** (see "Seed media" below for where the clips come from; re-run `seed.sql` if a seeded video says "This video can't be played"; tapping the error retries). Run `schema.sql` first (it adds `posts.video_url`), then `seed.sql`.
* **Video posts:** a post holds up to 4 photos / GIFs *or* 1 video (like X). The composer's photo button now opens photos and videos; a video must be MP4 / MOV, at most 2 min 20 s and 50 MB (checked before posting) and cannot be mixed with photos or GIFs. It is uploaded to the new public `post-videos` bucket and saved in `posts.video_url`. **Re-run `supabase/schema.sql`** (section 13) and run `flutter pub get` (new package `video_player`). In the timeline the video shows its first frame, a play button and its length (`widgets/post_video.dart`); tapping it opens `screens/video_viewer_screen.dart`:
  * black page, back button, "..." button, author + Follow, text, reply / repost / like / bookmark / share row, play / pause, time left, draggable progress line, speed, volume and rotate (the phone's landscape layout puts speed / volume / rotate / "..." in a pill at the top right, like X on a tablet);
  * **one tap on the screen hides all the overlays, another shows them again**; the video keeps playing (or stays paused) either way;
  * the "..." card has the speed switch (0.5x - 2x), Quality (only the original file exists, so it says Auto), **Auto-advance** (when a video ends, the next older video post starts; saved per account), Airplay & Bluetooth (explains where to pick the output: Flutter's video player has no AirPlay picker), Go to Post, **Add to Offline** (the file is saved on the phone with `flutter_cache_manager` and played from there next time), Not interested in this, Report post.
* **Keyboard:** the Grok tab asks the window for the keyboard height (the Scaffold hides it from `MediaQuery`), so the cards no longer overflow.
* **AI helper:** **redeploy the function** (`supabase functions deploy ai-assist`). It now reads the models the API key really has (`/models`) and picks a chat and image model from them, tries the next one when a model is missing, no longer sends `temperature`, and when the image service refuses a prompt (for example a trademarked character such as "Mighty Thor") it rewrites it as a plain visual description and tries once more. `AI_CHAT_MODEL` / `AI_IMAGE_MODEL` still override the choice.

## Notes (temporary status, replaces "Myday")

The project asks for a feature for *short, temporary status updates*. This app has **Notes**, like the Notes in X / Instagram DMs:

* One note per account, **up to 60 characters**, visible for **24 hours**. Posting a new note replaces the old one and restarts the 24 hours.
* It sits at the top of the **Chat tab**: first *Your note* (tap it to share, replace or delete a note), then the notes of the people you follow, newest first, each as a speech bubble above the profile picture.
* Tap someone's note to read it (with how long it has left) and **reply**: the reply is sent as a direct message ("Replied to your note: ...") to that person, so it follows the normal message rules (blocked accounts and closed inboxes cannot be written to).
* Privacy: a note is seen only by its author and the people who follow the author; blocked accounts, muted accounts (hidden in the app) and deactivated accounts never show. Only `set_status_note()` / `delete_status_note()` write to the table, so the app cannot pick its own expiry time; the `status_notes_feed` view only returns active notes. Changes arrive in real time.
* **Setup:** re-run `supabase/schema.sql` (section 14: table `status_notes`, policy, functions, view, realtime). Until it is run the strip is simply hidden. `seed.sql` adds nine notes from demo accounts; follow the demo accounts (last lines of the seed file) to see them.

## Communities and Lists (like X)

**Communities**
* *Communities* has two tabs: **Home** (posts of the communities you joined) and **Explore** (categories and communities to discover, with a search box). A welcome dialog shows on the first visit.
* Every community has a name, description, category, icon, cover photo, **rules** (1 to 10) and a **join policy**: *open* (anyone joins at once) or *ask to join* (a request the admin or a moderator approves or declines; the person sees "Requested" and can cancel it).
* Roles: **Admin** (the creator; can edit, delete, change roles, remove members, manage rules), **Moderator** (approve requests, hide posts, remove members) and **Member**. The "..." menu in a community shows only what your role allows: Edit community, Manage members, Join requests, Hidden posts, Rules, Leave.
* Moderators can **hide** a post from a community (kept in `community_hidden_posts`, shown again with *Unhide*). Hidden posts disappear from the community and from other people's timelines but stay on the author's profile.
* Posting: the composer has an audience chip (**Everyone** or one of your communities). Only members can post in a community; this is checked by a trigger, not only by the app.
* The community page follows the real X layout: cover photo with a back button and a share button, name, member count, **Join** (or *Joined* with a bell for "Be the first to know"), a **Trending / Media / About** tab bar that sticks while scrolling, hashtag chips under the tabs, a **Timeline options** dialog (Sort: Trending, New, Popular; View: My posts, My replies), a **Spotlight Community on your profile** dialog, a share dialog, and a full-screen **Join Community** page that shows the rules ("Agree and join" / "Agree and ask to join"). The icons (rocket, sparkles, people, globe, calendar, link, ...) are drawn as vector paths in `lib/core/x_icons.dart`.
* Not copied from X: Community Spaces cards and the "Post from Community List" label. The Spotlight / pin-to-home / notification toggles are saved on this device only (`user_prefs`).
* Writes (create, join, request, approve, set role, remove, hide) go through `SECURITY DEFINER` functions, so the app cannot give itself a role.
* Not included: report community (shows an info message only).

**Lists**
* *Lists* has **Pinned** (up to 10, reorder by pinning), **Discover** (suggested public lists), **Your Lists** and **Subscribed**. Follow or unfollow a list; the owner is not notified.
* Create or edit a list in two steps: name, description, banner photo and **Private** switch, then **add / remove members** from search or from your follows. Limits like X: 1000 lists per account and 5000 members per list (database trigger).
* A list page has **Posts** (members' posts, newest first) and **People** (members and followers). Private lists are only visible to the owner. The "..." menu has Edit, Pin / Unpin, Share link, Delete (owner) or Follow / Unfollow, Report (info only).
* Anyone's profile menu has **Add/remove from Lists** (the sheet lists your lists with a check mark per list).
* Not included: notification when someone adds you to a list, Delegate lists.

**Seed media (pictures and videos match their captions).** Every seeded photo is picked by reading the caption it belongs to: the isaw post shows isaw, the Coron budget plan shows Coron, the Mt. Pulag sunrise shows the sea of clouds, and so on. Posts whose caption has no suitable free photo simply have no picture. The photos are hosted on Wikimedia Commons (free licences: Creative Commons or public domain; the author and licence of each file are on its Commons page, linked from the file name in the URL) and the app sends a proper `User-Agent` (`lib/core/http_identity.dart`) because Commons refuses the generic Dart one. The 23 videos are short free stock clips from mixkit.co (Mixkit licence, H.264 mp4 so they play on both iOS and Android); where no clip showed exactly what a caption said, the caption was written to describe the clip instead (for example "Late-night coding session" under a coding clip). Everything is in the `seed_img` table at the top of `seed.sql`, so a photo is one line to change. All of it needs internet on the phone.

**Setup:** re-run `supabase/schema.sql` (section 15; it is safe to re-run and gives existing communities an admin row for their creator), then `supabase/seed.sql` (section 5): 13 fictional communities (3 of them "ask to join" with pending requests, one with a hidden spam post), about 70 community posts and 16 lists (one private) with followers. The last lines of the seed file show how to make your own account join the open communities and follow the public lists.

## Small X details (latest round)

* **Post page:** the author row ends with the Grok button and a "..." that opens the post menu (the old "X.com" text is gone).
* **Photo viewer:** "..." at the top right: Share post via..., Copy link to post, Copy image link, Go to post, Report post. (No "Save photo": saving to the gallery needs an extra plugin that this project does not use.)
* **React with Video:** the third row of the repost popup opens the camera, records a clip (up to 2 min 20 s) and opens the composer with the clip attached, quoting the post. That is how X does it: a video reaction is a quote post that holds your video. Needs the camera and microphone permissions that are already in `Info.plist` and the manifest.
* **Protected reply > Learn more:** opens a short explanation of who can see a reply from a protected account.
* **For you menu:** the "For you" tab has a "⌄". Tap it while it is active: Snooze topics or Refresh. *Snooze Topics* (Politics, Sports, Business & Finance, Science & Technology, Entertainment & Arts, Artificial Intelligence, Gaming, Crypto, Videos) hides those posts from For you for 24 hours; Reset clears it. Topics are matched by words in the post (and "any video" for Videos); the snooze is stored in the account's `user_prefs`, so it follows the account.
* **Polls:** the shortest poll is 5 minutes. The length wheels snap back to 5 min, and `schema.sql` (section 16) has a trigger so the database refuses shorter polls too (re-run `schema.sql`).
