import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';


/// Circular profile picture with an initial-letter fallback. Organisation
/// accounts (gold badge) use a rounded square instead, like on X.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 44,
    this.square = false,
  });

  final String? url;
  final String name;
  final double size;

  /// Rounded square instead of a circle.
  final bool square;

  /// Square avatars belong to gold (organisation) accounts.
  static bool isSquare(String? verified) => verified == 'gold';

  Widget _clip(Widget child) {
    if (square) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: child,
      );
    }
    return ClipOval(child: child);
  }

  @override
  Widget build(BuildContext context) {
    // Default picture like X's: pale circle with a grey silhouette.
    Widget fallback() {
      return _clip(
        Container(
          width: size,
          height: size,
          alignment: Alignment.bottomCenter,
          color: const Color(0xFFCFD9DE),
          child: Transform.translate(
            offset: Offset(0, size * 0.1),
            child: Icon(
              CupertinoIcons.person_fill,
              size: size * 0.9,
              color: const Color(0xFF687684),
            ),
          ),
        ),
      );
    }

    final u = url;
    if (u == null || u.isEmpty) return fallback();

    return _clip(
      CachedNetworkImage(
        imageUrl: u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallback(),
        errorWidget: (context, url, error) => fallback(),
      ),
    );
  }
}
