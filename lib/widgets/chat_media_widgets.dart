import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../services/api.dart';
import '../services/chat_media.dart';
import '../services/image_picker_service.dart';
import 'post_media.dart' show ImageViewerScreen;

const _white = Color(0xFFFFFFFF);

String _mmss(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

// ===========================================================================
// Picking a photo / video
// ===========================================================================

/// Action sheet "Photo or video / Take photo / Record video". Returns what was
/// chosen, or null when cancelled (or when it could not be used: the reason
/// is shown).
Future<ChatDraft?> pickChatAttachment(BuildContext context) async {
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('gallery'),
          child: const Text('Photo or video from gallery'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('photo'),
          child: const Text('Take a photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('video'),
          child: const Text('Record a video'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  try {
    switch (choice) {
      case 'gallery':
        final media = await pickGalleryMedia(1);
        if (media.video != null) return ChatDraft.video(media.video!);
        if (media.images.isNotEmpty) return ChatDraft.image(media.images.first);
        return null;
      case 'photo':
        final img = await pickCameraImage();
        return img == null ? null : ChatDraft.image(img);
      case 'video':
        final video = await recordCameraVideo();
        return video == null ? null : ChatDraft.video(video);
    }
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
  return null;
}

// ===========================================================================
// The message bar: field + attach + send / record
// ===========================================================================

/// The bottom row of a chat: attach button (photo / video), the text field,
/// and a send button that becomes a microphone while the field is empty.
/// Tap the microphone to record, then tap send (or the bin to throw away).
class ChatComposerBar extends StatefulWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.sending,
    required this.onSendText,
    required this.onSendMedia,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool sending;
  final VoidCallback onSendText;
  final Future<void> Function(ChatDraft draft) onSendMedia;

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  VoiceRecorder? _voice;
  bool _recording = false;
  bool _starting = false;
  Timer? _timer;
  int _ms = 0;
  final List<double> _levels = [];

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(ChatComposerBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _timer?.cancel();
    final v = _voice;
    if (v != null) unawaited(v.dispose());
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  Future<void> _attach() async {
    if (widget.sending) return;
    final draft = await pickChatAttachment(context);
    if (draft == null || !mounted) return;
    await widget.onSendMedia(draft);
  }

  Future<void> _startRecording() async {
    if (widget.sending || _starting || _recording) return;
    _starting = true;
    try {
      final voice = _voice ??= VoiceRecorder();
      final ok = await voice.start();
      if (!mounted) {
        await voice.cancel();
        return;
      }
      if (!ok) {
        showInfo(context, 'Allow microphone access to send voice messages.');
        return;
      }
      setState(() {
        _recording = true;
        _ms = 0;
        _levels.clear();
      });
      _timer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
        final v = _voice;
        if (v == null || !v.isRecording) return;
        final level = await v.level();
        if (!mounted || !_recording) return;
        setState(() {
          _ms = v.elapsed.inMilliseconds;
          _levels.add(level);
          if (_levels.length > 40) _levels.removeAt(0);
        });
        if (_ms >= maxVoiceSeconds * 1000) _finishRecording();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      _starting = false;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _cancelRecording() async {
    _stopTimer();
    await _voice?.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    _stopTimer();
    final draft = await _voice?.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (draft == null || (draft.durationMs ?? 0) < 800) {
      showInfo(context, 'Voice message too short. Tap the mic and speak.');
      return;
    }
    await widget.onSendMedia(draft);
  }

  Widget _circle(
    AppPalette p, {
    required IconData icon,
    required VoidCallback? onTap,
    Color? background,
    Color? color,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background ?? p.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color ?? _white),
        ),
      ),
    );
  }

  Widget _recordingRow(AppPalette p) {
    return Row(
      children: [
        _circle(
          p,
          icon: CupertinoIcons.trash,
          background: p.field,
          color: p.danger,
          onTap: _cancelRecording,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: p.danger, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  _mmss(_ms),
                  style: TextStyle(
                    color: p.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _LevelBars(levels: _levels, color: p.accent)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circle(
          p,
          icon: AppIcons.send,
          onTap: widget.sending ? null : _finishRecording,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: _recording
            ? _recordingRow(p)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _circle(
                    p,
                    icon: CupertinoIcons.photo,
                    background: p.field,
                    color: p.accent,
                    onTap: widget.sending ? null : _attach,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.controller,
                      placeholder: widget.placeholder,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: p.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: p.field,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      style: TextStyle(color: p.text, fontSize: 16),
                      placeholderStyle:
                          TextStyle(color: p.subtext, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.sending)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CupertinoActivityIndicator(color: p.accent),
                      ),
                    )
                  else if (_hasText)
                    _circle(p, icon: AppIcons.send, onTap: widget.onSendText)
                  else
                    _circle(
                      p,
                      icon: CupertinoIcons.mic_fill,
                      onTap: _startRecording,
                    ),
                ],
              ),
      ),
    );
  }
}

/// Little bars that move with the voice while recording.
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / 5).floor().clamp(1, 40);
        final shown = levels.length > count
            ? levels.sublist(levels.length - count)
            : levels;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final l in shown)
              Container(
                width: 3,
                height: 4 + 18 * l,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Showing the media inside a chat bubble
// ===========================================================================

/// The picture, video or voice message of a chat message.
class ChatMediaView extends StatelessWidget {
  const ChatMediaView({
    super.key,
    required this.path,
    required this.kind,
    required this.mine,
    required this.maxWidth,
    this.durationMs,
  });

  final String path;
  final String kind;
  final bool mine;
  final double maxWidth;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    switch (ChatMediaKindX.parse(kind)) {
      case ChatMediaKind.image:
        return _ChatImage(path: path, maxWidth: maxWidth);
      case ChatMediaKind.video:
        return _ChatVideoThumb(
          path: path,
          maxWidth: maxWidth,
          durationMs: durationMs,
        );
      case ChatMediaKind.voice:
        return VoiceBubble(path: path, mine: mine, durationMs: durationMs);
      case null:
        return const SizedBox.shrink();
    }
  }
}

class _ChatImage extends StatefulWidget {
  const _ChatImage({required this.path, required this.maxWidth});

  final String path;
  final double maxWidth;

  @override
  State<_ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<_ChatImage> {
  late Future<String> _url = Api.chatMediaUrl(widget.path);

  @override
  void didUpdateWidget(_ChatImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = Api.chatMediaUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final w = widget.maxWidth.clamp(120.0, 260.0);
    Widget box(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: w,
            height: w * 1.05,
            color: p.border,
            child: child,
          ),
        );
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) {
          return box(
            Center(
              child: Icon(CupertinoIcons.photo, size: 36, color: p.subtext),
            ),
          );
        }
        final url = snap.data;
        if (url == null) {
          return box(const Center(child: CupertinoActivityIndicator()));
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            appRoute(ImageViewerScreen(urls: [url]), fullscreen: true),
          ),
          child: box(
            CachedNetworkImage(
              imageUrl: url,
              cacheKey: widget.path,
              fit: BoxFit.cover,
              placeholder: (c, _) =>
                  const Center(child: CupertinoActivityIndicator()),
              errorWidget: (c, _, _) => Center(
                child: Icon(CupertinoIcons.photo, size: 36, color: p.subtext),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatVideoThumb extends StatelessWidget {
  const _ChatVideoThumb({
    required this.path,
    required this.maxWidth,
    this.durationMs,
  });

  final String path;
  final double maxWidth;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth.clamp(140.0, 260.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        appRoute(ChatVideoScreen(path: path), fullscreen: true),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: w,
          height: w * 0.62,
          color: const Color(0xFF14171A),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.play_fill,
                    size: 26, color: _white),
              ),
              if (durationMs != null)
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _mmss(durationMs!),
                      style: const TextStyle(
                        color: _white,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Voice message player
// ===========================================================================

/// Play / pause button, progress and length of a voice message. Only one voice
/// message plays at a time.
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({
    super.key,
    required this.path,
    required this.mine,
    this.durationMs,
  });

  final String path;
  final bool mine;
  final int? durationMs;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  static _VoiceBubbleState? _current;

  VideoPlayerController? _c;
  bool _loading = false;
  bool _playing = false;
  int _positionMs = 0;
  int _totalMs = 0;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.durationMs ?? 0;
  }

  @override
  void dispose() {
    if (_current == this) _current = null;
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    final total = v.duration.inMilliseconds;
    final done = total > 0 && v.position.inMilliseconds >= total - 80;
    if (done && v.isPlaying) {
      c.pause();
      c.seekTo(Duration.zero);
    }
    setState(() {
      _playing = v.isPlaying && !done;
      _positionMs = done ? 0 : v.position.inMilliseconds;
      if (total > 0) _totalMs = total;
    });
  }

  Future<void> _toggle() async {
    if (_loading) return;
    final existing = _c;
    if (existing != null && existing.value.isInitialized) {
      if (existing.value.isPlaying) {
        await existing.pause();
      } else {
        _current?._pauseIfOther(this);
        _current = this;
        await existing.play();
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await Api.chatMediaUrl(widget.path);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_tick);
      _c = c;
      _current?._pauseIfOther(this);
      _current = this;
      await c.play();
    } catch (_) {
      if (mounted) showError(context, 'This voice message could not be played.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pauseIfOther(_VoiceBubbleState other) {
    if (other != this) _c?.pause();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = widget.mine ? _white : p.text;
    final track = widget.mine ? const Color(0x55FFFFFF) : p.subtext.withValues(alpha: 0.35);
    final fraction =
        _totalMs > 0 ? (_positionMs / _totalMs).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: widget.mine ? p.accent : p.border,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.mine ? const Color(0x33FFFFFF) : p.background,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      _playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      size: 18,
                      color: widget.mine ? _white : p.accent,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Container(height: 4, color: track),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(height: 4, color: fg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _playing || _positionMs > 0
                      ? '${_mmss(_positionMs)} / ${_mmss(_totalMs)}'
                      : _mmss(_totalMs),
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Full-screen video of a chat
// ===========================================================================

/// Full-screen player for a video sent in a chat: tap the video to pause /
/// play, drag the line to move around.
class ChatVideoScreen extends StatefulWidget {
  const ChatVideoScreen({super.key, required this.path});

  final String path;

  @override
  State<ChatVideoScreen> createState() => _ChatVideoScreenState();
}

class _ChatVideoScreenState extends State<ChatVideoScreen> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final url = await Api.chatMediaUrl(widget.path);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _c = c;
      await c.initialize();
      if (!mounted) return;
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.setLooping(false);
      await c.play();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: _white,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Center(
                  child: _failed
                      ? const Text('This video could not be played.')
                      : !ready
                          ? const CupertinoActivityIndicator(color: _white)
                          : AspectRatio(
                              aspectRatio: c.value.aspectRatio,
                              child: VideoPlayer(c),
                            ),
                ),
              ),
            ),
            if (ready && !c.value.isPlaying)
              const Center(
                child: IgnorePointer(
                  child: Icon(CupertinoIcons.play_circle_fill,
                      size: 72, color: Color(0xCCFFFFFF)),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.arrow_left,
                          size: 22, color: _white),
                    ),
                  ),
                ),
              ),
            ),
            if (ready)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Text(_mmss(c.value.position.inMilliseconds)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: VideoProgressIndicator(
                            c,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: const VideoProgressColors(
                              playedColor: _white,
                              bufferedColor: Color(0x55FFFFFF),
                              backgroundColor: Color(0x33FFFFFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(_mmss(c.value.duration.inMilliseconds)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
