import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, SystemUiOverlayStyle;
import 'package:video_player/video_player.dart';

import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../core/x_icons.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../services/offline_videos.dart';
import '../services/user_prefs.dart';
import '../widgets/anchored_popup.dart' show rectOf;
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/post_card.dart' show repostGreen;
import '../widgets/post_menus.dart';
import '../widgets/post_video.dart' show videoClock;
import '../widgets/reply_guard.dart';
import '../widgets/share_post_sheet.dart';
import '../widgets/video_reaction.dart';
import 'compose_post_screen.dart';
import 'post_detail_screen.dart';
import 'report_screens.dart';

const _white = Color(0xFFFFFFFF);
const _dark = Color(0xFF1E2024);
const _glass = Color(0x99202327);
const _autoAdvanceKey = 'video_auto_advance';

/// What was picked in the "..." menu (the speed and the Auto-advance switch
/// apply at once and do not close it).
enum _MenuAction {
  quality,
  airplay,
  goToPost,
  offline,
  notInterested,
  report,
}

/// Full-screen video player, laid out like X:
///
/// * black page, the video in the middle, back button top left;
/// * author, Follow, text and the reply / repost / like / bookmark / share
///   row under (portrait) or over (landscape) the video;
/// * play / pause, the time that is left, the progress line, speed, volume
///   and rotate;
/// * "..." opens the settings card (speed, quality, auto-advance, offline,
///   report ...);
/// * one tap on the video hides all of that, another tap shows it again. The
///   video keeps playing (or stays paused) in both cases.
class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({super.key, required this.post});

  final Post post;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  static const _speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  late Post _post = widget.post;
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;
  bool _ended = false;
  bool _advancing = false;

  bool _overlays = true;
  double _speed = 1.0;
  bool _muted = false;

  /// Position (0..1) while the progress line is being dragged.
  double? _drag;
  bool _resumeAfterDrag = false;

  Profile? _author;

  bool get _autoAdvance => UserPrefs.instance.flag(_autoAdvanceKey, true);

  @override
  void initState() {
    super.initState();
    _open();
    _loadAuthor();
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    // Back to whatever the phone's rotation decides.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ------------------------------------------------------------ playback

  Future<void> _open() async {
    final old = _c;
    _c = null;
    old?.removeListener(_tick);
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _ready = false;
      _failed = false;
      _ended = false;
    });

    final url = _post.videoUrl;
    if (url == null || url.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    // A copy saved with "Add to Offline" plays without the network.
    final saved = await OfflineVideos.find(url);
    final c = saved != null
        ? VideoPlayerController.file(saved)
        : VideoPlayerController.networkUrl(Uri.parse(url));
    _c = c;
    try {
      await c.initialize();
      if (!mounted || _c != c) return;
      await c.setPlaybackSpeed(_speed);
      await c.setVolume(_muted ? 0 : 1);
      c.addListener(_tick);
      setState(() => _ready = true);
      await c.play();
    } catch (_) {
      if (mounted && _c == c) setState(() => _failed = true);
    }
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (v.hasError && !_failed) {
      setState(() => _failed = true);
      return;
    }
    final done = v.duration > Duration.zero &&
        v.position >= v.duration &&
        !v.isPlaying;
    if (done && !_ended) {
      _ended = true;
      if (_autoAdvance) _advance();
    } else if (!done) {
      _ended = false;
    }
  }

  /// "Auto-advance": when the video ends, the next older video post starts.
  Future<void> _advance() async {
    if (_advancing) return;
    _advancing = true;
    try {
      final list = await Api.fetchOlderVideoPosts(_post);
      if (!mounted) return;
      if (list.isEmpty) return;
      setState(() {
        _post = list.first;
        _author = null;
      });
      _loadAuthor();
      await _open();
    } catch (_) {
      // Stay on this video.
    } finally {
      _advancing = false;
    }
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || !_ready) return;
    final v = c.value;
    if (v.isPlaying) {
      c.pause();
    } else {
      if (v.position >= v.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _c?.setVolume(_muted ? 0 : 1);
  }

  void _setSpeed(double s) {
    setState(() => _speed = s);
    _c?.setPlaybackSpeed(s);
  }

  void _cycleSpeed() {
    final i = _speeds.indexOf(_speed);
    _setSpeed(_speeds[(i + 1) % _speeds.length]);
  }

  void _rotate() {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    SystemChrome.setPreferredOrientations(
      landscape
          ? const [DeviceOrientation.portraitUp]
          : const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    );
  }

  // ------------------------------------------------------------ progress

  void _dragStart() {
    final c = _c;
    if (c == null) return;
    _resumeAfterDrag = c.value.isPlaying;
    if (_resumeAfterDrag) c.pause();
  }

  void _dragUpdate(double fraction) => setState(() => _drag = fraction);

  Future<void> _dragEnd(double fraction) async {
    final c = _c;
    setState(() => _drag = null);
    if (c == null) return;
    await c.seekTo(c.value.duration * fraction);
    if (_resumeAfterDrag) await c.play();
  }

  // -------------------------------------------------------------- author

  Future<void> _loadAuthor() async {
    if (_post.userId == Api.uid) return;
    final id = _post.userId;
    try {
      final who = await Api.getProfile(id);
      if (mounted && _post.userId == id) setState(() => _author = who);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final before = _author;
    if (before == null) return;
    final after = before.afterFollowTap();
    setState(() => _author = after);
    try {
      await Api.setFollow(
        before.id,
        follow: after.followedByMe || after.requestedByMe,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _author = before);
      showError(context, e);
    }
  }

  // ------------------------------------------------------------- actions

  Future<void> _like() async {
    final before = _post;
    final next = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: before.likeCount + (before.likedByMe ? -1 : 1),
    );
    setState(() => _post = next);
    try {
      await Api.setLike(before.id, like: next.likedByMe);
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _repost() async {
    final before = _post;
    final next = before.copyWith(
      repostedByMe: !before.repostedByMe,
      repostCount: before.repostCount + (before.repostedByMe ? -1 : 1),
    );
    setState(() => _post = next);
    try {
      await Api.setRepost(before.id, reposted: next.repostedByMe);
      if (mounted) {
        showInfo(context, next.repostedByMe ? 'You reposted' : 'Repost removed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _repostMenu(Rect anchor) async {
    final choice = await showRepostPopup(
      context,
      anchor: anchor,
      reposted: _post.repostedByMe,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case RepostChoice.repost:
      case RepostChoice.undo:
        await _repost();
      case RepostChoice.quote:
        _c?.pause();
        final posted = await Navigator.of(context).push<bool>(
          appRoute(ComposePostScreen(quoting: _post), fullscreen: true),
        );
        if (posted == true && mounted) {
          setState(
            () => _post = _post.copyWith(repostCount: _post.repostCount + 1),
          );
          showSuccess(context, 'Your quote was posted');
        }
      case RepostChoice.video:
        _c?.pause();
        if (await reactWithVideo(context, _post) && mounted) {
          setState(
            () => _post = _post.copyWith(repostCount: _post.repostCount + 1),
          );
        }
    }
  }

  Future<void> _bookmark() async {
    final before = _post;
    final saved = !before.bookmarkedByMe;
    final next = before.copyWith(
      bookmarkedByMe: saved,
      bookmarkCount:
          (before.bookmarkCount + (saved ? 1 : -1)).clamp(0, 1 << 31).toInt(),
    );
    setState(() => _post = next);
    try {
      await Api.setBookmark(before.id, bookmarked: saved);
      if (mounted) {
        showInfo(
          context,
          saved ? 'Added to your Bookmarks' : 'Removed from your Bookmarks',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showError(context, e);
    }
  }

  Future<void> _reply() async {
    if (!await ensureCanReply(context, _post) || !mounted) return;
    _c?.pause();
    final posted = await Navigator.of(context).push<bool>(
      appRoute(ComposePostScreen(replyTo: _post), fullscreen: true),
    );
    if (posted == true && mounted) {
      setState(
        () => _post = _post.copyWith(replyCount: _post.replyCount + 1),
      );
      showSuccess(context, 'Your reply was sent');
    }
  }

  Future<void> _share() => showSharePostSheet(context, _post);

  // ---------------------------------------------------------------- menu

  Future<void> _openMenu() async {
    final url = _post.videoUrl ?? '';
    final saved = await OfflineVideos.isSaved(url);
    if (!mounted) return;
    final action = await showGeneralDialog<_MenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (_, _, _) => _VideoMenu(
        speeds: _speeds,
        speed: _speed,
        autoAdvance: _autoAdvance,
        saved: saved,
        onSpeed: _setSpeed,
        onAutoAdvance: (v) => UserPrefs.instance.set(_autoAdvanceKey, v),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.quality:
        showInfo(context, 'Auto (original quality) is the only option here.');
      case _MenuAction.airplay:
        showInfo(
          context,
          'Pick AirPlay or a Bluetooth speaker in your phone’s Control Center.',
        );
      case _MenuAction.goToPost:
        _c?.pause();
        await Navigator.of(context)
            .push(appRoute(PostDetailScreen(post: _post)));
      case _MenuAction.offline:
        await _toggleOffline(saved);
      case _MenuAction.notInterested:
        await Moderation.instance.hidePost(_post.id);
        if (!mounted) return;
        showInfo(context, 'Thanks. X will use this to make your timeline better.');
        Navigator.of(context).maybePop();
      case _MenuAction.report:
        _c?.pause();
        await Navigator.of(context).push(
          appRoute(ReportPostScreen(post: _post), fullscreen: true),
        );
    }
  }

  Future<void> _toggleOffline(bool saved) async {
    final url = _post.videoUrl ?? '';
    try {
      if (saved) {
        await OfflineVideos.remove(url);
        if (mounted) showInfo(context, 'Removed from Offline');
      } else {
        showInfo(context, 'Saving the video…');
        await OfflineVideos.save(url);
        if (mounted) showSuccess(context, 'Saved. You can watch it offline.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // ------------------------------------------------------------------ UI

  Widget _circle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: _glass, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: _white),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 24, color: _white),
      ),
    );
  }

  String _speedLabel() {
    final s = _speed;
    return s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';
  }

  Widget _speedButton(double size) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cycleSpeed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          _speedLabel(),
          style: TextStyle(
            color: _white,
            fontSize: size,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _video() {
    final c = _c;
    if (_failed) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.exclamationmark_circle,
                  size: 40, color: Color(0xFF71767B)),
              SizedBox(height: 10),
              Text(
                'This video can’t be played.',
                style: TextStyle(
                  color: Color(0xFF71767B),
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tap to try again',
                style: TextStyle(
                  color: Color(0xFF1D9BF0),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready || c == null) {
      return const CupertinoActivityIndicator(color: _white, radius: 14);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
          child: VideoPlayer(c),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, v, _) => v.isBuffering
              ? const CupertinoActivityIndicator(color: _white, radius: 14)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _topRow(bool landscape) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _circle(CupertinoIcons.arrow_left, () => Navigator.of(context).maybePop()),
          const Spacer(),
          if (landscape)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _glass,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  _speedButton(18),
                  _iconButton(
                    _muted
                        ? CupertinoIcons.speaker_slash
                        : CupertinoIcons.speaker_2,
                    _toggleMute,
                  ),
                  _iconButton(CupertinoIcons.rotate_right, _rotate),
                  _iconButton(CupertinoIcons.ellipsis, _openMenu),
                ],
              ),
            )
          else
            _circle(CupertinoIcons.ellipsis, _openMenu),
        ],
      ),
    );
  }

  Widget _followPill(AppPalette p) {
    final who = _author;
    if (who == null) return const SizedBox.shrink();
    final on = who.followedByMe || who.requestedByMe;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleFollow,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x4D808080),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          who.followedByMe
              ? 'Following'
              : (who.requestedByMe ? 'Pending' : 'Follow'),
          style: TextStyle(
            color: _white,
            fontSize: 15,
            fontWeight: on ? FontWeight.w500 : FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _authorRow(AppPalette p) {
    return Row(
      children: [
        Avatar(
          url: _post.avatarUrl,
          name: _post.authorName,
          size: 40,
          square: Avatar.isSquare(_post.authorVerified),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NameWithBadge(
                name: _post.authorName,
                verified: _post.authorVerified,
                locked: _post.authorProtected,
                badgeSize: 15,
                style: const TextStyle(
                  color: _white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '@${_post.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB0B4B8),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        _followPill(p),
      ],
    );
  }

  Widget _pill({
    required List<XShape> icon,
    required int count,
    required VoidCallback onTap,
    Color color = _white,
    void Function(Rect)? onAnchorTap,
  }) {
    return Expanded(
      child: Builder(
        builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAnchorTap == null ? onTap : () => onAnchorTap(rectOf(ctx)),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _dark,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                XIcon(icon, size: 22, color: color),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    compactCount(count),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundAction(List<XShape> icon, VoidCallback onTap, {Color color = _white}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(color: _dark, shape: BoxShape.circle),
        child: Center(child: XIcon(icon, size: 21, color: color)),
      ),
    );
  }

  Widget _actionsRow() {
    final p = _post;
    return Row(
      children: [
        _pill(icon: XIcons.reply, count: p.replyCount, onTap: _reply),
        const SizedBox(width: 8),
        _pill(
          icon: XIcons.repost,
          count: p.repostCount,
          onTap: _repost,
          color: p.repostedByMe ? repostGreen : _white,
          onAnchorTap: _repostMenu,
        ),
        const SizedBox(width: 8),
        _pill(
          icon: p.likedByMe ? XIcons.likeFill : XIcons.like,
          count: p.likeCount,
          onTap: _like,
          color: p.likedByMe ? AppPalette.like : _white,
        ),
        const SizedBox(width: 8),
        _roundAction(
          p.bookmarkedByMe ? XIcons.bookmarkFill : XIcons.bookmark,
          _bookmark,
          color: p.bookmarkedByMe ? const Color(0xFF1D9BF0) : _white,
        ),
        const SizedBox(width: 8),
        _roundAction(XIcons.share, _share),
      ],
    );
  }

  Widget _infoBlock(AppPalette p, {bool compact = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _authorRow(p),
          if (!compact && _post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _white,
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          const SizedBox(height: 14),
          _actionsRow(),
        ],
      ),
    );
  }

  Widget _playButton(VideoPlayerValue v) {
    final atEnd = v.duration > Duration.zero && v.position >= v.duration;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          v.isPlaying
              ? CupertinoIcons.pause_fill
              : (atEnd ? CupertinoIcons.gobackward : CupertinoIcons.play_fill),
          size: 28,
          color: _white,
        ),
      ),
    );
  }

  /// Play / pause, remaining time and progress line (+ speed, volume and
  /// rotate when the phone is upright; in landscape they are at the top).
  Widget _controls(bool landscape) {
    final c = _c;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c ?? ValueNotifier(VideoPlayerValue.uninitialized()),
      builder: (_, v, _) {
        final total = v.duration;
        final fraction = _drag ??
            (total.inMilliseconds <= 0
                ? 0.0
                : (v.position.inMilliseconds / total.inMilliseconds)
                    .clamp(0.0, 1.0)
                    .toDouble());
        final shown = _drag != null ? total * _drag! : v.position;
        final left = total - shown;
        final remaining = Text(
          '-${videoClock(left < Duration.zero ? Duration.zero : left)}',
          style: const TextStyle(
            color: Color(0xFFB0B4B8),
            fontSize: 17,
            decoration: TextDecoration.none,
          ),
        );
        final scrubber = _Scrubber(
          fraction: fraction,
          enabled: _ready,
          onStart: _dragStart,
          onChanged: _dragUpdate,
          onEnd: _dragEnd,
        );

        if (landscape) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 8),
            child: Row(
              children: [
                _playButton(v),
                const SizedBox(width: 6),
                Expanded(child: scrubber),
                const SizedBox(width: 14),
                remaining,
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            scrubber,
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  _playButton(v),
                  const SizedBox(width: 6),
                  remaining,
                  const Spacer(),
                  _speedButton(22),
                  _iconButton(
                    _muted
                        ? CupertinoIcons.speaker_slash
                        : CupertinoIcons.speaker_2,
                    _toggleMute,
                  ),
                  _iconButton(CupertinoIcons.rotate_right, _rotate),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // A phone on its side is only ~360 high: leave the text out then.
    final compact = landscape && MediaQuery.sizeOf(context).height < 460;

    final overlay = SafeArea(
      child: Column(
        children: [
          _topRow(landscape),
          const Spacer(),
          if (landscape)
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  _infoBlock(p, compact: compact),
                  _controls(true),
                ],
              ),
            )
          else ...[
            _infoBlock(p),
            _controls(false),
          ],
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: _white,
            fontSize: 16,
            decoration: TextDecoration.none,
          ),
          // One tap anywhere that is not a button hides / shows the overlays
          // (playing or paused); the video itself is not touched.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _overlays = !_overlays),
            child: Stack(
              children: [
                Positioned.fill(child: Center(child: _video())),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_overlays,
                    child: AnimatedOpacity(
                      opacity: _overlays ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: overlay,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The thin progress line with a round handle. Tap or drag to jump.
class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.fraction,
    required this.enabled,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  final double fraction;
  final bool enabled;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        double at(Offset o) =>
            width <= 0 ? 0.0 : (o.dx / width).clamp(0.0, 1.0).toDouble();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (d) {
                  onStart();
                  onEnd(at(d.localPosition));
                }
              : null,
          onHorizontalDragStart: enabled
              ? (d) {
                  onStart();
                  onChanged(at(d.localPosition));
                }
              : null,
          onHorizontalDragUpdate:
              enabled ? (d) => onChanged(at(d.localPosition)) : null,
          onHorizontalDragEnd: enabled ? (_) => onEnd(fraction) : null,
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 3, color: const Color(0x4DFFFFFF)),
                Container(height: 3, width: width * fraction, color: _white),
                Positioned(
                  left: (width * fraction - 6).clamp(0.0, width - 12),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: _white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The settings card (the "..." button): speed, quality, auto-advance,
/// AirPlay & Bluetooth, go to post, offline, not interested, report.
class _VideoMenu extends StatefulWidget {
  const _VideoMenu({
    required this.speeds,
    required this.speed,
    required this.autoAdvance,
    required this.saved,
    required this.onSpeed,
    required this.onAutoAdvance,
  });

  final List<double> speeds;
  final double speed;
  final bool autoAdvance;
  final bool saved;
  final ValueChanged<double> onSpeed;
  final ValueChanged<bool> onAutoAdvance;

  @override
  State<_VideoMenu> createState() => _VideoMenuState();
}

class _VideoMenuState extends State<_VideoMenu> {
  late double _speed = widget.speed;
  late bool _auto = widget.autoAdvance;

  static String _label(double s) =>
      s == s.roundToDouble() ? '${s.toInt()}x' : '${s}x';

  Widget _speedBar(AppPalette p) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final s in widget.speeds)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _speed = s);
                  widget.onSpeed(s);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s == _speed ? p.background : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: s == _speed
                        ? const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _label(s),
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    AppPalette p,
    IconData icon,
    String label, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 24, color: p.text),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: p.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    void pick(_MenuAction a) => Navigator.of(context).pop(a);
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: Container(
        width: (width - 48).clamp(260.0, 440.0).toDouble(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(30),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: p.text, decoration: TextDecoration.none),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _speedBar(p),
              const SizedBox(height: 8),
              _row(
                p,
                CupertinoIcons.slider_horizontal_3,
                'Quality',
                onTap: () => pick(_MenuAction.quality),
                trailing: Row(
                  children: [
                    Text(
                      'Auto',
                      style: TextStyle(
                        color: p.subtext,
                        fontSize: 17,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(CupertinoIcons.chevron_right,
                        size: 15, color: p.subtext),
                  ],
                ),
              ),
              _row(
                p,
                CupertinoIcons.play_circle,
                'Auto-advance',
                trailing: CupertinoSwitch(
                  value: _auto,
                  activeTrackColor: const Color(0xFF00BA7C),
                  onChanged: (v) {
                    setState(() => _auto = v);
                    widget.onAutoAdvance(v);
                  },
                ),
              ),
              _row(
                p,
                CupertinoIcons.tv,
                'Airplay & Bluetooth',
                onTap: () => pick(_MenuAction.airplay),
              ),
              _row(
                p,
                CupertinoIcons.square_split_2x1,
                'Go to Post',
                onTap: () => pick(_MenuAction.goToPost),
              ),
              _row(
                p,
                widget.saved ? CupertinoIcons.minus : CupertinoIcons.add,
                widget.saved ? 'Remove from Offline' : 'Add to Offline',
                onTap: () => pick(_MenuAction.offline),
              ),
              _row(
                p,
                CupertinoIcons.hand_thumbsdown,
                'Not interested in this',
                onTap: () => pick(_MenuAction.notInterested),
              ),
              _row(
                p,
                CupertinoIcons.flag,
                'Report post',
                onTap: () => pick(_MenuAction.report),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
