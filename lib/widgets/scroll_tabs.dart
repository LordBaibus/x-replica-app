import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// X's top tab strip: labels you can scroll sideways, the active one bold
/// with a short accent underline. Optionally a "+" at the end adds more tabs.
class ScrollTabs extends StatelessWidget {
  const ScrollTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.onAdd,
    this.dropdownIndex,
    this.onDropdown,
    this.dropdownKey,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  /// Shows a "+" at the end when set.
  final VoidCallback? onAdd;

  /// A tab with a small "⌄" after its label ("For you"). Tapping it while it
  /// is already the active tab calls [onDropdown] (a menu opens under it).
  final int? dropdownIndex;
  final VoidCallback? onDropdown;

  /// Lets the menu find where the dropdown tab is on screen.
  final GlobalKey? dropdownKey;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget tab(int i) {
      final active = i == index;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i == index && i == dropdownIndex && onDropdown != null) {
            onDropdown!();
          } else {
            onChanged(i);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                Row(
                  key: i == dropdownIndex ? dropdownKey : null,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        color: active ? p.text : p.subtext,
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (i == dropdownIndex)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: active ? p.text : p.subtext,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? p.accent : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < labels.length; i++) tab(i),
                if (onAdd != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAdd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Icon(CupertinoIcons.add, size: 22, color: p.text),
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
