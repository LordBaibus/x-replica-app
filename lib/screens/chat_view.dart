import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/format.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/chat_media.dart';
import '../widgets/anchored_popup.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/chat_media_widgets.dart';
import '../widgets/shared_post_card.dart';
import '../widgets/state_views.dart';
import 'profile_view.dart';

/// One-to-one conversation with live updates (Supabase realtime).
/// No scaffold of its own, so it can sit in a split pane on tablets / foldables.
///
/// Layout (like X): a header with the person, the start of the conversation
/// ("Joined … / N Followers / View profile"), the messages, and at the bottom
/// either the message field or, when the person's inbox is closed for me,
/// the "closed inbox" panel.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.partner,
    this.showHeader = false,
    this.showBack = false,
    this.onActivity,
    this.initialText = '',
  });

  final Profile partner;

  /// Show the person's name, "Unencrypted" and the call buttons on top.
  final bool showHeader;

  /// Show a back arrow in that header (the conversation is its own page).
  final bool showBack;

  /// Called after messages were sent / marked read, so the inbox can refresh.
  final VoidCallback? onActivity;

  /// Text the message field starts with (e.g. a post link to send).
  final String initialText;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final TextEditingController _input =
      TextEditingController(text: widget.initialText);
  List<Message> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  Object? _error;
  RealtimeChannel? _channel;
  RealtimeChannel? _reactionChannel;

  /// message id -> (user id -> emoji)
  Map<String, Map<String, String>> _reactions = const {};

  /// The message the next one answers (shown above the field).
  Message? _replyingTo;

  static const _emojis = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

  /// The partner with join date and follower count (the inbox list only has
  /// name and picture).
  late Profile _partner = widget.partner;

  /// null while checking. false = closed inbox for me.
  bool? _canMessage;
  bool _closedDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPartner();
    _checkInbox();
    _channel = Api.subscribeMessages(_onIncoming);
    _reactionChannel = Api.subscribeReactions(_loadReactions);
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.partner.id != widget.partner.id) {
      // Split pane: another conversation was picked.
      _partner = widget.partner;
      _canMessage = null;
      _closedDismissed = false;
      _replyingTo = null;
      _reactions = const {};
      _load();
      _loadPartner();
      _checkInbox();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) Api.unsubscribe(channel);
    final rc = _reactionChannel;
    if (rc != null) Api.unsubscribe(rc);
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadPartner() async {
    final id = widget.partner.id;
    try {
      final full = await Api.getProfile(id);
      if (mounted && widget.partner.id == id) setState(() => _partner = full);
    } catch (_) {
      // The intro just shows less.
    }
  }

  Future<void> _checkInbox() async {
    final id = widget.partner.id;
    final ok = await Api.canMessage(id);
    if (mounted && widget.partner.id == id) setState(() => _canMessage = ok);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.fetchMessages(widget.partner.id);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _markRead();
      _loadReactions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadReactions() async {
    if (!mounted || _messages.isEmpty) return;
    try {
      final ids = _messages.map((m) => m.id).toList();
      final r = await Api.fetchReactions(ids);
      if (mounted) setState(() => _reactions = r);
    } catch (_) {
      // Reactions are a bonus; the chat works without them.
    }
  }

  /// Sets / removes my reaction (optimistic, then saved).
  Future<void> _react(Message m, String? emoji) async {
    final me = Api.uid;
    final before = _reactions;
    final next = {
      for (final e in _reactions.entries) e.key: {...e.value},
    };
    final forMsg = next[m.id] ??= {};
    if (emoji == null) {
      forMsg.remove(me);
    } else {
      forMsg[me] = emoji;
    }
    setState(() => _reactions = next);
    try {
      await Api.setReaction(m.id, emoji);
    } catch (e) {
      if (!mounted) return;
      setState(() => _reactions = before);
      showError(context, e);
    }
  }

  Future<void> _messageMenu(Message m, Rect anchor) async {
    final mine = _reactions[m.id]?[Api.uid];
    final choice = await showAnchoredPopup<String>(
      context,
      anchor: anchor,
      width: 270,
      alignRight: m.senderId == Api.uid,
      preferAbove: true,
      dim: true,
      radius: 22,
      builder: (ctx) {
        final p = AppPalette.of(ctx);
        Widget row(IconData icon, String label, String value) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).pop(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(icon, size: 20, color: p.text),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final e in _emojis)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(ctx).pop('react:$e'),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mine == e ? p.border : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 0.5, color: p.border),
            row(CupertinoIcons.arrow_turn_up_left, 'Reply', 'reply'),
            row(CupertinoIcons.doc_on_doc, 'Copy text', 'copy'),
            if (mine != null)
              row(CupertinoIcons.heart_slash, 'Remove reaction', 'unreact'),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('react:')) {
      final e = choice.substring(6);
      await _react(m, mine == e ? null : e);
    } else if (choice == 'unreact') {
      await _react(m, null);
    } else if (choice == 'reply') {
      setState(() => _replyingTo = m);
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.content));
    }
  }

  Future<void> _markRead() async {
    try {
      await Api.markRead(widget.partner.id);
      widget.onActivity?.call();
    } catch (_) {
      // Not critical.
    }
  }

  void _onIncoming(Message m) {
    if (!mounted) return;
    final me = Api.uid;
    final partnerId = widget.partner.id;
    final belongsHere = (m.senderId == partnerId && m.receiverId == me) ||
        (m.senderId == me && m.receiverId == partnerId);
    if (!belongsHere) return;
    if (_messages.any((x) => x.id == m.id)) return;

    setState(() => _messages = [..._messages, m]);
    if (m.senderId == partnerId) _markRead();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await Api.sendMessage(
        widget.partner.id,
        text,
        replyTo: _replyingTo?.id,
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _replyingTo = null;
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

  /// Photo, video or voice message.
  Future<void> _sendMedia(ChatDraft draft) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final sent = await Api.sendMediaMessage(
        widget.partner.id,
        draft,
        replyTo: _replyingTo?.id,
      );
      if (!mounted) return;
      setState(() {
        _replyingTo = null;
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

  void _openProfile() => Navigator.of(context)
      .push(appRoute(ProfileScreen(userId: widget.partner.id)));

  Future<void> _call() => notify(
        context,
        title: 'Calls',
        message: 'Audio and video calls are not part of this project yet.',
      );

  Future<void> _useNumber() => notify(
        context,
        title: 'X Number',
        message: 'X Numbers are not part of this project yet.',
      );

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // --------------------------------------------------------------- header

  Widget _header(AppPalette p) {
    final partner = _partner;
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
              onTap: _openProfile,
              child: Row(
                children: [
                  Avatar(
                    url: partner.avatarUrl,
                    name: partner.name,
                    size: 36,
                    square: Avatar.isSquare(partner.verified),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NameWithBadge(
                          name: partner.name,
                          verified: partner.verified,
                          locked: partner.protectedPosts,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.lock_open,
                              size: 12,
                              color: p.subtext,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Unencrypted',
                              style: TextStyle(color: p.subtext, fontSize: 13),
                            ),
                          ],
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
            onTap: _call,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(CupertinoIcons.phone, size: 22, color: p.text),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _call,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(CupertinoIcons.videocam, size: 24, color: p.text),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- intro

  /// The top of the conversation: who this is.
  Widget _intro(AppPalette p) {
    final partner = _partner;
    final joined = partner.createdAt;
    final parts = <String>[
      if (joined != null) 'Joined ${_months[joined.month - 1]} ${joined.year}',
      '${compactCount(partner.followerCount)} '
          '${partner.followerCount == 1 ? 'Follower' : 'Followers'}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: Avatar(
              url: partner.avatarUrl,
              name: partner.name,
              size: 64,
              square: Avatar.isSquare(partner.verified),
            ),
          ),
          const SizedBox(height: 10),
          NameWithBadge(
            name: partner.name,
            verified: partner.verified,
            locked: partner.protectedPosts,
            badgeSize: 18,
            style: TextStyle(
              color: p.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@${partner.username}',
            style: TextStyle(color: p.subtext, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'View profile',
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

  Widget _bubble(Message m, AppPalette p, double maxWidth) {
    final mine = m.senderId == Api.uid;
    final postId = SharedPost.idIn(m.content);
    final typed = postId == null ? m.content : SharedPost.textIn(m.content);
    final textColor = mine ? const Color(0xFFFFFFFF) : p.text;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    // The coloured bubble with the words (left out when only a post was sent).
    final Widget? textBubble = (postId != null && typed.isEmpty && m.replyTo == null)
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? p.accent : p.border,
              borderRadius: bubbleRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.replyTo != null) _replyQuote(m, mine, p),
                if (typed.isNotEmpty)
                  Text(
                    typed,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
              ],
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
    final reactions = _reactions[m.id] ?? const <String, String>{};
    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    final myEmoji = reactions[Api.uid];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Builder(
              builder: (bubbleContext) => GestureDetector(
              onLongPress: () => _messageMenu(m, rectOf(bubbleContext)),
              onDoubleTap: () => _react(m, myEmoji == '❤️' ? null : '❤️'),
              child: content,
            ),
            ),
          ),
          if (counts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: myEmoji == null ? null : () => _react(m, null),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    [
                      for (final e in counts.entries)
                        counts.length == 1 && e.value == 1
                            ? e.key
                            : '${e.key} ${e.value}',
                    ].join('  '),
                    style: TextStyle(color: p.text, fontSize: 13),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              mine && m.readAt != null
                  ? '${_clock(m.createdAt)} · Seen'
                  : _clock(m.createdAt),
              style: TextStyle(color: p.subtext, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// The little quote of the message this one answers, inside the bubble.
  Widget _replyQuote(Message m, bool mine, AppPalette p) {
    Message? original;
    for (final x in _messages) {
      if (x.id == m.replyTo) {
        original = x;
        break;
      }
    }
    final fromMe = original?.senderId == Api.uid;
    final who = original == null
        ? ''
        : (fromMe ? 'You' : _partner.name);
    final color = mine ? const Color(0xFFFFFFFF) : p.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.6), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (who.isNotEmpty)
            Text(
              who,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          Text(
            original?.content ?? 'Original message',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 14),
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
        final maxWidth = constraints.maxWidth * 0.75;
        // The list is upside down (newest first), so the intro is the last
        // item and ends up on top.
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

  // --------------------------------------------------------------- bottom

  Widget _composer(AppPalette p) {
    final reply = _replyingTo;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Container(width: 3, height: 34, color: p.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${reply.senderId == Api.uid ? 'yourself' : _partner.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          reply.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _replyingTo = null),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(AppIcons.close, size: 18, color: p.subtext),
                    ),
                  ),
                ],
              ),
            ),
          ChatComposerBar(
            controller: _input,
            placeholder: 'Start a message',
            sending: _sending,
            onSendText: _send,
            onSendMedia: _sendMedia,
          ),
        ],
      ),
    );
  }

  /// "@x doesn't follow you…" with Not Now / Use X Number (shown when the
  /// person cannot be messaged: protected account, closed inbox, blocked).
  Widget _closedPanel(AppPalette p) {
    final handle = '@${_partner.username}';
    final reason = _partner.protectedPosts
        ? ' has protected their posts. Send a follow request and wait until '
            'it is accepted, or enter their X Number to send a message.'
        : ' doesn’t follow you. You must be verified or enter their X Number '
            'to send a message.';
    if (_closedDismissed) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            'You can’t send messages to $handle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 15),
          ),
        ),
      );
    }

    Widget button(String label, Color bg, Color fg, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(color: p.subtext, fontSize: 17, height: 1.3),
                children: [
                  TextSpan(
                    text: handle,
                    style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(text: reason),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                button('Not Now', p.field, p.text, () {
                  if (widget.showBack) {
                    Navigator.of(context).maybePop();
                  } else {
                    setState(() => _closedDismissed = true);
                  }
                }),
                const SizedBox(width: 12),
                button('Use X Number', p.text, p.background, _useNumber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final closed = _canMessage == false;

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
          if (closed) _closedPanel(p) else _composer(p),
        ],
      ),
    );
  }
}

/// A conversation opened as its own page (phones).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.partner, this.initialText = ''});

  final Profile partner;
  final String initialText;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      body: SafeArea(
        bottom: false,
        child: ChatView(
          partner: partner,
          showHeader: true,
          showBack: true,
          initialText: initialText,
        ),
      ),
    );
  }
}
