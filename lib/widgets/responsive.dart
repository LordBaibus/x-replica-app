import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';

/// Keeps content readable on tablets / unfolded foldables by capping its width.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 680});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Two-pane layout that respects a vertical hinge / fold (Galaxy Z Fold,
/// Pixel Fold …) and also kicks in on any wide screen (tablets, landscape).
///
/// Use [canSplit] to decide whether to show two panes or navigate instead.
class FoldAwareSplit extends StatelessWidget {
  const FoldAwareSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryWidth = 360,
  });

  final Widget primary;
  final Widget secondary;

  /// Width of the first pane when there is no physical fold.
  final double primaryWidth;

  static const double _wideBreakpoint = 720;

  static DisplayFeature? _verticalFold(BuildContext context) {
    for (final f in MediaQuery.displayFeaturesOf(context)) {
      final isFold = f.type == DisplayFeatureType.hinge ||
          f.type == DisplayFeatureType.fold;
      if (isFold && f.bounds.height > f.bounds.width) return f;
    }
    return null;
  }

  static bool canSplit(BuildContext context) =>
      _verticalFold(context) != null ||
      MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final fold = _verticalFold(context);
    if (fold != null) {
      final total = MediaQuery.sizeOf(context).width;
      return Row(
        children: [
          SizedBox(width: fold.bounds.left, child: primary),
          SizedBox(width: fold.bounds.width),
          SizedBox(width: total - fold.bounds.right, child: secondary),
        ],
      );
    }

    final p = AppPalette.of(context);
    return Row(
      children: [
        SizedBox(width: primaryWidth, child: primary),
        Container(width: 0.5, color: p.border),
        Expanded(child: secondary),
      ],
    );
  }
}
