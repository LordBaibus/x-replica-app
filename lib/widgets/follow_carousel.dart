import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/connect_screen.dart';
import '../screens/profile_view.dart';
import '../services/api.dart';
import 'avatar.dart';
import 'pill_button.dart';

/// "Who to follow" as X shows it under a profile: a row of cards you can
/// scroll sideways (header, avatar, Follow, bio, "Sam follows"), followed by
/// a "Show more" link.
class FollowCarousel extends StatefulWidget {
  const FollowCarousel({super.key});

  @override
  State<FollowCarousel> createState() => _FollowCarouselState();
}

class _FollowCarouselState extends State<FollowCarousel> {
  List<Suggestion> _items = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.suggestedProfiles(limit: 10);
      if (mounted) {
        setState(() {
          _items = list;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggle(Suggestion s) async {
    final i = _items.indexWhere((x) => x.profile.id == s.profile.id);
    if (i < 0) return;
    final next = s.profile.afterFollowTap();
    setState(() => _items = [..._items]..[i] = s.copyWith(profile: next));
    try {
      await Api.setFollow(
        s.profile.id,
        follow: next.followedByMe || next.requestedByMe,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = [..._items]..[i] = s);
      showError(context, e);
    }
  }

  Widget _card(Suggestion s, AppPalette p) {
    final profile = s.profile;
    final header = profile.headerUrl;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context)
          .push(appRoute(ProfileScreen(userId: profile.id))),
      child: Container(
        width: 262,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 72,
                  width: double.infinity,
                  child: header == null || header.isEmpty
                      ? const ColoredBox(color: Color(0xFFCFD9DE))
                      : CachedNetworkImage(
                          imageUrl: header,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFFCFD9DE)),
                        ),
                ),
                Positioned(
                  left: 12,
                  bottom: -26,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: p.background,
                      shape: BoxShape.circle,
                    ),
                    child: Avatar(
                      url: profile.avatarUrl,
                      name: profile.name,
                      size: 52,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      PillButton(
                        label: profile.followLabel,
                        style: profile.followIsOutline
                            ? PillStyle.outline
                            : PillStyle.inverse,
                        height: 32,
                        onPressed: () => _toggle(s),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '@${profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.text, fontSize: 15, height: 1.3),
                    ),
                  ),
                  if (s.context != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(CupertinoIcons.person_fill, size: 14, color: p.subtext),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.context!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.subtext,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
    if (_loaded && _items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: Text(
            'Who to follow',
            style: TextStyle(
              color: p.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else
          SizedBox(
            height: 232,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [for (final s in _items) _card(s, p)],
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              Navigator.of(context).push(appRoute(const ConnectScreen())),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Show more',
                    style: TextStyle(color: p.accent, fontSize: 17),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 14, color: p.subtext),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
