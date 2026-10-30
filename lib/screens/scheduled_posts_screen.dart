import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/page_header.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/schedule_dialog.dart' show formatScheduled;
import '../widgets/state_views.dart';
import '../widgets/post_skeleton.dart';


/// Posts I scheduled for later. They go public by themselves at the chosen
/// time (the feed only shows posts whose time has come); here I can cancel
/// them before that.
class ScheduledPostsScreen extends StatefulWidget {
  const ScheduledPostsScreen({super.key});

  @override
  State<ScheduledPostsScreen> createState() => _ScheduledPostsScreenState();
}

class _ScheduledPostsScreenState extends State<ScheduledPostsScreen> {
  List<Post>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await Api.fetchScheduledPosts();
      if (mounted) setState(() => _posts = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _delete(Post post) async {
    final ok = await confirm(
      context,
      title: 'Delete scheduled post?',
      message: 'It will not be posted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts = _posts?.where((x) => x.id != post.id).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_posts == null) {
      body = const PostSkeletonList();
    } else if (_posts!.isEmpty) {
      body = const EmptyState(
        icon: CupertinoIcons.calendar,
        title: 'No scheduled posts',
        subtitle: 'Tap the calendar in the composer to write a post for later.',
      );
    } else {
      body = ListView.builder(
        itemCount: _posts!.length,
        itemBuilder: (context, i) {
          final post = _posts![i];
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.calendar,
                              size: 15, color: p.accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatScheduled(post.scheduledAt!),
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.content.isEmpty
                            ? (post.imageUrl != null ? 'Photo' : 'Quote')
                            : post.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.text, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _delete(post),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(AppIcons.close, size: 18, color: p.subtext),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return PlainScaffold(
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              const PageHeader(title: 'Scheduled posts'),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
