import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/developers.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_mark.dart';
import '../widgets/responsive.dart';

/// Settings → Developer info: lists every group member and what they built.
/// Edit the data in lib/core/developers.dart.
class DeveloperInfoScreen extends StatelessWidget {
  const DeveloperInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: const AdaptiveAppBar(title: 'Developer info'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            const Center(child: BrandMark(size: 60)),
            const SizedBox(height: 14),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${AppConfig.version}',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              courseLine,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              groupName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Built with Flutter, adaptive_platform_ui and Supabase. '
              'An educational project — not affiliated with any social network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 22),
            Text(
              'GROUP MEMBERS',
              style: TextStyle(
                color: p.subtext,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            for (final dev in developers) ...[
              AdaptiveCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(url: null, name: dev.name, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev.name,
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dev.role,
                                style: TextStyle(color: p.accent, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in dev.contributions)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ', style: TextStyle(color: p.subtext)),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
