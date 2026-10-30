import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/post_detail_screen.dart';
import '../screens/report_screens.dart';
import 'popover_menu.dart';
import 'post_menus.dart' show copyPostLink;
import 'share_post_sheet.dart';

/// The pictures of a post, laid out like X: one wide picture, two portrait
/// pictures side by side, or a 3 / 4 picture grid, with rounded corners and a
/// thin outline. Tapping a picture reports its index.
class PostMedia extends StatelessWidget {
  const PostMedia({
    super.key,
    required this.urls,
    this.radius = 16,
    this.onTap,
  });

  final List<String> urls;
  final double radius;
  final ValueChanged<int>? onTap;

  static const double _gap = 2;

  Widget _img(AppPalette p, int i) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap!(i),
      child: CachedNetworkImage(
        imageUrl: urls[i],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(color: p.surface),
        errorWidget: (context, url, error) => Container(color: p.surface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    final n = urls.length > 4 ? 4 : urls.length;

    Widget grid;
    double ratio;
    if (n == 1) {
      ratio = 16 / 9;
      grid = _img(p, 0);
    } else if (n == 2) {
      ratio = 3 / 2;
      grid = Row(
        children: [
          Expanded(child: _img(p, 0)),
          const SizedBox(width: _gap),
          Expanded(child: _img(p, 1)),
        ],
      );
    } else if (n == 3) {
      ratio = 16 / 9;
      grid = Row(
        children: [
          Expanded(child: _img(p, 0)),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _img(p, 1)),
                const SizedBox(height: _gap),
                Expanded(child: _img(p, 2)),
              ],
            ),
          ),
        ],
      );
    } else {
      ratio = 16 / 9;
      grid = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _img(p, 0)),
                const SizedBox(width: _gap),
                Expanded(child: _img(p, 1)),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _img(p, 2)),
                const SizedBox(width: _gap),
                Expanded(child: _img(p, 3)),
              ],
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: p.border, width: 1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ColoredBox(color: p.background, child: grid),
        ),
      ),
    );
  }
}

enum _PhotoAction { share, copyPost, copyImage, goToPost, report }

/// Full-screen picture viewer: swipe between the post's pictures. With the
/// [post] it belongs to, the "..." button at the top right opens the picture
/// menu (share, copy links, go to post, report).
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.urls,
    this.initial = 0,
    this.post,
  });

  final List<String> urls;
  final int initial;
  final Post? post;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final GlobalKey _moreKey = GlobalKey();

  Future<void> _openMenu() async {
    final post = widget.post;
    if (post == null) return;
    final pick = await showPopoverMenu<_PhotoAction>(
      context,
      anchor: _moreKey,
      width: 280,
      entries: const [
        PopoverEntry(
          value: _PhotoAction.share,
          label: 'Share post via...',
          icon: CupertinoIcons.share,
        ),
        PopoverEntry(
          value: _PhotoAction.copyPost,
          label: 'Copy link to post',
          icon: CupertinoIcons.link,
        ),
        PopoverEntry(
          value: _PhotoAction.copyImage,
          label: 'Copy image link',
          icon: CupertinoIcons.photo,
        ),
        PopoverEntry(
          value: _PhotoAction.goToPost,
          label: 'Go to post',
          icon: CupertinoIcons.arrow_turn_up_right,
          groupStart: true,
        ),
        PopoverEntry(
          value: _PhotoAction.report,
          label: 'Report post',
          icon: CupertinoIcons.flag,
        ),
      ],
    );
    if (pick == null || !mounted) return;
    switch (pick) {
      case _PhotoAction.share:
        await showSharePostSheet(context, post);
      case _PhotoAction.copyPost:
        await copyPostLink(context, post);
      case _PhotoAction.copyImage:
        await Clipboard.setData(ClipboardData(text: widget.urls[_index]));
        if (mounted) showInfo(context, 'Image link copied');
      case _PhotoAction.goToPost:
        await Navigator.of(context).push(appRoute(PostDetailScreen(post: post)));
      case _PhotoAction.report:
        await Navigator.of(context).push(
          appRoute(ReportPostScreen(post: post), fullscreen: true),
        );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 16,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const CupertinoActivityIndicator(),
                    errorWidget: (context, url, error) => const Icon(
                      CupertinoIcons.photo,
                      size: 48,
                      color: Color(0xFF71767B),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.urls.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${_index + 1} / ${widget.urls.length}'),
                      ),
                    if (widget.post != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: _moreKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: _openMenu,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.ellipsis,
                            size: 20,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
