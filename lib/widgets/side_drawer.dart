import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';

/// X's account menu: the menu sits underneath and the whole app slides to the
/// right to reveal it (rounded corner, faded), instead of a panel covering the
/// screen. Built from plain widgets, no Material drawer.
class PushDrawer extends StatelessWidget {
  const PushDrawer({
    super.key,
    required this.open,
    required this.onClose,
    required this.drawer,
    required this.child,
  });

  final bool open;
  final VoidCallback onClose;

  /// The menu shown on the left.
  final Widget drawer;

  /// The app (tabs) that slides over.
  final Widget child;

  static const _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final width = math.min(total * 0.82, 380.0);

        return Stack(
          children: [
            // Menu (behind the app).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width,
              child: IgnorePointer(
                ignoring: !open,
                child: ColoredBox(
                  color: p.background,
                  // Outside any Scaffold: give text a clean base style (no
                  // Material ancestor on Android).
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                    child: SafeArea(child: drawer),
                  ),
                ),
              ),
            ),
            // The app, pushed to the right while the menu is open.
            AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: open ? width : 0,
              top: 0,
              bottom: 0,
              width: total,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: open ? 24 : 0),
                duration: _duration,
                curve: Curves.easeOutCubic,
                builder: (context, radius, content) => ClipRRect(
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(radius)),
                  child: content,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: child),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !open,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onClose,
                          onHorizontalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0) < -200) onClose();
                          },
                          child: AnimatedOpacity(
                            opacity: open ? 1 : 0,
                            duration: _duration,
                            child: ColoredBox(
                              color: p.background.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
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
