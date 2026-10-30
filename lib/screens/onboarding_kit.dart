import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../widgets/responsive.dart';

/// Building blocks shared by the sign-up screens (email code, birthday, name,
/// username, password, photo, interests ...). They copy the look of X's
/// sign-up flow: a back arrow, a heavy title, a grey subtitle, big borderless
/// input text and one wide black pill button pinned to the bottom.

bool _isDark(AppPalette p) => p.background.computeLuminance() < 0.5;

/// Page layout: top bar (back arrow / trailing action), title, subtitle,
/// [child] in the middle and [bottom] pinned under it (above the keyboard).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.bottom,
    this.showTopBar = true,
    this.titleAlign = TextAlign.start,
    this.leading,
    this.center,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;

  /// Right side of the top bar (e.g. "Skip").
  final Widget? trailing;

  /// Buttons pinned to the bottom.
  final Widget? bottom;

  /// False on pages that start with just the title (no arrow row).
  final bool showTopBar;
  final TextAlign titleAlign;

  /// Replaces the back arrow (e.g. a "Cancel" label).
  final Widget? leading;

  /// Centered in the top bar (e.g. the logo).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTopBar)
                SizedBox(
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (center != null) Center(child: center),
                      Row(
                        children: [
                          if (leading != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: leading,
                            )
                          else if (onBack != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onBack,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: Icon(AppIcons.back, size: 24, color: p.text),
                              ),
                            ),
                          const Spacer(),
                          if (trailing != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: trailing,
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 28),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title!,
                    textAlign: titleAlign,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    subtitle!,
                    textAlign: titleAlign,
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              Expanded(child: child),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wide pill at the bottom of each step. Black (white in dark mode) when
/// active, light grey when disabled; [outlined] gives the "Skip" look and
/// [soft] the light-grey "Skip for now" look.
class BlackButton extends StatelessWidget {
  const BlackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
    this.soft = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dark = _isDark(p);
    final enabled = onPressed != null && !busy;

    Color bg;
    Color fg;
    Border? border;
    if (outlined) {
      bg = const Color(0x00000000);
      fg = p.text;
      border = Border.all(color: p.subtext.withValues(alpha: 0.6), width: 1);
    } else if (soft) {
      bg = dark ? const Color(0xFF202327) : const Color(0xFFF1F1F1);
      fg = p.text;
    } else if (onPressed == null && !busy) {
      bg = dark ? const Color(0xFF2F3336) : const Color(0xFFD2D2D2);
      fg = dark ? const Color(0xFF71767B) : const Color(0xFF7A7570);
    } else {
      bg = p.text;
      fg = p.background;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: border,
        ),
        child: busy
            ? CupertinoActivityIndicator(color: fg)
            : Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Large borderless text input, like the name / username / password entry on
/// X: ~32pt text, blue caret, grey placeholder, optional prefix and suffix.
class BigTextField extends StatelessWidget {
  const BigTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.autofocus = true,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.fontSize = 32,
    this.letterSpacing,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final double fontSize;
  final double? letterSpacing;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscureText,
      textAlign: textAlign,
      cursorColor: p.accent,
      cursorWidth: 2,
      prefix: prefix,
      suffix: suffix,
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(),
      style: TextStyle(
        color: p.text,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: 1.25,
      ),
      placeholderStyle: TextStyle(
        color: p.subtext.withValues(alpha: 0.8),
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        height: 1.25,
      ),
    );
  }
}

/// Outlined rounded chip used for the interests and username suggestions.
class OutlineChip extends StatelessWidget {
  const OutlineChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;

  /// Smaller padding / text (username suggestions).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = selected ? p.background : p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 14,
          vertical: compact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          color: selected ? p.text : const Color(0x00000000),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? p.text : p.subtext.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 9),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small red message under an input.
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: TextStyle(color: p.danger, fontSize: 14, height: 1.3),
      ),
    );
  }
}
