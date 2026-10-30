import 'package:flutter/cupertino.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../services/account_sessions.dart';
import '../services/api.dart';
import '../services/saved_accounts.dart';
import 'avatar.dart';

/// What the person picked in the account switcher.
enum AccountsAction { switchTo, addExisting, createNew }

class AccountsChoice {
  const AccountsChoice(this.action, [this.account]);

  final AccountsAction action;
  final SavedAccount? account;
}

/// "Accounts": the accounts saved on this phone (tap to switch, long-press to
/// remove), plus "Add an existing account" and "Create a new account".
Future<AccountsChoice?> showAccountsSheet(BuildContext context) async {
  final accounts = await AccountSessions.switchable();
  if (!context.mounted) return null;
  return showCupertinoModalPopup<AccountsChoice>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _AccountsSheet(initial: accounts),
  );
}

class _AccountsSheet extends StatefulWidget {
  const _AccountsSheet({required this.initial});

  final List<SavedAccount> initial;

  @override
  State<_AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<_AccountsSheet> {
  late List<SavedAccount> _accounts = widget.initial;

  bool _isCurrent(SavedAccount a) =>
      a.email.toLowerCase() == Api.email.toLowerCase();

  Future<void> _remove(SavedAccount a) async {
    if (_isCurrent(a)) return;
    final ok = await confirm(
      context,
      title: 'Remove ${a.name}?',
      message:
          'It will no longer be listed here. You can add it again with its password.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await SavedAccounts.remove(a.email);
    final next = await AccountSessions.switchable();
    if (mounted) setState(() => _accounts = next);
  }

  Widget _row(AppPalette p, SavedAccount a) {
    final current = _isCurrent(a);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(
        current ? null : AccountsChoice(AccountsAction.switchTo, a),
      ),
      onLongPress: current ? null : () => _remove(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Avatar(url: a.avatarUrl, name: a.name, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    '@${a.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.subtext,
                      fontSize: 15,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (current)
              Icon(CupertinoIcons.check_mark_circled_solid,
                  size: 26, color: p.accent)
            else
              Icon(CupertinoIcons.circle, size: 26, color: p.subtext),
          ],
        ),
      ),
    );
  }

  Widget _action(AppPalette p, IconData icon, String label, AccountsAction a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(AccountsChoice(a)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: p.text),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
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
    final media = MediaQuery.of(context);
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
            maxHeight: media.size.height * 0.75,
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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Text(
                      'Accounts',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in _accounts) _row(p, a),
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: p.border,
                    ),
                    _action(
                      p,
                      CupertinoIcons.person_crop_circle_badge_plus,
                      'Add an existing account',
                      AccountsAction.addExisting,
                    ),
                    _action(
                      p,
                      AppIcons.person,
                      'Create a new account',
                      AccountsAction.createNew,
                    ),
                    if (_accounts.length > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                        child: Text(
                          'Tap an account to switch. Press and hold to remove it from this phone.',
                          style: TextStyle(color: p.subtext, fontSize: 13),
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
