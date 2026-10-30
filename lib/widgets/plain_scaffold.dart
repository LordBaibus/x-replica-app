import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// Full-screen page without an app bar. Unlike a bare Cupertino scaffold it
/// also sets a default text style, so no text on Android gets the yellow
/// double underline Flutter shows when there is no Material / text-style
/// ancestor.
class PlainScaffold extends StatelessWidget {
  const PlainScaffold({super.key, required this.child, this.floating});

  final Widget child;

  /// Optional button floating over the bottom-right corner.
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ColoredBox(
      color: p.background,
      child: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            if (floating != null)
              Positioned(
                right: 18,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
                child: floating!,
              ),
          ],
        ),
      ),
    );
  }
}

/// The round blue action button (compose, create list ...).
class RoundFab extends StatelessWidget {
  const RoundFab({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.accent,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 26, color: const Color(0xFFFFFFFF)),
      ),
    );
  }
}
