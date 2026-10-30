import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/x_icons.dart';

/// Rounded search box like the one at the top of X's Search and Chat tabs.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autocorrect: false,
      onChanged: onChanged,
      cursorColor: p.accent,
      clearButtonMode: OverlayVisibilityMode.editing,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: XIcon(XIcons.search, size: 18, color: p.subtext),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(22),
      ),
      style: TextStyle(color: p.text, fontSize: 16),
      placeholderStyle: TextStyle(color: p.subtext, fontSize: 16),
    );
  }
}
