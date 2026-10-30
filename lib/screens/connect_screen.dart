import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../widgets/responsive.dart';
import '../widgets/suggested_list.dart';

/// "Connect" page: accounts you may want to follow.
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AdaptiveScaffold(
      backgroundColor: p.background,
      appBar: const AdaptiveAppBar(title: 'Connect'),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Suggested for you',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Expanded(child: SuggestedList()),
            ],
          ),
        ),
      ),
    );
  }
}
