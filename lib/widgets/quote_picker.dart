import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'post_card.dart';
import 'state_views.dart';

/// "Choose a post to quote": bottom sheet with Bookmarks / Likes / Your
/// posts tabs. Resolves to the tapped post (or null when cancelled).
Future<Post?> showQuotePicker(BuildContext context) {
  final p = AppPalette.of(context);
  return showCupertinoModalPopup<Post>(
    context: context,
    builder: (ctx) => DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 16,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
      child: const _QuoteSheet(),
    ),
  );
}

class _QuoteSheet extends StatefulWidget {
  const _QuoteSheet();

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  static const _labels = ['Bookmarks', 'Likes', 'Your posts'];

  int _tab = 0;
  final List<List<Post>?> _lists = [null, null, null];
  final List<Object?> _errors = [null, null, null];

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int tab) async {
    setState(() => _errors[tab] = null);
    try {
      final list = switch (tab) {
        0 => await Api.fetchBookmarks(),
        1 => await Api.fetchUserLikes(Api.uid),
        _ => await Api.fetchUserPosts(Api.uid),
      };
      if (mounted) setState(() => _lists[tab] = list);
    } catch (e) {
      if (mounted) setState(() => _errors[tab] = e);
    }
  }

  void _select(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (_lists[i] == null) _load(i);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final height = media.size.height - media.padding.top - 16;

    Widget body;
    final list = _lists[_tab];
    final error = _errors[_tab];
    if (error != null) {
      body = ErrorView(error: error, onRetry: () => _load(_tab));
    } else if (list == null) {
      body = const LoadingView();
    } else if (list.isEmpty) {
      body = Center(
        child: Text(
          _tab == 0
              ? 'You have no bookmarks yet.'
              : _tab == 1
                  ? 'You haven’t liked any posts yet.'
                  : 'You haven’t posted anything yet.',
          style: TextStyle(color: p.subtext, fontSize: 16),
        ),
      );
    } else {
      body = ListView.builder(
        padding: EdgeInsets.only(bottom: media.padding.bottom + 12),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final post = list[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(post),
            // The card is only a preview here: a tap anywhere picks it.
            child: AbsorbPointer(
              child: PostCard(
                key: ValueKey('q-${post.id}'),
                post: post,
                isMine: post.userId == Api.uid,
                onLike: () {},
                onOpenAuthor: () {},
              ),
            ),
          );
        },
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: p.subtext.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: p.text, fontSize: 17)),
                  ),
                  Expanded(
                    child: Text(
                      'Choose a post to quote',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _select(i),
                        child: Column(
                          children: [
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (i == 0 && _tab == 0) ...[
                                  Icon(AppIcons.bookmark,
                                      size: 20, color: p.text),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  _labels[i],
                                  style: TextStyle(
                                    color: i == _tab ? p.text : p.subtext,
                                    fontSize: 17,
                                    fontWeight: i == _tab
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 4,
                              width: 90,
                              decoration: BoxDecoration(
                                color: i == _tab
                                    ? p.accent
                                    : const Color(0x00000000),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
