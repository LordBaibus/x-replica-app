import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/account_sessions.dart';
import '../services/api.dart';
import '../widgets/settings_kit.dart';
import 'account_screens.dart';
import 'chat_settings_screens.dart';
import 'data_screens.dart';
import 'interests_edit_screen.dart';
import 'prefs_screens.dart';
import 'privacy_screens.dart';
import 'security_screens.dart';
import 'settings_extra_screens.dart';
import 'subscription_screen.dart';
import 'support_screens.dart';

/// Asks for confirmation, signs out and returns to the sign-in screen.
Future<void> logOutWithConfirm(BuildContext context) async {
  final ok = await confirm(
    context,
    title: 'Log out of ${AppConfig.appName}?',
    confirmLabel: 'Log out',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final navigator = Navigator.of(context);
  final email = Api.email;
  try {
    await Api.signOut();
    // Close Settings / any pushed pages; AuthGate shows the "Log in to X"
    // screen with every account saved on this phone.
    navigator.popUntil((route) => route.isFirst);
    await AccountSessions.afterLogout(email);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}


// ---------------------------------------------------------------------------
// Data: every settings page is a list of entries so the search box can look
// through all of them.
// ---------------------------------------------------------------------------

class SettingsEntry {
  const SettingsEntry(this.title, {this.desc, this.icon, this.open});

  final String title;
  final String? desc;
  final IconData? icon;

  /// What a tap does. null shows the "not available" message.
  final void Function(BuildContext context)? open;
}

class SettingsSection {
  const SettingsSection(this.entries, {this.title});

  final String? title;
  final List<SettingsEntry> entries;
}

void _go(BuildContext c, Widget page) =>
    Navigator.of(c).push(appRoute(page));

void _soon(BuildContext c, String title) => notify(
      c,
      title: title,
      message: 'This setting is not available in this version of '
          '${AppConfig.appName}. The page is shown so the layout matches.',
    );

class _Catalog {
  _Catalog._();

  static const accountIntro =
      'See information about your account, download an archive of your '
      'data, or learn about your account deactivation options.';
  static const securityIntro =
      'Manage your account’s security and keep track of your account’s '
      'usage including apps that you have connected to your account.';
  static const timelineIntro =
      'Configure your timeline appearance and interactions';
  static const privacyIntro = 'Manage what information you see and share on X.';
  static const notificationsIntro =
      'Select the kinds of notifications you get about your activities, '
      'interests, and recommendations.';
  static const accessibilityIntro = 'Manage how X content is displayed to you.';

  static List<SettingsEntry> top() => [
        SettingsEntry(
          'Your account',
          icon: CupertinoIcons.person,
          desc: accountIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Your account',
              intro: accountIntro,
              sections: [SettingsSection(account())],
            ),
          ),
        ),
        SettingsEntry(
          'Security and account access',
          icon: CupertinoIcons.lock,
          desc: securityIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Security and account access',
              intro: securityIntro,
              sections: [SettingsSection(security())],
            ),
          ),
        ),
        SettingsEntry(
          'Subscription',
          icon: CupertinoIcons.checkmark_seal,
          desc: 'Manage your subscription features including Undo post '
              'timing.',
          open: (c) => Navigator.of(c)
              .push(appRoute(const SubscriptionScreen(), fullscreen: true)),
        ),
        SettingsEntry(
          'Timeline',
          icon: CupertinoIcons.rectangle_stack,
          desc: timelineIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Timeline',
              intro: timelineIntro,
              sections: [SettingsSection(timeline())],
            ),
          ),
        ),
        SettingsEntry(
          'Privacy and safety',
          icon: CupertinoIcons.checkmark_shield,
          desc: privacyIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Privacy and safety',
              intro: privacyIntro,
              sections: privacy(),
            ),
          ),
        ),
        SettingsEntry(
          'Notifications',
          icon: CupertinoIcons.bell,
          desc: notificationsIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Notifications',
              intro: notificationsIntro,
              sections: [SettingsSection(notifications())],
            ),
          ),
        ),
        SettingsEntry(
          'Accessibility, display, and languages',
          icon: CupertinoIcons.person_crop_circle,
          desc: accessibilityIntro,
          open: (c) => _go(
            c,
            SettingsPage(
              title: 'Accessibility, display, and languages',
              intro: accessibilityIntro,
              sections: [SettingsSection(accessibility())],
            ),
          ),
        ),
        SettingsEntry(
          'Storage',
          icon: CupertinoIcons.device_phone_portrait,
          desc: 'Manage how X uses storage on this device. Review and clear '
              'cached media, videos, and other data.',
          open: (c) => _go(c, const StorageScreen()),
        ),
        SettingsEntry(
          'Additional resources',
          icon: CupertinoIcons.ellipsis_circle,
          desc: 'Check out other places for helpful information to learn '
              'more about X products and services.',
          open: (c) => _go(c, const AdditionalResourcesScreen()),
        ),
      ];

  static List<SettingsEntry> account() => [
        SettingsEntry(
          'Account information',
          icon: CupertinoIcons.person,
          desc: 'See your account information like your phone number and '
              'email address.',
          open: (c) => _go(c, const AccountScreen()),
        ),
        SettingsEntry(
          'Change your password',
          icon: CupertinoIcons.lock_rotation,
          desc: 'Change your password at any time.',
          open: (c) => _go(c, const UpdatePasswordScreen()),
        ),
        SettingsEntry(
          'Download an archive of your data',
          icon: CupertinoIcons.arrow_down_to_line,
          desc: 'Get insights into the type of information stored for your '
              'account.',
          open: (c) => _go(c, const DataArchiveScreen()),
        ),
        SettingsEntry(
          'Deactivate your account',
          icon: CupertinoIcons.heart_slash,
          desc: 'Find out how you can deactivate your account',
          open: (c) => _go(c, const DeactivateScreen()),
        ),
      ];

  static List<SettingsEntry> security() => [
        SettingsEntry(
          'Security',
          icon: CupertinoIcons.lock,
          desc: 'Manage your account’s security',
          open: (c) => _go(c, const SecurityScreen()),
        ),
        SettingsEntry(
          'Apps and sessions',
          icon: CupertinoIcons.square_on_square,
          desc: 'See information about when you logged into your account and '
              'the apps you connected to your account.',
          open: (c) => Navigator.of(c).push(
            appRoute(const AppsAndSessionsScreen(), fullscreen: true),
          ),
        ),
        SettingsEntry(
          'Delegate',
          icon: CupertinoIcons.person_3,
          desc: 'Manage your shared accounts.',
          open: (c) => _go(c, const DelegateScreen()),
        ),
      ];

  static List<SettingsEntry> timeline() => [
        SettingsEntry(
          'Home screen tabs',
          desc: 'Reorder your list and community tabs on the home screen',
          open: (c) async {
            try {
              final me = await Api.getProfile(Api.uid);
              if (c.mounted) _go(c, InterestsEditScreen(me: me));
            } catch (e) {
              if (c.mounted) showError(c, e);
            }
          },
        ),
      ];

  static List<SettingsSection> privacy() => [
        SettingsSection(title: 'Your X activity', [
          SettingsEntry(
            'Audience and tagging',
            icon: CupertinoIcons.person_3,
            desc: 'Manage what information you allow other people on X to see.',
            open: (c) => _go(c, const AudienceTaggingScreen()),
          ),
          SettingsEntry(
            'Your posts',
            icon: CupertinoIcons.pencil,
            desc: 'Manage the information associated with your posts.',
            open: (c) => _go(c, const YourPostsScreen()),
          ),
          SettingsEntry(
            'Content you see',
            icon: CupertinoIcons.rectangle_stack,
            desc: 'Decide what you see on X based on your preferences.',
            open: (c) => _go(c, const ContentYouSeeScreen()),
          ),
          SettingsEntry(
            'Mute and block',
            icon: CupertinoIcons.speaker_slash,
            desc: 'Manage the accounts, words, and notifications that you’ve '
                'muted or blocked.',
            open: (c) => _go(c, const MuteBlockScreen()),
          ),
          SettingsEntry(
            'Chat',
            icon: CupertinoIcons.chat_bubble,
            desc: 'Manage who can message you directly.',
            open: (c) => _go(c, const ChatSettingsScreen()),
          ),
          SettingsEntry(
            'Spaces',
            icon: CupertinoIcons.mic_circle,
            desc: 'Manage your Spaces activity',
            open: (c) => _go(c, const SpacesSettingsScreen()),
          ),
          SettingsEntry(
            'Discoverability and contacts',
            icon: CupertinoIcons.person_crop_circle_badge_exclam,
            desc: 'Control your discoverability settings and manage contacts '
                'you’ve imported.',
            open: (c) => _go(c, const DiscoverabilityScreen()),
          ),
          SettingsEntry(
            'About your account',
            icon: CupertinoIcons.globe,
            desc: 'Manage the location associated with your account',
            open: (c) => _go(c, const AboutAccountScreen()),
          ),
        ]),
        SettingsSection(title: 'Data sharing and personalization', [
          SettingsEntry(
            'Ads preferences',
            icon: CupertinoIcons.arrow_up_right_square,
            desc: 'Manage your ads experience on X.',
            open: (c) => _go(c, const AdsPreferencesScreen()),
          ),
          SettingsEntry(
            'Inferred identity',
            icon: CupertinoIcons.waveform_path_ecg,
            desc: 'Allow X to personalize your experience with your inferred '
                'activity, e.g. activity on devices you haven’t used to log '
                'in to X.',
            open: (c) => _go(c, const InferredIdentityScreen()),
          ),
          SettingsEntry(
            'Data sharing with business partners',
            icon: CupertinoIcons.arrow_right_arrow_left,
            desc: 'Allow sharing of additional information with X’s business '
                'partners.',
            open: (c) => _go(c, const DataSharingScreen()),
          ),
          SettingsEntry(
            'Location information',
            icon: CupertinoIcons.location_circle,
            desc: 'Manage the location information X uses to personalize your '
                'experience.',
            open: (c) => _go(c, const LocationInfoScreen()),
          ),
          SettingsEntry(
            'AI & Third-party Collaborators',
            icon: CupertinoIcons.sparkles,
            desc: 'Allow your public data as well as your interactions, '
                'inputs, and results with AI tools and partners to be used '
                'for training and fine-tuning.',
            open: (c) => _go(c, const GrokCollaboratorsScreen()),
          ),
        ]),
        SettingsSection(title: 'Learn more about privacy on X', [
          SettingsEntry(
            'Privacy center',
            open: (c) => _go(c, const PrivacyCenterScreen()),
          ),
          SettingsEntry(
            'Privacy policy',
            open: (c) => _go(c, const PrivacyPolicyScreen()),
          ),
          SettingsEntry(
            'Contact us',
            open: (c) => _go(c, const ContactUsScreen()),
          ),
        ]),
      ];

  static List<SettingsEntry> notifications() => [
        SettingsEntry(
          'Filters',
          icon: CupertinoIcons.slider_horizontal_3,
          desc: 'Choose the notifications you’d like to see — and those you '
              'don’t.',
          open: (c) => _go(c, const NotificationFiltersScreen()),
        ),
        SettingsEntry(
          'Preferences',
          icon: CupertinoIcons.device_phone_portrait,
          desc: 'Select your preferences by notification type.',
          open: (c) => _go(c, const NotificationPreferencesScreen()),
        ),
      ];

  static List<SettingsEntry> accessibility() => [
        SettingsEntry(
          'Accessibility',
          icon: CupertinoIcons.eye_slash,
          desc: 'Manage aspects of your X experience such as limiting color '
              'contrast and motion. These settings affect all the X accounts '
              'on this device.',
          open: (c) => _go(c, const AccessibilitySettingsScreen()),
        ),
        SettingsEntry(
          'Display',
          icon: CupertinoIcons.paintbrush,
          desc: 'Manage your font size, color and background. These settings '
              'affect all the X accounts on this device.',
          open: (c) => _go(c, const DisplayScreen()),
        ),
        SettingsEntry(
          'Languages',
          icon: CupertinoIcons.globe,
          desc: 'Manage which languages are used to personalize your X '
              'experience.',
          open: (c) => _go(c, const LanguagesScreen()),
        ),
        SettingsEntry(
          'Data usage',
          icon: CupertinoIcons.chart_bar,
          desc: 'Limit how X uses some of your network data. These settings '
              'affect all the X accounts on this device.',
          open: (c) => _go(c, const NetworkDataUsageScreen()),
        ),
      ];

  /// Pages below the main ones, so the search box finds them too.
  static List<SettingsEntry> extras() => [
        SettingsEntry('Username',
            desc: 'Change your @username',
            open: (c) => _go(c, const AccountScreen())),
        SettingsEntry('Phone',
            desc: 'Add or change your phone number',
            open: (c) => _go(c, const AccountScreen())),
        SettingsEntry('Email',
            desc: 'Change your email address',
            open: (c) => _go(c, const EmailChangeScreen())),
        SettingsEntry('Country',
            desc: 'Select the country you live in',
            open: (c) => _go(c, const CountryScreen())),
        SettingsEntry('Automation',
            desc: 'Manage your automated account',
            open: (c) => openAutomation(c)),
        SettingsEntry('Parody, commentary and fan account',
            desc: 'Manage your profile label',
            open: (c) => openPcf(c)),
        SettingsEntry('Protect your posts',
            desc: 'Only show your posts to people who follow you',
            open: (c) => _go(c, const AudienceTaggingScreen())),
        SettingsEntry('Blocked accounts',
            desc: 'Review the accounts you have blocked',
            open: (c) => _go(c, const BlockedAccountsScreen())),
        SettingsEntry('Muted accounts',
            desc: 'Review the accounts you have muted',
            open: (c) => _go(c, const MutedAccountsScreen())),
        SettingsEntry('Muted words',
            desc: 'Review the words you have muted',
            open: (c) => _go(c, const MutedWordsScreen())),
        SettingsEntry('Muted notifications',
            desc: 'Choose which notifications to mute',
            open: (c) => _go(c, const MutedNotificationsScreen())),
        SettingsEntry('Message Requests',
            desc: 'Choose who can message you',
            open: (c) => _go(c, const MessageRequestsScreen())),
        SettingsEntry('Chat passcode',
            desc: 'Create or change your Chat passcode',
            open: (c) => _go(c, const PasscodeScreen())),
        SettingsEntry('Font size and theme',
            desc: 'Day, night and text size',
            open: (c) => _go(c, const DisplayScreen())),
        SettingsEntry('Email notifications',
            desc: 'Choose the emails you get',
            open: (c) => _go(c, const EmailNotificationsScreen())),
        SettingsEntry('Sessions',
            desc: 'See where you are logged in',
            open: (c) => Navigator.of(c).push(
                appRoute(const AppsAndSessionsScreen(), fullscreen: true))),
      ];

  /// Everything the search box looks through.
  static List<SettingsEntry> everything() => [
        ...top(),
        ...account(),
        ...security(),
        ...timeline(),
        for (final s in privacy()) ...s.entries,
        ...notifications(),
        ...accessibility(),
        ...extras(),
      ];
}

SettingsRow _row(BuildContext context, SettingsEntry e) => SettingsRow(
      title: e.title,
      description: e.desc,
      icon: e.icon,
      onTap: () {
        final open = e.open;
        if (open != null) {
          open(context);
        } else {
          _soon(context, e.title);
        }
      },
    );

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

/// "Settings" (opened from "Settings and privacy"): title, search box and the
/// nine sections.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    SettingsHandle.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _searchBox(AppPalette p) {
    final showHint = _query.text.isEmpty && !_focus.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CupertinoTextField(
            controller: _query,
            focusNode: _focus,
            textAlign: TextAlign.center,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            cursorColor: p.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(30),
            ),
            style: TextStyle(color: p.text, fontSize: 18),
          ),
          if (showHint)
            IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.search, size: 20, color: p.subtext),
                  const SizedBox(width: 8),
                  Text(
                    'Search settings',
                    style: TextStyle(color: p.subtext, fontSize: 18),
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
    final q = _query.text.trim().toLowerCase();

    List<Widget> rows;
    if (q.isEmpty) {
      rows = [
        const SizedBox(height: 24),
        for (final e in _Catalog.top()) _row(context, e),
        const SizedBox(height: 40),
      ];
    } else {
      final seen = <String>{};
      final hits = _Catalog.everything()
          .where((e) =>
              (e.title.toLowerCase().contains(q) ||
                  (e.desc ?? '').toLowerCase().contains(q)) &&
              seen.add(e.title))
          .toList();
      rows = hits.isEmpty
          ? [
              const SizedBox(height: 40),
              SettingsColumn(
                child: Text(
                  'No settings match "${_query.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtext, fontSize: 16),
                ),
              ),
            ]
          : [
              const SizedBox(height: 12),
              for (final e in hits) _row(context, e),
              const SizedBox(height: 40),
            ];
    }

    return SettingsFrame(
      title: 'Settings',
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [_searchBox(p), ...rows],
      ),
    );
  }
}

/// Generic settings page: grey intro text, then rows (optionally grouped
/// under bold headings separated by full-width lines).
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<SettingsSection> sections;

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: title,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SettingsIntro(intro),
          for (final s in sections) ...[
            if (s.title != null) ...[
              const SettingsDivider(),
              SettingsSectionTitle(s.title!),
            ],
            for (final e in s.entries) _row(context, e),
          ],
        ],
      ),
    );
  }
}
