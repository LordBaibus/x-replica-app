import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// Screen rectangle of the widget that owns [context] (an anchor for a popup).
Rect rectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _PopupLayout extends SingleChildLayoutDelegate {
  _PopupLayout({
    required this.anchor,
    required this.alignRight,
    required this.preferAbove,
    required this.padding,
  });

  final Rect anchor;
  final bool alignRight;
  final bool preferAbove;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth - 24,
        maxHeight: constraints.maxHeight - padding.vertical - 24,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = alignRight ? anchor.right - childSize.width : anchor.left;
    final maxLeft = size.width - childSize.width - 12;
    if (left > maxLeft) left = maxLeft;
    if (left < 12) left = 12;

    final topLimit = padding.top + 8;
    final bottomLimit = size.height - padding.bottom - 8;
    final below = anchor.bottom + 6;
    final above = anchor.top - 6 - childSize.height;
    final fitsBelow = below + childSize.height <= bottomLimit;
    final fitsAbove = above >= topLimit;

    double top;
    if (preferAbove) {
      top = fitsAbove ? above : (fitsBelow ? below : topLimit);
    } else {
      top = fitsBelow ? below : (fitsAbove ? above : topLimit);
    }
    if (top + childSize.height > bottomLimit) {
      top = bottomLimit - childSize.height;
    }
    if (top < topLimit) top = topLimit;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PopupLayout old) =>
      old.anchor != anchor ||
      old.alignRight != alignRight ||
      old.preferAbove != preferAbove ||
      old.padding != padding;
}

/// A card that floats next to [anchor] (the tapped button) and closes when
/// the screen around it is tapped. It flips above the anchor when there is no
/// room below. Resolves to whatever the card pops with.
Future<T?> showAnchoredPopup<T>(
  BuildContext context, {
  required Rect anchor,
  required double width,
  required WidgetBuilder builder,
  bool alignRight = true,
  bool preferAbove = false,
  bool dim = false,
  double radius = 18,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: dim ? const Color(0x59000000) : const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 130),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, __) {
      final p = AppPalette.of(ctx);
      final media = MediaQuery.of(ctx);
      final dark = p.background.computeLuminance() < 0.5;
      return DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: CustomSingleChildLayout(
          delegate: _PopupLayout(
            anchor: anchor,
            alignRight: alignRight,
            preferAbove: preferAbove,
            padding: media.padding,
          ),
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? p.surface : p.background,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 26,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// One row of a [showMenuAt] menu: label on the left, icon on the right.
class MenuRow<T> {
  const MenuRow({
    required this.value,
    required this.label,
    this.icon,
    this.iconWidget,
    this.destructive = false,
    this.checked = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Replaces [icon] when the symbol is not in the icon font.
  final Widget? iconWidget;
  final bool destructive;

  /// Shows a check mark on the left (the current choice).
  final bool checked;
}

/// X-style popup menu next to [anchor].
Future<T?> showMenuAt<T>(
  BuildContext context, {
  required Rect anchor,
  required List<MenuRow<T>> rows,
  double width = 290,
  bool alignRight = true,
  bool preferAbove = false,
  bool dim = false,
  bool leadingIcons = false,
}) {
  return showAnchoredPopup<T>(
    context,
    anchor: anchor,
    width: width,
    alignRight: alignRight,
    preferAbove: preferAbove,
    dim: dim,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      final children = <Widget>[];
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        if (i > 0) children.add(Container(height: 0.5, color: p.border));
        final color = r.destructive ? p.danger : p.text;
        final icon = r.iconWidget ??
            (r.icon == null ? null : Icon(r.icon, size: 22, color: color));
        children.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(r.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  if (leadingIcons && icon != null) ...[
                    icon,
                    const SizedBox(width: 16),
                  ],
                  if (r.checked)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 18,
                        color: p.text,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        height: 1.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (!leadingIcons && icon != null) ...[
                    const SizedBox(width: 12),
                    icon,
                  ],
                ],
              ),
            ),
          ),
        );
      }
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
    },
  );
}
