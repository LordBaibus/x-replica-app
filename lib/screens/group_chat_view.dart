import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/chat_media.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_media_widgets.dart';
import '../widgets/group_avatar.dart';
import '../widgets/shared_post_card.dart';
import '../widgets/state_views.dart';
import 'group_screens.dart';

/// A group conversation with live updates. Like [ChatView] it has no
/// scaffold of its own, so it also fits in the split pane on tablets.
class GroupChatView extends StatefulWidget {
  const GroupChatView({
    super.key,
    required this.group,
    this.showHeader = false,
    this.showBack = false,
    this.onActivity,
    this.onLeft,
  });

  final GroupChat group;
  final bool showHeader;
  final bool showBack;

  /// After messages were sent / read, or the group changed.
  final VoidCallback? onActivity;

  /// After I left the group.
  final VoidCallback? onLeft;

  @override
  State<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<GroupChatView> {
  final _input = TextEditingController();
  List<GroupMessage> _messages = const [];
  Map<String, GroupMember> _members = const {};
  late String _name = widget.group.name;
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  RealtimeChannel? _channel;

  String get _id => widget.group.id;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMembers();
    _channel = Api.subscribeGroupMessages(_onIncoming);
  }

  @override
  void didUpdateWidget(GroupChatView old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id) {
      _name = widget.group.name;
      _members = const {};
      _load();
      _loadMembers();
    }
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) Api.unsubscribe(c);
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.fetchGroupMessages(id);
      if (!mounted || id != _id) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMembers() async {
    final id = _id;
    try {
      final list = await Api.fetchGroupMembers(id);
      if (!mounted || id != _id) return;
      setState(() => _members = {for (final m in list) m.userId: m});
    } catch (_) {
      // Names fall back to "Someone".
    }
  }

  Future<void> _markRead() async {
    try {
      await Api.markGroupRead(_id);
      await Api.setChatPref(_id, markedUnread: false);
      widget.onActivity?.call();
    } catch (_) {
      // Not critical.
    }
  }

  void _onIncoming(GroupMessage m) {
    if (!mounted || m.groupId != _id) return;
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() => _messages = [..._messages, m]);
    if (m.senderId != Api.uid) {
      _markRead();
      if (!_members.containsKey(m.senderId)) _loadMembers();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await Api.sendGroupMessage(_id, text);
      if (!mounted) return;
      _input.clear();
      setState(() {
        if (!_messages.any((m) => m.id == sent.id)) {
          _messages = [..._messages, sent];
        }
        _sending = false;
      });
      widget.onActivity?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, 'You can’t send to this group any more.');
    }
  }

  /// Photo, video or voice message.
  Future<void> _sendMedia(ChatDraft draft) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final sent = await Api.sendGroupMediaMessage(_id, draft);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == sent.id)) {
          _messages = [..._messages, sent];
        }
        _sending = false;
      });
      widget.onActivity?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, e);
    }
  }

  Future<void> _openInfo() async {
    final result = await Navigator.of(context).push<String>(
      appRoute(GroupInfoScreen(groupId: _id, name: _name)),
    );
    if (!mounted) return;
    if (result == 'left') {
      widget.onActivity?.call();
      if (widget.onLeft != null) {
        widget.onLeft!();
      } else {
        Navigator.of(context).maybePop();
      }
    } else if (result == 'changed') {
      // The name may have changed: read it again.
      try {
        final all = await Api.fetchGroups();
        for (final g in all) {
          if (g.id == _id && mounted) setState(() => _name = g.name);
        }
      } catch (_) {}
      _loadMembers();
      widget.onActivity?.call();
    }
  }

  Future<void> _messageMenu(GroupMessage m) async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('copy'),
            child: const Text('Copy text'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.content));
      if (mounted) showInfo(context, 'Copied to clipboard');
    }
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _senderName(String id) => _members[id]?.name ?? 'Someone';

  // --------------------------------------------------------------- header

  Widget _header(AppPalette p) {
    final count = _members.isEmpty ? widget.group.memberCount : _members.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.showBack ? 0 : 16, 6, 8, 6),
      child: Row(
        children: [
          if (widget.showBack)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: 48,
                height: 44,
                child: Icon(AppIcons.back, size: 22, color: p.text),
              ),
            ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openInfo,
              child: Row(
                children: [
                  const GroupAvatar(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$count ${count == 1 ? 'member' : 'members'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openInfo,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(CupertinoIcons.info, size: 24, color: p.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(AppPalette p) {
    final count = _members.isEmpty ? widget.group.memberCount : _members.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          const GroupAvatar(size: 64),
          const SizedBox(height: 10),
          Text(
            _name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'member' : 'members'}',
            style: TextStyle(color: p.subtext, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openInfo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Group info',
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- messages

  Widget _bubble(GroupMessage m, AppPalette p, double maxWidth) {
    final mine = m.senderId == Api.uid;
    final postId = SharedPost.idIn(m.content);
    final typed = postId == null ? m.content : SharedPost.textIn(m.content);
    final textColor = mine ? const Color(0xFFFFFFFF) : p.text;

    final Widget? textBubble = (postId != null && typed.isEmpty)
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? p.accent : p.border,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Text(
              typed,
              style: TextStyle(color: textColor, fontSize: 16, height: 1.25),
            ),
          );
    final Widget content = m.hasMedia
        ? ChatMediaView(
            path: m.mediaPath!,
            kind: m.mediaKind!,
            mine: mine,
            maxWidth: maxWidth,
            durationMs: m.mediaMs,
          )
        : postId == null
        ? textBubble!
        : Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (textBubble != null) ...[
                textBubble,
                const SizedBox(height: 4),
              ],
              SizedBox(width: maxWidth, child: SharedPostCard(postId: postId)),
            ],
          );

    final member = _members[m.senderId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            Avatar(
              url: member?.avatarUrl,
              name: _senderName(m.senderId),
              size: 28,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        _senderName(m.senderId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.subtext,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onLongPress: m.hasMedia ? null : () => _messageMenu(m),
                    child: content,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(
                      _clock(m.createdAt),
                      style: TextStyle(color: p.subtext, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList(AppPalette p) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.7;
        return ListView.builder(
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: _messages.length + 1,
          itemBuilder: (context, i) {
            if (i == _messages.length) return _intro(p);
            final m = _messages[_messages.length - 1 - i];
            return _bubble(m, p, maxWidth);
          },
        );
      },
    );
  }

  Widget _composer(AppPalette p) {
    return ChatComposerBar(
      controller: _input,
      placeholder: 'Message the group',
      sending: _sending,
      onSendText: _send,
      onSendMedia: _sendMedia,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 15,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
      child: Column(
        children: [
          if (widget.showHeader) ...[
            _header(p),
            const HairlineDivider(),
          ],
          Expanded(child: _messageList(p)),
          const HairlineDivider(),
          _composer(p),
        ],
      ),
    );
  }
}

/// A group conversation as its own page (phones).
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({super.key, required this.group});

  final GroupChat group;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      body: SafeArea(
        bottom: false,
        child: GroupChatView(group: group, showHeader: true, showBack: true),
      ),
    );
  }
}
