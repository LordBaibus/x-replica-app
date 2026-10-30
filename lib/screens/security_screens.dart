import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/session_tracker.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import '../widgets/state_views.dart';
import 'account_screens.dart';

Future<T?> _push<T>(BuildContext c, Widget page, {bool full = false}) =>
    Navigator.of(c).push<T>(appRoute<T>(page, fullscreen: full));

// ===========================================================================
// Security
// ===========================================================================

/// "Security": two-factor, ID verification and the password protections.
/// These switches are stored but have no effect (a university project cannot
/// offer real 2FA, passkeys or ID checks).
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Security',
      items: [
        const PGap(8),
        PNav(
          'Two-factor authentication',
          desc: 'Help protect your account from unauthorized access by '
              'requiring a second authentication method in addition to your '
              'password. Learn more',
          open: (c) => notify(
            c,
            title: 'Two-factor authentication',
            message: 'Two-factor authentication is not available in this '
                'version of ${AppConfig.appName}.',
          ),
        ),
        PNav(
          'ID verification',
          desc: 'Add an ID to your account so we can confirm you are a real '
              'person. Your ID is only used to verify your account.',
          open: (c) => notify(
            c,
            title: 'ID verification',
            message: 'ID verification is not available in this version of '
                '${AppConfig.appName}.',
          ),
        ),
        const PSection('Additional password protection'),
        const PSwitch(
          'sec_password_reset_protect',
          'Password reset protect',
          desc: 'Add extra security by requiring more information when you '
              'ask to reset your password.',
        ),
        const PSwitch(
          'sec_passkey',
          'Passkey',
          desc: 'Use your fingerprint, face or screen lock to sign in. '
              'Passkeys are safer than passwords.',
        ),
      ],
    );
  }
}

// ===========================================================================
// Apps and sessions
// ===========================================================================

class AppsAndSessionsScreen extends StatefulWidget {
  const AppsAndSessionsScreen({super.key});

  @override
  State<AppsAndSessionsScreen> createState() => _AppsAndSessionsScreenState();
}

class _AppsAndSessionsScreenState extends State<AppsAndSessionsScreen> {
  bool _unlocked = false;

  /// Sessions and login history ask for the password once.
  Future<void> _guarded(Widget page) async {
    if (!_unlocked) {
      final ok = await confirmPasswordGate(context);
      if (!ok || !mounted) return;
      _unlocked = true;
    }
    if (!mounted) return;
    await _push<Object?>(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Apps and sessions',
      closeIcon: true,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          ValueRow(
            title: 'Connected apps',
            onTap: () => _push<Object?>(context, const ConnectedAppsScreen()),
          ),
          ValueRow(
            title: 'Sessions',
            onTap: () => _guarded(const SessionsScreen()),
          ),
          ValueRow(
            title: 'Account access history',
            onTap: () => _guarded(const AccessHistoryScreen()),
          ),
          ValueRow(
            title: 'Logged-in devices and apps',
            onTap: () => _guarded(const LoggedInDevicesScreen()),
          ),
        ],
      ),
    );
  }
}

class ConnectedAppsScreen extends StatelessWidget {
  const ConnectedAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyPage(
      title: 'Connected apps',
      heading: 'Manage connected apps in a flash',
      text: 'Third-party apps you allow to access your '
          '${AppConfig.appName} account will show up here.',
    );
  }
}

String _when(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  return timeago.format(t);
}

String _place(AppSession s) {
  final loc = s.location;
  return (loc == null || loc.isEmpty) ? (s.platform ?? 'Unknown location') : loc;
}

/// Loads sessions and shows loading / error / content.
class _SessionData extends StatefulWidget {
  const _SessionData({
    required this.title,
    required this.onlyActive,
    required this.builder,
  });

  final String title;
  final bool onlyActive;
  final Widget Function(
    BuildContext context,
    List<AppSession> sessions,
    Future<void> Function() reload,
  ) builder;

  @override
  State<_SessionData> createState() => _SessionDataState();
}

class _SessionDataState extends State<_SessionData> {
  List<AppSession>? _sessions;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await SessionTracker.list(onlyActive: widget.onlyActive);
      if (mounted) {
        setState(() {
          _sessions = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _sessions;
    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (list == null) {
      body = const LoadingView();
    } else {
      body = widget.builder(context, list, _load);
    }
    return SettingsFrame(title: widget.title, child: body);
  }
}

Widget _sessionRow(
  BuildContext context,
  AppSession s, {
  bool current = false,
  String? subtitle,
  bool chevron = true,
}) {
  final p = AppPalette.of(context);
  return SettingsColumn(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => notify(
        context,
        title: s.device,
        message: 'Platform: ${s.platform ?? 'Unknown'}\n'
            'Signed in: ${s.createdAt.toString().split('.').first}\n'
            'Last active: ${s.lastActive.toString().split('.').first}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.device,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ??
                        '${_place(s)} · ${current ? 'Active now' : _when(s.lastActive)}',
                    style: TextStyle(color: p.subtext, fontSize: 15),
                  ),
                ],
              ),
            ),
            if (chevron)
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: p.subtext.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    ),
  );
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SessionData(
      title: 'Sessions',
      onlyActive: true,
      builder: (context, sessions, reload) {
        final p = AppPalette.of(context);
        final currentId = SessionTracker.currentId;
        final current = sessions.where((s) => s.id == currentId).toList();
        final others = sessions.where((s) => s.id != currentId).toList();

        Widget heading(String t) => SettingsColumn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                child: Text(
                  t,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );

        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            heading('Current active session'),
            if (current.isNotEmpty)
              _sessionRow(context, current.first, current: true)
            else
              SettingsColumn(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    '${SessionTracker.deviceLabel()} · Active now',
                    style: TextStyle(color: p.text, fontSize: 17),
                  ),
                ),
              ),
            const SettingsDivider(),
            heading('Log out of other sessions'),
            SettingsColumn(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Logs you out of every device except this one.',
                  style: TextStyle(color: p.subtext, fontSize: 15),
                ),
              ),
            ),
            SettingsColumn(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: 'Log out of all other sessions?',
                    message: 'Every other device will be signed out of '
                        '${AppConfig.appName}.',
                    confirmLabel: 'Log out',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await SessionTracker.endOthers();
                    await reload();
                    if (context.mounted) {
                      showSuccess(context, 'Logged out of other sessions.');
                    }
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Log out of all other sessions',
                    style: TextStyle(
                      color: p.danger,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (others.isNotEmpty) ...[
              const SettingsDivider(),
              heading('Other active sessions'),
              for (final s in others) _sessionRow(context, s),
            ],
          ],
        );
      },
    );
  }
}

class AccessHistoryScreen extends StatelessWidget {
  const AccessHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SessionData(
      title: 'Account access history',
      onlyActive: false,
      builder: (context, sessions, reload) {
        if (sessions.isEmpty) {
          return const EmptyStateView(
            title: 'No history yet',
            text: 'Your logins will show up here.',
          );
        }
        final p = AppPalette.of(context);
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            for (final s in sessions)
              SettingsColumn(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logged in · ${s.device}',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.createdAt.toString().split('.').first}'
                        '${s.active ? '' : ' · Logged out'}',
                        style: TextStyle(color: p.subtext, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LoggedInDevicesScreen extends StatelessWidget {
  const LoggedInDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SessionData(
      title: 'Logged-in devices and apps',
      onlyActive: true,
      builder: (context, sessions, reload) {
        if (sessions.isEmpty) {
          return const EmptyStateView(
            title: 'No devices',
            text: 'Devices that are signed in will show up here.',
          );
        }
        final currentId = SessionTracker.currentId;
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            for (final s in sessions)
              _sessionRow(
                context,
                s,
                current: s.id == currentId,
                subtitle: s.id == currentId
                    ? 'This device · Active now'
                    : '${s.platform ?? 'Device'} · ${_when(s.lastActive)}',
              ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Delegate
// ===========================================================================

class DelegateScreen extends StatelessWidget {
  const DelegateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Delegate',
      items: [
        const PIntro('Share an account with people who have delegated roles.'),
        const PDivider(),
        const PSwitch(
          'delegate_allow_invites',
          'Allow others to invite you to their account',
          desc: 'When this is on, other accounts can invite you to manage '
              'their account. ',
          link: 'Learn more',
          def: true,
        ),
        const PSection('Your delegations'),
        PNav(
          'Accounts delegated to you',
          open: (c) => _push<Object?>(
            c,
            const EmptyPage(
              title: 'Accounts delegated to you',
              heading: 'No accounts yet',
              text: 'Accounts that have invited you to manage them will show '
                  'up here.',
            ),
          ),
        ),
        PNav(
          "Members you've delegated",
          open: (c) => _push<Object?>(
            c,
            const EmptyPage(
              title: "Members you've delegated",
              heading: 'No members yet',
              text: 'People you invite to manage your account will show up '
                  'here.',
            ),
          ),
        ),
      ],
    );
  }
}
