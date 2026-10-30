import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/follow_carousel.dart';
import '../widgets/pill_button.dart';
import '../widgets/profile_photo_viewer.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/share_profile_sheet.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'chat_view.dart';
import 'compose_post_screen.dart';
import 'edit_profile_screen.dart';
import 'follow_lists_screen.dart';
import 'profile_setup_flow.dart';
import 'search_screen.dart';
import '../core/x_icons.dart';
import '../widgets/post_skeleton.dart';

enum _ProfileTab { posts, replies, reposts, media }

/// A profile as X shows it: banner with round back / search buttons, avatar,
/// name, bio, stats, action buttons and the Posts / Replies / Reposts / Media
/// tabs with their "empty" messages.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileView> createState() => ProfileViewState();
}

class ProfileViewState extends State<ProfileView> {
  Profile? _profile;
  bool _loading = true;
  Object? _error;

  _ProfileTab _tab = _ProfileTab.posts;

  /// The first tab can show my posts or the posts I liked.
  bool _showLikes = false;

  /// The fourth tab shows photos or videos.
  bool _showVideos = false;

  final GlobalKey _mediaTabKey = GlobalKey();

  bool _showVerifyCard = true;

  List<Post> _posts = const [];
  List<Post>? _replies;
  List<Post>? _reposts;
  List<Post>? _likes;
  bool _tabLoading = false;

  bool get _isMe => widget.userId == Api.uid;

  @override
  void initState() {
    super.initState();
    _load();
    if (_isMe) Api.profileVersion.addListener(_onMyProfileChanged);
  }

  @override
  void dispose() {
    Api.profileVersion.removeListener(_onMyProfileChanged);
    super.dispose();
  }

  /// "Protect your posts" or an edit changed my profile elsewhere.
  void _onMyProfileChanged() {
    if (mounted) _load(silent: true);
  }

  Future<void> reload() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        Api.getProfile(widget.userId),
        Api.fetchUserPosts(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile;
        _posts = results[1] as List<Post>;
        _replies = null;
        _reposts = null;
        _likes = null;
        _loading = false;
        _error = null;
      });
      _ensureTabLoaded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  /// Replies / reposts / likes are fetched the first time their tab opens.
  Future<void> _ensureTabLoaded() async {
    final needs = switch (_tab) {
      _ProfileTab.replies => _replies == null,
      _ProfileTab.reposts => _reposts == null,
      _ProfileTab.posts => _showLikes && _likes == null,
      _ProfileTab.media => false,
    };
    if (!needs) return;
    setState(() => _tabLoading = true);
    try {
      if (_tab == _ProfileTab.replies) {
        final r = await Api.fetchUserReplies(widget.userId);
        if (mounted) setState(() => _replies = r);
      } else if (_tab == _ProfileTab.reposts) {
        final r = await Api.fetchUserReposts(widget.userId);
        if (mounted) setState(() => _reposts = r);
      } else {
        final r = await Api.fetchUserLikes(widget.userId);
        if (mounted) setState(() => _likes = r);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Show an empty list instead of spinning forever.
          if (_tab == _ProfileTab.replies) _replies = const [];
          if (_tab == _ProfileTab.reposts) _reposts = const [];
          if (_tab == _ProfileTab.posts) _likes = const [];
        });
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _tabLoading = false);
    }
  }

  void _selectTab(_ProfileTab t) {
    if (t == _tab) {
      // Tapping the selected "Posts" / "Photos" tab again offers a menu.
      if (t == _ProfileTab.posts) _pickPostsMode();
      if (t == _ProfileTab.media) _pickMediaMode();
      return;
    }
    setState(() => _tab = t);
    _ensureTabLoaded();
  }

  Future<void> _pickPostsMode() async {
    final choice = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: !_showLikes,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Posts'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _showLikes,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Likes'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == null || choice == _showLikes || !mounted) return;
    setState(() => _showLikes = choice);
    _ensureTabLoaded();
  }

  /// Small popover under the media tab: Videos / Photos (like X).
  Future<void> _pickMediaMode() async {
    final box = _mediaTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + box.size.height;
    final right = topLeft.dx + box.size.width;

    final choice = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, _, __) {
        final p = AppPalette.of(ctx);
        Widget row(IconData icon, String label, bool selected, bool value) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: p.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(CupertinoIcons.checkmark_alt, size: 18, color: p.accent),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned(
              top: bottom - 4,
              right: MediaQuery.sizeOf(ctx).width - right + 8,
              width: 190,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border, width: 0.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    row(CupertinoIcons.play_rectangle, 'Videos', _showVideos, true),
                    row(CupertinoIcons.photo_on_rectangle, 'Photos', !_showVideos, false),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    if (choice == null || choice == _showVideos || !mounted) return;
    setState(() => _showVideos = choice);
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null) return;
    final next = profile.afterFollowTap();
    setState(() => _profile = next);
    try {
      final state = await Api.setFollow(
        profile.id,
        follow: next.followedByMe || next.requestedByMe,
      );
      // The account turned out to be protected (the page was out of date).
      if (state == FollowState.requested && !next.requestedByMe && mounted) {
        setState(() => _profile = next.copyWith(
              followedByMe: false,
              requestedByMe: true,
              protectedPosts: true,
              followerCount: profile.followerCount,
            ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _profile = profile);
      showError(context, e);
    }
  }

  /// "Set Up" walks through picture, header and bio; once the profile is
  /// set up the same button edits it.
  Future<void> _edit() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<bool>(
      profile.isSetUp
          ? appRoute(EditProfileScreen(profile: profile))
          : appRoute(ProfileSetupFlow(profile: profile), fullscreen: true),
    );
    if (saved == true) _load(silent: true);
  }

  void _message() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(appRoute(ChatScreen(partner: profile)));
  }

  Future<void> _share() async {
    final profile = _profile;
    if (profile == null) return;
    await showShareProfileSheet(context, profile);
  }

  void _joinedInfo(Profile profile) {
    final d = profile.createdAt;
    if (d == null) return;
    notify(
      context,
      title: 'Joined ${monthNames[d.month - 1]} ${d.year}',
      message: '@${profile.username} created this account on '
          '${monthNames[d.month - 1]} ${d.day}, ${d.year}.',
    );
  }

  void _removeFromLists(Post post) {
    setState(() {
      _posts = _posts.where((x) => x.id != post.id).toList();
      _replies = _replies?.where((x) => x.id != post.id).toList();
      _reposts = _reposts?.where((x) => x.id != post.id).toList();
      _likes = _likes?.where((x) => x.id != post.id).toList();
    });
  }

  // ---- UI ----------------------------------------------------------------

  List<Post> get _shown {
    switch (_tab) {
      case _ProfileTab.posts:
        return _showLikes ? (_likes ?? const []) : _posts;
      case _ProfileTab.replies:
        return _replies ?? const [];
      case _ProfileTab.reposts:
        return _reposts ?? const [];
      case _ProfileTab.media:
        // Only images can be uploaded, so the Videos list is always empty.
        return _showVideos
            ? const []
            : _posts.where((x) => x.imageUrl != null).toList();
    }
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: const Color(0xFFFFFFFF)),
      ),
    );
  }

  Widget _banner(Profile profile, AppPalette p) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (profile.headerUrl ?? '').isEmpty
              ? null
              : () => _openPhoto(profile, header: true),
          child: SizedBox(
            height: 120 + top,
            width: double.infinity,
            child: (profile.headerUrl ?? '').isEmpty
                ? const ColoredBox(color: Color(0xFFB0B0B0))
                : CachedNetworkImage(
                    imageUrl: profile.headerUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFB0B0B0)),
                  ),
          ),
        ),
        Positioned(
          left: 12,
          top: top + 8,
          child: _circleButton(
            AppIcons.back,
            () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          right: 12,
          top: top + 8,
          child: _circleButton(
            AppIcons.search,
            () => Navigator.of(context)
                .push(appRoute(const SearchScreen())),
          ),
        ),
      ],
    );
  }

  /// The picture on top of the banner's lower edge. It is drawn by [_header]
  /// (not inside the banner) because the part that hangs below the banner
  /// would otherwise not receive taps.
  Widget _avatarBadge(Profile profile, AppPalette p) {
    final square = Avatar.isSquare(profile.verified);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPhoto(profile, header: false),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.background,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(76 * 0.14 + 3) : null,
        ),
        child: Avatar(
          url: profile.avatarUrl,
          name: profile.name,
          size: 76,
          square: square,
        ),
      ),
    );
  }

  /// Profile picture / header full screen (tap them), with Share and Follow.
  void _openPhoto(Profile profile, {required bool header}) {
    showProfilePhoto(
      context,
      url: header ? profile.headerUrl : profile.avatarUrl,
      name: profile.name,
      header: header,
      square: Avatar.isSquare(profile.verified),
      onShare: _share,
      onFollow: _isMe ? null : _toggleFollow,
      followLabel: () => _profile?.followLabel ?? profile.followLabel,
    );
  }

  /// Small grey pill on the profile ("Automated", "Parody account" ...).
  Widget _badge(AppPalette p, String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: p.subtext),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: p.subtext,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  /// Followers / Following page. Hidden for protected accounts I don't follow.
  void _openFollowLists(Profile profile, FollowTab tab) {
    if (_walled(profile)) return;
    Navigator.of(context).push(appRoute(FollowListsScreen(
      userId: profile.id,
      title: profile.name,
      initial: tab,
    )));
  }

  Widget _stat(AppPalette p, int n, String label, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${compactCount(n)} ',
                style: TextStyle(
                  color: p.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: label,
                style: TextStyle(color: p.subtext, fontSize: 14),
              ),
            ],
          ),
        ),
        ),
      );

  Widget _verifyCard(AppPalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'You’re not verified yet',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showVerifyCard = false),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(AppIcons.close, size: 18, color: p.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Get verified to increase your account’s credibility and grow faster.',
              style: TextStyle(color: p.subtext, fontSize: 16, height: 1.25),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => notify(
              context,
              title: 'Verification',
              message: 'Verification is not part of this student project, '
                  'so there is nothing to finish here.',
            ),
            child: Container(
              height: 46,
              margin: const EdgeInsets.only(right: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.text,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Text(
                'Finish Verification',
                style: TextStyle(
                  color: p.background,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Profile profile, AppPalette p) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _headerBody(profile, p),
        Positioned(
          left: 16,
          top: 120 + top - 38,
          child: _avatarBadge(profile, p),
        ),
      ],
    );
  }

  Widget _headerBody(Profile profile, AppPalette p) {
    final joined = profile.createdAt;
    // Someone else's protected account has its own layout (like on X).
    final wide = !_isMe && profile.protectedPosts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(profile, p),
        if (_isMe)
          const SizedBox(height: 46)
        else if (wide)
          // Protected account: a round share button next to the picture; the
          // Message / Follow buttons come below the counts.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _share,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border, width: 1),
                    ),
                    child: XIcon(XIcons.share, size: 20, color: p.text),
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PillButton(icon: AppIcons.mail, onPressed: _message),
                    const SizedBox(width: 8),
                    PillButton(
                      label: profile.followLabel,
                      style: profile.followIsOutline
                          ? PillStyle.outline
                          : PillStyle.inverse,
                      onPressed: _toggleFollow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NameWithBadge(
                name: profile.name,
                verified: profile.verified,
                locked: profile.protectedPosts,
                badgeSize: 20,
                style: TextStyle(
                  color: p.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '@${profile.username}',
                style: TextStyle(color: p.subtext, fontSize: 15),
              ),
              if (profile.automated || profile.labelText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (profile.automated)
                        _badge(
                          p,
                          profile.managedByUsername == null
                              ? 'Automated'
                              : 'Automated by @${profile.managedByUsername}',
                          CupertinoIcons.gear,
                        ),
                      if (profile.labelText != null)
                        _badge(p, profile.labelText!, CupertinoIcons.tag),
                    ],
                  ),
                ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio,
                  style: TextStyle(color: p.text, fontSize: 15, height: 1.3),
                ),
              ],
              if (joined != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _joinedInfo(profile),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.calendar, size: 16, color: p.subtext),
                      const SizedBox(width: 6),
                      Text(
                        'Joined ${monthNames[joined.month - 1]} ${joined.year}',
                        style: TextStyle(color: p.subtext, fontSize: 14),
                      ),
                      const SizedBox(width: 2),
                      Icon(CupertinoIcons.chevron_right,
                          size: 12, color: p.subtext),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat(p, profile.followingCount, 'Following',
                      () => _openFollowLists(profile, FollowTab.following)),
                  _stat(p, profile.followerCount, 'Followers',
                      () => _openFollowLists(profile, FollowTab.followers)),
                ],
              ),
            ],
          ),
        ),
        if (wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Message',
                    onPressed: _message,
                    height: 44,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    label: profile.followLabel,
                    style: profile.followIsOutline
                        ? PillStyle.outline
                        : PillStyle.inverse,
                    onPressed: _toggleFollow,
                    height: 44,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        if (_isMe)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Share Profile',
                    onPressed: _share,
                    height: 42,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PillButton(
                    label: profile.isSetUp ? 'Edit profile' : 'Set Up',
                    onPressed: _edit,
                    height: 42,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        if (_isMe && _showVerifyCard) _verifyCard(p),
        if (!_walled(profile)) _tabs(p),
      ],
    );
  }

  /// Icon tabs; the selected one also shows its name.
  Widget _tabs(AppPalette p) {
    Widget tab(_ProfileTab t, IconData icon, String label,
        {bool chevron = false, Key? key}) {
      final active = t == _tab;
      final color = active ? p.text : p.subtext;
      return Expanded(
        key: key,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectTab(t),
          child: Column(
            children: [
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (active) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (chevron) ...[
                    const SizedBox(width: 3),
                    Icon(CupertinoIcons.chevron_down, size: 12, color: color),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: active ? p.accent : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        children: [
          tab(
            _ProfileTab.posts,
            CupertinoIcons.text_alignleft,
            _showLikes ? 'Likes' : 'Posts',
            chevron: true,
          ),
          tab(_ProfileTab.replies, CupertinoIcons.arrow_turn_up_left, 'Replies'),
          tab(_ProfileTab.reposts, CupertinoIcons.arrow_2_squarepath, 'Reposts'),
          tab(
            _ProfileTab.media,
            _showVideos ? CupertinoIcons.play_rectangle : CupertinoIcons.photo_on_rectangle,
            _showVideos ? 'Videos' : 'Photos',
            chevron: true,
            key: _mediaTabKey,
          ),
        ],
      ),
    );
  }

  /// Someone else's protected account that I am not (yet) a follower of: its
  /// posts are hidden.
  bool _walled(Profile profile) =>
      !_isMe && profile.protectedPosts && !profile.followedByMe;

  /// "These posts are protected." instead of the tabs and posts.
  Widget _protectedPanel(Profile profile, AppPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 44, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These posts are protected.',
            style: TextStyle(
              color: p.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Only confirmed followers have access to '
            '@${profile.username}’s posts and complete profile. '
            'Tap the “Follow” button to send a follow request.',
            style: TextStyle(color: p.subtext, fontSize: 18, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _empty(Profile profile, AppPalette p) {
    String title;
    String? body;
    Widget? action;

    switch (_tab) {
      case _ProfileTab.posts when _showLikes:
        title = _isMe ? 'You haven’t liked any posts yet' : 'No likes yet';
        body = 'Posts that are liked will show up here.';
      case _ProfileTab.posts:
        if (_isMe && !profile.isSetUp) {
          title = 'Your posts will show up here, but let’s set up your profile first.';
          action = PillButton(
            label: 'Set up profile',
            style: PillStyle.primary,
            height: 40,
            fontSize: 15,
            onPressed: _edit,
          );
        } else {
          title = _isMe ? 'You haven’t posted yet' : 'No posts yet';
          body = _isMe ? 'When you post, it will show up here.' : null;
        }
      case _ProfileTab.replies:
        if (_isMe && !profile.isSetUp) {
          title = 'Your posts will show up here, but let’s set up your profile first.';
          action = PillButton(
            label: 'Set up profile',
            style: PillStyle.primary,
            height: 40,
            fontSize: 15,
            onPressed: _edit,
          );
        } else {
          title = 'Nothing to see here — yet.';
          body = 'Replies will show up here.';
        }
      case _ProfileTab.reposts:
        title = 'Nothing to see here — yet.';
        body = 'Reposts will show up here.';
      case _ProfileTab.media:
        title = _showVideos ? 'Lights, camera ... videos!' : 'Lights, camera ... pictures!';
        body = _showVideos
            ? 'Your videos will show up here.'
            : 'Your photos will show up here.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: p.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.start,
              style: TextStyle(color: p.subtext, fontSize: 16),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            action,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final profile = _profile;

    if (_loading && profile == null) {
      return Stack(
        children: [
          const LoadingView(),
          Positioned(
            left: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: _circleButton(
              AppIcons.back,
              () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    }
    if (profile == null) {
      return Stack(
        children: [
          ErrorView(error: _error ?? 'Profile not found.', onRetry: _load),
          Positioned(
            left: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: _circleButton(
              AppIcons.back,
              () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    }

    final shown = _shown;
    final waiting = _tabLoading &&
        shown.isEmpty &&
        (_tab != _ProfileTab.posts || _showLikes);

    return ContentWidth(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _load(silent: true)),
          SliverToBoxAdapter(child: _header(profile, p)),
          if (_walled(profile))
            SliverToBoxAdapter(child: _protectedPanel(profile, p))
          else if (waiting)
            const SliverToBoxAdapter(child: PostSkeletons(count: 4))
          else if (shown.isEmpty)
            SliverToBoxAdapter(child: _empty(profile, p))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final post = shown[i];
                  return PostTile(
                    key: ValueKey('${_tab.name}_${_showLikes}_${post.id}'),
                    post: post,
                    currentProfileId: widget.userId,
                    onDeleted: _removeFromLists,
                  );
                },
                childCount: shown.length,
              ),
            ),
          if (_isMe && !waiting)
            const SliverToBoxAdapter(child: FollowCarousel()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// A profile opened from elsewhere (feed, search, chat…). Full-bleed, with
/// round back / search buttons over the banner.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ProfileViewState> _view = GlobalKey<ProfileViewState>();

  /// Writing a post never needs a set-up profile.
  Future<void> _compose() async {
    final posted = await Navigator.of(context).push<bool>(
      appRoute(const ComposePostScreen(), fullscreen: true),
    );
    if (posted == true) _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PlainScaffold(
      floating: RoundFab(icon: AppIcons.compose, onPressed: _compose),
      child: ProfileView(key: _view, userId: widget.userId),
    );
  }
}
