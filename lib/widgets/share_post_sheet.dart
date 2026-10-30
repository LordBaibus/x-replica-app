import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/chat_view.dart';
import '../screens/people_view.dart';
import '../services/api.dart';
import 'avatar.dart';
import 'badges.dart';
import 'post_menus.dart';

/// The "Share post" sheet: search + people to send the post to as a message,
/// and Copy Link / Share via... / Messages at the bottom.
Future<void> showSharePostSheet(BuildContext context, Post post) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _ShareSheet(post: post, parent: context),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.post, required this.parent});

  final Post post;
  final BuildContext parent;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<Profile> _suggested = const [];
  List<Profile>? _found;
  final List<Profile> _picked = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final list = await Api.shareTargets();
      if (!mounted) return;
      setState(() {
        _suggested = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    final text = q.trim();
    if (text.isEmpty) {
      setState(() => _found = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final list = await Api.searchProfiles(text);
        if (!mounted || _search.text.trim() != text) return;
        setState(() => _found = list.where((x) => x.id != Api.uid).toList());
      } catch (_) {}
    });
  }

  bool _isPicked(Profile p) => _picked.any((x) => x.id == p.id);

  void _toggle(Profile p) {
    setState(() {
      if (_isPicked(p)) {
        _picked.removeWhere((x) => x.id == p.id);
      } else {
        _picked.add(p);
      }
    });
  }

  Future<void> _copy() async {
    final parent = widget.parent;
    Navigator.of(context).pop();
    if (parent.mounted) await copyPostLink(parent, widget.post);
  }

  Future<void> _messages() async {
    final parent = widget.parent;
    final post = widget.post;
    if (post.userId != Api.uid) Api.logPostEvent(post.id, 'share');
    Navigator.of(context).pop();
    if (!parent.mounted) return;
    final picked = await Navigator.of(parent)
        .push<Profile>(appRoute(const PeoplePickScreen()));
    if (picked != null && parent.mounted) {
      Navigator.of(parent).push(
        appRoute(ChatScreen(partner: picked, initialText: postLink(post))),
      );
    }
  }

  Future<void> _send() async {
    if (_picked.isEmpty || _sending) return;
    setState(() => _sending = true);
    final parent = widget.parent;
    final link = postLink(widget.post);
    if (widget.post.userId != Api.uid) Api.logPostEvent(widget.post.id, 'share');
    var failed = 0;
    for (final p in _picked) {
      try {
        await Api.sendMessage(p.id, link);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!parent.mounted) return;
    if (failed == 0) {
      showSuccess(parent, 'Sent');
    } else if (failed == _picked.length) {
      showError(parent, 'Could not send. They may not accept messages.');
    } else {
      showInfo(parent, 'Sent, but $failed could not be reached');
    }
  }

  Widget _row(AppPalette p, Profile who) {
    final on = _isPicked(who);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(who),
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

  Widget _target(
    AppPalette p, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.field),
              child: Icon(icon, size: 24, color: p.text),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.text,
                fontSize: 13,
                decoration: TextDecoration.none,
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
    final media = MediaQuery.of(context);
    final shown = _found ?? _suggested;
    final height = media.size.height * 0.72;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 560, maxHeight: height),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(CupertinoIcons.search, size: 18, color: p.subtext),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _search,
                          onChanged: _onSearch,
                          placeholder: 'Search',
                          placeholderStyle:
                              TextStyle(color: p.subtext, fontSize: 16),
                          style: TextStyle(color: p.text, fontSize: 16),
                          decoration: null,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: CupertinoActivityIndicator(),
                      )
                    : shown.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              _found == null
                                  ? 'Search for someone to send this post to.'
                                  : 'No people found.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 8),
                            children: [for (final who in shown) _row(p, who)],
                          ),
              ),
              Container(height: 0.5, color: p.border),
              if (_picked.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _target(
                        p,
                        icon: CupertinoIcons.link,
                        label: 'Copy Link',
                        onTap: _copy,
                      ),
                      _target(
                        p,
                        icon: CupertinoIcons.share,
                        label: 'Share via...',
                        onTap: _copy,
                      ),
                      _target(
                        p,
                        icon: CupertinoIcons.chat_bubble_fill,
                        label: 'Messages',
                        onTap: _messages,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _send,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _sending
                          ? const CupertinoActivityIndicator(
                              color: Color(0xFFFFFFFF),
                            )
                          : Text(
                              _picked.length == 1
                                  ? 'Send'
                                  : 'Send separately',
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
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
