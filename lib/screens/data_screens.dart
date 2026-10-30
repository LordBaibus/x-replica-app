import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/api.dart';
import '../services/grok_history.dart';
import '../services/user_prefs.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import 'account_screens.dart';

Future<T?> _push<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(appRoute<T>(page));

// ===========================================================================
// Spaces
// ===========================================================================

class SpacesSettingsScreen extends StatelessWidget {
  const SpacesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Spaces',
      items: [
        const PIntro('Manage your Spaces activity'),
        const PSwitch(
          'spaces_show_listening',
          'Allow followers to see which Spaces you’re listening to',
          desc: 'Your followers will see the Spaces you are listening to in '
              'their timeline. ',
          link: 'Learn more',
          def: true,
        ),
        const PDivider(),
        PNav(
          'Manage your Spaces recording history',
          desc: 'Share, listen to, or delete your past recordings',
          open: (c) => _push<Object?>(c, const SpacesRecordingHistoryScreen()),
        ),
        PNav(
          'Manage your scheduled Spaces',
          desc: 'Share, edit, or cancel your scheduled Spaces',
          open: (c) => _push<Object?>(c, const ScheduledSpacesScreen()),
        ),
      ],
    );
  }
}

class ScheduledSpacesScreen extends StatelessWidget {
  const ScheduledSpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Manage your scheduled Spaces',
      headerDivider: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: p.surface,
            padding: const EdgeInsets.all(18),
            child: Text(
              'Here are all the Spaces you’ve scheduled. You can edit and '
              'share them, or cancel.',
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
            ),
          ),
          const Expanded(
            child: EmptyStateView(
              title: 'No scheduled Spaces',
              text: 'Spaces you schedule will show up here.',
            ),
          ),
        ],
      ),
    );
  }
}

class SpacesRecordingHistoryScreen extends StatelessWidget {
  const SpacesRecordingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Recording history',
      headerDivider: true,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: p.surface,
            padding: const EdgeInsets.all(18),
            child: LinkText(
              'Here are all the Spaces you’ve recorded. You can share, '
              'listen to, or delete them. Keep in mind that X will always '
              'keep a copy of each Space for at least 30 days after a Space '
              'has ended. ',
              link: 'Learn more',
            ),
          ),
          const Expanded(
            child: EmptyStateView(
              title: 'No recordings',
              text: 'Spaces you record will show up here.',
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Discoverability and contacts
// ===========================================================================

class DiscoverabilityScreen extends StatefulWidget {
  const DiscoverabilityScreen({super.key});

  @override
  State<DiscoverabilityScreen> createState() => _DiscoverabilityScreenState();
}

class _DiscoverabilityScreenState extends State<DiscoverabilityScreen> {
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      final v = await Api.getPhone();
      if (mounted) setState(() => _phone = v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Discoverability and contacts',
      child: ListenableBuilder(
        listenable: UserPrefs.instance,
        builder: (context, _) {
          final prefs = UserPrefs.instance;
          final hasPhone = _phone != null;
          return ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [
              const SettingsIntro(
                'Control your discoverability settings and manage contacts '
                'you’ve imported.',
              ),
              const SettingsDivider(),
              const SettingsSectionTitle('Discoverability'),
              SwitchRow(
                title: 'Let others find you by your email',
                description: 'Let people who have your email address find '
                    'and connect with you.',
                value: prefs.flag('find_by_email', true),
                onChanged: (v) => prefs.set('find_by_email', v),
              ),
              SwitchRow(
                title: 'Let others find you by your phone',
                description: hasPhone
                    ? 'Let people who have your phone number find and '
                        'connect with you.'
                    : 'You need to add a phone number for this setting. ',
                link: hasPhone ? null : 'Add now',
                onLink: hasPhone
                    ? null
                    : () async {
                        await _push<Object?>(
                          context,
                          PhoneScreen(existing: _phone),
                        );
                        _loadPhone();
                      },
                value: hasPhone && prefs.flag('find_by_phone'),
                onChanged: hasPhone
                    ? (v) => prefs.set('find_by_phone', v)
                    : null,
              ),
              const SettingsDivider(),
              const SettingsSectionTitle('Contacts'),
              SwitchRow(
                title: 'Sync address book contacts',
                description: 'Sync your contacts to find people you know and '
                    'get better suggestions. ',
                link: 'Learn more',
                value: prefs.flag('sync_contacts'),
                onChanged: (v) => prefs.set('sync_contacts', v),
              ),
              CenterAction(
                text: 'Remove all contacts',
                description: 'This removes the contacts you imported. People '
                    'you follow stay the same.',
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: 'Remove all contacts?',
                    message: 'This removes the contacts you imported.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await prefs.set('sync_contacts', false);
                  if (context.mounted) {
                    showSuccess(context, 'Contacts removed.');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// About your account
// ===========================================================================

class AboutAccountScreen extends StatelessWidget {
  const AboutAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'About your account',
      items: [
        const PGap(8),
        const PSection('Privacy Settings'),
        const PNote('You can choose to show region or country as your '
            'account location'),
        const PRadio('account_location', 'Use Region / Continent', 'region'),
        const PRadio(
          'account_location',
          'Use Country',
          'country',
          isDefault: true,
        ),
        PAction(
          'Report a problem',
          color: AppPalette.light.accent,
          run: (c) async => notify(
            c,
            title: 'Report a problem',
            message: 'Thanks! Reporting is not connected in this version of '
                '${AppConfig.appName}.',
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Ads, inferred identity, data sharing, location
// ===========================================================================

void _seeData(BuildContext c) => notify(
      c,
      title: 'See your X data',
      message: 'Your data download is not available in this version of '
          '${AppConfig.appName}.',
    );

class AdsPreferencesScreen extends StatelessWidget {
  const AdsPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Ads preferences',
      items: [
        const PIntro('Manage your ads experience on X.'),
        const PSwitch(
          'ads_personalized',
          'Personalized ads',
          desc: 'You will always see some ads on X, but when personalized '
              'ads is turned on, X may show you ads based on your activity. ',
          link: 'Learn more',
          def: true,
        ),
        const PDivider(),
        PNav('See your X data', open: _seeData),
      ],
    );
  }
}

class InferredIdentityScreen extends StatelessWidget {
  const InferredIdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Inferred identity',
      items: [
        PGap(8),
        PSwitch(
          'inferred_identity',
          'Personalize based on your inferred identity',
          desc: 'Allow X to personalize your experience with your inferred '
              'activity, e.g. activity on devices you haven’t used to log in '
              'to X.',
          def: true,
        ),
      ],
    );
  }
}

class DataSharingScreen extends StatelessWidget {
  const DataSharingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Data sharing with business partners',
      items: [
        PGap(8),
        PSwitch(
          'partner_sharing',
          'Allow additional information sharing with business partners',
          desc: 'X may share extra information with its business partners to '
              'help them show you more relevant content. ',
          link: 'Learn more',
        ),
        PSwitch(
          'youtube_inline',
          'Allow videos from YouTube to play inline',
          desc: 'Videos from YouTube are subject to the YouTube ',
          link: 'Terms of Service',
          after: ' and Privacy Policy.',
          def: true,
        ),
      ],
    );
  }
}

class LocationInfoScreen extends StatelessWidget {
  const LocationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Location information',
      items: [
        const PGap(8),
        const PSwitch(
          'location_personalize',
          'Personalize based on places you’ve been',
          desc: 'X always uses some information, like where you signed up '
              'and your current location, to help show you more relevant '
              'content. When this setting is enabled, X may also personalize '
              'based on other places you’ve been. ',
          link: 'Learn more',
          def: true,
        ),
        const PDivider(),
        PNav(
          'Approximate location',
          value: 'Enabled',
          desc: 'This is the approximate location X uses to show you content '
              'near you. It is based on your connection.',
          open: (c) => notify(
            c,
            title: 'Approximate location',
            message: 'Approximate location is always on in this version of '
                '${AppConfig.appName}.',
          ),
        ),
        const PDivider(),
        PNav('See your X data', open: _seeData),
      ],
    );
  }
}

// ===========================================================================
// Grok & Third-party Collaborators
// ===========================================================================

class GrokCollaboratorsScreen extends StatelessWidget {
  const GrokCollaboratorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Grok & Third-party Collaborators',
      items: [
        const PGap(8),
        const PSwitch(
          'grok_training',
          'Allow your public data as well as your interactions, inputs, and '
              'results with Grok and xAI to be used for training and '
              'fine-tuning.',
          desc: 'This also means your data may be used to train and improve '
              'AI models. ',
          link: 'Learn more',
          def: true,
        ),
        const PSwitch(
          'grok_personalize',
          'Allow X to personalize your experience with Grok',
          desc: 'Grok can use your profile and activity to give you more '
              'relevant answers. ',
          link: 'Learn more',
          def: true,
        ),
        const PSwitch(
          'grok_remember',
          'Allow Grok to remember your conversation history',
          desc: 'Turn this off and new Grok conversations are not saved. ',
          link: 'Learn more',
          def: true,
        ),
        const PDivider(),
        PAction(
          'Delete conversation history',
          run: (c) async {
            final ok = await confirm(
              c,
              title: 'Delete conversation history?',
              message: 'All your saved Grok conversations on this device '
                  'will be deleted.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!ok || !c.mounted) return;
            try {
              await GrokHistory.clearAll();
              if (c.mounted) showSuccess(c, 'Conversation history deleted.');
            } catch (e) {
              if (c.mounted) showError(c, e);
            }
          },
        ),
      ],
    );
  }
}
