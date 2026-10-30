import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';

/// "Add/remove from Lists": my lists with a check mark for the ones the
/// account is already in. Tapping a row adds or removes the account.
Future<void> showListsSheet(
  BuildContext context, {
  required String userId,
  required String handle,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _ListsSheet(userId: userId, handle: handle),
  );
}

class _ListsSheet extends StatefulWidget {
  const _ListsSheet({required this.userId, required this.handle});

  final String userId;
  final String handle;

  @override
  State<_ListsSheet> createState() => _ListsSheetState();
}

class _ListsSheetState extends State<_ListsSheet> {
  List<UserList> _lists = const [];
  final Set<String> _in = {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await Api.fetchMyLists();
      final members = await Future.wait([
        for (final l in lists) Api.fetchListMembers(l.id),
      ]);
      if (!mounted) return;
      setState(() {
        _lists = lists;
        for (var i = 0; i < lists.length; i++) {
          if (members[i].any((m) => m.id == widget.userId)) {
            _in.add(lists[i].id);
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggle(UserList l) async {
    final add = !_in.contains(l.id);
    setState(() => add ? _in.add(l.id) : _in.remove(l.id));
    try {
      await Api.setListMember(l.id, widget.userId, add: add);
    } catch (e) {
      if (!mounted) return;
      setState(() => add ? _in.remove(l.id) : _in.add(l.id));
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: CupertinoActivityIndicator(),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          friendlyError(_error!),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 15),
        ),
      );
    } else if (_lists.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'You don’t have any Lists yet. Create one from the Lists page.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 15),
        ),
      );
    } else {
      body = ListView(
        shrinkWrap: true,
        children: [
          for (final l in _lists)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggle(l),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _in.contains(l.id)
                            ? p.accent
                            : const Color(0x00000000),
                        border: Border.all(
                          color: _in.contains(l.id) ? p.accent : p.subtext,
                          width: 1.5,
                        ),
                      ),
                      child: _in.contains(l.id)
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
            ),
        ],
      );
    }

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
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: media.size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: media.padding.bottom + 8),
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
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add/remove ${widget.handle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(36, 36),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: p.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: p.border),
              Flexible(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
