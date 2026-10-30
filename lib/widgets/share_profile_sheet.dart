import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../screens/onboarding_kit.dart' show BlackButton;
import '../screens/people_view.dart';
import '../screens/chat_view.dart';

/// The sheet that opens from "Share Profile": a "Chat Required" message on
/// top and a row of share targets below, like on X.
Future<void> showShareProfileSheet(BuildContext context, Profile profile) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _ShareSheet(profile: profile, parent: context),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.profile, required this.parent});

  final Profile profile;
  final BuildContext parent;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '@${profile.username}'));
    if (context.mounted) Navigator.of(context).pop();
    if (parent.mounted) showInfo(parent, 'Copied @${profile.username}');
  }

  Future<void> _message(BuildContext context) async {
    Navigator.of(context).pop();
    if (!parent.mounted) return;
    final picked = await Navigator.of(parent)
        .push<Profile>(appRoute(const PeoplePickScreen()));
    if (picked != null && parent.mounted) {
      Navigator.of(parent).push(appRoute(ChatScreen(partner: picked)));
    }
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
        width: 84,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: p.text),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return DefaultTextStyle(
      style: TextStyle(
        color: p.text,
        fontSize: 15,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: p.subtext.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.chat_bubble, size: 54, color: p.text),
                      const SizedBox(height: 18),
                      Text(
                        'Chat Required',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Before you can share with others, you will need to '
                        'finish setting up Chat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.subtext,
                          fontSize: 17,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 28),
                      BlackButton(
                        label: 'Set up',
                        onPressed: () => _message(context),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.border, width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _target(
                          p,
                          icon: CupertinoIcons.link,
                          label: 'Copy Link',
                          onTap: () => _copy(context),
                        ),
                        _target(
                          p,
                          icon: CupertinoIcons.share,
                          label: 'Share via...',
                          onTap: () => _copy(context),
                        ),
                        _target(
                          p,
                          icon: CupertinoIcons.chat_bubble_fill,
                          label: 'Messages',
                          onTap: () => _message(context),
                        ),
                      ],
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
