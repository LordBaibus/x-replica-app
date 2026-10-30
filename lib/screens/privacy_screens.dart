import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import '../widgets/state_views.dart';
import '../widgets/underline_tabs.dart';

Future<T?> _push<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(appRoute<T>(page));

// ===========================================================================
// Audience and tagging
// ===========================================================================

class AudienceTaggingScreen extends StatefulWidget {
  const AudienceTaggingScreen({super.key});

  @override
  State<AudienceTaggingScreen> createState() => _AudienceTaggingScreenState();
}

class _AudienceTaggingScreenState extends State<AudienceTaggingScreen> {
  bool? _protected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.getProfile(Api.uid);
      if (mounted) setState(() => _protected = me.protectedPosts);
    } catch (_) {
      if (mounted) setState(() => _protected = false);
    }
  }

  Future<void> _setProtected(bool v) async {
    final before = _protected;
    setState(() => _protected = v);
    try {
      await Api.setProtected(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _protected = before);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Audience and tagging',
      child: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 48),
            children: [
              SwitchRow(
                title: 'Protect your posts',
                description: 'Only show your posts to people who follow you. '
                    'If selected, you will need to approve each new '
                    'follower. ',
                link: 'Learn more',
                value: _protected ?? false,
                onChanged: _protected == null ? null : _setProtected,
              ),
              SwitchRow(
                title: 'Protect your videos',
                description: 'If selected, videos you post or send via Chat will '
                    'not be downloadable by default. This setting applies to '
                    'videos shared going forward and is not retroactive. ',
                link: 'Learn more',
                value: prefs.flag('protect_videos'),
                onChanged: (v) => prefs.set('protect_videos', v),
              ),
              ValueRow(
                title: 'Photo tagging',
                value: prefs.text('photo_tagging', 'Off'),
                onTap: () async {
                  final v = await pickOption<String>(
                    context,
                    title: 'Photo tagging',
                    selected: prefs.text('photo_tagging', 'Off'),
                    items: const [
                      PickItem('Everyone can tag you', 'Everyone'),
                      PickItem('Only people you follow can tag you',
                          'Only people you follow'),
                      PickItem('Off', 'Off'),
                    ],
                  );
                  if (v != null) await prefs.set('photo_tagging', v);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Your posts / Content you see / Explore settings
// ===========================================================================

class YourPostsScreen extends StatelessWidget {
  const YourPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Your posts',
      items: [
        PGap(8),
        PSwitch(
          'post_media_sensitive',
          'Mark media you post as containing material that may be sensitive',
          desc: 'Some posts may include media that people may not want to '
              'see. Turn this on and your photos and videos will carry a '
              'warning.',
        ),
      ],
    );
  }
}

class ContentYouSeeScreen extends StatelessWidget {
  const ContentYouSeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Content you see',
      items: [
        const PGap(8),
        PNav(
          'Explore settings',
          desc: 'Decide what shows up in Explore.',
          open: (c) => _push<Object?>(c, const ExploreSettingsScreen()),
        ),
        PNav(
          'Update sensitive content preferences',
          desc: 'Choose the kinds of sensitive content you want to see.',
          open: (c) => notify(
            c,
            title: 'Sensitive content preferences',
            message: 'Sensitive content preferences are only available on '
                'the web. Log in on the web to continue.',
          ),
        ),
      ],
    );
  }
}

class ExploreSettingsScreen extends StatelessWidget {
  const ExploreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Explore settings',
      child: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          final current = prefs.flag('explore_current_location', true);
          return ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [
              const SettingsDivider(),
              const SettingsSectionTitle('Location'),
              SwitchRow(
                title: 'Show content in your current location',
                description: 'See what is happening around you right now.',
                value: current,
                onChanged: (v) => prefs.set('explore_current_location', v),
              ),
              ValueRow(
                title: 'Explore locations',
                value: prefs.text('explore_location', 'Select'),
                dim: current,
                onTap: current
                    ? null
                    : () async {
                        final v = await pickOption<String>(
                          context,
                          title: 'Explore locations',
                          selected: prefs.text('explore_location', 'Select'),
                          items: const [
                            PickItem('Worldwide', 'Worldwide'),
                            PickItem('Philippines', 'Philippines'),
                            PickItem('United States', 'United States'),
                            PickItem('United Kingdom', 'United Kingdom'),
                            PickItem('Japan', 'Japan'),
                          ],
                        );
                        if (v != null) await prefs.set('explore_location', v);
                      },
              ),
              const SettingsDivider(),
              const SettingsSectionTitle('Personalization'),
              SwitchRow(
                title: 'Trends for you',
                description: 'You can personalize trends based on your '
                    'location and who you follow.',
                value: prefs.flag('explore_trends_for_you', true),
                onChanged: (v) => prefs.set('explore_trends_for_you', v),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Mute and block
// ===========================================================================

class MuteBlockScreen extends StatelessWidget {
  const MuteBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Mute and block',
      items: [
        const PIntro('Manage the accounts, words, and notifications that '
            'you’ve muted or blocked.'),
        PNav(
          'Blocked accounts',
          icon: CupertinoIcons.nosign,
          desc: 'Review the accounts you have blocked.',
          open: (c) => _push<Object?>(c, const BlockedAccountsScreen()),
        ),
        PNav(
          'Muted accounts',
          icon: CupertinoIcons.speaker_slash,
          desc: 'Review the accounts you have muted.',
          open: (c) => _push<Object?>(c, const MutedAccountsScreen()),
        ),
        PNav(
          'Muted words',
          icon: CupertinoIcons.text_badge_xmark,
          desc: 'Review the words you have muted.',
          open: (c) => _push<Object?>(c, const MutedWordsScreen()),
        ),
        PNav(
          'Muted notifications',
          icon: CupertinoIcons.bell_slash,
          desc: 'Choose which notifications to mute.',
          open: (c) => _push<Object?>(c, const MutedNotificationsScreen()),
        ),
      ],
    );
  }
}

/// List of people for Blocked / Muted accounts with a button to undo.
class _AccountList extends StatefulWidget {
  const _AccountList({
    super.key,
    required this.load,
    required this.buttonLabel,
    required this.onUndo,
    required this.emptyTitle,
    required this.emptyText,
  });

  final Future<List<Profile>> Function() load;
  final String buttonLabel;
  final Future<void> Function(Profile) onUndo;
  final String emptyTitle;
  final String emptyText;

  @override
  State<_AccountList> createState() => _AccountListState();
}

class _AccountListState extends State<_AccountList> {
  List<Profile>? _list;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final l = await widget.load();
      if (mounted) {
        setState(() {
          _list = l;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (_error != null) return ErrorView(error: _error!, onRetry: _reload);
    final list = _list;
    if (list == null) return const LoadingView();
    if (list.isEmpty) {
      return EmptyStateView(
        title: widget.emptyTitle,
        text: widget.emptyText,
        link: 'Learn more',
      );
    }
    return ListView(
      children: [
        for (final u in list)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Avatar(url: u.avatarUrl, name: u.name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${u.username}',
                        style: TextStyle(color: p.subtext, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: '${widget.buttonLabel == 'Blocked' ? 'Unblock' : 'Unmute'} '
                          '@${u.username}?',
                      confirmLabel:
                          widget.buttonLabel == 'Blocked' ? 'Unblock' : 'Unmute',
                    );
                    if (!ok || !context.mounted) return;
                    try {
                      await widget.onUndo(u);
                      if (mounted) {
                        setState(() => _list = [
                              for (final x in list)
                                if (x.id != u.id) x,
                            ]);
                      }
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.buttonLabel == 'Blocked'
                          ? p.danger
                          : p.text,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: TextStyle(
                        color: widget.buttonLabel == 'Blocked'
                            ? const Color(0xFFFFFFFF)
                            : p.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Blocked accounts',
      child: Column(
        children: [
          UnderlineTabs(
            labels: const ['All', 'Chat'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: _tab == 0
                ? _AccountList(
                    key: const ValueKey('blocked-all'),
                    load: Moderation.instance.blockedProfiles,
                    buttonLabel: 'Blocked',
                    onUndo: (u) => Moderation.instance.unblock(u.id),
                    emptyTitle: 'Block unwanted accounts',
                    emptyText: 'When you block someone, they will not be able '
                        'to follow or message you, and you will not see their '
                        'posts or notifications. ',
                  )
                : const EmptyStateView(
                    key: ValueKey('blocked-chat'),
                    title: 'Block unwanted accounts from messaging you',
                    text: 'Accounts you block from Chat will show up here. ',
                    link: 'Learn more',
                  ),
          ),
        ],
      ),
    );
  }
}

class MutedAccountsScreen extends StatelessWidget {
  const MutedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Muted accounts',
      child: _AccountList(
        load: Moderation.instance.mutedProfiles,
        buttonLabel: 'Muted',
        onUndo: (u) => Moderation.instance.unmute(u.id),
        emptyTitle: 'Mute unwanted accounts',
        emptyText: 'Posts from accounts you mute will not show up in your '
            'timeline. They will not know you muted them. ',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Muted words
// ---------------------------------------------------------------------------

class MutedWordsScreen extends StatelessWidget {
  const MutedWordsScreen({super.key});

  String _describe(Map<String, dynamic> w) {
    final where = [
      if (w['home'] != false) 'Home timeline',
      if (w['notif'] != false) 'Notifications',
    ].join(', ');
    final from = w['from'] == 'unfollowed' ? 'People you do not follow' : 'Anyone';
    final until = w['until'] == null
        ? 'Forever'
        : 'Until ${DateTime.tryParse('${w['until']}')?.toLocal().toString().split(' ').first ?? ''}';
    return '$where · $from · $until';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) {
        final p = AppPalette.of(context);
        final prefs = UserPrefs.instance;
        final words = Moderation.instance.activeWords();
        final seenIntro = prefs.flag('seen_muted_words_intro');
        final showIntro = !seenIntro && words.isEmpty;

        if (showIntro) {
          return SettingsFrame(
            title: 'Muted words',
            child: EmptyStateView(
              icon: CupertinoIcons.bubble_left_bubble_right,
              title: 'Muted words',
              text: "When you mute words, you won't see them in your "
                  'notifications or timeline. ',
              link: 'Learn more',
              action: PillAction(
                label: 'Got it',
                onPressed: () => prefs.set('seen_muted_words_intro', true),
              ),
            ),
          );
        }

        return SettingsFrame(
          title: 'Muted words',
          action: HeaderAction(
            label: 'Add',
            onPressed: () => _push<Object?>(context, const AddMutedWordScreen()),
          ),
          child: words.isEmpty
              ? EmptyStateView(
                  title: 'No muted words',
                  text: 'Words you mute will show up here.',
                  action: PillAction(
                    label: 'Add',
                    onPressed: () =>
                        _push<Object?>(context, const AddMutedWordScreen()),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 48),
                  children: [
                    for (final w in words)
                      SettingsColumn(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${w['w']}',
                                      style: TextStyle(
                                        color: p.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _describe(w),
                                      style: TextStyle(
                                        color: p.subtext,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  final ok = await confirm(
                                    context,
                                    title: 'Unmute "${w['w']}"?',
                                    confirmLabel: 'Unmute',
                                  );
                                  if (!ok) return;
                                  final all = prefs.maps(Moderation.wordsKey);
                                  all.removeWhere((x) => x['w'] == w['w']);
                                  await prefs.set(Moderation.wordsKey, all);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    CupertinoIcons.trash,
                                    size: 20,
                                    color: p.subtext,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class AddMutedWordScreen extends StatefulWidget {
  const AddMutedWordScreen({super.key});

  @override
  State<AddMutedWordScreen> createState() => _AddMutedWordScreenState();
}

class _AddMutedWordScreenState extends State<AddMutedWordScreen> {
  final _c = TextEditingController();
  bool _home = true;
  bool _notif = true;
  String _from = 'anyone';
  String _duration = 'Forever';
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _durations = ['Forever', '24 hours', '7 days', '30 days'];

  DateTime? _until() {
    final now = DateTime.now().toUtc();
    switch (_duration) {
      case '24 hours':
        return now.add(const Duration(hours: 24));
      case '7 days':
        return now.add(const Duration(days: 7));
      case '30 days':
        return now.add(const Duration(days: 30));
      default:
        return null;
    }
  }

  Future<void> _add() async {
    final word = Moderation.normalizeWord(_c.text);
    if (word.isEmpty) {
      setState(() => _error = 'Enter a word or phrase.');
      return;
    }
    if (!_home && !_notif) {
      setState(() => _error = 'Choose Home timeline, Notifications or both.');
      return;
    }
    final prefs = UserPrefs.instance;
    final all = prefs.maps(Moderation.wordsKey);
    all.removeWhere((x) => x['w'] == word);
    all.add({
      'w': word,
      'home': _home,
      'notif': _notif,
      'from': _from,
      'until': _until()?.toIso8601String(),
    });
    await prefs.set(Moderation.wordsKey, all);
    if (!mounted) return;
    showSuccess(context, 'Muted "$word".');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Add muted words',
      child: FormBody(
        bottom: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: PillAction(
            label: 'Add',
            kind: PillKind.blue,
            fullWidth: true,
            onPressed: _add,
          ),
        ),
        children: [
          const SizedBox(height: 14),
          UnderlineField(
            placeholder: 'Keyword or phrase',
            controller: _c,
            autofocus: true,
            errorText: _error,
            maxLength: 60,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 10),
          SwitchRow(
            title: 'Home timeline',
            value: _home,
            onChanged: (v) => setState(() => _home = v),
          ),
          SwitchRow(
            title: 'Notifications',
            value: _notif,
            onChanged: (v) => setState(() => _notif = v),
          ),
          ValueRow(
            title: 'Mute from',
            value: _from == 'anyone' ? 'Anyone' : 'People you don’t follow',
            onTap: () async {
              final v = await pickOption<String>(
                context,
                title: 'Mute from',
                selected: _from,
                items: const [
                  PickItem('Anyone', 'anyone'),
                  PickItem('People you don’t follow', 'unfollowed'),
                ],
              );
              if (v != null) setState(() => _from = v);
            },
          ),
          ValueRow(
            title: 'Duration',
            value: _duration,
            onTap: () async {
              final v = await pickOption<String>(
                context,
                title: 'Duration',
                selected: _duration,
                items: [for (final d in _durations) PickItem(d, d)],
              );
              if (v != null) setState(() => _duration = v);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Muted notifications
// ---------------------------------------------------------------------------

class MutedNotificationsScreen extends StatelessWidget {
  const MutedNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Muted notifications',
      items: [
        PSection('Mute notifications from people'),
        PSwitch('mute_n_not_following', "You don't follow", bold: false),
        PSwitch('mute_n_not_following_me', "Who don't follow you", bold: false),
        PSwitch('mute_n_new_account', 'With a new account', bold: false),
        PSwitch(
          'mute_n_default_photo',
          'Who have a default profile photo',
          bold: false,
        ),
        PSwitch(
          'mute_n_unconfirmed_email',
          "Who haven't confirmed their email",
          bold: false,
        ),
        PSwitch(
          'mute_n_unconfirmed_phone',
          "Who haven't confirmed their phone number",
          bold: false,
        ),
        PNote(
          'These filters will not affect notifications from people you '
          'follow. ',
          link: 'Learn more',
        ),
      ],
    );
  }
}

/// Used in the post menu: "Mute @user" / "Block @user".
Future<void> muteUserWithConfirm(
  BuildContext context, {
  required String userId,
  required String username,
}) async {
  final ok = await confirm(
    context,
    title: 'Mute @$username?',
    message: 'Their posts will no longer show in your timeline. They will '
        'not be told.',
    confirmLabel: 'Mute',
  );
  if (!ok || !context.mounted) return;
  try {
    await Moderation.instance.mute(userId);
    if (context.mounted) showSuccess(context, 'Muted @$username.');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> blockUserWithConfirm(
  BuildContext context, {
  required String userId,
  required String username,
}) async {
  final ok = await confirm(
    context,
    title: 'Block @$username?',
    message: 'They will not be able to follow or message you, and you will '
        'not see their posts. If you follow each other, both follows are '
        'removed.',
    confirmLabel: 'Block',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  try {
    await Moderation.instance.block(userId);
    if (context.mounted) showSuccess(context, 'Blocked @$username.');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
