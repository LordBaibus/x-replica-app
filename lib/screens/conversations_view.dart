import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../widgets/avatar.dart';
import '../widgets/responsive.dart';
import '../widgets/chat_header.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/note_sheets.dart';
import '../widgets/notes_strip.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/popover_menu.dart';
import '../widgets/search_pill.dart';
import '../widgets/state_views.dart';
import 'chat_view.dart';

/// Inbox. On phones a tap opens the chat as a new page; on tablets and
/// unfolded foldables the chat opens beside the list (split at the hinge).
class ConversationsView extends StatefulWidget {
  const ConversationsView({
    super.key,
    this.me,
    this.onOpenDrawer,
    this.onOpenSettings,
  });

  /// Signed-in user, drawer opener and settings shortcut for the header.
  final Profile? me;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSettings;

  @override
  State<ConversationsView> createState() => ConversationsViewState();
}

enum _Show { all, unread, direct, groups, requests }

class ConversationsViewState extends State<ConversationsView> {
  final _filter = TextEditingController();
  final GlobalKey _modeKey = GlobalKey();
  _Show _show = _Show.all;
  List<Conversation> _items = const [];
  bool _loading = true;
  Object? _error;
  Profile? _selected;

  RealtimeChannel? _channel;
  RealtimeChannel? _notesChannel;
  Timer? _debounce;
  Timer? _notesDebounce;
  Timer? _expiry;

  // Notes (24-hour status). `_notesReady` stays false when the table is not
  // there yet, so the strip is simply hidden instead of showing an error.
  List<StatusNote> _notes = const [];
  bool _notesReady = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotes();
    _channel = Api.subscribeMessages((_) => _scheduleReload());
    _notesChannel = Api.subscribeStatusNotes(() {
      _notesDebounce?.cancel();
      _notesDebounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _loadNotes();
      });
    });
    // Notes vanish after 24 hours: drop expired ones while the tab is open.
    _expiry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _notes.isEmpty) return;
      if (_notes.any((n) => n.isExpired)) {
        setState(() => _notes = _notes.where((n) => !n.isExpired).toList());
      }
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    _debounce?.cancel();
    _notesDebounce?.cancel();
    _expiry?.cancel();
    final channel = _channel;
    if (channel != null) Api.unsubscribe(channel);
    final notesChannel = _notesChannel;
    if (notesChannel != null) Api.unsubscribe(notesChannel);
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final list = await Api.fetchStatusNotes();
      if (!mounted) return;
      setState(() {
        _notes = list;
        _notesReady = true;
      });
    } catch (_) {
      if (mounted && !_notesReady) setState(() {});
    }
  }

  StatusNote? get _myNote {
    final id = widget.me?.id;
    for (final n in _notes) {
      if (n.userId == (id ?? Api.uid)) return n;
    }
    return null;
  }

  List<StatusNote> get _othersNotes {
    final mine = widget.me?.id ?? Api.uid;
    final mod = Moderation.instance;
    return _notes
        .where((n) =>
            n.userId != mine &&
            !mod.muted.contains(n.userId) &&
            !mod.blocked.contains(n.userId))
        .toList();
  }

  Future<void> _openMyNote() async {
    final changed = await showMyNoteSheet(
      context,
      me: widget.me,
      current: _myNote,
    );
    if (changed && mounted) _loadNotes();
  }

  Widget _notesStrip() {
    return NotesStrip(
      me: widget.me,
      mine: _myNote,
      notes: _othersNotes,
      onMine: _openMyNote,
      onNote: (n) => showNoteSheet(context, n),
    );
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> reload() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await Api.fetchConversations();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e;
      });
    }
  }

  /// Opens a conversation with [partner] (page on phones, side pane on wide screens).
  void openChat(Profile partner) {
    if (FoldAwareSplit.canSplit(context)) {
      setState(() => _selected = partner);
    } else {
      Navigator.of(context)
          .push(appRoute(ChatScreen(partner: partner)))
          .then((_) {
        if (mounted) _load(silent: true);
      });
    }
  }

  /// "New chat" card; opens the conversation with the person picked.
  Future<void> newChat() async {
    final Profile? picked = await showNewChatDialog(context);
    if (picked != null && mounted) openChat(picked);
  }

  String get _modeLabel => switch (_show) {
        _Show.all => 'All',
        _Show.unread => 'Unread',
        _Show.direct => 'Direct',
        _Show.groups => 'Groups',
        _Show.requests => 'Requests',
      };

  Future<void> _openModeMenu() async {
    final choice = await showPopoverMenu<String>(
      context,
      anchor: _modeKey,
      entries: [
        PopoverEntry(
          value: 'all',
          label: 'All',
          icon: CupertinoIcons.chat_bubble,
          checked: _show == _Show.all,
        ),
        PopoverEntry(
          value: 'unread',
          label: 'Unread',
          icon: CupertinoIcons.chat_bubble_2_fill,
          checked: _show == _Show.unread,
        ),
        PopoverEntry(
          value: 'direct',
          label: 'Direct',
          icon: CupertinoIcons.person,
          checked: _show == _Show.direct,
        ),
        PopoverEntry(
          value: 'groups',
          label: 'Groups',
          icon: CupertinoIcons.person_2,
          checked: _show == _Show.groups,
        ),
        PopoverEntry(
          value: 'requests',
          label: 'Requests',
          icon: CupertinoIcons.tray_arrow_down,
          checked: _show == _Show.requests,
          groupStart: true,
        ),
        const PopoverEntry(
          value: 'settings',
          label: 'Settings',
          icon: CupertinoIcons.gear,
        ),
        const PopoverEntry(
          value: 'read',
          label: 'Mark All Read',
          icon: CupertinoIcons.checkmark_circle,
          groupStart: true,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'all':
        setState(() => _show = _Show.all);
      case 'unread':
        setState(() => _show = _Show.unread);
      case 'direct':
        setState(() => _show = _Show.direct);
      case 'groups':
        setState(() => _show = _Show.groups);
      case 'requests':
        setState(() => _show = _Show.requests);
      case 'settings':
        widget.onOpenSettings?.call();
      case 'read':
        try {
          await Api.markAllRead();
          if (!mounted) return;
          await _load(silent: true);
          if (mounted) showInfo(context, 'All messages marked as read.');
        } catch (e) {
          if (mounted) showError(context, e);
        }
    }
  }

  Widget _row(Conversation c, AppPalette p) {
    final selected = _selected?.id == c.partnerId;
    final preview = '${c.lastFromMe ? 'You: ' : ''}${c.lastMessage}';
    final unread = c.unreadCount > 0;

    return Column(
      children: [
        GestureDetector(
          onTap: () => openChat(c.partner),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: selected ? p.surface : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Avatar(url: c.avatarUrl, name: c.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '@${c.partner.username} · '
                              '${timeago.format(c.lastAt, locale: 'en_short')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? p.text : p.subtext,
                          fontSize: 14,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${c.unreadCount}',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }

  Widget _noMessages(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chat_bubble, size: 56, color: p.text),
            const SizedBox(height: 14),
            Text(
              'No Messages',
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a new conversation to begin messaging.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 17, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBody(AppPalette p) {
    final showNotes = _notesReady && _filter.text.trim().isEmpty;
    if (!showNotes) return _chatList(p);
    return Column(
      children: [
        _notesStrip(),
        const HairlineDivider(),
        Expanded(child: _chatList(p)),
      ],
    );
  }

  Widget _chatList(AppPalette p) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: () => _load());

    // Only 1-to-1 chats exist, so Groups and Requests are always empty.
    final base = switch (_show) {
      _Show.all || _Show.direct => _items,
      _Show.unread => _items.where((c) => c.unreadCount > 0).toList(),
      _Show.groups || _Show.requests => const <Conversation>[],
    };
    final q = _filter.text.trim().toLowerCase();
    final items = q.isEmpty
        ? base
        : base
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.partner.username.toLowerCase().contains(q))
            .toList();
    if (items.isEmpty && q.isNotEmpty) {
      return EmptyState(
        icon: AppIcons.search,
        title: 'No results for "$q"',
        subtitle: 'Try searching for a different name or username.',
      );
    }
    if (items.isEmpty) return _noMessages(p);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: items.length,
      itemBuilder: (context, i) => _row(items[i], p),
    );
  }

  Widget _header(AppPalette p) {
    return ChatHeader(
      me: widget.me,
      onAvatar: widget.onOpenDrawer ?? () {},
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: newChat,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(CupertinoIcons.plus_bubble, size: 26, color: p.text),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: _modeKey,
            behavior: HitTestBehavior.opaque,
            onTap: _openModeMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: p.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _modeLabel,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.chevron_down, size: 14, color: p.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final split = FoldAwareSplit.canSplit(context);
    final selected = _selected;
    final paneWidth =
        (MediaQuery.sizeOf(context).width * 0.39).clamp(320.0, 460.0).toDouble();

    final Widget body = split
        ? FoldAwareSplit(
            primaryWidth: paneWidth,
            primary: _listBody(p),
            secondary: selected == null
                ? const SizedBox.shrink()
                : ChatView(
                    key: ValueKey(selected.id),
                    partner: selected,
                    showHeader: true,
                    onActivity: () {
                      if (mounted) _load(silent: true);
                    },
                  ),
          )
        : ContentWidth(child: _listBody(p));

    return PlainScaffold(
      floating: RoundFab(icon: CupertinoIcons.plus_bubble, onPressed: newChat),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(p),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SearchPill(
                controller: _filter,
                placeholder: 'Search',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const HairlineDivider(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
