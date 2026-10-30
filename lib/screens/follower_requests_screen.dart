import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/page_header.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'profile_view.dart';

/// Follower requests: people who asked to follow my protected account. Each
/// can be accepted (they become a follower and can read my posts) or
/// declined. When nobody is waiting X's "You're up to date" message shows.
class FollowerRequestsScreen extends StatefulWidget {
  const FollowerRequestsScreen({super.key});

  @override
  State<FollowerRequestsScreen> createState() => _FollowerRequestsScreenState();
}

class _FollowerRequestsScreenState extends State<FollowerRequestsScreen> {
  List<Profile> _requests = const [];
  bool _loading = true;
  Object? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await Api.fetchFollowRequests();
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  Future<void> _answer(Profile who, {required bool accept}) async {
    if (_busy.contains(who.id)) return;
    setState(() => _busy.add(who.id));
    try {
      if (accept) {
        await Api.acceptFollowRequest(who.id);
      } else {
        await Api.declineFollowRequest(who.id);
      }
      await Moderation.instance.reload();
      if (!mounted) return;
      setState(() {
        _busy.remove(who.id);
        _requests = _requests.where((x) => x.id != who.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(who.id));
      showError(context, e);
      _load(silent: true);
    }
  }

  /// Round icon button: tick (accept) or red cross (decline).
  Widget _circle(AppPalette p, IconData icon, Color color, Color border,
      VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  Widget _row(AppPalette p, Profile who) {
    final busy = _busy.contains(who.id);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context)
              .push(appRoute(ProfileScreen(userId: who.id))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  url: who.avatarUrl,
                  name: who.name,
                  size: 46,
                  square: Avatar.isSquare(who.verified),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameWithBadge(
                        name: who.name,
                        verified: who.verified,
                        locked: who.protectedPosts,
                        badgeSize: 15,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@${who.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                      if (who.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            who.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.text, fontSize: 15),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _circle(
                  p,
                  CupertinoIcons.checkmark,
                  p.text,
                  p.border,
                  busy ? null : () => _answer(who, accept: true),
                ),
                const SizedBox(width: 8),
                _circle(
                  p,
                  CupertinoIcons.xmark,
                  p.danger,
                  p.danger.withValues(alpha: 0.35),
                  busy ? null : () => _answer(who, accept: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _upToDate(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You're up to date",
            style: TextStyle(
              color: p.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "When someone requests to follow you, it'll show up "
            'here for you to accept or decline.',
            style: TextStyle(color: p.subtext, fontSize: 16, height: 1.35),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_requests.isEmpty) {
      body = _upToDate(p);
    } else {
      body = ListView(
        children: [for (final who in _requests) _row(p, who)],
      );
    }
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Follower requests'),
            Expanded(child: ContentWidth(maxWidth: 520, child: body)),
          ],
        ),
      ),
    );
  }
}
