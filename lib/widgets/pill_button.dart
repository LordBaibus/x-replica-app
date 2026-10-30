import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';

enum PillStyle {
  /// Solid accent (blue) button.
  primary,

  /// High-contrast button: light pill in dark mode, dark pill in light mode.
  /// Used for "Follow" and "Log in", like the original.
  inverse,

  /// Transparent with a thin border ("Following", "Edit profile").
  outline,
}

/// Fully rounded button. With only an [icon] it is a circle.
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.style = PillStyle.outline,
    this.height = 34,
    this.fontSize = 14,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PillStyle style;
  final double height;
  final double fontSize;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final Color bg;
    final Color fg;
    Color? border;
    switch (widget.style) {
      case PillStyle.primary:
        bg = p.accent;
        fg = const Color(0xFFFFFFFF);
      case PillStyle.inverse:
        bg = p.text;
        fg = p.background;
      case PillStyle.outline:
        bg = const Color(0x00000000);
        fg = p.text;
        border = p.subtext.withValues(alpha: 0.55);
    }

    final enabled = widget.onPressed != null;
    final iconOnly = widget.label == null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 90),
        opacity: !enabled ? 0.5 : (_pressed ? 0.75 : 1),
        child: Container(
          height: widget.height,
          width: iconOnly ? widget.height : null,
          padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: border == null ? null : Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: widget.fontSize + 4, color: fg),
              if (widget.icon != null && widget.label != null)
                const SizedBox(width: 8),
              if (widget.label != null)
                Text(
                  widget.label!,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
