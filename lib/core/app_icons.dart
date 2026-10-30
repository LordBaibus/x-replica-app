import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

/// Icons for the whole app. Only Cupertino icons are used (no Material
/// library); PlatformInfo ternaries pick the best glyph per platform.
class AppIcons {
  AppIcons._();

  static bool get _ios => PlatformInfo.isIOS;

  // --- IconData (used with Icon / AdaptiveButton.icon) ---------------------
  static IconData get home => CupertinoIcons.house;
  static IconData get search => CupertinoIcons.search;
  static IconData get mail => CupertinoIcons.mail;
  static IconData get person => CupertinoIcons.person;
  static IconData get heart => CupertinoIcons.heart;
  static IconData get heartFilled => CupertinoIcons.heart_fill;
  static IconData get photo => CupertinoIcons.photo;
  static IconData get camera => CupertinoIcons.camera;
  static IconData get add => CupertinoIcons.add;
  static IconData get close => CupertinoIcons.xmark;
  static IconData get trash => CupertinoIcons.trash;
  static IconData get lock => CupertinoIcons.lock;
  static IconData get info => CupertinoIcons.info;
  static IconData get logout => CupertinoIcons.square_arrow_right;
  static IconData get personAdd => CupertinoIcons.person_add;
  static IconData get chat => CupertinoIcons.chat_bubble_2;
  static IconData get people => CupertinoIcons.person_2;
  static IconData get back => CupertinoIcons.arrow_left;
  static IconData get bookmark => CupertinoIcons.bookmark;
  static IconData get bookmarkFilled => CupertinoIcons.bookmark_fill;
  static IconData get calendar => CupertinoIcons.calendar;
  static IconData get share => CupertinoIcons.share;
  static IconData get bell => CupertinoIcons.bell;
  static IconData get bellFilled => CupertinoIcons.bell_fill;
  static IconData get at => CupertinoIcons.at;
  static IconData get personFilled => CupertinoIcons.person_fill;

  // Per-platform picks
  static IconData get send =>
      _ios ? CupertinoIcons.arrow_up : CupertinoIcons.paperplane_fill;
  static IconData get compose =>
      _ios ? CupertinoIcons.pencil : CupertinoIcons.square_pencil;
  static IconData get settings =>
      _ios ? CupertinoIcons.settings : CupertinoIcons.gear;
  static IconData get more =>
      _ios ? CupertinoIcons.ellipsis : CupertinoIcons.ellipsis_vertical;
  static IconData get chevron =>
      _ios ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_forward;

  // --- Navigation destinations: SF Symbol name on iOS, IconData on Android -
  static dynamic navHome(bool selected) => _ios
      ? (selected ? 'house.fill' : 'house')
      : (selected ? CupertinoIcons.house_fill : CupertinoIcons.house);

  static dynamic navSearch(bool selected) =>
      _ios ? 'magnifyingglass' : CupertinoIcons.search;

  /// Grok tab (AI assistant): sparkles.
  static dynamic navGrok(bool selected) =>
      _ios ? 'sparkles' : CupertinoIcons.sparkles;

  static dynamic navNotifications(bool selected) => _ios
      ? (selected ? 'bell.fill' : 'bell')
      : (selected ? CupertinoIcons.bell_fill : CupertinoIcons.bell);

  static dynamic navMessages(bool selected) => _ios
      ? (selected ? 'envelope.fill' : 'envelope')
      : (selected ? CupertinoIcons.mail_solid : CupertinoIcons.mail);

  static dynamic navProfile(bool selected) => _ios
      ? (selected ? 'person.fill' : 'person')
      : (selected ? CupertinoIcons.person_fill : CupertinoIcons.person);
}
