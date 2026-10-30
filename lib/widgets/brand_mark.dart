import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';
import '../core/x_icons.dart';

/// The X logo (vector, same shape as the real one) in the text colour, so it
/// is black in light mode and white in dark mode. Used on the sign-in screen,
/// in the home header and next to "Premium".
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return XLogo(size: size, color: p.text);
  }
}
