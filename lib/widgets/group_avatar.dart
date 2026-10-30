import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// Round picture of a group chat (groups have no photo yet): the people icon
/// on a soft circle.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
      child: Icon(CupertinoIcons.person_3_fill, size: size * 0.5, color: p.subtext),
    );
  }
}
