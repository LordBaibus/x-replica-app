import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../models/models.dart';
import 'avatar.dart';
import 'badges.dart';

/// Contents of the account menu, laid out like X's: account header on top,
/// the big feature list, a divider, then the smaller settings entries.
class DrawerMenu extends StatelessWidget {
  const DrawerMenu({
    super.key,
    required this.me,
    required this.onProfile,
    required this.onAddAccount,
    required this.onSubscription,
    required this.onBookmarks,
    required this.onCommunities,
    required this.onLists,
    required this.onFollowerRequests,
    required this.onFollowList,
    required this.onCreatorStudio,
    required this.onDeveloper,
    required this.onSettings,
    required this.onHelp,
    required this.onLogout,
    this.requestCount = 0,
  });

  final Profile? me;
  final VoidCallback onProfile;
  final VoidCallback onAddAccount;
  final VoidCallback onSubscription;
  final VoidCallback onBookmarks;
  final VoidCallback onCommunities;
  final VoidCallback onLists;
  final VoidCallback onFollowerRequests;

  /// Opens the follow page: `true` = Followers tab, `false` = Following tab.
  final void Function(bool followers) onFollowList;
  final VoidCallback onCreatorStudio;
  final VoidCallback onDeveloper;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  /// Follow requests waiting for an answer (shown as a blue dot with a number).
  final int requestCount;

  Widget _stat(AppPalette p, int n, String label, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$n ',
                style: TextStyle(
                  color: p.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: label,
                style: TextStyle(color: p.subtext, fontSize: 16),
              ),
            ],
          ),
        ),
        ),
      );

  /// Large entry (Profile, Bookmarks ...).
  Widget _big(AppPalette p, IconData icon, String label, VoidCallback onTap,
      {int badge = 0}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 27, color: p.text),
            const SizedBox(width: 22),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (badge > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Small entry (Settings and privacy, Help Center ...).
  Widget _small(AppPalette p, IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? p.text),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color ?? p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = me?.name ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onProfile,
                  child: Avatar(url: me?.avatarUrl, name: name, size: 46),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAddAccount,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      CupertinoIcons.person_crop_circle_badge_plus,
                      size: 28,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NameWithBadge(
                    name: name,
                    verified: me?.verified,
                    locked: me?.protectedPosts ?? false,
                    badgeSize: 21,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    me == null ? '' : '@${me!.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            child: Row(
              children: [
                _stat(p, me?.followingCount ?? 0, 'Following',
                    () => onFollowList(false)),
                _stat(p, me?.followerCount ?? 0, 'Followers',
                    () => onFollowList(true)),
              ],
            ),
          ),
          _big(p, AppIcons.person, 'Profile', onProfile),
          _big(p, CupertinoIcons.checkmark_seal, 'Subscription', onSubscription),
          _big(p, AppIcons.bookmark, 'History', onBookmarks),
          _big(p, AppIcons.people, 'Communities', onCommunities),
          _big(
            p,
            CupertinoIcons.list_bullet_below_rectangle,
            'Lists',
            onLists,
          ),
          _big(
            p,
            CupertinoIcons.person_badge_plus,
            'Follower requests',
            onFollowerRequests,
            badge: requestCount,
          ),
          _big(p, CupertinoIcons.paperplane, 'Creator Studio', onCreatorStudio),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
            child: Container(height: 0.5, color: p.subtext.withValues(alpha: 0.35)),
          ),
          _small(p, AppIcons.info, 'Developer info', onDeveloper),
          _small(p, AppIcons.settings, 'Settings and privacy', onSettings),
          _small(p, CupertinoIcons.question_circle, 'Help Center', onHelp),
          _small(p, AppIcons.logout, 'Log out', onLogout, color: p.danger),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
