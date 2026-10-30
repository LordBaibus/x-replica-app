import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../models/models.dart';

/// "Join Community": the full-screen page X shows before you join. The
/// person reviews the rules and taps "Agree and join" ("Agree and ask to
/// join" when moderators answer the request). Resolves to true when the
/// person agrees.
Future<bool> showCommunityJoinSheet(
  BuildContext context, {
  required Community community,
  required List<CommunityRule> rules,
}) async {
  final agreed = await Navigator.of(context).push<bool>(
    CupertinoPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => _JoinPage(community: community, rules: rules),
    ),
  );
  return agreed ?? false;
}

class _JoinPage extends StatelessWidget {
  const _JoinPage({required this.community, required this.rules});

  final Community community;
  final List<CommunityRule> rules;

  TextStyle _t(Color c, double size, {FontWeight w = FontWeight.w400}) =>
      TextStyle(
        color: c,
        fontSize: size,
        fontWeight: w,
        height: 1.25,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final restricted = community.isRestricted;
    return ColoredBox(
      color: p.background,
      child: DefaultTextStyle(
        style: _t(p.text, 16),
        child: Column(
          children: [
            SizedBox(height: media.padding.top + 8),
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Icon(CupertinoIcons.xmark,
                            size: 24, color: p.text),
                      ),
                    ),
                  ),
                  Text('Join Community',
                      style: _t(p.text, 17, w: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Text(
                        'Review and agree to the rules for ${community.name}',
                        style: _t(p.text, 24, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          style: _t(p.subtext, 16),
                          children: [
                            const TextSpan(
                              text: 'These are set and enforced by Community '
                                  'admins and are in addition to ',
                            ),
                            TextSpan(
                              text: 'our Rules.',
                              style: _t(p.accent, 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (rules.isEmpty)
                        Text('This Community has no rules yet.',
                            style: _t(p.subtext, 16)),
                      for (var i = 0; i < rules.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 26),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.text,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: _t(p.background, 15,
                                      w: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rules[i].title,
                                        style: _t(p.text, 18,
                                            w: FontWeight.w700)),
                                    if (rules[i].description.isNotEmpty)
                                      Text(rules[i].description,
                                          style: _t(p.text, 17)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 0.5, color: p.border),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                media.padding.bottom + 14,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Text(
                        restricted ? 'Agree and ask to join' : 'Agree and join',
                        style: _t(const Color(0xFFFFFFFF), 17,
                            w: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
