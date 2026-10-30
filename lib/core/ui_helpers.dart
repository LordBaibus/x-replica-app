import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Push-transition: Cupertino slide on iOS, a fade + slide on Android
/// (built from plain widgets, no Material page route).
Route<T> appRoute<T>(Widget page, {bool fullscreen = false}) {
  if (PlatformInfo.isIOS) {
    return CupertinoPageRoute<T>(
      builder: (_) => page,
      fullscreenDialog: fullscreen,
    );
  }
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreen,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final begin = fullscreen ? const Offset(0, 0.08) : const Offset(0.06, 0);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Turns any exception into a short, human-readable message.
String friendlyError(Object error) {
  if (error is AuthException) {
    final m = error.message;
    if (m.toLowerCase().contains('invalid login')) {
      return 'Wrong email or password.';
    }
    return m;
  }
  if (error is PostgrestException) {
    if (error.code == '23505') return 'That value is already taken.';
    return error.message;
  }
  if (error is StorageException) return 'Upload failed: ${error.message}';
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'No internet connection.';
  }
  return text.replaceFirst('Exception: ', '');
}

void showError(BuildContext context, Object error) {
  AdaptiveSnackBar.show(
    context,
    message: friendlyError(error),
    type: AdaptiveSnackBarType.error,
  );
}

void showSuccess(BuildContext context, String message) {
  AdaptiveSnackBar.show(
    context,
    message: message,
    type: AdaptiveSnackBarType.success,
  );
}

void showInfo(BuildContext context, String message) {
  AdaptiveSnackBar.show(context, message: message);
}

/// Native confirmation dialog. Resolves to true only when the user confirms.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) {
  final completer = Completer<bool>();
  AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: 'Cancel',
        style: AlertActionStyle.cancel,
        onPressed: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
      AlertAction(
        title: confirmLabel,
        style: destructive ? AlertActionStyle.destructive : AlertActionStyle.primary,
        onPressed: () {
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    ],
  ).whenComplete(() {
    // Dismissed without choosing (e.g. tapped outside) counts as "no".
    Future<void>.delayed(Duration.zero, () {
      if (!completer.isCompleted) completer.complete(false);
    });
  });
  return completer.future;
}

/// Simple one-button native dialog.
Future<void> notify(
  BuildContext context, {
  required String title,
  String? message,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: 'OK',
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
  );
}
