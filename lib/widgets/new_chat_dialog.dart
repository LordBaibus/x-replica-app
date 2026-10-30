import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'avatar.dart';
import 'state_views.dart';

/// What "New chat" can resolve to besides a person.
enum NewChatChoice { group }

/// The "New chat" card: search box, "Create group" and a list of people.
/// Resolves to the [Profile] that was tapped, [NewChatChoice.group] when
/// "Create group" was tapped, or null when cancelled.
Future<Object?> showNewChatDialog(BuildContext context) {
  return showGeneralDialog<Object>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, _) => const _NewChatCard(),
  );
}

class _NewChatCard extends StatefulWidget {
  const _NewChatCard();

  @override
  State<_NewChatCard> createState() => _NewChatCardState();
}

class _NewChatCardState extends State<_NewChatCard> {
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
        _people = found;
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

  Widget _createGroup(AppPalette p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(NewChatChoice.group),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: p.field, shape: BoxShape.circle),
              child: Icon(CupertinoIcons.person_3, size: 24, color: p.text),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Create group',
                style: TextStyle(
                  color: p.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: p.subtext),
          ],
        ),
      ),
    );
  }

  Widget _person(Profile u, AppPalette p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Avatar(url: u.avatarUrl, name: u.name, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${u.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.subtext, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(AppPalette p) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _search(_query.text);
        },
      );
    }
    final showGroup = _query.text.trim().isEmpty;
    final extra = showGroup ? 1 : 0;
    if (_people.isEmpty && !showGroup) {
      return Center(
        child: Text(
          'No people found',
          style: TextStyle(color: p.subtext, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _people.length + extra,
      itemBuilder: (context, i) {
        if (showGroup && i == 0) return _createGroup(p);
        return _person(_people[i - extra], p);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = (size.height - keyboard - 96).clamp(260.0, 640.0).toDouble();

    return DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 16,
        decoration: TextDecoration.none,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600, maxHeight: maxH),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              'New chat',
                              style: TextStyle(
                                color: p.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).pop(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: p.text,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CupertinoTextField(
                          controller: _query,
                          autofocus: true,
                          autocorrect: false,
                          placeholder: 'Search',
                          onChanged: (v) {
                            setState(() {});
                            _onChanged(v);
                          },
                          prefix: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Icon(
                              CupertinoIcons.search,
                              size: 20,
                              color: p.subtext,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: null,
                          cursorColor: p.accent,
                          style: TextStyle(color: p.text, fontSize: 17),
                          placeholderStyle:
                              TextStyle(color: p.subtext, fontSize: 17),
                        ),
                      ),
                      Container(height: 0.5, color: p.border),
                      Expanded(child: _list(p)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
