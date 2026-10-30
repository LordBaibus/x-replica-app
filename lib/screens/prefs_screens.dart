import 'package:adaptive_platform_ui/adaptive_platform_ui.dart' show PlatformInfo;
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/api.dart';
import '../services/display_prefs.dart';
import '../services/user_prefs.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dialog_card.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import 'account_screens.dart';
import 'privacy_screens.dart';

Future<T?> _push<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(appRoute<T>(page));

// ===========================================================================
// Notifications
// ===========================================================================

class NotificationFiltersScreen extends StatelessWidget {
  const NotificationFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Filters',
      items: [
        const PGap(8),
        const PSwitch(
          'notif_quality_filter',
          'Quality filter',
          desc: 'Filter lower-quality content from your notifications. This '
              'won’t filter notifications from people you follow or accounts '
              'you’ve interacted with recently.',
          def: true,
        ),
        const PDivider(),
        PNav(
          'Muted notifications',
          open: (c) => _push<Object?>(c, const MutedNotificationsScreen()),
        ),
      ],
    );
  }
}

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Preferences',
      items: [
        const PGap(8),
        PNav(
          'Push notifications',
          open: (c) => _push<Object?>(c, const PushNotificationsScreen()),
        ),
        PNav(
          'SMS notifications',
          open: (c) => _push<Object?>(c, const SmsNotificationsScreen()),
        ),
        PNav(
          'Email notifications',
          open: (c) => _push<Object?>(c, const EmailNotificationsScreen()),
        ),
      ],
    );
  }
}

class PushNotificationsScreen extends StatelessWidget {
  const PushNotificationsScreen({super.key});

  Widget _step(AppPalette p, int n, Widget icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(
              '$n.',
              style: TextStyle(
                color: p.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: p.text, fontSize: 17),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ios = PlatformInfo.isIOS;
    return SettingsFrame(
      title: 'Push notifications',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Turn on notifications?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                _step(
                  p,
                  1,
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.danger,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      CupertinoIcons.bell_fill,
                      size: 20,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  'Tap "Notifications"',
                ),
                _step(
                  p,
                  2,
                  IgnorePointer(
                    child: Transform.scale(
                      scale: 0.8,
                      child: const XSwitch(value: true, onChanged: null),
                    ),
                  ),
                  'Turn "Allow Notifications" on',
                ),
                const SizedBox(height: 24),
                PillAction(
                  label: ios ? 'Open iOS Settings' : 'Open Settings',
                  onPressed: () => notify(
                    context,
                    title: ios ? 'Open iOS Settings' : 'Open Settings',
                    message: 'Open your phone’s Settings, find '
                        '${AppConfig.appName}, tap Notifications and turn '
                        'Allow Notifications on.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SmsNotificationsScreen extends StatefulWidget {
  const SmsNotificationsScreen({super.key});

  @override
  State<SmsNotificationsScreen> createState() => _SmsNotificationsScreenState();
}

class _SmsNotificationsScreenState extends State<SmsNotificationsScreen> {
  String? _phone;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.getPhone();
      if (mounted) setState(() => _phone = v);
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (!_loaded) {
      return const SettingsFrame(
        title: 'SMS notifications',
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_phone != null) {
      return PrefsPage(
        title: 'SMS notifications',
        items: const [
          PGap(8),
          PSwitch(
            'sms_notifications',
            'SMS notifications',
            desc: 'Get text messages about activity on your account.',
          ),
        ],
      );
    }
    return SettingsFrame(
      title: 'SMS notifications',
      child: EmptyStateView(
        title: 'Add your phone number',
        text: 'To receive SMS notifications',
        action: PillAction(
          label: 'Add',
          onPressed: () async {
            await _push<Object?>(context, const PhoneScreen());
            _load();
          },
        ),
      ),
    );
  }
}

class EmailNotificationsScreen extends StatelessWidget {
  const EmailNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Email notifications',
      items: [
        PGap(8),
        PSwitch(
          'email_notifications',
          'Email notifications',
          desc: 'Get emails to find out what’s going on when you’re not on '
              'X. You can turn them off anytime.',
          def: true,
        ),
        PSection('Related to you and your posts'),
        PSwitch('email_new', 'New notifications', bold: false, def: true),
        PSwitch('email_chat', 'Chat', bold: false, def: true),
        PSwitch('email_posts', 'Posts emailed to you', bold: false, def: true),
        PSection('From your network'),
        PValue(
          'email_top_posts',
          'Top posts and Stories',
          options: ['Periodically', 'Daily', 'Weekly', 'Never'],
          def: 'Periodically',
        ),
        PSwitch(
          'email_performance',
          'Updates about the performance of your posts',
          bold: false,
        ),
        PSection('From X'),
        PSwitch(
          'email_news',
          'News about updates to X products and features',
          bold: false,
          def: true,
        ),
        PSwitch(
          'email_tips',
          'Tips on getting more out of X',
          bold: false,
          def: true,
        ),
        PSwitch(
          'email_missed',
          'Things you’ve missed since you last logged into X',
          bold: false,
          def: true,
        ),
        PSwitch(
          'email_partners',
          'News about X on partner products and other third-party services',
          bold: false,
        ),
        PSwitch(
          'email_surveys',
          'Participation in X research surveys',
          bold: false,
        ),
        PSwitch(
          'email_recommended',
          'Suggestions for recommended accounts',
          bold: false,
          def: true,
        ),
        PSwitch(
          'email_recent_follows',
          'Suggestions based on your recent follows',
          bold: false,
          def: true,
        ),
        PSwitch(
          'email_business',
          'Tips on X business products',
          bold: false,
        ),
      ],
    );
  }
}

// ===========================================================================
// Accessibility
// ===========================================================================

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const autoplay = ['On cellular or Wi-Fi', 'Only on Wi-Fi', 'Never'];
    return PrefsPage(
      title: 'Accessibility',
      showHandle: false,
      items: [
        const PIntro('Manage aspects of your X experience such as limiting '
            'color contrast and motion. These settings affect all the X '
            'accounts on this device.'),
        const PSection('VoiceOver'),
        const PSwitch(
          'a11y_hashtag',
          'Pronounce # as "hashtag"',
          bold: false,
        ),
        const PSwitch(
          'a11y_usernames',
          'Include usernames in timelines',
          bold: false,
        ),
        const PSwitch(
          'a11y_short_urls',
          'Read shortened URLs',
          bold: false,
        ),
        const PSection('Interaction'),
        const PValue(
          'a11y_magic_tap',
          'Magic Tap action',
          options: ['None', 'Like', 'Repost', 'Reply', 'Bookmark'],
          def: 'None',
        ),
        const PSection('Motion'),
        const PSwitch(
          'a11y_reduce_motion',
          'Reduce motion',
          desc: 'Limit the amount of in-app animation, including the live '
              'engagement counts.',
        ),
        const PValue(
          'a11y_video_autoplay',
          'Video autoplay',
          options: autoplay,
          def: 'Only on Wi-Fi',
        ),
        const PSection('Media'),
        const PSwitch(
          'a11y_image_reminder',
          'Receive image description reminder',
          desc: 'Get a reminder to add descriptions to the images you post.',
        ),
        const PSection('Sound'),
        const PSwitch(
          'a11y_spaces_sounds',
          'Sound effects in Spaces',
          bold: false,
          def: true,
        ),
        const PSection('Learn more about accessibility at X'),
        PNav(
          'Accessibility at X',
          open: (c) => notify(
            c,
            title: 'Accessibility at X',
            message: '${AppConfig.appName} has no help pages. The link is '
                'shown so the layout matches.',
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Display (real: theme + font size for the whole app)
// ===========================================================================

class DisplayScreen extends StatelessWidget {
  const DisplayScreen({super.key});

  Widget _tile(
    BuildContext context,
    AppPalette p, {
    required ThemeChoice choice,
    required String label,
    required IconData icon,
  }) {
    final selected = DisplayPrefs.instance.theme == choice;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => DisplayPrefs.instance.setTheme(choice),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? p.accent : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? p.accent : p.text),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? p.accent : p.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Display',
      showHandle: false,
      child: ListenableBuilder(
        listenable: DisplayPrefs.instance,
        builder: (context, _) {
          final p = AppPalette.of(context);
          final prefs = DisplayPrefs.instance;
          return ListView(
            padding: const EdgeInsets.only(bottom: 60),
            children: [
              const SettingsIntro(
                'Manage your font size, color and background. These settings '
                'affect all the X accounts on this device.',
              ),
              const SettingsDivider(),
              SettingsColumn(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      _tile(
                        context,
                        p,
                        choice: ThemeChoice.system,
                        label: 'System',
                        icon: CupertinoIcons.gear,
                      ),
                      _tile(
                        context,
                        p,
                        choice: ThemeChoice.day,
                        label: 'Day',
                        icon: CupertinoIcons.sun_max,
                      ),
                      _tile(
                        context,
                        p,
                        choice: ThemeChoice.night,
                        label: 'Night',
                        icon: CupertinoIcons.moon,
                      ),
                    ],
                  ),
                ),
              ),
              const SettingsDivider(),
              const SettingsSectionTitle('Font size'),
              SettingsColumn(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.border, width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview · @preview',
                              style: TextStyle(
                                color: p.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'At the heart of ${AppConfig.appName} is '
                              'conversation. Drag the slider to choose how '
                              'big the text is. It applies to the whole app '
                              'on this device.',
                              style: TextStyle(
                                color: p.text,
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SettingsColumn(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Text(
                        'Aa',
                        style: TextStyle(color: p.text, fontSize: 13),
                      ),
                      Expanded(
                        child: CupertinoSlider(
                          value: prefs.fontStep.toDouble(),
                          min: 0,
                          max: (DisplayPrefs.fontScales.length - 1).toDouble(),
                          divisions: DisplayPrefs.fontScales.length - 1,
                          activeColor: p.accent,
                          onChanged: (v) => prefs.setFontStep(v.round()),
                        ),
                      ),
                      Text(
                        'Aa',
                        style: TextStyle(color: p.text, fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Languages
// ===========================================================================

const List<String> kLanguages = [
  'English',
  'Tagalog',
  'Amharic - አማርኛ',
  'Arabic - العربية',
  'Armenian - հայերեն',
  'Bangla - বাংলা',
  'Basque - euskara',
  'Bulgarian - български',
  'Burmese - မြန်မာ',
  'Catalan - català',
  'Central Kurdish - کوردیی ناوەندی',
  'Chinese - 中文',
  'Czech - čeština',
  'Danish - dansk',
  'Dutch - Nederlands',
  'Finnish - suomi',
  'French - français',
  'German - Deutsch',
  'Greek - Ελληνικά',
  'Hebrew - עברית',
  'Hindi - हिन्दी',
  'Hungarian - magyar',
  'Indonesian - Indonesia',
  'Italian - italiano',
  'Japanese - 日本語',
  'Korean - 한국어',
  'Malay - Melayu',
  'Norwegian - norsk',
  'Persian - فارسی',
  'Polish - polski',
  'Portuguese - português',
  'Romanian - română',
  'Russian - русский',
  'Spanish - español',
  'Swedish - svenska',
  'Thai - ไทย',
  'Turkish - Türkçe',
  'Ukrainian - українська',
  'Urdu - اردو',
  'Vietnamese - Tiếng Việt',
];

class LanguagesScreen extends StatelessWidget {
  const LanguagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Languages',
      showHandle: false,
      items: [
        const PIntro('Manage which languages are used to personalize your X '
            'experience.'),
        const PDivider(),
        PNav(
          'Content languages',
          desc: 'Select the languages you want to see posts, people and '
              'trends in.',
          open: (c) => showCardDialog<void>(
            c,
            maxWidth: 480,
            builder: (ctx) => const _LanguageDialog(),
          ),
        ),
      ],
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: UserPrefs.instance,
      builder: (context, _) {
        final prefs = UserPrefs.instance;
        var chosen = prefs.strings('content_languages');
        if (chosen.isEmpty) chosen = ['English'];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandMark(size: 30),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(CupertinoIcons.xmark, size: 22, color: p.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select language',
              style: TextStyle(
                color: p.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You’ll be able to see posts, people, and trends in any '
              'languages you choose.',
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final lang in kLanguages)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lang,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          XSwitch(
                            value: chosen.contains(lang),
                            onChanged: (v) {
                              final next = [...chosen];
                              if (v) {
                                if (!next.contains(lang)) next.add(lang);
                              } else {
                                if (next.length == 1) return;
                                next.remove(lang);
                              }
                              prefs.set('content_languages', next);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DialogPillButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Data usage (network)
// ===========================================================================

class NetworkDataUsageScreen extends StatelessWidget {
  const NetworkDataUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const options = ['On cellular or Wi-Fi', 'Only on Wi-Fi', 'Never'];
    return PrefsPage(
      title: 'Data usage',
      showHandle: false,
      items: [
        const PIntro('Limit how X uses some of your network data. These '
            'settings affect all the X accounts on this device.'),
        const PDivider(),
        const PSwitch(
          'data_saver',
          'Data saver',
          desc: 'When on, images and videos load at lower quality and videos '
              'do not play on their own. This only changes how much data '
              'this device uses.',
        ),
        const PDivider(),
        const PValue(
          'data_hq_images',
          'High-quality images',
          options: options,
          def: 'Only on Wi-Fi',
          desc: 'Choose when higher-quality images are loaded.',
        ),
        const PValue(
          'data_hq_uploads',
          'High-quality image uploads',
          options: options,
          def: 'Never',
          desc: 'Choose when you upload images in higher quality. It uses '
              'more data.',
        ),
        const PValue(
          'data_hq_video',
          'High-quality video',
          options: options,
          def: 'Only on Wi-Fi',
          desc: 'Choose when higher-quality video is played.',
        ),
        const PValue(
          'data_video_autoplay',
          'Video autoplay',
          options: options,
          def: 'Only on Wi-Fi',
          desc: 'Choose when videos start playing on their own.',
        ),
      ],
    );
  }
}
