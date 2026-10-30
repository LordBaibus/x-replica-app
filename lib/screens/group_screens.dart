import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/app_text_field.dart';
import '../widgets/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/group_avatar.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'profile_view.dart';

/// Search box + people with a check circle. The parts above the search box
/// ([header]) scroll together with the list, so nothing overflows when the
/// keyboard is open or the phone is small.
class PeopleChecklist extends StatefulWidget {
  const PeopleChecklist({
    super.key,
    required this.selected,
    required this.onToggle,
    this.header = const [],
    this.exclude = const {},
  });

  /// Picked people (id -> profile).
  final Map<String, Profile> selected;
  final ValueChanged<Profile> onToggle;
  final List<Widget> header;

  /// People who are already in the group.
  final Set<String> exclude;

  @override
  State<PeopleChecklist> createState() => _PeopleChecklistState();
}

class _PeopleChecklistState extends State<PeopleChecklist> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Profile> _people = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
  }

  Future<void> _search(String q) async {
    try {
      final found = await Api.searchProfiles(q);
      if (!mounted || q.trim() != _query.text.trim()) return;
      setState(() {
        _people = found.where((x) => !widget.exclude.contains(x.id)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Widget _row(AppPalette p, Profile who) {
    final on = widget.selected.containsKey(who.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onToggle(who),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Avatar(
              url: who.avatarUrl,
              name: who.name,
              size: 44,
              square: Avatar.isSquare(who.verified),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NameWithBadge(
                    name: who.name,
                    verified: who.verified,
                    locked: who.protectedPosts,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${who.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? p.accent : const Color(0x00000000),
                border: Border.all(
                  color: on ? p.accent : p.subtext,
                  width: 1.5,
                ),
              ),
              child: on
                  ? const Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 16,
                      color: Color(0xFFFFFFFF),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CupertinoActivityIndicator()),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          friendlyError(_error!),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.danger, fontSize: 15),
        ),
      );
    } else if (_people.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'No people found',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 15),
        ),
      );
    } else {
      body = Column(children: [for (final u in _people) _row(p, u)]);
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...widget.header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: AppTextField(
            controller: _query,
            placeholder: 'Search people',
            autocorrect: false,
            onChanged: _onChanged,
            prefixIcon: Icon(AppIcons.search, size: 18, color: p.subtext),
          ),
        ),
        body,
      ],
    );
  }
}

/// Little chips with the picked people (tap ✕ to remove).
Widget pickedChips(
  AppPalette p,
  Map<String, Profile> selected,
  ValueChanged<Profile> onRemove,
) {
  if (selected.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final u in selected.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onRemove(u),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Avatar(url: u.avatarUrl, name: u.name, size: 24),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(AppIcons.close, size: 14, color: p.subtext),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// New group
// ---------------------------------------------------------------------------

/// Name the group, pick the people, create it. Pops with the new
/// [GroupChat] (so the inbox can open it right away).
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final Map<String, Profile> _picked = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggle(Profile u) {
    setState(() {
      if (_picked.remove(u.id) == null) {
        if (_picked.length >= 49) {
          showInfo(context, 'A group can have up to 50 people.');
          return;
        }
        _picked[u.id] = u;
      }
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showInfo(context, 'Give the group a name.');
      return;
    }
    if (_picked.isEmpty) {
      showInfo(context, 'Pick at least one person.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final id = await Api.createGroup(name, _picked.keys.toList());
      if (!mounted) return;
      Navigator.of(context).pop(
        GroupChat(
          id: id,
          name: name,
          memberCount: _picked.length + 1,
          lastMessage: '',
          lastAt: DateTime.now(),
          lastFromMe: false,
          lastSenderName: null,
          unreadCount: 0,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'New group'),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 560,
          child: Column(
            children: [
              Expanded(
                child: PeopleChecklist(
                  selected: _picked,
                  onToggle: _toggle,
                  header: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: AppTextField(
                        controller: _name,
                        placeholder: 'Group name',
                        maxLength: 50,
                        textCapitalization: TextCapitalization.sentences,
                        prefixIcon: Icon(
                          CupertinoIcons.person_3,
                          size: 18,
                          color: p.subtext,
                        ),
                      ),
                    ),
                    pickedChips(p, _picked, _toggle),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: AdaptiveButton(
                    color: p.accent,
                    textColor: const Color(0xFFFFFFFF),
                    onPressed: _busy ? null : _create,
                    enabled: !_busy,
                    label: _busy
                        ? 'Creating…'
                        : _picked.isEmpty
                            ? 'Create group'
                            : 'Create group (${_picked.length + 1})',
                    style: AdaptiveButtonStyle.filled,
                    size: AdaptiveButtonSize.large,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add people
// ---------------------------------------------------------------------------

/// Pick more people for an existing group. Pops with true when people were
/// added.
class AddMembersScreen extends StatefulWidget {
  const AddMembersScreen({
    super.key,
    required this.groupId,
    required this.existing,
  });

  final String groupId;
  final Set<String> existing;

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final Map<String, Profile> _picked = {};
  bool _busy = false;

  void _toggle(Profile u) {
    setState(() {
      if (_picked.remove(u.id) == null) _picked[u.id] = u;
    });
  }

  Future<void> _add() async {
    if (_picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.addGroupMembers(widget.groupId, _picked.keys.toList());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Add people'),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 560,
          child: Column(
            children: [
              Expanded(
                child: PeopleChecklist(
                  selected: _picked,
                  onToggle: _toggle,
                  exclude: widget.existing,
                  header: [pickedChips(p, _picked, _toggle)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: AdaptiveButton(
                    color: p.accent,
                    textColor: const Color(0xFFFFFFFF),
                    onPressed: _busy || _picked.isEmpty ? null : _add,
                    enabled: !_busy && _picked.isNotEmpty,
                    label: _busy ? 'Adding…' : 'Add (${_picked.length})',
                    style: AdaptiveButtonStyle.filled,
                    size: AdaptiveButtonSize.large,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group info
// ---------------------------------------------------------------------------

/// Name, members and "Leave group". Pops with 'left' when I left the group,
/// 'changed' when the name or people changed.
class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.name,
  });

  final String groupId;
  final String name;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late String _name = widget.name;
  List<GroupMember> _members = const [];
  bool _loading = true;
  bool _changed = false;
  Object? _error;

  bool get _iAmAdmin =>
      _members.any((m) => m.userId == Api.uid && m.isAdmin);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.fetchGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _close([String? result]) =>
      Navigator.of(context).pop(result ?? (_changed ? 'changed' : null));

  Future<void> _rename() async {
    final c = TextEditingController(text: _name);
    final newName = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Group name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: c,
            autofocus: true,
            maxLength: 50,
            placeholder: 'Group name',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (newName == null || newName.isEmpty || newName == _name || !mounted) {
      return;
    }
    try {
      await Api.renameGroup(widget.groupId, newName);
      if (!mounted) return;
      setState(() {
        _name = newName;
        _changed = true;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      appRoute(
        AddMembersScreen(
          groupId: widget.groupId,
          existing: {for (final m in _members) m.userId},
        ),
      ),
    );
    if (added == true && mounted) {
      _changed = true;
      _load();
    }
  }

  Future<void> _remove(GroupMember m) async {
    final ok = await confirm(
      context,
      title: 'Remove ${m.name}?',
      message: 'They will no longer see this group.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.removeGroupMember(widget.groupId, m.userId);
      if (!mounted) return;
      _changed = true;
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      title: 'Leave group?',
      message: 'You will stop getting messages from "$_name".',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.leaveGroup(widget.groupId);
      if (mounted) _close('left');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _memberRow(AppPalette p, GroupMember m) {
    final isMe = m.userId == Api.uid;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isMe
          ? null
          : () => Navigator.of(context)
              .push(appRoute(ProfileScreen(userId: m.userId))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Avatar(url: m.avatarUrl, name: m.name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '${m.name} (you)' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${m.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (m.isAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: p.subtext,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (_iAmAdmin && !isMe)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _remove(m),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    CupertinoIcons.minus_circle,
                    size: 22,
                    color: p.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    AppPalette p,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final c = color ?? p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 20),
          const Center(child: GroupAvatar(size: 84)),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _iAmAdmin ? _rename : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_iAmAdmin) ...[
                    const SizedBox(width: 8),
                    Icon(CupertinoIcons.pencil, size: 18, color: p.subtext),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${_members.length} ${_members.length == 1 ? 'member' : 'members'}',
              style: TextStyle(color: p.subtext, fontSize: 15),
            ),
          ),
          const SizedBox(height: 14),
          const HairlineDivider(),
          if (_iAmAdmin)
            _action(p, CupertinoIcons.person_add, 'Add people', _add),
          for (final m in _members) _memberRow(p, m),
          const SizedBox(height: 8),
          const HairlineDivider(),
          _action(
            p,
            CupertinoIcons.square_arrow_left,
            'Leave group',
            _leave,
            color: p.danger,
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AdaptiveScaffold(
        backgroundColor: p.background,
        appBar: const AdaptiveAppBar(title: 'Group info'),
        body: SafeArea(child: ContentWidth(maxWidth: 560, child: body)),
      ),
    );
  }
}
