import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/x_icons.dart';

/// One row of an [showXMenuDialog].
class XMenuItem {
  const XMenuItem({required this.icon, required this.label});

  final List<XShape> icon;
  final String label;
}

TextStyle _ts(Color c, double size, {FontWeight w = FontWeight.w400}) =>
    TextStyle(
      color: c,
      fontSize: size,
      fontWeight: w,
      height: 1.2,
      decoration: TextDecoration.none,
    );

/// The rounded dark card X uses for its small dialogs.
Future<T?> _card<T>(
  BuildContext context,
  Widget Function(BuildContext ctx, AppPalette p) builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0xB3000000),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, __) {
      final p = AppPalette.of(ctx);
      final w = MediaQuery.sizeOf(ctx).width;
      return Center(
        child: Container(
          width: (w * 0.82).clamp(280.0, 520.0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: DefaultTextStyle(
            style: _ts(p.text, 17),
            child: builder(ctx, p),
          ),
        ),
      );
    },
  );
}

Widget _pillButton(
  Color bg,
  Color fg,
  String label,
  VoidCallback onTap,
) =>
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Text(label, style: _ts(fg, 17, w: FontWeight.w700)),
      ),
    );

/// A small card with a few icon + label rows and a Cancel pill (the
/// "Spotlight Community on your profile" and the share menus of X).
/// Resolves to the index of the tapped row, or null.
Future<int?> showXMenuDialog(
  BuildContext context, {
  required List<XMenuItem> items,
}) {
  return _card<int>(
    context,
    (ctx, p) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  XIcon(items[i].icon, size: 24, color: p.text),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(items[i].label,
                        style: _ts(p.text, 18, w: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        _pillButton(p.field, p.text, 'Cancel', () => Navigator.of(ctx).pop()),
      ],
    ),
  );
}

/// What the Trending / New / Popular and My posts / My replies options of a
/// Community timeline stand for.
enum CommunityTimeline { trending, newest, popular, myPosts, myReplies }

extension CommunityTimelineLabel on CommunityTimeline {
  String get label => switch (this) {
        CommunityTimeline.trending => 'Trending',
        CommunityTimeline.newest => 'New',
        CommunityTimeline.popular => 'Popular',
        CommunityTimeline.myPosts => 'My posts',
        CommunityTimeline.myReplies => 'My replies',
      };
}

/// "Timeline options": Sort (Trending, New, Popular) and View (My posts,
/// My replies), one radio choice.
Future<CommunityTimeline?> showTimelineOptions(
  BuildContext context, {
  required CommunityTimeline current,
}) {
  return _card<CommunityTimeline>(
    context,
    (ctx, p) {
      Widget radio(bool on) => Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: on ? p.text : p.subtext,
                width: on ? 2 : 1.5,
              ),
            ),
            child: on
                ? Container(
                    width: 14,
                    height: 14,
                    decoration:
                        BoxDecoration(color: p.text, shape: BoxShape.circle),
                  )
                : null,
          );

      Widget row(List<XShape> icon, CommunityTimeline t) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  XIcon(icon, size: 26, color: p.text),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(t.label,
                        style: _ts(p.text, 19, w: FontWeight.w500)),
                  ),
                  radio(t == current),
                ],
              ),
            ),
          );

      Widget heading(String s) => Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(s, style: _ts(p.subtext, 16)),
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Timeline options',
                    style: _ts(p.text, 22, w: FontWeight.w700)),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: Icon(CupertinoIcons.xmark, size: 24, color: p.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 0.5, color: p.border),
          heading('Sort'),
          row(XIcons.rocket, CommunityTimeline.trending),
          row(XIcons.sparkleOutline, CommunityTimeline.newest),
          row(XIcons.like, CommunityTimeline.popular),
          heading('View'),
          row(XIcons.person, CommunityTimeline.myPosts),
          row(XIcons.person, CommunityTimeline.myReplies),
        ],
      );
    },
  );
}

/// "Be the first to know": shown after joining and from the bell button.
/// Resolves to {spaces, pinned} when saved, or null when dismissed.
Future<({bool spaces, bool pinned})?> showCommunityNotifyDialog(
  BuildContext context, {
  required bool spaces,
  required bool pinned,
}) {
  var s = spaces;
  var pn = pinned;
  return _card<({bool spaces, bool pinned})>(
    context,
    (ctx, p) => StatefulBuilder(
      builder: (ctx, setState) {
        Widget box(bool on) => Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? p.text : const Color(0x00000000),
                borderRadius: BorderRadius.circular(7),
                border: on ? null : Border.all(color: p.subtext, width: 1.5),
              ),
              child: on
                  ? Icon(CupertinoIcons.checkmark_alt,
                      size: 20, color: p.background)
                  : null,
            );

        Widget row(String label, bool on, VoidCallback tap) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: _ts(p.text, 18, w: FontWeight.w600)),
                    ),
                    box(on),
                  ],
                ),
              ),
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Be the first to know',
                textAlign: TextAlign.center,
                style: _ts(p.text, 22, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Get notifications for the content you care about.',
                textAlign: TextAlign.center, style: _ts(p.subtext, 15)),
            const SizedBox(height: 14),
            row('Community Spaces (audio chats)', s,
                () => setState(() => s = !s)),
            row('Pinned', pn, () => setState(() => pn = !pn)),
            const SizedBox(height: 14),
            _pillButton(
              p.text,
              p.background,
              'Save',
              () => Navigator.of(ctx).pop((spaces: s, pinned: pn)),
            ),
          ],
        );
      },
    ),
  );
}
