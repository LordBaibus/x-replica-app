import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/topics.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/dialog_card.dart';
import '../widgets/search_pill.dart';
import '../widgets/settings_parts.dart';
import 'interests_edit_screen.dart';

/// Opens the "Timelines" panel (the "+" at the end of the Home tabs).
/// Resolves to true when the pinned topics changed.
Future<bool> showTimelinesPanel(BuildContext context, Profile? me) async {
  final changed = await showCardDialog<bool>(
    context,
    maxWidth: 520,
    builder: (ctx) => TimelinesPanel(me: me),
  );
  return changed == true;
}

/// X's "Timelines" panel: search, the pinned timelines and the list of topics
/// with a green + to pin one. Pinned topics are saved in the profile and
/// become the extra tabs on Home (the first three).
class TimelinesPanel extends StatefulWidget {
  const TimelinesPanel({super.key, required this.me});

  final Profile? me;

  @override
  State<TimelinesPanel> createState() => _TimelinesPanelState();
}

class _TimelinesPanelState extends State<TimelinesPanel> {
  final _search = TextEditingController();
  late List<String> _pinned = [...?widget.me?.interests];
  bool _topicsOpen = true;
  bool _changed = false;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(Topic t) async {
    if (_busy) return;
    final next = [..._pinned];
    if (next.contains(t.id)) {
      next.remove(t.id);
    } else {
      next.add(t.id);
    }
    setState(() {
      _pinned = next;
      _busy = true;
    });
    try {
      await Api.updateMyProfile({'interests': next});
      _changed = true;
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _pinned = [...?widget.me?.interests]);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      appRoute(InterestsEditScreen(me: widget.me)),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Widget _tile(AppPalette p, Topic t, {required bool pinned}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(t.icon, size: 22, color: p.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: pinned ? p.field : kSwitchOn,
                shape: BoxShape.circle,
              ),
              child: Icon(
                pinned ? CupertinoIcons.minus : CupertinoIcons.add,
                size: 18,
                color: pinned ? p.text : const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _search.text.trim().toLowerCase();
    final pinnedTopics = Topics.fromIds(_pinned);
    final others = [
      for (final t in Topics.all)
        if (!_pinned.contains(t.id) &&
            (q.isEmpty || t.label.toLowerCase().contains(q)))
          t,
    ];
    final pinnedShown = [
      for (final t in pinnedTopics)
        if (q.isEmpty || t.label.toLowerCase().contains(q)) t,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.square_stack_3d_up, size: 22, color: p.text),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Timelines',
                style: TextStyle(
                  color: p.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(_changed),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(CupertinoIcons.xmark, size: 22, color: p.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SearchPill(
          controller: _search,
          placeholder: 'Search',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pinned',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _edit,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            color: p.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (pinnedShown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nothing pinned yet. The first three topics you pin '
                    'become tabs on Home.',
                    style: TextStyle(color: p.subtext, fontSize: 14),
                  ),
                ),
              for (final t in pinnedShown) _tile(p, t, pinned: true),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _topicsOpen = !_topicsOpen),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        'Topics',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _topicsOpen
                            ? CupertinoIcons.chevron_down
                            : CupertinoIcons.chevron_up,
                        size: 14,
                        color: p.text,
                      ),
                    ],
                  ),
                ),
              ),
              if (_topicsOpen)
                for (final t in others) _tile(p, t, pinned: false),
            ],
          ),
        ),
      ],
    );
  }
}
