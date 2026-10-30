import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../services/user_prefs.dart';
import 'dialog_card.dart';

/// "Welcome to Communities": shown the first time the Communities screen is
/// opened on an account.
Future<void> maybeShowCommunitiesWelcome(BuildContext context) async {
  final prefs = UserPrefs.instance;
  await prefs.load();
  if (prefs.flag('seen_communities_welcome')) return;
  if (!context.mounted) return;
  await prefs.set('seen_communities_welcome', true);
  if (!context.mounted) return;
  await showCardDialog<void>(
    context,
    maxWidth: 440,
    builder: (ctx) => const _Welcome(),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  Widget _item(AppPalette p, IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: p.text),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(
              'Welcome to Communities',
              style: TextStyle(
                color: p.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _item(
            p,
            CupertinoIcons.person_2,
            'Find your people',
            'Join Communities built around the things you care about.',
          ),
          _item(
            p,
            CupertinoIcons.chat_bubble_text,
            'Share with the group',
            'Post to a Community to reach the members who care most.',
          ),
          _item(
            p,
            CupertinoIcons.bell,
            'Stay in the loop',
            'See what members are talking about, all in one place.',
          ),
          const SizedBox(height: 16),
          DialogPillButton(
            label: 'Check it out',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
