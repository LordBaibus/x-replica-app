import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/page_header.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/post_tile.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import '../core/x_icons.dart';
import '../widgets/post_skeleton.dart';

/// "History" (sidebar): Bookmarks, Videos, Articles and Likes in four icon
/// tabs. Bookmarks and Likes are real; Videos and Articles stay empty
/// because this app has no video player or articles.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  int _tab = 0;

  List<Post>? _bookmarks;
  List<Post>? _likes;
  Object? _error;

  bool _searching = false;
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks({bool silent = false}) async {
    try {
      final list = await Api.fetchBookmarks();
      if (!mounted) return;
      setState(() {
        _bookmarks = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _bookmarks == null) _error = e;
      });
    }
  }

  Future<void> _loadLikes({bool silent = false}) async {
    try {
      final list = await Api.fetchUserLikes(Api.uid);
      if (!mounted) return;
      setState(() {
        _likes = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || _likes == null) _error = e;
      });
    }
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() {
      _tab = i;
      _error = null;
      _searching = false;
      _query.clear();
    });
    if (i == 3 && _likes == null) _loadLikes();
  }

  void _remove(Post post) {
    setState(() {
      _bookmarks = _bookmarks?.where((x) => x.id != post.id).toList();
      _likes = _likes?.where((x) => x.id != post.id).toList();
    });
  }

  void _info() {
    final text = switch (_tab) {
      1 => 'Videos you watch for at least 10 minutes are listed here, '
          'so you can find them again.',
      2 => 'Articles you read are listed here, so you can find them again.',
      _ => 'Posts you like are listed here, so you can find them again.',
    };
    notify(context, title: 'About History', message: text);
  }

  // ---- UI ----------------------------------------------------------------

  Widget _trailing(AppPalette p) {
    final isBookmarks = _tab == 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBookmarks
          ? () => setState(() {
                _searching = !_searching;
                if (!_searching) _query.clear();
              })
          : _info,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          isBookmarks
              ? (_searching ? AppIcons.close : AppIcons.search)
              : CupertinoIcons.info_circle,
          size: 22,
          color: p.text,
        ),
      ),
    );
  }

  Widget _searchField(AppPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CupertinoTextField(
        controller: _query,
        autofocus: true,
        placeholder: 'Search Bookmarks',
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: XIcon(XIcons.search, size: 16, color: p.subtext),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        style: TextStyle(color: p.text, fontSize: 15),
        placeholderStyle: TextStyle(color: p.subtext, fontSize: 15),
        cursorColor: p.accent,
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(20),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _plainEmpty(AppPalette p, String? title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postList(
    List<Post> posts,
    Future<void> Function() onRefresh, {
    required bool removeWhenUnbookmarked,
  }) {
    return ContentWidth(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final post = posts[i];
                return PostTile(
                  key: ValueKey('${_tab}_${post.id}'),
                  post: post,
                  onDeleted: _remove,
                  onChanged: (next) {
                    if (removeWhenUnbookmarked && !next.bookmarkedByMe) {
                      _remove(next);
                    }
                    if (!removeWhenUnbookmarked && !next.likedByMe) {
                      _remove(next);
                    }
                  },
                );
              },
              childCount: posts.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  Widget _body(AppPalette p) {
    switch (_tab) {
      case 1:
        return _plainEmpty(
          p,
          null,
          'Videos you watch will show here (minimum 10 minute duration)',
        );
      case 2:
        return _plainEmpty(p, null, 'Articles you read will show here');
      case 3:
        if (_error != null) {
          return ErrorView(error: _error!, onRetry: _loadLikes);
        }
        final likes = _likes;
        if (likes == null) return const PostSkeletonList();
        if (likes.isEmpty) {
          return _plainEmpty(
            p,
            'Like some posts',
            'Tap the heart on any post to show it some love. '
                "When you do, it'll show up here.",
          );
        }
        return _postList(
          likes,
          () => _loadLikes(silent: true),
          removeWhenUnbookmarked: false,
        );
      default:
        if (_error != null) {
          return ErrorView(error: _error!, onRetry: _loadBookmarks);
        }
        final all = _bookmarks;
        if (all == null) return const PostSkeletonList();
        final q = _query.text.trim().toLowerCase();
        final list = q.isEmpty
            ? all
            : all
                .where((x) =>
                    x.content.toLowerCase().contains(q) ||
                    x.authorName.toLowerCase().contains(q) ||
                    x.username.toLowerCase().contains(q))
                .toList();
        if (list.isEmpty) {
          return q.isEmpty
              ? _plainEmpty(
                  p,
                  'Save posts for later',
                  'Bookmark posts to easily find them again in the future.',
                )
              : _plainEmpty(p, null, 'No bookmarks match "$q".');
        }
        return _postList(
          list,
          () => _loadBookmarks(silent: true),
          removeWhenUnbookmarked: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: 'History',
              middle: _tab == 0 && _searching ? _searchField(p) : null,
              trailing: _trailing(p),
            ),
            ContentWidth(
              child: IconTabs(
                icons: const [
                  CupertinoIcons.bookmark,
                  CupertinoIcons.play_rectangle,
                  CupertinoIcons.doc_richtext,
                  CupertinoIcons.heart,
                ],
                labels: const ['Bookmarks', 'Videos', 'Articles', 'Likes'],
                index: _tab,
                onChanged: _select,
              ),
            ),
            Expanded(child: _body(p)),
          ],
        ),
      ),
    );
  }
}
