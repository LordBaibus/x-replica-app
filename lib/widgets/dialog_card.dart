import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';

/// Centred rounded white card over a dimmed screen: the look of X's
/// schedule / GIF / disclosure dialogs. Built from plain widgets, so it
/// works the same on iOS and Android.
Future<T?> showCardDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 480,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, animation, secondary) {
      final p = AppPalette.of(ctx);
      final media = MediaQuery.of(ctx);
      final inset = media.viewInsets.bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.fromLTRB(16, 16 + media.padding.top, 16, 16 + inset),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: media.size.height - media.padding.top - 32 - inset,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Title row of a card dialog: optional back arrow, title, ✕ on the right.
class CardHeader extends StatelessWidget {
  const CardHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.onBack,
    this.centered = false,
    this.circleClose = false,
    this.divider = true,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final bool centered;

  /// Grey circle behind the ✕ (GIF dialog).
  final bool circleClose;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final close = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: circleClose
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
              child: Icon(AppIcons.close, size: 18, color: p.text),
            )
          : SizedBox(
              width: 40,
              height: 40,
              child: Icon(AppIcons.close, size: 22, color: p.text),
            ),
    );
    final back = onBack == null
        ? (centered ? const SizedBox(width: 40) : const SizedBox.shrink())
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(CupertinoIcons.chevron_left, size: 22, color: p.text),
            ),
          );
    final text = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            back,
            Expanded(child: text),
            close,
          ],
        ),
        if (divider) ...[
          const SizedBox(height: 8),
          Container(height: 1, color: p.border),
        ],
      ],
    );
  }
}

enum DialogPillStyle { solid, grey }

/// Full-width pill at the bottom of a card dialog: black ("Next",
/// "Schedule", "Done") or light grey ("Cancel").
class DialogPillButton extends StatelessWidget {
  const DialogPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = DialogPillStyle.solid,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DialogPillStyle style;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final solid = style == DialogPillStyle.solid;
    final enabled = onPressed != null && !busy;
    final bg = solid ? p.text : p.field;
    final fg = solid ? p.background : p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Container(
          height: 52,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26),
          ),
          child: busy
              ? CupertinoActivityIndicator(color: fg)
              : Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
