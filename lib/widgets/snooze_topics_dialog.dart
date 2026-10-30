import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../services/snooze_topics.dart';
import 'dialog_card.dart';
import 'settings_parts.dart' show XSwitch;

/// "Snooze Topics": switch topics off in the For you timeline for 24 hours.
/// Every switch applies at once. Resolves to true when something changed.
Future<bool> showSnoozeTopicsDialog(BuildContext context) async {
  final before = SnoozedTopics.instance.active;
  await showCardDialog<void>(
    context,
    maxWidth: 440,
    builder: (ctx) => const _SnoozeBody(),
  );
  final after = SnoozedTopics.instance.active;
  return before.length != after.length || !before.containsAll(after);
}

class _SnoozeBody extends StatefulWidget {
  const _SnoozeBody();

  @override
  State<_SnoozeBody> createState() => _SnoozeBodyState();
}

class _SnoozeBodyState extends State<_SnoozeBody> {
  Future<void> _toggle(String id, bool on) async {
    setState(() {});
    await SnoozedTopics.instance.set(id, on);
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
    await SnoozedTopics.instance.reset();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final on = SnoozedTopics.instance.active;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardHeader(
          title: 'Snooze Topics',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                  child: Text(
                    'Select topics to hide for 24 hours',
                    style: TextStyle(color: p.subtext, fontSize: 16),
                  ),
                ),
                for (final t in SnoozedTopics.topics)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 24, color: p.text),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            t.label,
                            style: TextStyle(
                              color: p.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        XSwitch(
                          value: on.contains(t.id),
                          onChanged: (v) => _toggle(t.id, v),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _reset,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'Reset',
              style: TextStyle(
                color: p.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
