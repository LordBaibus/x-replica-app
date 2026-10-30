import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// One row of a [showPopoverMenu].
class PopoverEntry<T> {
  const PopoverEntry({
    required this.value,
    required this.label,
    required this.icon,
    this.checked = false,
    this.groupStart = false,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Shows a check mark on the left (the current choice).
  final bool checked;

  /// Draws a thick separator band above this row (starts a new group).
  final bool groupStart;
}

/// Small menu anchored under the widget that carries [anchor] (like the
/// "All ▾" filter in Chat). Resolves to the chosen value, or null.
Future<T?> showPopoverMenu<T>(
  BuildContext context, {
  required GlobalKey anchor,
  required List<PopoverEntry<T>> entries,
  double width = 250,
}) {
  final box = anchor.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return Future<T?>.value(null);
  final topLeft = box.localToGlobal(Offset.zero);
  final top = topLeft.dy + box.size.height + 6;
  final right = topLeft.dx + box.size.width;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (ctx, _, __) {
      final p = AppPalette.of(ctx);
      final screenW = MediaQuery.sizeOf(ctx).width;
      final w = width > screenW - 16 ? screenW - 16 : width;
      var left = right - w;
      if (left < 8) left = 8;

      final rows = <Widget>[];
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        if (i > 0) {
          rows.add(
            e.groupStart
                ? Container(height: 8, color: p.surface)
                : Container(height: 0.5, color: p.border),
          );
        }
        rows.add(
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(e.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: e.checked
                        ? Icon(CupertinoIcons.checkmark_alt,
                            size: 18, color: p.text)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      e.label,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Icon(e.icon, size: 20, color: p.text),
                ],
              ),
            ),
          ),
        );
      }

      return DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              width: w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: rows),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
