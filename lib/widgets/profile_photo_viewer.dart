import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import 'avatar.dart';

/// Full-screen look at a profile picture or header (tap them on a profile),
/// like X: dimmed page behind, the picture in the middle and Share / Follow
/// pills at the bottom. Tap outside the picture to close.
Future<void> showProfilePhoto(
  BuildContext context, {
  required String? url,
  required String name,

  /// True for the wide banner, false for the profile picture.
  required bool header,

  /// Profile pictures of organisation accounts are rounded squares.
  bool square = false,
  VoidCallback? onShare,

  /// Null hides the Follow pill (my own profile).
  Future<void> Function()? onFollow,
  String Function()? followLabel,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0xE6000000),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (_, __, ___) => _PhotoViewer(
      url: url,
      name: name,
      header: header,
      square: square,
      onShare: onShare,
      onFollow: onFollow,
      followLabel: followLabel,
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.url,
    required this.name,
    required this.header,
    required this.square,
    this.onShare,
    this.onFollow,
    this.followLabel,
  });

  final String? url;
  final String name;
  final bool header;
  final bool square;
  final VoidCallback? onShare;
  final Future<void> Function()? onFollow;
  final String Function()? followLabel;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  Future<void> _follow() async {
    final f = widget.onFollow;
    if (f == null) return;
    final done = f();
    // The label flips at once (optimistic), then once more when the server
    // answers.
    if (mounted) setState(() {});
    await done;
    if (mounted) setState(() {});
  }

  Widget _pill({
    IconData? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: const Color(0x2EFFFFFF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 21, color: const Color(0xFFFFFFFF)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picture(Size screen) {
    final url = widget.url;
    final hasUrl = url != null && url.isNotEmpty;
    if (widget.header) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: SizedBox(
          width: screen.width,
          child: CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              height: 200,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            errorWidget: (_, __, ___) => const SizedBox(
              height: 200,
              child: Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: 48,
                  color: Color(0xFF71767B),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final side = [screen.width - 48, screen.height * 0.6, 560.0]
        .reduce((a, b) => a < b ? a : b);
    final radius = widget.square ? side * 0.2 : side / 2;
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: side,
          height: side,
          child: hasUrl
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const Center(child: CupertinoActivityIndicator()),
                  errorWidget: (_, __, ___) =>
                      Avatar(url: null, name: widget.name, size: side),
                )
              : Avatar(url: null, name: widget.name, size: side),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DefaultTextStyle(
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 16,
        decoration: TextDecoration.none,
      ),
      child: Stack(
        children: [
          // Tap anywhere that is not the picture or a pill to close.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Center(child: _picture(mq.size)),
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.padding.bottom + 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _pill(
                  icon: AppIcons.share,
                  label: 'Share',
                  onTap: widget.onShare ?? () {},
                ),
                if (widget.onFollow != null) ...[
                  const SizedBox(width: 14),
                  _pill(
                    label: widget.followLabel?.call() ?? 'Follow',
                    onTap: _follow,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
