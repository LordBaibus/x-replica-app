import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';
import '../models/models.dart';
import 'avatar.dart';

/// Header of the Chat tab: my avatar (opens the drawer) on the left, "Chat"
/// centred, optional actions on the right.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.me,
    required this.onAvatar,
    this.trailing,
  });

  final Profile? me;
  final VoidCallback onAvatar;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'Chat',
              style: TextStyle(
                color: p.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAvatar,
                child: Avatar(
                  url: me?.avatarUrl,
                  name: me?.name ?? '',
                  size: 32,
                ),
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}
