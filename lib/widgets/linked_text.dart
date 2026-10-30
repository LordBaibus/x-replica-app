import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../screens/profile_view.dart';
import '../screens/search_screen.dart';
import '../services/api.dart';

/// Text whose @mentions and #hashtags are tappable links in the accent colour.
///
/// - `@name` opens that person's profile (or says the account does not exist).
/// - `#tag` opens search for the hashtag.
class LinkedText extends StatefulWidget {
  const LinkedText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
    this.linkColor,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Defaults to the accent colour of the theme.
  final Color? linkColor;

  /// `@name` (not part of an e-mail address) or `#tag`.
  static final RegExp tokens =
      RegExp(r'((?<![A-Za-z0-9_])@[A-Za-z0-9_]{1,15}|#[A-Za-z0-9_]+)');

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Future<void> _openMention(String name) async {
    final nav = Navigator.of(context);
    final ctx = context;
    try {
      final id = await Api.profileIdByUsername(name);
      if (!mounted) return;
      if (id == null) {
        showInfo(ctx, 'There is no account named @$name.');
        return;
      }
      nav.push(appRoute(ProfileScreen(userId: id)));
    } catch (e) {
      if (mounted) showError(ctx, e);
    }
  }

  void _openTag(String tag) {
    Navigator.of(context).push(appRoute(SearchScreen(initialQuery: tag)));
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final text = widget.text;
    final color = widget.linkColor ?? AppPalette.of(context).accent;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in LinkedText.tokens.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final token = m.group(0)!;
      final rec = TapGestureRecognizer()
        ..onTap = token.startsWith('@')
            ? () => _openMention(token.substring(1))
            : () => _openTag(token);
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: token,
        style: TextStyle(color: color),
        recognizer: rec,
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
