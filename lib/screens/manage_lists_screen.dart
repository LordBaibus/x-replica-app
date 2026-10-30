import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/responsive.dart';
import 'lists_screen.dart' show ListIcon;

/// "Manage Lists" like X: pin up to 10 Lists to the top of the Lists page,
/// delete the ones you made or unfollow the ones you follow.
class ManageListsScreen extends StatefulWidget {
  const ManageListsScreen({super.key, required this.lists});

  final List<UserList> lists;

  @override
  State<ManageListsScreen> createState() => _ManageListsScreenState();
}

class _ManageListsScreenState extends State<ManageListsScreen> {
  late List<UserList> _lists = widget.lists;

  int get _pinCount => _lists.where((l) => l.pinnedByMe).length;

  void _replace(UserList l) {
    _lists = [for (final x in _lists) x.id == l.id ? l : x];
  }

  Future<void> _togglePin(UserList l) async {
    final pin = !l.pinnedByMe;
    if (pin && _pinCount >= 10) {
      showInfo(context, 'You can pin up to 10 Lists.');
      return;
    }
    setState(() => _replace(l.copyWith(pinnedByMe: pin)));
    try {
      await Api.setListPinned(l.id, pinned: pin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _replace(l));
      showError(context, e);
    }
  }

  Future<void> _remove(UserList l) async {
    final mine = l.ownerId == Api.uid;
    final ok = await confirm(
      context,
      title: mine ? 'Delete ${l.name}?' : 'Unfollow ${l.name}?',
      message: mine ? 'This can’t be undone.' : null,
      confirmLabel: mine ? 'Delete' : 'Unfollow',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      if (mine) {
        await Api.deleteList(l.id);
      } else {
        await Api.setListFollow(l.id, follow: false);
      }
      if (!mounted) return;
      setState(() => _lists = _lists.where((x) => x.id != l.id).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final sorted = [
      ..._lists.where((l) => l.pinnedByMe),
      ..._lists.where((l) => !l.pinnedByMe),
    ];
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Manage Lists'),
      body: SafeArea(
        child: ContentWidth(
          child: sorted.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 0),
                  child: Text(
                    'You haven’t created or followed any Lists yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.subtext, fontSize: 16),
                  ),
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        'Pin the Lists you open the most ($_pinCount of 10 pinned).',
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                    ),
                    for (final l in sorted)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            ListIcon(list: l, size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          l.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: p.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (l.isPrivate) ...[
                                        const SizedBox(width: 6),
                                        Icon(CupertinoIcons.lock_fill,
                                            size: 13, color: p.subtext),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    l.ownerId == Api.uid
                                        ? '${l.memberCount} '
                                            '${l.memberCount == 1 ? 'member' : 'members'} · by you'
                                        : '${l.memberCount} '
                                            '${l.memberCount == 1 ? 'member' : 'members'} · by @${l.ownerUsername}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: p.subtext, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _togglePin(l),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  l.pinnedByMe
                                      ? CupertinoIcons.pin_fill
                                      : CupertinoIcons.pin,
                                  size: 22,
                                  color: l.pinnedByMe ? p.accent : p.subtext,
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _remove(l),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  l.ownerId == Api.uid
                                      ? CupertinoIcons.trash
                                      : CupertinoIcons.minus_circle,
                                  size: 22,
                                  color: p.subtext,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
