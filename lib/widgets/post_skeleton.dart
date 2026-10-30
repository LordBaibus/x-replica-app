import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';

/// Grey placeholder shapes of a post while the timeline loads, like the
/// skeleton of X: avatar, a short name line, the text lines, sometimes a
/// picture, and the row of four small action marks. The whole list pulses
/// softly (no shimmer sweep, same as X).
///
/// Shapes are deterministic per row, so the list does not jump around when
/// it rebuilds.
class PostSkeletons extends StatefulWidget {
  const PostSkeletons({super.key, this.count = 3, this.firstWithMedia});

  /// Number of placeholder posts.
  final int count;

  /// Force the media block on (true) or off (false) for the first row.
  final bool? firstWithMedia;

  @override
  State<PostSkeletons> createState() => _PostSkeletonsState();
}

class _PostSkeletonsState extends State<PostSkeletons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = Tween<double>(begin: 1.0, end: 0.45)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // (text line widths as fractions, has picture)
  static const _shapes = <(List<double>, bool)>[
    ([1.0, 0.92, 0.55], false),
    ([1.0, 0.7], true),
    ([0.95, 1.0, 0.8], false),
    ([0.85, 0.4], true),
    ([1.0, 0.6], false),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final block = p.field;
    return Semantics(
      label: 'Loading posts',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: Column(
            children: [
              for (var i = 0; i < widget.count; i++)
                _row(
                  block,
                  p,
                  _shapes[i % _shapes.length],
                  i == 0 && widget.firstWithMedia != null
                      ? widget.firstWithMedia!
                      : _shapes[i % _shapes.length].$2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(Color c, {double? width, double height = 13, double radius = 7}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _row(
    Color c,
    AppPalette p,
    (List<double>, bool) shape,
    bool media,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bar(c, width: 110, height: 14),
                      const SizedBox(width: 8),
                      _bar(c, width: 70, height: 14),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final w in shape.$1) ...[
                    FractionallySizedBox(
                      widthFactor: w,
                      alignment: Alignment.centerLeft,
                      child: _bar(c, height: 13),
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (media) ...[
                    const SizedBox(height: 4),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 4; i++) _bar(c, width: 34, height: 12),
                      const SizedBox(width: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page version: fills the screen with placeholder posts and does not
/// scroll. Use it where a screen used to show the spinner while posts load.
class PostSkeletonList extends StatelessWidget {
  const PostSkeletonList({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: PostSkeletons(count: count),
    );
  }
}

/// Placeholder rows for notifications and similar lists: a round picture and
/// two text lines.
class RowSkeletonList extends StatelessWidget {
  const RowSkeletonList({super.key, this.count = 9});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = p.field;
    Widget bar(double? w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(7),
          ),
        );
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _Pulse(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(150 + (i % 3) * 30.0, 14),
                          const SizedBox(height: 10),
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.9 : 0.65,
                            alignment: Alignment.centerLeft,
                            child: bar(null, 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _a = Tween<double>(begin: 1.0, end: 0.45)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: widget.child);
}
