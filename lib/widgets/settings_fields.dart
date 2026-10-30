import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/app_palette.dart';
import 'settings_kit.dart';
import 'settings_parts.dart';

/// Bold label above a text field that only has an underline (X's account
/// forms: "New", "Current password" ...). [label] may be null.
class UnderlineField extends StatefulWidget {
  const UnderlineField({
    super.key,
    this.label,
    this.controller,
    this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.errorText,
    this.textInputAction,
    this.inputFormatters,
    this.fontSize = 18,
  });

  final String? label;
  final TextEditingController? controller;
  final String? placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool autofocus;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Widget before the text (flag button on the phone page).
  final Widget? prefix;
  final String? errorText;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final double fontSize;

  @override
  State<UnderlineField> createState() => _UnderlineFieldState();
}

class _UnderlineFieldState extends State<UnderlineField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasError = widget.errorText != null;
    final lineColor = hasError
        ? p.danger
        : (_focus.hasFocus ? p.accent : p.subtext.withValues(alpha: 0.6));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              widget.label!,
              style: TextStyle(
                color: p.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: lineColor, width: _focus.hasFocus ? 2 : 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null) widget.prefix!,
              Expanded(
                child: CupertinoTextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  placeholder: widget.placeholder,
                  obscureText: widget.obscure,
                  autocorrect: false,
                  enableSuggestions: !widget.obscure,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  cursorColor: p.accent,
                  maxLines: 1,
                  inputFormatters: [
                    ...?widget.inputFormatters,
                    if (widget.maxLength != null)
                      LengthLimitingTextInputFormatter(widget.maxLength),
                  ],
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: null,
                  style: TextStyle(color: p.text, fontSize: widget.fontSize),
                  placeholderStyle:
                      TextStyle(color: p.subtext, fontSize: widget.fontSize),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.errorText!,
              style: TextStyle(color: p.danger, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

/// Six boxes for a verification code. A transparent text field underneath
/// does the typing, so the number pad, paste and delete all work.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = widget.controller.text;
    final active = text.length.clamp(0, widget.length - 1);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 2,
            height: 2,
            child: Opacity(
              opacity: 0,
              child: CupertinoTextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: widget.onChanged,
                decoration: null,
                padding: EdgeInsets.zero,
                style: const TextStyle(color: Color(0x00000000), fontSize: 1),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  width: 42,
                  height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: widget.hasError
                            ? p.danger
                            : (_focus.hasFocus && i == active
                                ? p.accent
                                : p.subtext.withValues(alpha: 0.6)),
                        width: _focus.hasFocus && i == active ? 2.5 : 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    i < text.length ? text[i] : '',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top-of-page heading used by the "Add your phone number" style pages.
class BigHeading extends StatelessWidget {
  const BigHeading(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: p.text,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
  }
}

/// Settings page body that scrolls and keeps the content in the centred
/// column (forms such as Update username).
class FormBody extends StatelessWidget {
  const FormBody({super.key, required this.children, this.bottom});

  final List<Widget> children;

  /// Pinned under the scrolling content (buttons).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              for (final c in children) SettingsColumn(child: c),
            ],
          ),
        ),
        if (bottom != null) SettingsColumn(child: bottom!),
      ],
    );
  }
}

/// Page that only shows an empty state ("No archived chats").
class EmptyPage extends StatelessWidget {
  const EmptyPage({
    super.key,
    required this.title,
    required this.heading,
    this.text,
    this.link,
    this.showHandle = true,
    this.headerDivider = false,
    this.icon,
  });

  final String title;
  final String heading;
  final String? text;
  final String? link;
  final bool showHandle;
  final bool headerDivider;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: title,
      showHandle: showHandle,
      headerDivider: headerDivider,
      child: EmptyStateView(
        title: heading,
        text: text,
        link: link,
        icon: icon,
      ),
    );
  }
}
