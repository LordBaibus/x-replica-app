import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';

/// X-style tab strip: equal-width labels, the active one bold with a short
/// accent underline, and a hairline under the whole strip.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

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
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Center(
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 15),
                        Text(
                          labels[i],
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: i == index ? p.text : p.subtext,
                            fontSize: 15,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Container(
                          height: 4,
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
              ),
            ),
        ],
      ),
    );
  }
}
