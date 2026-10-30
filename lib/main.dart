import 'dart:io' show HttpOverrides;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show
        ColorScheme,
        NavigationBarThemeData,
        NavigationDestinationLabelBehavior,
        ThemeData,
        ThemeMode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/app_palette.dart';
import 'core/config.dart';
import 'core/http_identity.dart';
import 'models/models.dart' show Profile;
import 'services/account_sessions.dart';
import 'services/api.dart';
import 'services/display_prefs.dart';
import 'widgets/state_views.dart';
import 'widgets/pill_button.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_flow.dart';
import 'screens/setup_required_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A proper User-Agent so Wikimedia Commons photos load (see http_identity).
  HttpOverrides.global = XReplicaHttpOverrides();

  // "2h", "5m" style timestamps like the real thing.
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());

  // Theme + font size from Settings > Display (kept on this device).
  await DisplayPrefs.instance.load();

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    // Keeps the saved logins of all accounts on this phone up to date.
    AccountSessions.start();
  }

  runApp(const XReplicaApp());
}

class XReplicaApp extends StatelessWidget {
  const XReplicaApp({super.key});

  static CupertinoThemeData _cupertino(Brightness brightness) {
    final p = AppPalette.forBrightness(brightness);
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: p.accent,
      scaffoldBackgroundColor: p.background,
      barBackgroundColor: p.background,
    );
  }

  /// Android (Material shell inside adaptive_platform_ui): the same colours,
  /// so switches, dialogs, sheets and the navigation bar are dark in dark mode.
  static ThemeData _material(Brightness brightness) {
    final p = AppPalette.forBrightness(brightness);
    const white = Color(0xFFFFFFFF);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.border,
      // Android tab bar like X's: flat, icons only. (The long label
      // "Notifications" wrapped onto two lines in the Material bar.)
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        backgroundColor: p.background,
        surfaceTintColor: const Color(0x00000000),
        indicatorColor: const Color(0x00000000),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: white,
        secondary: p.accent,
        onSecondary: white,
        error: p.danger,
        onError: white,
        surface: p.background,
        onSurface: p.text,
        surfaceContainerHighest: p.field,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surface,
        outline: p.border,
        outlineVariant: p.border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Settings > Display changes the theme or the font size.
    return ListenableBuilder(
      listenable: DisplayPrefs.instance,
      builder: (context, _) {
        final display = DisplayPrefs.instance;
        final forced = display.forcedBrightness;
        // Font size step on top of the phone's own text size. The override
        // sits above the app, so every page, dialog and sheet gets it.
        final mq = MediaQuery.of(context);
        final base = mq.textScaler.scale(1.0);
        final effective = forced ?? mq.platformBrightness;
        final dark = effective == Brightness.dark;
        final palette = AppPalette.forBrightness(effective);
        return MediaQuery(
          data: mq.copyWith(
            // Keeps very large phone fonts from pushing rows and bars past
            // the edge of the screen (the yellow "overflowed" stripes).
            textScaler: TextScaler.linear(
              (base * display.fontScale).clamp(0.8, 1.3).toDouble(),
            ),
            // Day / Night in Settings > Display: every widget below, native
            // iOS controls and Material ones too, sees that brightness.
            platformBrightness: effective,
          ),
          child: AdaptiveApp(
            title: AppConfig.appName,
            themeMode: forced == null
                ? ThemeMode.system
                : (dark ? ThemeMode.dark : ThemeMode.light),
            cupertinoLightTheme: _cupertino(Brightness.light),
            cupertinoDarkTheme: _cupertino(Brightness.dark),
            materialLightTheme: _material(Brightness.light),
            materialDarkTheme: _material(Brightness.dark),
            // Status bar / navigation bar icons that stay readable.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                statusBarColor: const Color(0x00000000),
                systemNavigationBarColor: palette.background,
                systemNavigationBarIconBrightness:
                    dark ? Brightness.light : Brightness.dark,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
            localizationsDelegates: const [
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: AppConfig.isConfigured
                ? const AuthGate()
                : const SetupRequiredScreen(),
          ),
        );
      },
    );
  }
}

/// Shows the sign-in screen when logged out and the app when logged in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) return const AuthScreen();
        // Keyed by user id so state resets when the account changes.
        return SessionGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Signed in: loads the profile, then shows either the remaining sign-up
/// steps (new account that has not finished them yet) or the app itself.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Profile? _profile;
  Object? _error;
  bool _onboarded = false;
  String? _initialSearch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final profile = await Api.getProfile(Api.uid);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _onboarded = profile.onboarded;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final profile = _profile;

    if (profile == null) {
      return AdaptiveScaffold(
        backgroundColor: p.background,
        body: _error == null
            ? const LoadingView()
            : SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ErrorView(error: _error!, onRetry: _load),
                    PillButton(
                      label: 'Log out',
                      onPressed: () => Api.signOut(),
                    ),
                  ],
                ),
              ),
      );
    }

    if (!_onboarded) {
      return OnboardingFlow(
        profile: profile,
        onFinished: (query) => setState(() {
          _onboarded = true;
          _initialSearch = query;
        }),
      );
    }
    return HomeShell(initialSearch: _initialSearch);
  }
}
