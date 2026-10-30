import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../widgets/badges.dart';

/// Reasons offered by the report flow, in X's order.
const _reportReasons = <String>[
  'Spam',
  'Hate, Abuse, or Harassment',
  'Child Safety',
  'Violent Speech',
  'Graphic or Violent Media',
  'Illegal and Regulated Behaviors',
  'Impersonation',
  'Adult Sexual Content',
  'Private or Non-Consensual Content',
  'Suicide or Self-Harm',
  'Terrorism or Violent Extremism',
  'Civic Integrity',
];

/// Shared frame of the two full-screen flows: a top bar with a centre title
/// and "Cancel" on the right.
class _FlowFrame extends StatelessWidget {
  const _FlowFrame({
    required this.title,
    required this.child,
    this.background,
  });

  final Widget title;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ColoredBox(
      color: background ?? p.background,
      child: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 52,
                color: p.background,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    title,
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: p.text, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: p.accent.withValues(alpha: 0.18)),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Report post": pick what is wrong, then a short thank-you step. The
/// report is saved in the `reports` table.
class ReportPostScreen extends StatefulWidget {
  const ReportPostScreen({super.key, required this.post});

  final Post post;

  @override
  State<ReportPostScreen> createState() => _ReportPostScreenState();
}

class _ReportPostScreenState extends State<ReportPostScreen> {
  int? _picked;
  bool _done = false;
  bool _sending = false;

  Future<void> _submit() async {
    final i = _picked;
    if (i == null || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.reportPost(widget.post, _reportReasons[i]);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, e);
    }
  }

  Widget _progress(AppPalette p, double fraction) {
    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 3,
          width: c.maxWidth * fraction,
          color: p.accent,
        ),
      ),
    );
  }

  Widget _bigButton(AppPalette p, String label, VoidCallback? onTap) {
    final on = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.text : const Color(0xFF8B8D91),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? p.background : const Color(0xFFFFFFFF),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _reasons(AppPalette p) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(
              'What are you reporting?',
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 3, child: _progress(p, 0.33)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              Text(
                'Please choose the category that best describes your issue.',
                style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _reportReasons.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _picked = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _reportReasons[i],
                            style: TextStyle(
                              color: p.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _picked == i ? p.accent : p.subtext,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _picked == i
                              ? Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: p.accent,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: p.text, fontSize: 15, height: 1.35),
                  children: [
                    const TextSpan(
                      text:
                          'You can learn more about our policies and additional reporting options in our ',
                    ),
                    TextSpan(
                      text: 'Help Center',
                      style: TextStyle(color: p.accent),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _bigButton(
            p,
            'Next',
            _picked == null || _sending ? null : _submit,
          ),
        ),
      ],
    );
  }

  Future<void> _mute() async {
    try {
      await Moderation.instance.mute(widget.post.userId);
      if (mounted) showInfo(context, '@${widget.post.username} was muted');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _block() async {
    final handle = '@${widget.post.username}';
    if (!await confirm(
      context,
      title: 'Block $handle?',
      message: 'They will not be able to follow you or see your posts.',
      confirmLabel: 'Block',
      destructive: true,
    )) {
      return;
    }
    try {
      await Moderation.instance.block(widget.post.userId);
      if (mounted) showInfo(context, '$handle was blocked');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _thanks(AppPalette p) {
    final handle = '@${widget.post.username}';
    Widget action(String label, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 16, color: p.subtext),
              ],
            ),
          ),
        );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(
              'Thanks for letting us know',
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 3, child: _progress(p, 1)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              Text(
                'Your report was saved and helps make the app safer. You can also take action on your own:',
                style: TextStyle(color: p.subtext, fontSize: 15, height: 1.35),
              ),
              const SizedBox(height: 16),
              action('Mute $handle', _mute),
              action('Block $handle', _block),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _bigButton(p, 'Done', () => Navigator.of(context).maybePop()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _FlowFrame(
      title: XMark(color: p.text, size: 22),
      child: _done ? _thanks(p) : _reasons(p),
    );
  }
}

/// "Request a Community Note about this post". The request (with the optional
/// source link and explanation) is saved in `note_requests`.
class CommunityNoteScreen extends StatefulWidget {
  const CommunityNoteScreen({super.key, required this.post});

  final Post post;

  @override
  State<CommunityNoteScreen> createState() => _CommunityNoteScreenState();
}

class _CommunityNoteScreenState extends State<CommunityNoteScreen> {
  final _source = TextEditingController();
  final _reason = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _source.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await Api.requestNote(
        widget.post.id,
        source: _source.text,
        reason: _reason.text,
      );
      if (!mounted) return;
      // Message first: the context is gone once the page is closed.
      showInfo(context, 'Community Note requested');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, e);
    }
  }

  Widget _point(AppPalette p, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: p.text),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: p.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(AppPalette p, String hint, TextEditingController c,
      {int maxLines = 1}) {
    return CupertinoTextField(
      controller: c,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 3,
      placeholder: hint,
      placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
      style: TextStyle(color: p.text, fontSize: 17),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.border, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dark = p.background.computeLuminance() < 0.5;
    const underline = TextDecoration.underline;
    return _FlowFrame(
      background: dark ? const Color(0xFF1B1D21) : const Color(0xFF9B9B9B),
      title: Text(
        'Community Notes',
        style: TextStyle(
          color: p.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(22),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            children: [
              Text(
                'Request a Community Note about this post',
                style: TextStyle(
                  color: p.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Think this post is potentially misleading? Request a Community Note.',
                style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 24),
              _point(p, CupertinoIcons.speaker_2_fill,
                  'Contributors will see alerts on posts that get enough requests'),
              _point(p, CupertinoIcons.pencil,
                  'If a note is written and rated helpful by other contributors, it will be shown on the post'),
              _point(p, CupertinoIcons.person_3_fill,
                  'X doesn’t choose which notes show – Community Notes is by the people, for the people'),
              const SizedBox(height: 4),
              Text(
                'Add a source?',
                style: TextStyle(
                  color: p.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help Community Notes contributors by including a link to an X post that explains what is potentially misleading.',
                style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 12),
              _field(p, 'Link to an X post', _source),
              const SizedBox(height: 20),
              Text(
                'Explain?',
                style: TextStyle(
                  color: p.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Help Community Notes contributors by explaining more about what is potentially misleading.',
                style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 12),
              _field(p, 'Explanation', _reason, maxLines: 4),
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: p.subtext, fontSize: 15, height: 1.35),
                  children: const [
                    TextSpan(text: 'Requests are anonymized and made '),
                    TextSpan(
                      text: 'available to the public',
                      style: TextStyle(decoration: underline),
                    ),
                    TextSpan(text: ' for transparency'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: p.subtext, fontSize: 15),
                  children: const [
                    TextSpan(text: 'Learn more about '),
                    TextSpan(
                      text: 'Community Notes',
                      style: TextStyle(decoration: underline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _submit,
                child: Opacity(
                  opacity: _sending ? 0.5 : 1,
                  child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.text,
                    borderRadius: BorderRadius.circular(27),
                  ),
                  child: Text(
                    'Agree & Request a note',
                    style: TextStyle(
                      color: p.background,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
