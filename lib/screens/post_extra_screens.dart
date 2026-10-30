import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../widgets/page_header.dart';
import '../widgets/person_tile.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'profile_view.dart';

/// "Post activity": who quoted a post and who reposted it, in two tabs.
class PostInteractionsScreen extends StatefulWidget {
  const PostInteractionsScreen({
    super.key,
    required this.post,
    this.initialTab = 0,
  });

  final Post post;

  /// 0 = Quotes, 1 = Reposts.
  final int initialTab;

  @override
  State<PostInteractionsScreen> createState() => _PostInteractionsScreenState();
}

class _PostInteractionsScreenState extends State<PostInteractionsScreen> {
  late int _tab = widget.initialTab;
  bool _newestFirst = true;

  List<Post> _quotes = const [];
  List<Profile> _reposters = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.fetchQuotes(widget.post.id),
        Api.fetchReposters(widget.post.id),
      ]);
      await Moderation.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _quotes = results[0] as List<Post>;
        final following = Moderation.instance.following;
        _reposters = [
          for (final x in results[1] as List<Profile>)
            x.copyWith(
              followedByMe: following.contains(x.id),
              requestedByMe: Moderation.instance.requested.contains(x.id),
            ),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow(Profile who) async {
    final next = who.afterFollowTap();
    void apply(Profile value) {
      setState(() {
        _reposters = [
          for (final x in _reposters) x.id == who.id ? value : x,
        ];
      });
    }

    apply(next);
    try {
      await Api.setFollow(
        who.id,
        follow: next.followedByMe || next.requestedByMe,
      );
      await Moderation.instance.reload();
    } catch (e) {
      if (!mounted) return;
      apply(who);
      showError(context, e);
    }
  }

  Widget _quotesList() {
    if (_quotes.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.quote_bubble,
        title: 'No quotes yet',
        subtitle: 'When someone quotes this post, it will show up here.',
      );
    }
    final list = _newestFirst ? _quotes : _quotes.reversed.toList();
    return ListView(
      children: [
        for (final q in list) PostTile(key: ValueKey(q.id), post: q),
      ],
    );
  }

  Widget _repostersList() {
    if (_reposters.isEmpty) {
      return const EmptyState(
        icon: CupertinoIcons.arrow_2_squarepath,
        title: 'No reposts yet',
        subtitle: 'When someone reposts this post, they will show up here.',
      );
    }
    final list = _newestFirst ? _reposters : _reposters.reversed.toList();
    return ListView(
      children: [
        for (final who in list)
          PersonTile(
            key: ValueKey(who.id),
            profile: who,
            onTap: () => Navigator.of(context)
                .push(appRoute(ProfileScreen(userId: who.id))),
            onToggleFollow:
                who.id == Api.uid ? null : () => _toggleFollow(who),
          ),
      ],
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
    } else {
      body = _tab == 0 ? _quotesList() : _repostersList();
    }

    return AdaptiveScaffold(
      backgroundColor: p.background,
      body: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: SafeArea(
          child: ContentWidth(
            child: Column(
              children: [
                PageHeader(
                  title: 'Post activity',
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _newestFirst = !_newestFirst),
                    child: Icon(
                      CupertinoIcons.arrow_up_arrow_down,
                      size: 22,
                      color: p.text,
                    ),
                  ),
                ),
                IconTabs(
                  icons: const [
                    CupertinoIcons.pencil,
                    CupertinoIcons.arrow_2_squarepath,
                  ],
                  labels: const ['Quotes', 'Reposts'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
