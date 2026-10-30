import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';

class _Benefit {
  const _Benefit(this.icon, this.label, {this.info = false});

  final IconData icon;
  final String label;
  final bool info;
}

class _Tier {
  const _Tier({
    required this.name,
    required this.intro,
    required this.extra,
    required this.monthly,
    required this.monthlyNote,
    required this.yearly,
    required this.yearlyNote,
    required this.renews,
    required this.cta,
  });

  final String name;
  final String intro;
  final List<_Benefit> extra;
  final String monthly;
  final String monthlyNote;
  final String yearly;
  final String yearlyNote;
  final String renews;
  final String cta;
}

const _base = <_Benefit>[
  _Benefit(CupertinoIcons.rectangle_stack, 'Fewer timeline ads'),
  _Benefit(CupertinoIcons.checkmark_seal_fill, 'Premium checkmark', info: true),
  _Benefit(CupertinoIcons.money_dollar_circle, 'Get paid to post', info: true),
  _Benefit(CupertinoIcons.pencil, 'Edit posts'),
  _Benefit(
    CupertinoIcons.line_horizontal_3_decrease,
    'Customize your experience',
    info: true,
  ),
  _Benefit(CupertinoIcons.arrow_up, 'Create longer posts'),
  _Benefit(CupertinoIcons.doc_text, 'Write Articles', info: true),
  _Benefit(CupertinoIcons.camera, 'Media Studio', info: true),
  _Benefit(CupertinoIcons.film, '1080p video uploads'),
  _Benefit(CupertinoIcons.camera, 'Post longer videos'),
  _Benefit(CupertinoIcons.arrow_up, 'Higher posting limits'),
  _Benefit(CupertinoIcons.graph_square, 'Advanced Analytics'),
  _Benefit(CupertinoIcons.bookmark, 'Bookmark folders'),
  _Benefit(CupertinoIcons.play_circle, 'Download videos'),
  _Benefit(CupertinoIcons.chat_bubble, 'Higher DM limits'),
];

const _ai = <_Benefit>[
  _Benefit(CupertinoIcons.paperplane, 'Shared usage pool across all products'),
  _Benefit(CupertinoIcons.sparkles, 'AI chat, voice, imagine, and build'),
  _Benefit(CupertinoIcons.sparkles, 'AI API'),
  _Benefit(CupertinoIcons.cube, 'Code editor'),
];

// The Plus prices are the ones shown in the original screen; the other tiers
// use placeholder numbers (nothing can be bought in this project).
const _tiers = <_Tier>[
  _Tier(
    name: 'Plus',
    intro: 'Our introductory plan:',
    extra: [],
    monthly: '₱368',
    monthlyNote: '25% off for 6 months, then ₱490 monthly',
    yearly: '₱4,900',
    yearlyNote: '₱409/month',
    renews: 'Renews at ₱490 a month after offer ends, cancel anytime',
    cta: 'Claim limited-time offer',
  ),
  _Tier(
    name: 'Premium',
    intro: 'Everything in Plus, and more:',
    extra: [
      _Benefit(CupertinoIcons.arrow_up, 'Larger reply boost'),
      _Benefit(CupertinoIcons.arrow_up, 'Prioritized ranking in replies'),
    ],
    monthly: '₱980',
    monthlyNote: 'Billed monthly',
    yearly: '₱9,800',
    yearlyNote: '₱817/month',
    renews: 'Renews at ₱980 a month, cancel anytime',
    cta: 'Subscribe',
  ),
  _Tier(
    name: 'Super',
    intro: 'Everything in Premium, and more:',
    extra: [
      _Benefit(CupertinoIcons.arrow_up, 'Larger reply boost'),
      _Benefit(CupertinoIcons.arrow_up, 'Prioritized ranking in replies'),
      _Benefit(CupertinoIcons.person_2, 'Creator subscriptions'),
    ],
    monthly: '₱1,960',
    monthlyNote: 'Billed monthly',
    yearly: '₱19,600',
    yearlyNote: '₱1,633/month',
    renews: 'Renews at ₱1,960 a month, cancel anytime',
    cta: 'Subscribe',
  ),
  _Tier(
    name: 'Ultra',
    intro: 'Everything in Super, and more:',
    extra: [
      _Benefit(CupertinoIcons.arrow_up, 'Larger reply boost'),
      _Benefit(CupertinoIcons.arrow_up, 'Prioritized ranking in replies'),
      _Benefit(CupertinoIcons.person_2, 'Creator subscriptions'),
      _Benefit(CupertinoIcons.sparkles, 'Highest usage limits'),
    ],
    monthly: '₱4,900',
    monthlyNote: 'Billed monthly',
    yearly: '₱49,000',
    yearlyNote: '₱4,083/month',
    renews: 'Renews at ₱4,900 a month, cancel anytime',
    cta: 'Subscribe',
  ),
];

/// "One subscription. Access to everything." — plans and benefits. Display
/// only: nothing can be purchased in this project.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _tier = 0;
  bool _yearly = false;

  Widget _logos(AppPalette p) {
    Widget icon(IconData i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Icon(i, size: 26, color: p.text),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 26),
        icon(CupertinoIcons.sparkles),
        icon(CupertinoIcons.cube_fill),
        icon(CupertinoIcons.circle_fill),
      ],
    );
  }

  Widget _segments(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tiers.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tier = i),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _tier ? p.background : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: i == _tier
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _tiers[i].name,
                    style: TextStyle(
                      color: i == _tier ? p.text : p.subtext,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(AppPalette p, String text, {bool brand = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (brand) ...[
                const BrandMark(size: 14),
                const SizedBox(width: 6),
              ],
              Text(text, style: TextStyle(color: p.subtext, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: p.border),
        ],
      ),
    );
  }

  Widget _benefit(AppPalette p, _Benefit b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(b.icon, size: 18, color: p.text),
          const SizedBox(width: 10),
          Flexible(
            child: Text(b.label, style: TextStyle(color: p.text, fontSize: 16)),
          ),
          if (b.info) ...[
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => notify(
                context,
                title: b.label,
                message: 'Included with the ${_tiers[_tier].name} plan.',
              ),
              child: Icon(
                CupertinoIcons.info_circle,
                size: 15,
                color: p.subtext,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceCard(
    AppPalette p, {
    required bool selected,
    required String price,
    required String unit,
    required String note,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: selected ? p.accent.withValues(alpha: 0.07) : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? p.accent : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: price,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(color: p.subtext, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: TextStyle(
                  color: selected ? p.accent : p.subtext,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = _tiers[_tier];
    final plusBenefits = [..._base, ...t.extra];

    return PlainScaffold(
      child: SafeArea(
        child: ContentWidth(
          maxWidth: 640,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _logos(p),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 16,
                              color: p.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      Text(
                        'One subscription.\nAccess to everything.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                        decoration: BoxDecoration(
                          color: p.background,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: p.border, width: 0.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 16,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _segments(p),
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                t.intro,
                                style: TextStyle(
                                  color: p.subtext,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            _sectionLabel(
                              p,
                              'Benefits',
                              brand: true,
                            ),
                            for (final b in plusBenefits) _benefit(p, b),
                            _sectionLabel(p, 'AI Benefits'),
                            for (final b in _ai) _benefit(p, b),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    _priceCard(
                      p,
                      selected: !_yearly,
                      price: t.monthly,
                      unit: 'monthly',
                      note: t.monthlyNote,
                      onTap: () => setState(() => _yearly = false),
                    ),
                    const SizedBox(width: 12),
                    _priceCard(
                      p,
                      selected: _yearly,
                      price: t.yearly,
                      unit: 'yearly',
                      note: t.yearlyNote,
                      onTap: () => setState(() => _yearly = true),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Text(
                  t.renews,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtext, fontSize: 15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => notify(
                    context,
                    title: 'Demo only',
                    message: 'Payments are not part of ${AppConfig.appName}, '
                        'so nothing was charged.',
                  ),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.text,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Text(
                      t.cta,
                      style: TextStyle(
                        color: p.background,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  'Prices shown do not include applicable taxes or fees. New '
                  'subscriptions auto-renew until you cancel. Cancel anytime, '
                  'at least 24 hours prior to renewal to avoid additional '
                  'charges. Prices subject to change.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.subtext, fontSize: 12, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
