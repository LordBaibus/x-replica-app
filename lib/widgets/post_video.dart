import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:video_player/video_player.dart';

import '../core/app_palette.dart';

/// "1:43" / "0:09" / "1:02:03".
String videoClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// The video of a post as it looks in a timeline: the first frame in a
/// rounded box with a play button and the length at the bottom left, like X.
/// Nothing plays here; tapping opens the full-screen player.
///
/// Give it a network [url] (a posted video) or a local [file] (a video that
/// is still being composed, then [onRemove] draws the X button).
class VideoPoster extends StatefulWidget {
  const VideoPoster({
    super.key,
    this.url,
    this.file,
    this.onTap,
    this.onRemove,
    this.radius = 16,
  }) : assert(url != null || file != null);

  final String? url;
  final String? file;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double radius;

  @override
  State<VideoPoster> createState() => _VideoPosterState();
}

class _VideoPosterState extends State<VideoPoster> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(VideoPoster old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.file != widget.file) {
      _c?.dispose();
      _c = null;
      _ready = false;
      _failed = false;
      _init();
    }
  }

  Future<void> _init() async {
    final c = widget.file != null
        ? VideoPlayerController.file(File(widget.file!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _c = c;
    try {
      await c.initialize();
      await c.setVolume(0);
      // A tiny seek makes Android draw the first frame while paused.
      await c.seekTo(const Duration(milliseconds: 120));
      if (!mounted || _c != c) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted && _c == c) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = _c;
    final ratio = (_ready && c != null && c.value.aspectRatio > 0)
        ? c.value.aspectRatio.clamp(0.8, 16 / 9).toDouble()
        : 16 / 9;

    Widget frame;
    if (_ready && c != null) {
      frame = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      );
    } else {
      frame = const SizedBox.expand();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF000000)),
                frame,
                if (!_ready && !_failed)
                  const Center(
                    child: CupertinoActivityIndicator(
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                if (_failed)
                  const Center(
                    child: Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 36,
                      color: Color(0xFF71767B),
                    ),
                  ),
                if (!_failed)
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        size: 30,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                if (_ready && c != null)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _badge(videoClock(c.value.duration)),
                  ),
                if (widget.onRemove != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onRemove,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xB3000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                          color: Color(0xFFFFFFFF),
                        ),
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
