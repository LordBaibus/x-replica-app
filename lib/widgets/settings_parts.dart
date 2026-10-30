import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/user_prefs.dart';
import 'settings_kit.dart';

/// Green of X's switches.
const Color kSwitchOn = Color(0xFF00BA7C);

/// "lo********@gmail.com" – used where the app shows an email it just
/// sent a code to.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final name = email.substring(0, at);
  final shown = name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
  final stars = (name.length - shown.length).clamp(2, 8);
  return '$shown${'*' * stars}${email.substring(at)}';
}

/// What the "Learn more" links do: this replica has no help pages.
void showLearnMore(BuildContext context) => notify(
      context,
      title: 'Learn more',
      message: '${AppConfig.appName} is a university project, so it has no '
          'help-centre pages. The link is shown so the layout matches.',
    );

/// Switch in X's green.
class XSwitch extends StatelessWidget {
  const XSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: kSwitchOn,
        inactiveTrackColor: const Color(0xFF8E9399),
      );
}

/// Grey paragraph with an optional blue link in it ("… Learn more").
class LinkText extends StatefulWidget {
  const LinkText(
    this.text, {
    super.key,
    this.link,
    this.onLink,
    this.after = '',
    this.fontSize = 15,
    this.color,
    this.align = TextAlign.start,
  });

  final String text;
  final String? link;
  final VoidCallback? onLink;
  final String after;
  final double fontSize;
  final Color? color;
  final TextAlign align;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () {
      final cb = widget.onLink;
      if (cb != null) {
        cb();
      } else {
        showLearnMore(context);
      }
    };

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: widget.color ?? p.subtext,
          fontSize: widget.fontSize,
          height: 1.3,
        ),
        children: [
          TextSpan(text: widget.text),
          if (widget.link != null)
            TextSpan(
              text: widget.link,
              style: TextStyle(color: p.accent),
              recognizer: _tap,
            ),
          if (widget.after.isNotEmpty) TextSpan(text: widget.after),
        ],
      ),
      textAlign: widget.align,
    );
  }
}

/// Bold title + grey description + switch.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.link,
    this.onLink,
    this.after = '',
    this.bold = true,
    this.titleSize = 17,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;
  final String? link;
  final VoidCallback? onLink;
  final String after;
  final bool bold;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: p.text,
                      fontSize: titleSize,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                XSwitch(value: value, onChanged: onChanged),
              ],
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 70),
                child: LinkText(
                  description!,
                  link: link,
                  onLink: onLink,
                  after: after,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bold title with the current value on the right and a chevron (or ⋮).
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.title,
    this.value,
    this.description,
    this.icon,
    this.onTap,
    this.menu = false,
    this.chevron = true,
    this.danger = false,
    this.dim = false,
  });

  final String title;
  final String? value;
  final String? description;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Shows ⋮ instead of the chevron (rows that open a small menu).
  final bool menu;
  final bool chevron;
  final bool danger;

  /// Greyed out (row that cannot be used right now).
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: dim ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null)
                      SizedBox(
                        width: 40,
                        child: Icon(
                          icon,
                          size: 24,
                          color: danger ? p.danger : p.text,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: danger ? p.danger : p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        value!,
                        style: TextStyle(color: p.subtext, fontSize: 17),
                      ),
                    ],
                    if (menu) ...[
                      const SizedBox(width: 12),
                      Icon(
                        CupertinoIcons.ellipsis_vertical,
                        size: 18,
                        color: p.subtext,
                      ),
                    ] else if (chevron) ...[
                      const SizedBox(width: 10),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 16,
                        color: p.subtext.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
                if (description != null)
                  Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      right: 30,
                      left: icon != null ? 40 : 0,
                    ),
                    child: Text(
                      description!,
                      style: TextStyle(
                        color: p.subtext,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row with a blue check circle on the right when selected (country list,
/// profile labels).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.bold = true,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration:
                      BoxDecoration(color: p.accent, shape: BoxShape.circle),
                  child: const Icon(
                    CupertinoIcons.checkmark,
                    size: 14,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row with a round radio button on the right.
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.bold = true,
    this.padded = true,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final bool bold;

  /// False inside a dialog (it has its own padding).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.accent : p.subtext.withValues(alpha: 0.6),
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
    return padded ? SettingsColumn(child: row) : row;
  }
}

/// Centred bold text button ("Log out", "Remove all contacts" ...).
class CenterAction extends StatelessWidget {
  const CenterAction({
    super.key,
    required this.text,
    required this.onTap,
    this.color,
    this.description,
    this.topPadding = 22,
  });

  final String text;
  final VoidCallback onTap;
  final Color? color;
  final String? description;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding, bottom: 14),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color ?? p.danger,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          if (description != null)
            Text(
              description!,
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
            ),
        ],
      ),
    );
  }
}

enum PillKind { black, blue, teal, grey }

/// Rounded button used on settings pages ("Continue", "Confirm", "Got it").
class PillAction extends StatelessWidget {
  const PillAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = PillKind.black,
    this.fullWidth = false,
    this.busy = false,
    this.height = 48,
    this.horizontal = 30,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillKind kind;
  final bool fullWidth;
  final bool busy;
  final double height;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Color bg;
    final Color fg;
    switch (kind) {
      case PillKind.black:
        bg = p.text;
        fg = p.background;
      case PillKind.blue:
        bg = p.accent;
        fg = const Color(0xFFFFFFFF);
      case PillKind.teal:
        bg = const Color(0xFF00A98F);
        fg = const Color(0xFFFFFFFF);
      case PillKind.grey:
        bg = p.subtext.withValues(alpha: 0.28);
        fg = p.text.withValues(alpha: 0.7);
    }
    final enabled = onPressed != null && !busy;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: onPressed == null && kind != PillKind.grey ? 0.5 : 1,
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? CupertinoActivityIndicator(color: fg)
                  : Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 17,
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

/// "Done" at the top right of a page: grey until [enabled].
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled && !busy ? onPressed : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: enabled ? p.text : p.subtext.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        // A Row (not Container.alignment) so the pill hugs its label instead
        // of stretching over the whole header.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            busy
                ? CupertinoActivityIndicator(color: p.background)
                : Text(
                    label,
                    style: TextStyle(
                      color: enabled ? p.background : p.subtext,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Centred icon + bold headline + grey sentence ("No archived chats").
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.text,
    this.icon,
    this.action,
    this.link,
    this.onLink,
  });

  final String title;
  final String? text;
  final IconData? icon;
  final Widget? action;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 80),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 56, color: p.text),
                const SizedBox(height: 18),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (text != null) ...[
                const SizedBox(height: 10),
                LinkText(
                  text!,
                  link: link,
                  onLink: onLink,
                  fontSize: 17,
                  align: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 24),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice of [pickOption].
class PickItem<T> {
  const PickItem(this.label, this.value);

  final String label;
  final T value;
}

/// Bottom action sheet with a list of choices; resolves to the picked value
/// (null when dismissed). The current choice gets a ✓.
Future<T?> pickOption<T>(
  BuildContext context, {
  String? title,
  required List<PickItem<T>> items,
  T? selected,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 17,
          decoration: TextDecoration.none,
        ),
        child: CupertinoActionSheet(
          title: title == null ? null : Text(title),
          actions: [
            for (final it in items)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(it.value),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (it.value == selected) ...[
                      Icon(CupertinoIcons.checkmark_alt,
                          size: 18, color: p.accent),
                      const SizedBox(width: 8),
                    ],
                    Flexible(child: Text(it.label)),
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Data-driven pages: a list of items that read and write UserPrefs.
// ---------------------------------------------------------------------------

abstract class PrefItem {
  const PrefItem();
}

/// Grey paragraph under the title.
class PIntro extends PrefItem {
  const PIntro(this.text, {this.link, this.onLink, this.after = ''});

  final String text;
  final String? link;
  final void Function(BuildContext context)? onLink;
  final String after;
}

/// Full-width line + bold heading.
class PSection extends PrefItem {
  const PSection(this.title);

  final String title;
}

/// Just a full-width line.
class PDivider extends PrefItem {
  const PDivider();
}

class PGap extends PrefItem {
  const PGap([this.height = 12]);

  final double height;
}

/// Small grey paragraph (footnote).
class PNote extends PrefItem {
  const PNote(this.text, {this.link, this.onLink});

  final String text;
  final String? link;
  final void Function(BuildContext context)? onLink;
}

/// Switch stored under [prefKey].
class PSwitch extends PrefItem {
  const PSwitch(
    this.prefKey,
    this.title, {
    this.desc,
    this.link,
    this.onLink,
    this.after = '',
    this.def = false,
    this.guard,
    this.bold = true,
  });

  final String prefKey;
  final String title;
  final String? desc;
  final String? link;
  final void Function(BuildContext context)? onLink;
  final String after;
  final bool def;
  final bool bold;

  /// Asked before the value changes; returning false cancels the change.
  final Future<bool> Function(BuildContext context, bool next)? guard;
}

/// Row that opens a list of choices; the choice (a String) is stored under
/// [prefKey].
class PValue extends PrefItem {
  const PValue(
    this.prefKey,
    this.title, {
    required this.options,
    required this.def,
    this.desc,
    this.sheetTitle,
    this.menu = false,
    this.icon,
  });

  final String prefKey;
  final String title;
  final List<String> options;
  final String def;
  final String? desc;
  final String? sheetTitle;
  final bool menu;
  final IconData? icon;
}

/// Round radio; all radios of one list share [prefKey].
class PRadio extends PrefItem {
  const PRadio(this.prefKey, this.title, this.value, {this.isDefault = false});

  final String prefKey;
  final String title;
  final String value;

  /// Selected while nothing was stored yet.
  final bool isDefault;
}

/// Row that opens another page (or does something).
class PNav extends PrefItem {
  const PNav(
    this.title, {
    this.desc,
    this.value,
    this.icon,
    this.open,
    this.menu = false,
  });

  final String title;
  final String? desc;
  final String? value;
  final IconData? icon;
  final bool menu;
  final void Function(BuildContext context)? open;
}

/// Centred bold button (red by default).
class PAction extends PrefItem {
  const PAction(this.text, {this.desc, this.color, this.run});

  final String text;
  final String? desc;
  final Color? color;
  final Future<void> Function(BuildContext context)? run;
}

/// A whole settings page built from [items]. Switches and choices are saved
/// by [UserPrefs].
class PrefsPage extends StatefulWidget {
  const PrefsPage({
    super.key,
    required this.title,
    required this.items,
    this.showHandle = true,
    this.headerDivider = false,
  });

  final String title;
  final List<PrefItem> items;
  final bool showHandle;
  final bool headerDivider;

  @override
  State<PrefsPage> createState() => _PrefsPageState();
}

class _PrefsPageState extends State<PrefsPage> {
  UserPrefs get _prefs => UserPrefs.instance;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_changed);
  }

  @override
  void dispose() {
    _prefs.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _notAvailable(String title) => notify(
        context,
        title: title,
        message: 'This setting is not available in this version of '
            '${AppConfig.appName}. The page is shown so the layout matches.',
      );

  Widget _build(BuildContext context, PrefItem item) {
    if (item is PIntro) {
      return SettingsColumn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
          child: LinkText(
            item.text,
            link: item.link,
            onLink: item.onLink == null ? null : () => item.onLink!(context),
            after: item.after,
            fontSize: 16,
          ),
        ),
      );
    }
    if (item is PSection) {
      return Column(
        children: [
          const SettingsDivider(),
          SettingsSectionTitle(item.title),
        ],
      );
    }
    if (item is PDivider) return const SettingsDivider();
    if (item is PGap) return SizedBox(height: item.height);
    if (item is PNote) {
      return SettingsColumn(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LinkText(
            item.text,
            link: item.link,
            onLink: item.onLink == null ? null : () => item.onLink!(context),
          ),
        ),
      );
    }
    if (item is PSwitch) {
      return SwitchRow(
        title: item.title,
        description: item.desc,
        link: item.link,
        onLink: item.onLink == null ? null : () => item.onLink!(context),
        after: item.after,
        bold: item.bold,
        value: _prefs.flag(item.prefKey, item.def),
        onChanged: (v) async {
          final guard = item.guard;
          if (guard != null && !await guard(context, v)) return;
          await _prefs.set(item.prefKey, v);
        },
      );
    }
    if (item is PValue) {
      final current = _prefs.text(item.prefKey, item.def);
      return ValueRow(
        title: item.title,
        value: current,
        description: item.desc,
        menu: item.menu,
        icon: item.icon,
        onTap: () async {
          final picked = await pickOption<String>(
            context,
            title: item.sheetTitle ?? item.title,
            items: [for (final o in item.options) PickItem(o, o)],
            selected: current,
          );
          if (picked != null) await _prefs.set(item.prefKey, picked);
        },
      );
    }
    if (item is PRadio) {
      final stored = _prefs.text(item.prefKey);
      final selected =
          stored.isEmpty ? item.isDefault : stored == item.value;
      return RadioRow(
        title: item.title,
        selected: selected,
        onTap: () => _prefs.set(item.prefKey, item.value),
      );
    }
    if (item is PNav) {
      return ValueRow(
        title: item.title,
        value: item.value,
        description: item.desc,
        icon: item.icon,
        menu: item.menu,
        onTap: () {
          final open = item.open;
          if (open != null) {
            open(context);
          } else {
            _notAvailable(item.title);
          }
        },
      );
    }
    if (item is PAction) {
      return CenterAction(
        text: item.text,
        color: item.color,
        description: item.desc,
        onTap: () {
          final run = item.run;
          if (run != null) {
            run(context);
          } else {
            _notAvailable(item.text);
          }
        },
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: widget.title,
      showHandle: widget.showHandle,
      headerDivider: widget.headerDivider,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [for (final i in widget.items) _build(context, i)],
      ),
    );
  }
}
