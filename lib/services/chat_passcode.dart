import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// How the Chat tab is protected on this device.
enum ChatSecurity {
  /// Chat has not been set up yet (shows the "Welcome" screen).
  none,

  /// A 4-digit passcode must be entered once per app start.
  passcode,

  /// "Let device manage my passcode": no extra prompt.
  device,
}

/// Local passcode gate for the Chat tab (X's "Create Passcode" flow).
///
/// Only a salted hash of the code is kept, in this device's preferences, one
/// per account. It protects the screen on this device; messages themselves
/// are stored in Supabase like all other data of the app.
class ChatPasscode {
  ChatPasscode._();

  static final Set<String> _unlocked = {};

  static String get _pinKey => 'chat_pin_${Api.uid}';
  static String get _deviceKey => 'chat_device_${Api.uid}';

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('x_replica:${Api.uid}:$pin')).toString();

  static Future<ChatSecurity> mode() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_pinKey) != null) return ChatSecurity.passcode;
    if (prefs.getBool(_deviceKey) ?? false) return ChatSecurity.device;
    return ChatSecurity.none;
  }

  /// True after the right passcode was entered since the app started.
  static bool get isUnlocked => _unlocked.contains(Api.uid);

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _hash(pin));
    await prefs.remove(_deviceKey);
    _unlocked.add(Api.uid);
  }

  static Future<void> useDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceKey, true);
    await prefs.remove(_pinKey);
  }

  static Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = prefs.getString(_pinKey) == _hash(pin);
    if (ok) _unlocked.add(Api.uid);
    return ok;
  }

  /// "Forgot passcode?": back to the Welcome screen.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_deviceKey);
    _unlocked.remove(Api.uid);
  }
}
