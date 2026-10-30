import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'avatar.dart';

/// The header row used on every main tab: my avatar on the left (opens the
/// side drawer), something in the middle, an optional action on the right.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.me,
    required this.onAvatar,
    required this.middle,
    this.trailing,
  });

  final Profile? me;
  final VoidCallback onAvatar;
  final Widget middle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAvatar,
              child: Avatar(
                url: me?.avatarUrl,
                name: me?.name ?? '',
                size: 32,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: middle,
              ),
            ),
            SizedBox(
              width: 32,
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}
