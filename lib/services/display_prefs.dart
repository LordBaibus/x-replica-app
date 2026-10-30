import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which colours the whole app uses.
enum ThemeChoice { system, day, night }

/// "Display" settings: theme (System / Day / Night) and font size. Like on X
/// they belong to the device, not to an account, so they are kept in
/// SharedPreferences and also work on the sign-in screen.
class DisplayPrefs extends ChangeNotifier {
  DisplayPrefs._();

  static final DisplayPrefs instance = DisplayPrefs._();

  static const _themeKey = 'display_theme';
  static const _fontKey = 'display_font';

  /// Text scale of the four font-size steps (second step = normal).
  static const List<double> fontScales = [0.9, 1.0, 1.15, 1.3];
  static const int defaultFontStep = 1;

  ThemeChoice _theme = ThemeChoice.system;
  int _fontStep = defaultFontStep;

  ThemeChoice get theme => _theme;
  int get fontStep => _fontStep;
  double get fontScale => fontScales[_fontStep];

  /// Day / Night force a brightness; System leaves it to the phone.
  Brightness? get forcedBrightness {
    switch (_theme) {
      case ThemeChoice.day:
        return Brightness.light;
      case ThemeChoice.night:
        return Brightness.dark;
      case ThemeChoice.system:
        return null;
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getInt(_themeKey) ?? 0;
      _theme = ThemeChoice.values[t.clamp(0, ThemeChoice.values.length - 1)];
      _fontStep = (prefs.getInt(_fontKey) ?? defaultFontStep)
          .clamp(0, fontScales.length - 1);
    } catch (_) {}
  }

  Future<void> setTheme(ThemeChoice value) async {
    if (value == _theme) return;
    _theme = value;
    _applyEverywhere();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, value.index);
    } catch (_) {}
  }

  Future<void> setFontStep(int step) async {
    final s = step.clamp(0, fontScales.length - 1);
    if (s == _fontStep) return;
    _fontStep = s;
    _applyEverywhere();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_fontKey, s);
    } catch (_) {}
  }

  /// Tells the root widget (theme + text scale) and then rebuilds every
  /// widget that is on screen, because `AppPalette.of` reads these values
  /// without registering for updates.
  void _applyEverywhere() {
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
