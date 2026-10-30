import 'dart:math' as math;
import 'dart:ui' show Canvas, Paint, PaintingStyle, Path, Size, StrokeCap, StrokeJoin;

import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../core/x_icons.dart';
import 'package:flutter/widgets.dart';

/// Colour of a verification badge: blue (person), gold (organisation), grey.
Color verifiedColor(String? type) {
  switch (type) {
    case 'gold':
      return const Color(0xFFE2B719);
    case 'gray':
      return const Color(0xFF829AAB);
    default:
      return const Color(0xFF1D9BF0);
  }
}

/// Small scalloped badge with a check mark, shown after a name.
/// Draws nothing when [type] is null.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.type, this.size = 17});

  /// blue | gold | gray | null
  final String? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (type == null) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BadgePainter(verifiedColor(type))),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final path = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      // Eight soft bumps around a circle.
      final rad = r * (0.9 + 0.1 * math.cos(8 * a));
      final x = r + rad * math.cos(a);
      final y = r + rad * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );

    final w = size.width;
    final check = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.72, w * 0.35);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.color != color;
}

/// Name text followed by its verification badge, on one line.
class NameWithBadge extends StatelessWidget {
  const NameWithBadge({
    super.key,
    required this.name,
    required this.verified,
    required this.style,
    this.badgeSize = 17,
    this.locked = false,
  });

  final String name;
  final String? verified;
  final TextStyle style;
  final double badgeSize;

  /// Protected account: a padlock after the name (before the badge).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (locked) ...[
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.lock_fill,
            size: badgeSize - 2,
            color: style.color,
          ),
        ],
        if (verified != null) ...[
          const SizedBox(width: 3),
          VerifiedBadge(type: verified, size: badgeSize),
        ],
      ],
    );
  }
}

/// The small X logo at the top right of a post in the timeline.
class XMark extends StatelessWidget {
  const XMark({super.key, required this.color, this.size = 19});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => XLogo(size: size, color: color);
}
