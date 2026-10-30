import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'avatar.dart';
import 'group_avatar.dart';
import 'shared_post_card.dart';

/// What can be done to a chat from the long-press menu.
enum ChatMenuAction {
  open,
  markUnread,
  markRead,
  pin,
  unpin,
  mute,
  unmute,
  archive,
  unarchive,
  delete,
}

/// Long-press on a chat in the inbox: a preview of the latest messages and a
/// menu with Mark as unread, Pin, Mute, Archive and Delete. Resolves to what
/// was chosen (or null).
///
/// [personId] is set for a 1-to-1 chat, [groupId] for a group.
Future<ChatMenuAction?> showChatContextMenu(
  BuildContext context, {
  String? personId,
  String? groupId,
  required String title,
  String? avatarUrl,
  required bool unread,
  required ChatPref pref,
}) {
  return showGeneralDialog<ChatMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x73000000),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
    pageBuilder: (ctx, _, _) => _ChatMenuPage(
      personId: personId,
      groupId: groupId,
      title: title,
      avatarUrl: avatarUrl,
      unread: unread,
      pref: pref,
    ),
  );
}

class _ChatMenuPage extends StatelessWidget {
  const _ChatMenuPage({
    required this.personId,
    required this.groupId,
    required this.title,
    required this.avatarUrl,
    required this.unread,
    required this.pref,
  });

  final String? personId;
  final String? groupId;
  final String title;
  final String? avatarUrl;
  final bool unread;
  final ChatPref pref;

  Widget _item(
    BuildContext ctx,
    AppPalette p,
    IconData icon,
    String label,
    ChatMenuAction action, {
    bool danger = false,
    bool first = false,
  }) {
    final color = danger ? p.danger : p.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first)
          Container(
            height: danger ? 8 : 0.5,
            color: danger ? p.surface : p.border,
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(action),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 22, color: color),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _menu(BuildContext ctx, AppPalette p) {
    final isUnread = unread || pref.markedUnread;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _item(
              ctx,
              p,
              isUnread
                  ? CupertinoIcons.chat_bubble_text
                  : CupertinoIcons.circle_fill,
              isUnread ? 'Mark as read' : 'Mark as unread',
              isUnread ? ChatMenuAction.markRead : ChatMenuAction.markUnread,
              first: true,
            ),
            _item(
              ctx,
              p,
              pref.pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
              pref.pinned ? 'Unpin conversation' : 'Pin conversation',
              pref.pinned ? ChatMenuAction.unpin : ChatMenuAction.pin,
            ),
            _item(
              ctx,
              p,
              pref.muted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
              pref.muted ? 'Unmute' : 'Mute',
              pref.muted ? ChatMenuAction.unmute : ChatMenuAction.mute,
            ),
            _item(
              ctx,
              p,
              CupertinoIcons.archivebox,
              pref.archived ? 'Unarchive' : 'Archive',
              pref.archived ? ChatMenuAction.unarchive : ChatMenuAction.archive,
            ),
            _item(
              ctx,
              p,
              groupId != null
                  ? CupertinoIcons.square_arrow_left
                  : CupertinoIcons.trash,
              groupId != null ? 'Leave group' : 'Delete conversation',
              ChatMenuAction.delete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final wide = w >= 720;
    final menuW = (w - 32).clamp(200.0, 270.0).toDouble();
    final previewH =
        (media.size.height * (wide ? 0.6 : 0.4)).clamp(180.0, 420.0).toDouble();

    final preview = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(ChatMenuAction.open),
      child: _ChatPreview(
        personId: personId,
        groupId: groupId,
        title: title,
        avatarUrl: avatarUrl,
        height: previewH,
      ),
    );

    final Widget content = wide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: (w * 0.42).clamp(300.0, 440.0).toDouble(), child: preview),
              const SizedBox(width: 16),
              SizedBox(width: menuW, child: _menu(context, p)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              preview,
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: menuW, child: _menu(context, p)),
              ),
            ],
          );

    return DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 16,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 760 : 480),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card with the latest messages of the chat (read only).
class _ChatPreview extends StatefulWidget {
  const _ChatPreview({
    required this.personId,
    required this.groupId,
    required this.title,
    required this.avatarUrl,
    required this.height,
  });

  final String? personId;
  final String? groupId;
  final String title;
  final String? avatarUrl;
  final double height;

  @override
  State<_ChatPreview> createState() => _ChatPreviewState();
}

class _Line {
  const _Line({required this.text, required this.mine, this.sender});

  final String text;
  final bool mine;
  final String? sender;
}

class _ChatPreviewState extends State<_ChatPreview> {
  List<_Line>? _lines;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = Api.uid;
    try {
      final lines = <_Line>[];
      final gid = widget.groupId;
      if (gid != null) {
        final results = await Future.wait([
          Api.fetchGroupMessages(gid, limit: 10, newest: true),
          Api.fetchGroupMembers(gid),
        ]);
        final msgs = results[0] as List<GroupMessage>;
        final names = {
          for (final m in results[1] as List<GroupMember>) m.userId: m.name,
        };
        for (final m in msgs) {
          lines.add(_Line(
            text: SharedPost.preview(m.content),
            mine: m.senderId == me,
            sender: m.senderId == me ? null : (names[m.senderId] ?? 'Someone'),
          ));
        }
      } else {
        final msgs =
            await Api.fetchMessages(widget.personId!, limit: 10, newest: true);
        for (final m in msgs) {
          lines.add(_Line(
            text: SharedPost.preview(m.content),
            mine: m.senderId == me,
          ));
        }
      }
      if (mounted) setState(() => _lines = lines);
    } catch (_) {
      if (mounted) setState(() => _lines = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lines = _lines;

    Widget body;
    if (lines == null) {
      body = const Center(child: CupertinoActivityIndicator());
    } else if (lines.isEmpty) {
      body = Center(
        child: Text(
          'No messages yet',
          style: TextStyle(
            color: p.subtext,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
        ),
      );
    } else {
      // Newest at the bottom; older ones are cut off at the top.
      body = SingleChildScrollView(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: l.mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (l.sender != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 1),
                        child: Text(
                          l.sender!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.subtext,
                            fontSize: 11,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: l.mine ? p.accent : p.border,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          l.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: l.mine ? const Color(0xFFFFFFFF) : p.text,
                            fontSize: 15,
                            height: 1.2,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
            ),
            child: Row(
              children: [
                widget.groupId != null
                    ? const GroupAvatar(size: 30)
                    : Avatar(url: widget.avatarUrl, name: widget.title, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
