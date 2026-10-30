import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../core/x_icons.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/community_dialogs.dart';
import '../widgets/community_join_sheet.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'community_manage_screens.dart';
import 'compose_post_screen.dart';
import 'profile_view.dart';
import 'search_screen.dart';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Link to a community that can be copied or shared.
String communityLink(Community c) => 'xreplica://community/${c.id}';

/// One community like on X: cover photo, name, category, members, the
/// Spotlight / share / Join buttons and the tabs Trending (with its timeline
/// options), Media and About (info and rules).
class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.community});

  final Community community;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  late Community _c = widget.community;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _tabsKey = GlobalKey();

  int _tab = 0; // 0 Trending (or the chosen timeline), 1 Media, 2 About
  CommunityTimeline _mode = CommunityTimeline.trending;
  String? _tag;
  bool _sticky = false;

  List<Post> _posts = const [];
  List<Post> _myReplies = const [];
  List<CommunityRule> _rules = const [];
  List<CommunityMember> _staff = const [];
  List<CommunityMember> _faces = const [];
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  static const _tabNames = ['Trending', 'Media', 'About'];

  String get _spacesKey => 'community_notify_spaces_${_c.id}';
  String get _pinnedKey => 'community_notify_pinned_${_c.id}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final box = _tabsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final dy = box.localToGlobal(Offset.zero).dy;
    final limit = MediaQuery.paddingOf(context).top + 48;
    final sticky = dy <= limit;
    if (sticky != _sticky) setState(() => _sticky = sticky);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final fresh = await Api.fetchCommunity(_c.id);
      final r = await Future.wait<Object>([
        Api.fetchCommunityPosts(_c.id),
        Api.fetchCommunityRules(_c.id),
        Api.fetchCommunityMembers(_c.id),
      ]);
      final posts = r[0] as List<Post>;
      var replies = <Post>[];
      try {
        replies =
            await Api.fetchMyCommunityReplies(posts.map((x) => x.id).toList());
      } catch (_) {}
      if (!mounted) return;
      final members = r[2] as List<CommunityMember>;
      setState(() {
        if (fresh != null) _c = fresh;
        _posts = posts;
        _myReplies = replies;
        _rules = r[1] as List<CommunityRule>;
        _staff = members.where((m) => m.isAdmin || m.isModerator).toList();
        _faces = members.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  // ------------------------------------------------------------ join flow

  Future<void> _join() async {
    if (_busy) return;
    final agreed = await showCommunityJoinSheet(
      context,
      community: _c,
      rules: _rules,
    );
    if (!agreed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await Api.joinCommunity(_c.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (result == 'joined') {
          _c = _c.copyWith(
            joinedByMe: true,
            myRole: 'member',
            memberCount: _c.memberCount + 1,
          );
        } else {
          _c = _c.copyWith(requestedByMe: true);
        }
      });
      if (result == 'joined') {
        await _notifyDialog();
      } else {
        showSuccess(context, 'Request sent. Moderators will review it.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _cancelRequest() async {
    final ok = await confirm(
      context,
      title: 'Cancel your request?',
      message: 'You can ask to join again later.',
      confirmLabel: 'Cancel request',
    );
    if (!ok || !mounted) return;
    try {
      await Api.cancelJoinRequest(_c.id);
      if (mounted) setState(() => _c = _c.copyWith(requestedByMe: false));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      title: 'Leave ${_c.name}?',
      message: _c.isRestricted
          ? 'To come back you will have to ask to join again.'
          : 'You can join again at any time.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.leaveCommunity(_c.id);
      if (!mounted) return;
      setState(() {
        _c = _c.copyWith(
          joinedByMe: false,
          clearRole: true,
          memberCount: _c.memberCount - 1,
        );
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // ------------------------------------------------------------ dialogs

  Future<void> _notifyDialog() async {
    final prefs = UserPrefs.instance;
    final saved = await showCommunityNotifyDialog(
      context,
      spaces: prefs.flag(_spacesKey, true),
      pinned: prefs.flag(_pinnedKey, true),
    );
    if (saved == null) return;
    await prefs.set(_spacesKey, saved.spaces);
    await prefs.set(_pinnedKey, saved.pinned);
    if (mounted) showSuccess(context, 'Notification settings saved');
  }

  Future<void> _spotlightMenu() async {
    final i = await showXMenuDialog(
      context,
      items: const [
        XMenuItem(
          icon: XIcons.sparkle,
          label: 'Spotlight Community on your profile',
        ),
        XMenuItem(
          icon: XIcons.homeFill,
          label: 'Pin Community to Home screen',
        ),
      ],
    );
    if (i == null || !mounted) return;
    final prefs = UserPrefs.instance;
    final key = i == 0 ? 'community_spotlight' : 'community_pinned_home';
    final ids = prefs.strings(key);
    final on = ids.contains(_c.id);
    await prefs.set(
      key,
      on ? ids.where((x) => x != _c.id).toList() : [...ids, _c.id],
    );
    if (!mounted) return;
    showInfo(
      context,
      i == 0
          ? (on ? 'Removed from your profile' : 'Spotlighted on your profile')
          : (on ? 'Unpinned from Home' : 'Pinned to Home'),
    );
  }

  Future<void> _shareMenu() async {
    final i = await showXMenuDialog(
      context,
      items: const [
        XMenuItem(icon: XIcons.compose, label: 'Share via post'),
        XMenuItem(icon: XIcons.link, label: 'Copy link'),
        XMenuItem(icon: XIcons.share, label: 'Share via...'),
      ],
    );
    if (i == null || !mounted) return;
    if (i == 0) {
      await Navigator.of(context).push<bool>(
        appRoute(
          ComposePostScreen(initialText: communityLink(_c)),
          fullscreen: true,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: communityLink(_c)));
    if (mounted) showInfo(context, 'Copied to clipboard');
  }

  Future<void> _moreMenu() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_c.name),
        actions: [
          if (_c.isMod)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openSettings();
              },
              child: const Text('Community settings'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Clipboard.setData(ClipboardData(text: communityLink(_c)));
              showInfo(context, 'Copied to clipboard');
            },
            child: const Text('Copy link'),
          ),
          if (_c.joinedByMe && !_c.isAdmin)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _leave();
              },
              child: const Text('Leave Community'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _timelineOptions() async {
    final pick = await showTimelineOptions(context, current: _mode);
    if (pick == null || !mounted) return;
    setState(() {
      _mode = pick;
      _tab = 0;
    });
  }

  Future<void> _openSettings() async {
    final gone = await Navigator.of(context)
        .push<bool>(appRoute(CommunitySettingsScreen(community: _c)));
    if (!mounted) return;
    if (gone == true) {
      Navigator.of(context).pop();
      return;
    }
    _load(silent: true);
  }

  Future<void> _post() async {
    if (!_c.joinedByMe) {
      await _join();
      if (!_c.joinedByMe || !mounted) return;
    }
    final posted = await Navigator.of(context).push<bool>(
      appRoute(
        ComposePostScreen(communityId: _c.id, communityName: _c.name),
        fullscreen: true,
      ),
    );
    if (posted == true) _load(silent: true);
  }

  // ------------------------------------------------------------ moderation

  Future<void> _hide(Post post) async {
    final reason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Hide this post'),
        message: const Text('Which rule does it break? The author is told why.'),
        actions: [
          for (var i = 0; i < _rules.length; i++)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(_rules[i].title),
              child: Text('${i + 1}. ${_rules[i].title}'),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('Other'),
            child: const Text('Other'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await Api.hideCommunityPost(post.id, reason: reason);
      if (!mounted) return;
      setState(() => _posts = _posts.where((x) => x.id != post.id).toList());
      showSuccess(context, 'Post hidden');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // ------------------------------------------------------------------ UI

  Widget _circle(IconData? icon, List<XShape>? shapes, VoidCallback onTap,
      {double size = 38, Color? bg, Color? fg}) {
    final color = fg ?? const Color(0xFFFFFFFF);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg ?? const Color(0x66000000),
          shape: BoxShape.circle,
        ),
        child: shapes != null
            ? XIcon(shapes, size: size * 0.5, color: color)
            : Icon(icon, size: size * 0.52, color: color),
      ),
    );
  }

  Widget _cover(AppPalette p) {
    final url = _c.banner;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 190 + top,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          else
            ColoredBox(color: p.field),
          Positioned(
            left: 12,
            top: top + 8,
            child: _circle(
                AppIcons.back, null, () => Navigator.of(context).maybePop()),
          ),
          Positioned(
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                _circle(null, XIcons.search,
                    () => Navigator.of(context).push(appRoute(const SearchScreen()))),
                const SizedBox(width: 10),
                _circle(AppIcons.more, null, _moreMenu),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineIcon(AppPalette p, List<XShape> shapes, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.subtext.withValues(alpha: 0.6)),
          ),
          child: XIcon(shapes, size: 22, color: p.text),
        ),
      );

  Widget _faceStack(AppPalette p) {
    if (_faces.isEmpty) return const SizedBox.shrink();
    const size = 30.0;
    const step = 20.0;
    return SizedBox(
      width: size + step * (_faces.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < _faces.length; i++)
            Positioned(
              left: step * i,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.surface, width: 2),
                ),
                child: Avatar(
                  url: _faces[i].profile.avatarUrl,
                  name: _faces[i].profile.name,
                  size: size - 4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(AppPalette p) {
    if (_busy) {
      return const SizedBox(
        height: 42,
        width: 80,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_c.joinedByMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _outlineIcon(p, XIcons.sparkle, _spotlightMenu),
          const SizedBox(width: 10),
          _outlineIcon(p, XIcons.personAdd, _shareMenu),
          const SizedBox(width: 10),
          _outlineIcon(p, XIcons.bellPlus, _notifyDialog),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _outlineIcon(p, XIcons.sparkle, _spotlightMenu),
        const SizedBox(width: 10),
        _outlineIcon(p, XIcons.share, _shareMenu),
        const SizedBox(width: 10),
        if (_c.requestedByMe)
          PillButton(
            label: 'Requested',
            style: PillStyle.outline,
            height: 42,
            fontSize: 16,
            onPressed: _cancelRequest,
          )
        else
          PillButton(
            label: _c.isRestricted ? 'Ask to join' : 'Join',
            style: PillStyle.inverse,
            height: 42,
            fontSize: 16,
            onPressed: _join,
          ),
      ],
    );
  }

  Widget _header(AppPalette p) {
    return Container(
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _c.name,
            style: TextStyle(
              color: p.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Text(
              _c.category,
              style: TextStyle(
                color: p.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _faceStack(p),
                  if (_faces.isNotEmpty) const SizedBox(width: 10),
                  Text(
                    '${compactCount(_c.memberCount)} '
                    '${_c.memberCount == 1 ? 'Member' : 'Members'}',
                    style: TextStyle(color: p.subtext, fontSize: 16),
                  ),
                ],
              ),
              _actions(p),
            ],
          ),
          if (_c.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _c.description,
              style: TextStyle(color: p.text, fontSize: 17, height: 1.3),
            ),
          ],
          if (_c.isMod && _c.pendingRequests > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openSettings,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_c.pendingRequests} '
                  '${_c.pendingRequests == 1 ? 'join request' : 'join requests'}',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ tabs

  Widget _tabItem(AppPalette p, int i) {
    final active = _tab == i;
    final label = i == 0 ? _mode.label : _tabNames[i];
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i == 0 && _tab == 0) {
            _timelineOptions();
          } else {
            setState(() => _tab = i);
          }
        },
        child: Center(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: active ? p.text : p.subtext,
                        fontSize: 17,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (i == 0) ...[
                      const SizedBox(width: 6),
                      Icon(CupertinoIcons.chevron_down,
                          size: 15, color: active ? p.text : p.subtext),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? p.accent : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabsRow(AppPalette p, {Key? key}) => DecoratedBox(
        key: key,
        decoration: BoxDecoration(
          color: p.background,
          border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
        ),
        child: Row(children: [for (var i = 0; i < 3; i++) _tabItem(p, i)]),
      );

  Widget _stickyBar(AppPalette p) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: p.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(AppIcons.back, size: 24, color: p.text),
                  ),
                ),
                Expanded(
                  child: Text(
                    _c.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      Navigator.of(context).push(appRoute(const SearchScreen())),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: XIcon(XIcons.search, size: 22, color: p.text),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _moreMenu,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 16),
                    child: Icon(AppIcons.more, size: 22, color: p.text),
                  ),
                ),
              ],
            ),
          ),
          _tabsRow(p),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ posts

  static final RegExp _hash = RegExp(r'#[\p{L}\p{N}_]+', unicode: true);

  List<String> get _tags {
    final count = <String, int>{};
    final shown = <String, String>{};
    for (final x in _posts) {
      for (final m in _hash.allMatches(x.content)) {
        final t = m.group(0)!;
        final k = t.toLowerCase();
        count[k] = (count[k] ?? 0) + 1;
        shown.putIfAbsent(k, () => t);
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) => count[b]!.compareTo(count[a]!));
    return [for (final k in keys.take(12)) shown[k]!];
  }

  List<Post> get _shown {
    var list = [..._posts];
    if (_tab == 1) {
      return list.where((x) => x.images.isNotEmpty || x.hasVideo).toList();
    }
    if (_tag != null) {
      final t = _tag!.toLowerCase();
      list = list.where((x) => x.content.toLowerCase().contains(t)).toList();
    }
    int engagement(Post x) => x.likeCount + x.repostCount * 2 + x.replyCount * 2;
    switch (_mode) {
      case CommunityTimeline.trending:
        double score(Post x) {
          final hours = DateTime.now().difference(x.createdAt).inMinutes / 60;
          return (engagement(x) + 1) / (hours + 2).clamp(1, 1e9);
        }
        list.sort((a, b) => score(b).compareTo(score(a)));
      case CommunityTimeline.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CommunityTimeline.popular:
        list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case CommunityTimeline.myPosts:
        list = list.where((x) => x.userId == Api.uid).toList();
      case CommunityTimeline.myReplies:
        list = [..._myReplies];
    }
    return list;
  }

  Widget _hashtags(AppPalette p) {
    final tags = _tags;
    if (tags.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 54,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, _) => const SizedBox(width: 26),
        itemBuilder: (context, i) {
          final on = _tag == tags[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _tag = on ? null : tags[i]),
            child: Center(
              child: Text(
                tags[i],
                style: TextStyle(
                  color: p.accent,
                  fontSize: 17,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                  decoration: on ? TextDecoration.underline : null,
                  decorationColor: p.accent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _postRow(Post post, AppPalette p) {
    return Column(
      children: [
        PostTile(
          key: ValueKey('${post.id}-$_tab-${_mode.name}'),
          post: post,
          onDeleted: (x) =>
              setState(() => _posts = _posts.where((y) => y.id != x.id).toList()),
        ),
        if (_c.isMod && post.userId != Api.uid)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _hide(post),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.eye_slash, size: 16, color: p.subtext),
                      const SizedBox(width: 6),
                      Text(
                        'Hide post (moderator)',
                        style: TextStyle(color: p.subtext, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _postList(AppPalette p) {
    final list = _shown;
    if (list.isEmpty) {
      final text = _tab == 1
          ? 'No photos or videos in this Community yet.'
          : switch (_mode) {
              CommunityTimeline.myPosts =>
                'You have not posted in this Community yet.',
              CommunityTimeline.myReplies =>
                'You have not replied in this Community yet.',
              _ => 'No posts here yet. Be the first to post in this Community!',
            };
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 16),
        ),
      );
    }
    return Column(children: [for (final post in list) _postRow(post, p)]);
  }

  // ------------------------------------------------------------ About tab

  Widget _section(String title, AppPalette p, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: p.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );

  Widget _infoRow(AppPalette p, List<XShape> icon, InlineSpan text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 42,
              child: XIcon(icon, size: 26, color: p.subtext),
            ),
            Expanded(
              child: Text.rich(
                text,
                style: TextStyle(color: p.text, fontSize: 18, height: 1.25),
              ),
            ),
          ],
        ),
      );

  Widget _about(AppPalette p) {
    final created = _c.createdAt;
    final bold = TextStyle(color: p.text, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Community Info', p),
        _infoRow(p, XIcons.people,
            const TextSpan(text: 'Only Community members can post.')),
        _infoRow(
          p,
          XIcons.globe,
          TextSpan(
            children: [
              TextSpan(text: 'All Communities are publicly visible. ', style: bold),
              TextSpan(
                text: _c.isRestricted
                    ? 'Anyone can ask to join; moderators answer each request.'
                    : 'Anyone can join this Community.',
              ),
            ],
          ),
        ),
        if (created != null)
          _infoRow(
            p,
            XIcons.calendar,
            TextSpan(
              children: [
                TextSpan(
                  text: 'Created ${_months[created.month - 1]} '
                      '${created.day}, ${created.year}',
                ),
                if (_c.ownerUsername.isNotEmpty) ...[
                  const TextSpan(text: ' by '),
                  TextSpan(
                    text: '@${_c.ownerUsername}',
                    style: TextStyle(color: p.accent),
                  ),
                ],
              ],
            ),
          ),
        Container(height: 0.5, color: p.border),
        _section('Rules', p),
        if (_rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'The admin has not added rules yet.',
              style: TextStyle(color: p.subtext, fontSize: 16),
            ),
          )
        else
          for (var i = 0; i < _rules.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 6),
                    decoration:
                        BoxDecoration(color: p.text, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: p.background,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rules[i].title,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_rules[i].description.isNotEmpty)
                          Text(
                            _rules[i].description,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 17,
                              height: 1.25,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        Container(height: 0.5, color: p.border),
        _section(
          'Moderators',
          p,
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              appRoute(CommunityMembersScreen(community: _c)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${compactCount(_c.memberCount)} members',
                  style: TextStyle(color: p.accent, fontSize: 15),
                ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 13, color: p.subtext),
              ],
            ),
          ),
        ),
        for (final m in _staff)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context)
                .push(appRoute(ProfileScreen(userId: m.profile.id))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Avatar(
                    url: m.profile.avatarUrl,
                    name: m.profile.name,
                    size: 44,
                    square: Avatar.isSquare(m.profile.verified),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NameWithBadge(
                          name: m.profile.name,
                          verified: m.profile.verified,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${m.profile.username}',
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: Text(
                      m.isAdmin ? 'Admin' : 'Moderator',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget content() {
      if (_loading) return const PostSkeletons(count: 4);
      if (_error != null) return ErrorView(error: _error!, onRetry: _load);
      return _tab == 2 ? _about(p) : _postList(p);
    }

    return PlainScaffold(
      floating: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _post,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.accent,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const XIcon(XIcons.compose,
              size: 26, color: Color(0xFFFFFFFF)),
        ),
      ),
      child: ContentWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(
                    onRefresh: () => _load(silent: true)),
                SliverToBoxAdapter(child: _cover(p)),
                SliverToBoxAdapter(child: _header(p)),
                SliverToBoxAdapter(child: _tabsRow(p, key: _tabsKey)),
                if (_tab == 0 && !_loading && _error == null)
                  SliverToBoxAdapter(child: _hashtags(p)),
                SliverToBoxAdapter(child: content()),
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            )),
            if (_sticky)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _stickyBar(p),
              ),
          ],
        ),
      ),
    );
  }
}
