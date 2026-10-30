import 'package:flutter/widgets.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../models/models.dart';
import 'avatar.dart';
import 'badges.dart';
import 'pill_button.dart';
import 'state_views.dart';

/// A row for a user in search results: avatar, names, bio and a Follow button.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.profile,
    required this.onTap,
    this.onToggleFollow,
    this.contextLabel,
  });

  final Profile profile;
  final VoidCallback onTap;

  /// When null (e.g. while picking a chat partner) no Follow button is shown.
  final VoidCallback? onToggleFollow;

  /// Small line above the row, e.g. "Sam follows".
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contextLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 30, bottom: 6),
                    child: Row(
                      children: [
                        Icon(AppIcons.personFilled, size: 14, color: p.subtext),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            contextLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.subtext,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(url: profile.avatarUrl, name: profile.name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameWithBadge(
                        name: profile.name,
                        verified: profile.verified,
                        locked: profile.protectedPosts,
                        badgeSize: 15,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.subtext, fontSize: 14),
                      ),
                      if (profile.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            profile.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onToggleFollow != null) ...[
                  const SizedBox(width: 10),
                  PillButton(
                    label: profile.followLabel,
                    style: profile.followIsOutline
                        ? PillStyle.outline
                        : PillStyle.inverse,
                    onPressed: onToggleFollow,
                  ),
                ],
              ],
            ),
              ],
            ),
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }
}
