import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../widgets/brand_mark.dart';
import '../widgets/responsive.dart';

/// Shown instead of crashing when the Supabase keys were not provided.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 56),
                const SizedBox(height: 20),
                Text(
                  'Connect ${AppConfig.appName} to Supabase',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Supabase URL and publishable key were not provided. Run the '
                  'app with:',
                  style: TextStyle(color: p.subtext, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    'flutter run \\\n'
                    '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                    '  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 13,
                      fontFamily: 'Courier',
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'See README.md for the full setup (SQL schema, storage '
                  'buckets, release builds).',
                  style: TextStyle(color: p.subtext, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
