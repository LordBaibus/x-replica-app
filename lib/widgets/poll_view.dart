import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';

/// "3h left" / "1d left" for an open poll.
String pollTimeLeft(DateTime end) {
  final d = end.difference(DateTime.now());
  if (d.inDays >= 1) return '${d.inDays}d left';
  if (d.inHours >= 1) return '${d.inHours}h left';
  if (d.inMinutes >= 1) return '${d.inMinutes}m left';
  return 'Less than a minute left';
}

/// A poll under a post: tap an answer to vote, then see the results.
class PollView extends StatefulWidget {
  const PollView({super.key, required this.post});

  final Post post;

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  List<PollOption>? _options;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Api.fetchPollResults(widget.post.id);
      if (mounted) {
        setState(() {
          _options = list;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _ended => !widget.post.pollEndsAt!.isAfter(DateTime.now());

  Future<void> _vote(PollOption option) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Api.votePoll(widget.post.id, option.id);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final options = _options;

    if (options == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _failed
            ? GestureDetector(
                onTap: _load,
                child: Text(
                  'Couldn’t load the poll. Tap to retry.',
                  style: TextStyle(color: p.subtext, fontSize: 14),
                ),
              )
            : const CupertinoActivityIndicator(),
      );
    }

    final total = options.fold<int>(0, (a, o) => a + o.votes);
    final voted = options.any((o) => o.votedByMe);
    final showResults = _ended || voted || widget.post.userId == Api.uid;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: showResults
                  ? _resultBar(p, o, total)
                  : _voteButton(p, o),
            ),
          Text(
            '$total ${total == 1 ? 'vote' : 'votes'} · '
            '${_ended ? 'Final results' : pollTimeLeft(widget.post.pollEndsAt!)}',
            style: TextStyle(color: p.subtext, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _voteButton(AppPalette p, PollOption o) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _vote(o),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: p.accent, width: 1.2),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          o.label,
          style: TextStyle(
            color: p.accent,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _resultBar(AppPalette p, PollOption o, int total) {
    final fraction = total == 0 ? 0.0 : o.votes / total;
    final percent = (fraction * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        color: p.surface,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.02, 1.0),
              child: Container(
                color: o.votedByMe
                    ? p.accent.withValues(alpha: 0.45)
                    : p.accent.withValues(alpha: 0.22),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight:
                            o.votedByMe ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (o.votedByMe) ...[
                    const SizedBox(width: 6),
                    Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 15, color: p.text),
                  ],
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
