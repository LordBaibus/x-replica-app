import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';

/// Text field used across the app. Looks the same on iOS and Android: thin
/// outlined box that turns accent-blue (not Material purple) when focused,
/// no character counter, optional leading icon.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.prefixIcon,
    this.suffix,
    this.textAlign = TextAlign.start,
    this.style,
    this.padding,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;

  /// Hard limit on characters (no counter is shown).
  final int? maxLength;
  final bool obscureText;
  final bool autocorrect;
  final bool autofocus;

  /// Icon or small widget shown inside the box before the text.
  final Widget? prefixIcon;

  /// Widget shown inside the box after the text (e.g. a show/hide eye).
  final Widget? suffix;
  final TextAlign textAlign;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final focused = _focus.hasFocus;
    final hasPrefix = widget.prefixIcon != null;

    return CupertinoTextField(
      controller: widget.controller,
      focusNode: _focus,
      placeholder: widget.placeholder,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      minLines: widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      cursorColor: p.accent,
      inputFormatters: [
        ...?widget.inputFormatters,
        if (widget.maxLength != null)
          LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      prefix: hasPrefix
          ? Padding(
              padding: const EdgeInsets.only(left: 14),
              child: widget.prefixIcon,
            )
          : null,
      suffix: widget.suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 14),
              child: widget.suffix,
            )
          : null,
      padding: widget.padding ??
          EdgeInsets.symmetric(horizontal: hasPrefix ? 12 : 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: focused ? p.accent : p.subtext.withValues(alpha: 0.4),
          width: focused ? 2 : 1,
        ),
      ),
      style: widget.style ?? TextStyle(color: p.text, fontSize: 17),
      placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
    );
  }
}

/// Password input with a tappable eye that shows / hides the text.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.controller,
    this.placeholder,
    this.textInputAction,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppTextField(
      controller: widget.controller,
      placeholder: widget.placeholder,
      obscureText: _hide,
      autocorrect: false,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      prefixIcon: Icon(AppIcons.lock, size: 18, color: p.subtext),
      suffix: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _hide = !_hide),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
          child: Icon(
            _hide ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            size: 22,
            color: p.subtext,
          ),
        ),
      ),
    );
  }
}
