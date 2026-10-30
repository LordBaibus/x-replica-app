import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';

/// Header used by secondary pages: back arrow on the left, centred title,
/// optional action on the right (same look as X's History / Creator Studio).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing, this.middle});

  final String title;
  final Widget? trailing;

  /// Replaces the title (e.g. a search field).
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(AppIcons.back, size: 22, color: p.text),
            ),
          ),
          Expanded(
            child: middle ??
                Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
          ),
          SizedBox(
            width: 52,
            height: 52,
            child: trailing == null ? null : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}

/// Row of icon tabs; the selected one also shows its label and a blue bar.
class IconTabs extends StatelessWidget {
  const IconTabs({
    super.key,
    required this.icons,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<IconData> icons;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < icons.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[i],
                          size: 20,
                          color: i == index ? p.text : p.subtext,
                        ),
                        if (i == index) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: i == index
                            ? p.accent
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
