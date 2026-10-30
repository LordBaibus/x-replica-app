import 'package:flutter/widgets.dart';

import '../services/display_prefs.dart';

/// Colour tokens that follow the system light/dark setting.
/// Looks up from the platform brightness so it works under both the
/// Cupertino and Material shells that AdaptiveApp builds.
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.field,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.danger,
  });

  final Color background;
  final Color surface;

  /// Fill of search boxes and message inputs.
  final Color field;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;
  final Color danger;

  /// Heart colour of a liked post.
  static const Color like = Color(0xFFF91880);

  static const AppPalette dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF16181C),
    field: Color(0xFF202327),
    border: Color(0xFF2F3336),
    text: Color(0xFFE7E9EA),
    subtext: Color(0xFF71767B),
    accent: Color(0xFF1D9BF0),
    danger: Color(0xFFF4212E),
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F9F9),
    field: Color(0xFFEFF3F4),
    border: Color(0xFFEFF3F4),
    text: Color(0xFF0F1419),
    subtext: Color(0xFF536471),
    accent: Color(0xFF1D9BF0),
    danger: Color(0xFFF4212E),
  );

  /// iOS and Android both follow the phone's light / dark setting (main.dart
  /// gives the Cupertino and the Material shell matching themes).
  ///
  /// Settings > Display can force Day or Night on both platforms; when it
  /// does, that choice wins.
  static AppPalette of(BuildContext context) {
    final forced = DisplayPrefs.instance.forcedBrightness;
    if (forced != null) return forBrightness(forced);
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? dark
        : light;
  }

  static AppPalette forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;
}
