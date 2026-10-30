import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../services/drafts.dart';
import '../widgets/page_header.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';

/// "Drafts": posts that were written but not sent. Tapping one returns it to
/// the composer (the screen pops with the [DraftPost]).
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<DraftPost> _drafts = Drafts.all();

  Future<void> _delete(DraftPost d) async {
    final ok = await confirm(
      context,
      title: 'Delete draft?',
      message: 'This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await Drafts.remove(d.id);
    if (mounted) setState(() => _drafts = Drafts.all());
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final Widget body = _drafts.isEmpty
        ? const EmptyState(
            icon: CupertinoIcons.doc_text,
            title: 'No drafts',
            subtitle:
                'When you close the composer, you can save what you wrote and finish it later.',
          )
        : ListView.builder(
            itemCount: _drafts.length,
            itemBuilder: (context, i) {
              final d = _drafts[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(d),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: p.border, width: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.preview.isEmpty ? '(empty)' : d.preview,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 16,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.texts.length > 1
                                  ? 'Thread of ${d.texts.length} posts · ${timeago.format(d.savedAt)}'
                                  : 'Saved ${timeago.format(d.savedAt)}',
                              style: TextStyle(color: p.subtext, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _delete(d),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(AppIcons.close, size: 18, color: p.subtext),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return PlainScaffold(
      child: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              const PageHeader(title: 'Drafts'),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
