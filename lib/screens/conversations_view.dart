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
import '../widgets/chat_context_menu.dart';
import '../widgets/chat_header.dart';
import '../widgets/group_avatar.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/note_sheets.dart';
import '../widgets/notes_strip.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/popover_menu.dart';
import '../widgets/search_pill.dart';
import '../widgets/shared_post_card.dart';
import '../widgets/state_views.dart';
import 'chat_view.dart';
import 'group_chat_view.dart';
import 'group_screens.dart';

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

enum _Show { all, unread, direct, groups, archived, requests }

/// One row of the inbox: a person or a group.
class _Chat {
  const _Chat.dm(this.dm)
      : group = null,
        isGroup = false;
  const _Chat.group(this.group)
      : dm = null,
        isGroup = true;

  final Conversation? dm;
  final GroupChat? group;
  final bool isGroup;

  String get chatId => isGroup ? group!.id : dm!.partnerId;
  String get title => isGroup ? group!.name : dm!.name;
  String? get avatarUrl => isGroup ? null : dm!.avatarUrl;
  DateTime get lastAt => isGroup ? group!.lastAt : dm!.lastAt;
  int get unread => isGroup ? group!.unreadCount : dm!.unreadCount;

  String get preview {
    if (isGroup) {
      final g = group!;
      if (g.lastMessage.isEmpty) return '${g.memberCount} members';
      final who = g.lastFromMe ? 'You' : (g.lastSenderName ?? 'Someone');
      return '$who: ${SharedPost.preview(g.lastMessage)}';
    }
    final c = dm!;
    return '${c.lastFromMe ? 'You: ' : ''}${SharedPost.preview(c.lastMessage)}';
  }
}

class ConversationsViewState extends State<ConversationsView> {
  final _filter = TextEditingController();
  final GlobalKey _modeKey = GlobalKey();
  _Show _show = _Show.all;
  List<Conversation> _items = const [];
  List<GroupChat> _groups = const [];
  Map<String, ChatPref> _prefs = const {};
  bool _loading = true;
  Object? _error;
  Profile? _selected;
  GroupChat? _selectedGroup;

  RealtimeChannel? _channel;
  RealtimeChannel? _groupChannel;
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
    _groupChannel = Api.subscribeGroupMessages((_) => _scheduleReload());
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
    final groupChannel = _groupChannel;
    if (groupChannel != null) Api.unsubscribe(groupChannel);
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
      // Groups and list options are extras: when they are not there yet
      // (database not updated) the inbox still shows the 1-to-1 chats.
      List<GroupChat> groups = const [];
      Map<String, ChatPref> prefs = const {};
      try {
        groups = await Api.fetchGroups();
      } catch (_) {}
      try {
        prefs = await Api.fetchChatPrefs();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = list;
        _groups = groups;
        _prefs = prefs;
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
    _clearUnreadFlag(partner.id);
    if (FoldAwareSplit.canSplit(context)) {
      setState(() {
        _selected = partner;
        _selectedGroup = null;
      });
    } else {
      Navigator.of(context)
          .push(appRoute(ChatScreen(partner: partner)))
          .then((_) {
        if (mounted) _load(silent: true);
      });
    }
  }

  /// Opens a group chat (page on phones, side pane on wide screens).
  void openGroup(GroupChat group) {
    _clearUnreadFlag(group.id);
    if (FoldAwareSplit.canSplit(context)) {
      setState(() {
        _selectedGroup = group;
        _selected = null;
      });
    } else {
      Navigator.of(context)
          .push(appRoute(GroupChatScreen(group: group)))
          .then((_) {
        if (mounted) _load(silent: true);
      });
    }
  }

  /// Opening a chat takes away its "marked as unread" dot.
  void _clearUnreadFlag(String chatId) {
    if (_prefs[chatId]?.markedUnread != true) return;
    _prefs = {..._prefs, chatId: _prefs[chatId]!.copyWith(markedUnread: false)};
    Api.setChatPref(chatId, markedUnread: false).catchError((_) {});
  }

  /// "New chat" card: opens the person picked, or starts a new group.
  Future<void> newChat() async {
    final picked = await showNewChatDialog(context);
    if (!mounted) return;
    if (picked is Profile) {
      openChat(picked);
    } else if (picked == NewChatChoice.group) {
      final made = await Navigator.of(context)
          .push<GroupChat>(appRoute(const CreateGroupScreen()));
      if (made != null && mounted) {
        await _load(silent: true);
        if (mounted) openGroup(made);
      }
    }
  }

  // ---- long-press menu -----------------------------------------------------

  Future<void> _setPref(
    String chatId, {
    bool? pinned,
    bool? muted,
    bool? archived,
    bool? markedUnread,
  }) async {
    final before = _prefs;
    final cur = _prefs[chatId] ?? const ChatPref();
    setState(() {
      _prefs = {
        ..._prefs,
        chatId: cur.copyWith(
          pinned: pinned,
          muted: muted,
          archived: archived,
          markedUnread: markedUnread,
        ),
      };
    });
    try {
      await Api.setChatPref(
        chatId,
        pinned: pinned,
        muted: muted,
        archived: archived,
        markedUnread: markedUnread,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = before);
      showError(context, e);
    }
  }

  Future<void> _chatMenu(_Chat c) async {
    final pref = _prefs[c.chatId] ?? const ChatPref();
    final action = await showChatContextMenu(
      context,
      personId: c.isGroup ? null : c.chatId,
      groupId: c.isGroup ? c.chatId : null,
      title: c.title,
      avatarUrl: c.avatarUrl,
      unread: c.unread > 0,
      pref: pref,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ChatMenuAction.open:
        c.isGroup ? openGroup(c.group!) : openChat(c.dm!.partner);
      case ChatMenuAction.markUnread:
        await _setPref(c.chatId, markedUnread: true);
      case ChatMenuAction.markRead:
        try {
          if (c.unread > 0) {
            c.isGroup
                ? await Api.markGroupRead(c.chatId)
                : await Api.markRead(c.chatId);
          }
          await _setPref(c.chatId, markedUnread: false);
          if (mounted) await _load(silent: true);
        } catch (e) {
          if (mounted) showError(context, e);
        }
      case ChatMenuAction.pin:
        await _setPref(c.chatId, pinned: true);
        if (mounted) showInfo(context, 'Conversation pinned');
      case ChatMenuAction.unpin:
        await _setPref(c.chatId, pinned: false);
      case ChatMenuAction.mute:
        await _setPref(c.chatId, muted: true);
        if (mounted) showInfo(context, 'Conversation muted');
      case ChatMenuAction.unmute:
        await _setPref(c.chatId, muted: false);
      case ChatMenuAction.archive:
        await _setPref(c.chatId, archived: true, pinned: false);
        if (mounted) showInfo(context, 'Conversation archived');
      case ChatMenuAction.unarchive:
        await _setPref(c.chatId, archived: false);
      case ChatMenuAction.delete:
        await _deleteChat(c);
    }
  }

  Future<void> _deleteChat(_Chat c) async {
    final ok = c.isGroup
        ? await confirm(
            context,
            title: 'Leave group?',
            message: 'You will stop getting messages from "${c.title}".',
            confirmLabel: 'Leave',
            destructive: true,
          )
        : await confirm(
            context,
            title: 'Delete conversation?',
            message: 'The messages disappear from your side only. '
                '${c.title} keeps their copy.',
            confirmLabel: 'Delete',
            destructive: true,
          );
    if (!ok || !mounted) return;
    try {
      if (c.isGroup) {
        await Api.leaveGroup(c.chatId);
      } else {
        await Api.clearConversation(c.chatId);
      }
      if (!mounted) return;
      setState(() {
        if (_selected?.id == c.chatId) _selected = null;
        if (_selectedGroup?.id == c.chatId) _selectedGroup = null;
      });
      await _load(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Everything in the inbox: people (without the ones I deleted) and
  /// groups, pinned first, then newest first.
  List<_Chat> get _allChats {
    final out = <_Chat>[];
    for (final c in _items) {
      final cleared = _prefs[c.partnerId]?.clearedAt;
      if (cleared != null && !c.lastAt.isAfter(cleared)) continue;
      out.add(_Chat.dm(c));
    }
    for (final g in _groups) {
      out.add(_Chat.group(g));
    }
    out.sort((a, b) {
      final pa = _prefs[a.chatId]?.pinned == true ? 1 : 0;
      final pb = _prefs[b.chatId]?.pinned == true ? 1 : 0;
      if (pa != pb) return pb - pa;
      return b.lastAt.compareTo(a.lastAt);
    });
    return out;
  }

  String get _modeLabel => switch (_show) {
        _Show.all => 'All',
        _Show.unread => 'Unread',
        _Show.direct => 'Direct',
        _Show.groups => 'Groups',
        _Show.archived => 'Archived',
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
          value: 'archived',
          label: 'Archived',
          icon: CupertinoIcons.archivebox,
          checked: _show == _Show.archived,
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
      case 'archived':
        setState(() => _show = _Show.archived);
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

  Widget _row(_Chat c, AppPalette p) {
    final pref = _prefs[c.chatId] ?? const ChatPref();
    final selected = c.isGroup
        ? _selectedGroup?.id == c.chatId
        : _selected?.id == c.chatId;
    final unread = c.unread > 0;
    final flagged = pref.markedUnread && !unread;
    final bold = unread || pref.markedUnread;
    final when = timeago.format(c.lastAt, locale: 'en_short');

    return Column(
      children: [
        GestureDetector(
          onTap: () => c.isGroup ? openGroup(c.group!) : openChat(c.dm!.partner),
          onLongPress: () => _chatMenu(c),
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: selected ? p.surface : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                c.isGroup
                    ? const GroupAvatar(size: 48)
                    : Avatar(url: c.avatarUrl, name: c.title, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.title,
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
                              c.isGroup
                                  ? '· $when'
                                  : '@${c.dm!.partner.username} · $when',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          ),
                          if (pref.muted) ...[
                            const SizedBox(width: 6),
                            Icon(CupertinoIcons.bell_slash_fill,
                                size: 13, color: p.subtext),
                          ],
                          if (pref.pinned) ...[
                            const SizedBox(width: 6),
                            Icon(CupertinoIcons.pin_fill,
                                size: 13, color: p.subtext),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: bold ? p.text : p.subtext,
                          fontSize: 14,
                          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
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
                      color: pref.muted ? p.subtext : p.accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${c.unread}',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else if (flagged) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: pref.muted ? p.subtext : p.accent,
                      shape: BoxShape.circle,
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
    final archived = _show == _Show.archived;
    final unreadOnly = _show == _Show.unread;
    return ScrollSafeCenter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived ? CupertinoIcons.archivebox : CupertinoIcons.chat_bubble,
              size: 56,
              color: p.text,
            ),
            const SizedBox(height: 14),
            Text(
              archived
                  ? 'No archived chats'
                  : unreadOnly
                      ? 'No unread messages'
                      : 'No Messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              archived
                  ? 'Chats you archive show up here.'
                  : unreadOnly
                      ? 'You are all caught up.'
                      : 'Start a new conversation to begin messaging.',
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

    // "Requests" has nothing yet (every message from a person who may
    // write to me lands in the normal list).
    final all = _allChats;
    bool archived(_Chat c) => _prefs[c.chatId]?.archived == true;
    final base = switch (_show) {
      _Show.all => all.where((c) => !archived(c)).toList(),
      _Show.unread => all
          .where((c) =>
              !archived(c) &&
              (c.unread > 0 || _prefs[c.chatId]?.markedUnread == true))
          .toList(),
      _Show.direct => all.where((c) => !archived(c) && !c.isGroup).toList(),
      _Show.groups => all.where((c) => !archived(c) && c.isGroup).toList(),
      _Show.archived => all.where(archived).toList(),
      _Show.requests => const <_Chat>[],
    };
    final q = _filter.text.trim().toLowerCase();
    final items = q.isEmpty
        ? base
        : base
            .where((c) =>
                c.title.toLowerCase().contains(q) ||
                (!c.isGroup &&
                    c.dm!.partner.username.toLowerCase().contains(q)))
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
    final selectedGroup = _selectedGroup;
    final paneWidth =
        (MediaQuery.sizeOf(context).width * 0.39).clamp(320.0, 460.0).toDouble();

    final Widget body = split
        ? FoldAwareSplit(
            primaryWidth: paneWidth,
            primary: _listBody(p),
            secondary: selectedGroup != null
                ? GroupChatView(
                    key: ValueKey('group-${selectedGroup.id}'),
                    group: selectedGroup,
                    showHeader: true,
                    onActivity: () {
                      if (mounted) _load(silent: true);
                    },
                    onLeft: () {
                      if (!mounted) return;
                      setState(() => _selectedGroup = null);
                      _load(silent: true);
                    },
                  )
                : selected == null
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
