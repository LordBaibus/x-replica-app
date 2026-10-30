import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../services/api.dart';
import 'plain_scaffold.dart';
import 'responsive.dart';

/// "@username" shown under every settings title. Loaded once by the first
/// settings page and reused by the pages opened from it.
class SettingsHandle {
  SettingsHandle._();

  static String? value;

  static Future<void> load() async {
    if (value != null) return;
    await refresh();
  }

  /// Reads the username again (after it was changed).
  static Future<void> refresh() async {
    try {
      final me = await Api.getProfile(Api.uid);
      value = '@${me.username}';
    } catch (_) {}
  }
}

/// Page frame used by every settings page: back arrow, centred title with
/// the "@username" under it, then the content.
///
/// [action] is a button at the right of the header ("Done"), [closeIcon]
/// swaps the back arrow for an ✕ (full-screen pages), [headerDivider] draws a
/// thin line under the header.
class SettingsFrame extends StatelessWidget {
  const SettingsFrame({
    super.key,
    required this.title,
    required this.child,
    this.showHandle = true,
    this.action,
    this.closeIcon = false,
    this.headerDivider = false,
    this.onBack,
  });

  final String title;
  final Widget child;
  final bool showHandle;
  final Widget? action;
  final bool closeIcon;
  final bool headerDivider;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final handle = SettingsHandle.value;
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showHandle && handle != null)
                          Text(
                            handle,
                            style: TextStyle(color: p.subtext, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          closeIcon
                              ? CupertinoIcons.xmark
                              : CupertinoIcons.arrow_left,
                          size: closeIcon ? 22 : 24,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                  if (action != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: action,
                      ),
                    ),
                ],
              ),
            ),
            if (headerDivider) const SettingsDivider(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Keeps settings content in a centred column (like X on tablets) while
/// dividers can still span the whole width.
class SettingsColumn extends StatelessWidget {
  const SettingsColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: 680,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    );
  }
}

/// Full-width thin line between sections.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppPalette.of(context).border);
}

/// Bold section heading ("Your X activity").
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
          child: Text(
            title,
            style: TextStyle(
              color: p.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey explanatory paragraph under the page title.
class SettingsIntro extends StatelessWidget {
  const SettingsIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
        child: Text(
          text,
          style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
        ),
      ),
    );
  }
}

/// A tappable settings row: optional icon, bold title, grey description and
/// a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.onTap,
    this.trailing,
    this.chevron = true,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsColumn(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: description == null ? 14 : 15,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null)
                SizedBox(
                  width: 38,
                  child: Icon(icon, size: 22, color: p.text),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          description!,
                          style: TextStyle(
                            color: p.subtext,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: 12),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: p.subtext.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
