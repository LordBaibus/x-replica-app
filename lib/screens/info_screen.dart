import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';
import '../widgets/responsive.dart';

/// Simple "nothing here yet" style page used for the menu entries that this
/// educational replica does not implement (Subscription, Communities, Lists,
/// Follower requests, Creator Studio) and for the Help Center.
class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.title,
    required this.headline,
    required this.body,
    this.points = const [],
  });

  final String title;
  final String headline;
  final String body;

  /// Optional bullet list under the text (Help Center).
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: AdaptiveAppBar(title: title),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    color: p.subtext,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
                for (final point in points) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 12),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 16,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
