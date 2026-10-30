import 'package:flutter/widgets.dart';

/// One piece of an icon: an SVG-style path in a 24 x 24 box.
/// [kind]: 0 = filled, 1 = outline stroke, 2 = filled + stroke (rounded),
/// 3 = filled with the even-odd rule (holes where sub-paths overlap).
class XShape {
  const XShape(this.d, this.kind, this.width);
  final String d;
  final int kind;
  final double width;
}

/// The icon set of the X app, drawn as vectors (so they follow any colour and
/// size, in light and dark mode). Outline = not selected, "Fill"/"Bold" =
/// selected. Paths use only absolute M / L / C / Q / Z commands.
class XIcons {
  XIcons._();

  static const homeFill = <XShape>[
    XShape('M12 2.7L21.6 8.5Q22.5 9 22.5 10L22.5 19Q22.5 22 19.5 22L15 22L15 16.6Q15 14.4 12 14.4Q9 14.4 9 16.6L9 22L4.5 22Q1.5 22 1.5 19L1.5 10Q1.5 9 2.4 8.5Z', 2, 1.2),
  ];

  static const home = <XShape>[
    XShape('M9.6 21.2L9.6 16.8Q9.6 15 12 15Q14.4 15 14.4 16.8L14.4 21.2L19.2 21.2Q22 21.2 22 18.6L22 10.2Q22 9.4 21.3 9L12.6 3.6Q12 3.2 11.4 3.6L2.7 9Q2 9.4 2 10.2L2 18.6Q2 21.2 4.8 21.2Z', 1, 2),
  ];

  static const search = <XShape>[
    XShape('M19.6 11.4C19.6 16.15 15.75 20 11 20C6.25 20 2.4 16.15 2.4 11.4C2.4 6.65 6.25 2.8 11 2.8C15.75 2.8 19.6 6.65 19.6 11.4Z', 1, 2),
    XShape('M17.4 17.8L22.2 22.6', 1, 2),
  ];

  static const searchBold = <XShape>[
    XShape('M19.6 11.4C19.6 16.15 15.75 20 11 20C6.25 20 2.4 16.15 2.4 11.4C2.4 6.65 6.25 2.8 11 2.8C15.75 2.8 19.6 6.65 19.6 11.4Z', 1, 3.1),
    XShape('M17.4 17.8L22.2 22.6', 1, 3.1),
  ];

  static const grok = <XShape>[
    XShape('M18.103 8.103C19.875 11.255 19.662 15.442 17.583 18.311C15.504 21.18 12.079 22.017 9.231 20.35', 1, 2.5),
    XShape('M6.497 17.497C4.801 14.48 4.917 10.496 6.784 7.628C8.651 4.761 11.844 3.662 14.694 4.907', 1, 2.5),
    XShape('M2.4 22.6L11.2 11.6L21.8 1.8L13.2 13.2Z', 0, 0),
  ];

  static const grokBold = <XShape>[
    XShape('M18.103 8.103C19.875 11.255 19.662 15.442 17.583 18.311C15.504 21.18 12.079 22.017 9.231 20.35', 1, 3.3),
    XShape('M6.497 17.497C4.801 14.48 4.917 10.496 6.784 7.628C8.651 4.761 11.844 3.662 14.694 4.907', 1, 3.3),
    XShape('M2.4 22.6L11.2 11.6L21.8 1.8L13.2 13.2Z', 0, 0),
  ];

  static const bell = <XShape>[
    XShape('M3 17.9C5.2 17 5.8 14 6 11.5C6.3 6.8 8.8 3.2 12 3.2C15.2 3.2 17.7 6.8 18 11.5C18.2 14 18.8 17 21 17.9Z', 1, 2),
    XShape('M8.2 17.9C8.2 20.5 9.8 21.8 12 21.8C14.2 21.8 15.8 20.5 15.8 17.9', 1, 2),
  ];

  static const bellFill = <XShape>[
    XShape('M3 17.9C5.2 17 5.8 14 6 11.5C6.3 6.8 8.8 3.2 12 3.2C15.2 3.2 17.7 6.8 18 11.5C18.2 14 18.8 17 21 17.9Z', 2, 1.4),
    XShape('M8.2 17.9C8.2 20.5 9.8 21.8 12 21.8C14.2 21.8 15.8 20.5 15.8 17.9', 2, 2),
  ];

  static const chat = <XShape>[
    XShape('M12 1.9C17.5 1.9 21.5 6 21.5 11.4C21.5 16.8 17.4 21 12.3 21C10.9 21 9.6 20.7 8.5 20.1C7.1 21.4 4.8 22 2.7 21.4C3.7 20.4 4.1 19 3.8 17.7C3 16 2.5 13.8 2.5 11.4C2.5 6 6.6 1.9 12 1.9Z', 1, 2),
  ];

  static const chatFill = <XShape>[
    XShape('M12 1.9C17.5 1.9 21.5 6 21.5 11.4C21.5 16.8 17.4 21 12.3 21C10.9 21 9.6 20.7 8.5 20.1C7.1 21.4 4.8 22 2.7 21.4C3.7 20.4 4.1 19 3.8 17.7C3 16 2.5 13.8 2.5 11.4C2.5 6 6.6 1.9 12 1.9Z', 2, 1.4),
  ];

  static const reply = <XShape>[
    XShape('M1.751 10C1.751 5.58 5.335 2 9.756 2L14.122 2C18.612 2 22.251 5.64 22.251 10.13C22.251 13.09 20.644 15.81 18.055 17.24L10.001 21.7L10.001 18.01L9.934 18.01C5.444 18.11 1.751 14.5 1.751 10ZM9.756 4C6.439 4 3.751 6.69 3.751 10C3.751 13.37 6.521 16.08 9.889 16.01L10.24 16L12.001 16L12.001 18.3L17.088 15.49C19.039 14.41 20.251 12.36 20.251 10.13C20.251 6.74 17.507 4 14.122 4L9.756 4Z', 0, 0),
  ];

  static const repost = <XShape>[
    XShape('M4.5 3.88L8.932 8.02L7.568 9.48L5.5 7.55L5.5 16C5.5 17.1 6.396 18 7.5 18L13 18L13 20L7.5 20C5.291 20 3.5 18.21 3.5 16L3.5 7.55L1.432 9.48L0.068 8.02L4.5 3.88ZM16.5 6L11 6L11 4L16.5 4C18.709 4 20.5 5.79 20.5 8L20.5 16.45L22.568 14.52L23.932 15.98L19.5 20.12L15.068 15.98L16.432 14.52L18.5 16.45L18.5 8C18.5 6.9 17.604 6 16.5 6Z', 0, 0),
  ];

  static const like = <XShape>[
    XShape('M16.697 5.5C15.475 5.44 14.018 6.01 12.807 7.66L12.002 8.75L11.196 7.66C9.984 6.01 8.526 5.44 7.304 5.5C6.061 5.57 4.955 6.28 4.394 7.41C3.842 8.53 3.761 10.19 4.873 12.23C5.947 14.2 8.13 16.5 12.002 18.84C15.872 16.5 18.054 14.2 19.128 12.23C20.239 10.19 20.158 8.53 19.605 7.41C19.044 6.28 17.939 5.57 16.697 5.5ZM20.884 13.19C19.533 15.67 16.883 18.31 12.505 20.86L12.002 21.16L11.498 20.86C7.119 18.31 4.469 15.67 3.116 13.19C1.756 10.69 1.706 8.33 2.602 6.52C3.489 4.73 5.249 3.61 7.203 3.51C8.854 3.42 10.571 4.07 12.001 5.52C13.43 4.07 15.147 3.42 16.797 3.51C18.751 3.61 20.511 4.73 21.398 6.52C22.294 8.33 22.244 10.69 20.884 13.19Z', 0, 0),
  ];

  static const likeFill = <XShape>[
    XShape('M20.884 13.19C19.533 15.67 16.883 18.31 12.505 20.86L12.002 21.16L11.498 20.86C7.119 18.31 4.469 15.67 3.116 13.19C1.756 10.69 1.706 8.33 2.602 6.52C3.489 4.73 5.249 3.61 7.203 3.51C8.854 3.42 10.571 4.07 12.001 5.52C13.43 4.07 15.147 3.42 16.797 3.51C18.751 3.61 20.511 4.73 21.398 6.52C22.294 8.33 22.244 10.69 20.884 13.19Z', 0, 0),
  ];

  static const views = <XShape>[
    XShape('M8.75 21L8.75 3L10.75 3L10.75 21L8.75 21ZM18 21L18 8.5L20 8.5L20 21L18 21ZM4 21L4.004 11L6.004 11L6 21L4 21ZM13.248 21L13.248 14L15.248 14L15.248 21L13.248 21Z', 0, 0),
  ];

  static const bookmark = <XShape>[
    XShape('M4 4.5C4 3.12 5.119 2 6.5 2L17.5 2C18.881 2 20 3.12 20 4.5L20 22.94L12 17.23L4 22.94L4 4.5ZM6.5 4C6.224 4 6 4.22 6 4.5L6 19.06L12 14.77L18 19.06L18 4.5C18 4.22 17.776 4 17.5 4L6.5 4Z', 0, 0),
  ];

  static const bookmarkFill = <XShape>[
    XShape('M4 4.5C4 3.12 5.119 2 6.5 2L17.5 2C18.881 2 20 3.12 20 4.5L20 22.94L12 17.23L4 22.94L4 4.5Z', 0, 0),
  ];

  static const share = <XShape>[
    XShape('M12 2.59L17.7 8.29L16.29 9.71L13 6.41L13 16L11 16L11 6.41L7.7 9.71L6.29 8.29L12 2.59ZM21 15L20.98 18.51C20.98 19.89 19.86 21 18.48 21L5.5 21C4.11 21 3 19.88 3 18.5L3 15L5 15L5 18.5C5 18.78 5.22 19 5.5 19L18.48 19C18.76 19 18.98 18.78 18.98 18.5L19 15L21 15Z', 0, 0),
  ];

  static const compose = <XShape>[
    XShape('M23 3C16.38 2.9 12.62 5.421 9.95 9.03C7.29 12.61 6 17.331 6 22L8 22C8 20.993 8.07 19.988 8.19 19L12 19C16.1 19 19.48 15.918 19.94 11.946C22.79 10.147 23.17 6.359 23 3ZM16 11L14.5 11L14.5 13L16 13C16.63 12.984 17.2 12.92 17.72 12.812C16.95 15.24 14.68 17 12 17L8.55 17C9.12 14.488 10.12 12.149 11.55 10.22C13.71 7.308 16.84 5.309 21 5.033C20.95 8.079 19.9 11 16 11ZM4 9L4 6L1 6L1 4L4 4L4 1L6 1L6 4L9 4L9 6L6 6L6 9L4 9Z', 0, 0),
  ];

  static const sparkle = <XShape>[
    XShape('M 13.4 3.6 Q 14.936 11.664 23 13.2 Q 14.936 14.736 13.4 22.8 Q 11.864 14.736 3.8 13.2 Q 11.864 11.664 13.4 3.6 Z', 0, 0),
    XShape('M 5.4 1.5 Q 5.992 4.608 9.1 5.2 Q 5.992 5.792 5.4 8.9 Q 4.808 5.792 1.7 5.2 Q 4.808 4.608 5.4 1.5 Z', 0, 0),
  ];

  static const sparkleOutline = <XShape>[
    XShape('M 13.4 3.6 Q 14.936 11.664 23 13.2 Q 14.936 14.736 13.4 22.8 Q 11.864 14.736 3.8 13.2 Q 11.864 11.664 13.4 3.6 Z', 1, 1.8),
    XShape('M 5.4 1.5 Q 5.992 4.608 9.1 5.2 Q 5.992 5.792 5.4 8.9 Q 4.808 5.792 1.7 5.2 Q 4.808 4.608 5.4 1.5 Z', 1, 1.8),
  ];

  static const rocket = <XShape>[
    XShape('M 18.375 5.625 C 18.896 9.788 16.814 13.431 13.431 15.773 L 8.227 10.569 C 10.569 7.186 14.212 5.104 18.375 5.625 Z', 1, 1.8),
    XShape('M 10.504 8.942 L 6.08 9.203 L 3.868 11.415 L 7.576 12.781', 1, 1.8),
    XShape('M 15.058 13.496 L 14.797 17.92 L 12.585 20.132 L 11.219 16.424', 1, 1.8),
    XShape('M 7.837 14.082 L 5.625 18.375 L 9.918 16.163', 1, 1.8),
    XShape('M 15.123 8.877 C 15.733 9.488 15.733 10.478 15.123 11.089 C 14.512 11.7 13.522 11.7 12.911 11.089 C 12.3 10.478 12.3 9.488 12.911 8.877 C 13.522 8.267 14.512 8.267 15.123 8.877 Z', 1, 1.8),
  ];

  static const person = <XShape>[
    XShape('M 5.651 19 L 18.349 19 C 18.012 17.2 17.326 15.79 16.404 14.81 C 15.318 13.65 13.838 13 12 13 C 10.162 13 8.683 13.65 7.596 14.81 C 6.674 15.79 5.988 17.2 5.651 19 Z M 6.137 13.44 C 7.627 11.85 9.648 11 12 11 C 14.352 11 16.373 11.85 17.863 13.44 C 19.34 15.02 20.229 17.24 20.495 19.9 L 20.605 21 L 3.395 21 L 3.505 19.9 C 3.771 17.24 4.66 15.02 6.137 13.44 Z M 12 4 C 10.895 4 10 4.9 10 6 C 10 7.1 10.895 8 12 8 C 13.105 8 14 7.1 14 6 C 14 4.9 13.105 4 12 4 Z M 8 6 C 8 3.79 9.791 2 12 2 C 14.209 2 16 3.79 16 6 C 16 8.21 14.209 10 12 10 C 9.791 10 8 8.21 8 6 Z', 0, 0),
  ];

  static const personAdd = <XShape>[
    XShape('M 10 4 C 8.895 4 8 4.9 8 6 C 8 7.1 8.895 8 10 8 C 11.105 8 12 7.1 12 6 C 12 4.9 11.105 4 10 4 Z M 6 6 C 6 3.79 7.791 2 10 2 C 12.209 2 14 3.79 14 6 C 14 8.21 12.209 10 10 10 C 7.791 10 6 8.21 6 6 Z M 19 10 L 19 13 L 21 13 L 21 10 L 24 10 L 24 8 L 21 8 L 21 5 L 19 5 L 19 8 L 16 8 L 16 10 L 19 10 Z M 3.651 19 L 16.349 19 C 16.012 17.2 15.326 15.79 14.404 14.81 C 13.318 13.65 11.838 13 10 13 C 8.162 13 6.683 13.65 5.596 14.81 C 4.674 15.79 3.988 17.2 3.651 19 Z M 4.137 13.44 C 5.627 11.85 7.648 11 10 11 C 12.352 11 14.373 11.85 15.863 13.44 C 17.34 15.02 18.229 17.24 18.495 19.9 L 18.605 21 L 1.395 21 L 1.505 19.9 C 1.771 17.24 2.66 15.02 4.137 13.44 Z', 0, 0),
  ];

  static const link = <XShape>[
    XShape('M 18.36 5.64 C 16.41 3.68 13.25 3.68 11.29 5.64 L 9.88 7.05 L 8.46 5.64 L 9.88 4.22 C 12.61 1.49 17.04 1.49 19.78 4.22 C 22.51 6.96 22.51 11.39 19.78 14.12 L 18.36 15.54 L 16.95 14.12 L 18.36 12.71 C 20.32 10.75 20.32 7.59 18.36 5.64 Z M 16.24 9.17 L 9.17 16.24 L 7.76 14.83 L 14.83 7.76 L 16.24 9.17 Z M 4.22 9.88 L 5.64 8.46 L 7.05 9.88 L 5.64 11.29 C 3.68 13.25 3.68 16.41 5.64 18.36 C 7.59 20.32 10.75 20.32 12.71 18.36 L 14.12 16.95 L 15.54 18.36 L 14.12 19.78 C 11.39 22.51 6.96 22.51 4.22 19.78 C 1.49 17.04 1.49 12.61 4.22 9.88 Z', 0, 0),
  ];

  static const bellPlus = <XShape>[
    XShape('M 3.22 18.738 C 5.024 18 5.516 15.54 5.68 13.49 C 5.926 9.636 7.976 6.684 10.6 6.684 C 13.224 6.684 15.274 9.636 15.52 13.49 C 15.684 15.54 16.176 18 17.98 18.738 Z', 1, 2),
    XShape('M 7.484 18.738 C 7.484 20.87 8.796 21.936 10.6 21.936 C 12.404 21.936 13.716 20.87 13.716 18.738', 1, 2),
    XShape('M 15.2 5.2 L 22 5.2', 1, 1.8),
    XShape('M 18.6 1.8 L 18.6 8.6', 1, 1.8),
  ];

  static const people = <XShape>[
    XShape('M 8.6 4.1 C 10.367 4.1 11.8 5.533 11.8 7.3 C 11.8 9.067 10.367 10.5 8.6 10.5 C 6.833 10.5 5.4 9.067 5.4 7.3 C 5.4 5.533 6.833 4.1 8.6 4.1 Z', 0, 0),
    XShape('M 16.3 5.6 C 17.736 5.6 18.9 6.764 18.9 8.2 C 18.9 9.636 17.736 10.8 16.3 10.8 C 14.864 10.8 13.7 9.636 13.7 8.2 C 13.7 6.764 14.864 5.6 16.3 5.6 Z', 0, 0),
    XShape('M 2.4 20.6 Q 2.4 13.6 8.6 13.6 Q 14.8 13.6 14.8 20.6 Z', 0, 0),
    XShape('M 14.6 13.8 Q 15.4 13.5 16.3 13.5 Q 21.8 13.5 21.8 19.6 L 16.6 19.6 Q 16.5 16.2 14.6 13.8 Z', 0, 0),
  ];

  static const globe = <XShape>[
    XShape('M 12 2 C 17.523 2 22 6.477 22 12 C 22 17.523 17.523 22 12 22 C 6.477 22 2 17.523 2 12 C 2 6.477 6.477 2 12 2 Z M 7.2 5.8 Q 9.6 4.6 11.2 6.8 Q 12.2 9 10.2 10.6 Q 9 12.6 11 14.2 Q 10 18.2 8 18.2 Q 4.8 15.2 5.4 11 Q 5.6 8 7.2 5.8 Z M 14.6 7.6 Q 17.6 7 18.6 9.8 Q 19.2 13 17.2 14.6 Q 15 16.2 14 14.2 Q 13 11 14.6 7.6 Z', 3, 0),
  ];

  static const calendar = <XShape>[
    XShape('M 5.5 4.6 L 18.5 4.6 Q 21 4.6 21 7.1 L 21 18.5 Q 21 21 18.5 21 L 5.5 21 Q 3 21 3 18.5 L 3 7.1 Q 3 4.6 5.5 4.6 Z', 1, 1.8),
    XShape('M 3 9.4 L 21 9.4', 1, 1.8),
  ];

  static const xLogo = <XShape>[
    XShape('M18.244 2.25L21.552 2.25L14.325 10.51L22.827 21.75L16.17 21.75L10.956 14.933L4.99 21.75L1.68 21.75L9.41 12.915L1.254 2.25L8.08 2.25L12.793 8.481ZM17.083 19.77L18.916 19.77L7.084 4.126L5.117 4.126Z', 0, 0),
  ];
}

/// Draws an [XIcons] entry at [size] in [color].
class XIcon extends StatelessWidget {
  const XIcon(this.shapes, {super.key, this.size = 24, required this.color});

  final List<XShape> shapes;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _XIconPainter(shapes, color),
    );
  }
}

/// The X logo (the real one, as a vector), used instead of a letter "X".
class XLogo extends StatelessWidget {
  const XLogo({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      XIcon(XIcons.xLogo, size: size, color: color);
}

class _XIconPainter extends CustomPainter {
  _XIconPainter(this.shapes, this.color);

  final List<XShape> shapes;
  final Color color;

  static final Map<String, Path> _cache = {};

  static Path _parse(String d) {
    return _cache.putIfAbsent(d, () {
      final path = Path();
      final tokens = RegExp(r'([MLCQZ])|(-?\d*\.?\d+)')
          .allMatches(d)
          .map((m) => m.group(1) ?? m.group(2)!)
          .toList();
      var i = 0;
      double n() => double.parse(tokens[i++]);
      String cmd = 'M';
      while (i < tokens.length) {
        final t = tokens[i];
        if (RegExp(r'[MLCQZ]').hasMatch(t)) {
          cmd = t;
          i++;
        }
        switch (cmd) {
          case 'M':
            path.moveTo(n(), n());
            cmd = 'L';
          case 'L':
            path.lineTo(n(), n());
          case 'C':
            path.cubicTo(n(), n(), n(), n(), n(), n());
          case 'Q':
            path.quadraticBezierTo(n(), n(), n(), n());
          case 'Z':
            path.close();
        }
      }
      return path;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final s in shapes) {
      final parsed = _parse(s.d);
      final path =
          s.kind == 3 ? (Path.from(parsed)..fillType = PathFillType.evenOdd) : parsed;
      if (s.kind == 0 || s.kind == 2 || s.kind == 3) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..isAntiAlias = true
            ..color = color,
        );
      }
      if (s.kind == 1 || s.kind == 2) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..isAntiAlias = true
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_XIconPainter old) =>
      old.color != color || old.shapes != shapes;
}
