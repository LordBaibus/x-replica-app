import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';

/// "Community Notes" of one post: every note people wrote, with the
/// Helpful / Not helpful ratings that decide when a note is shown on the post.
class PostNotesScreen extends StatefulWidget {
  const PostNotesScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostNotesScreen> createState() => _PostNotesScreenState();
}

class _PostNotesScreenState extends State<PostNotesScreen> {
  List<CommunityNote> _notes = const [];
  int _requests = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await Future.wait([
        Api.fetchNotes(widget.post.id),
        Api.noteRequestCount(widget.post.id),
      ]);
      if (!mounted) return;
      setState(() {
        _notes = r[0] as List<CommunityNote>;
        _requests = r[1] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _rate(CommunityNote n, bool helpful) async {
    // Tapping the same rating again takes it back.
    final next = n.myRating == helpful ? null : helpful;
    try {
      await Api.rateNote(n.id, next);
      await _load(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(CommunityNote n) async {
    final ok = await confirm(
      context,
      title: 'Delete your note?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.deleteNote(n.id);
      await _load(silent: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _write() async {
    final added = await Navigator.of(context).push<bool>(
      appRoute(WriteNoteScreen(post: widget.post), fullscreen: true),
    );
    if (added == true) await _load(silent: true);
  }

  Widget _pill(AppPalette p, String label, bool on, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? p.accent : null,
          border: Border.all(color: on ? p.accent : p.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? const Color(0xFFFFFFFF) : p.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _note(AppPalette p, CommunityNote n) {
    final mine = n.authorId == Api.uid;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                n.shown
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.hourglass,
                size: 16,
                color: n.shown ? p.accent : p.subtext,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n.shown ? 'Shown on the post' : 'Needs more ratings',
                  style: TextStyle(
                    color: n.shown ? p.accent : p.subtext,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (mine)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _delete(n),
                  child: Icon(CupertinoIcons.delete, size: 18, color: p.subtext),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            n.body,
            style: TextStyle(color: p.text, fontSize: 16, height: 1.3),
          ),
          if (n.sourceUrl != null && n.sourceUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              n.sourceUrl!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.accent, fontSize: 14),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'by @${n.authorUsername} · '
            '${timeago.format(n.createdAt, locale: 'en_short')} · '
            '${n.helpfulCount} helpful · ${n.notHelpfulCount} not helpful',
            style: TextStyle(color: p.subtext, fontSize: 13),
          ),
          if (!mine) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _pill(p, 'Helpful', n.myRating == true, () => _rate(n, true)),
                const SizedBox(width: 10),
                _pill(p, 'Not helpful', n.myRating == false,
                    () => _rate(n, false)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _content(AppPalette p) {
    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text(
            _requests == 0
                ? 'Nobody has requested a note on this post.'
                : '$_requests ${_requests == 1 ? 'person' : 'people'} asked '
                    'for a Community Note on this post.',
            style: TextStyle(color: p.subtext, fontSize: 14),
          ),
        ),
        if (_notes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: Text(
              'No notes yet. Be the first to add context.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.subtext, fontSize: 16),
            ),
          ),
        for (final n in _notes) _note(p, n),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _write,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.text,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Text(
                'Write a note',
                style: TextStyle(
                  color: p.background,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Text(
            'A note is shown on the post once at least 2 people rated it '
            'helpful and more people rated it helpful than not helpful.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      body = _content(p);
    }
    return AdaptiveScaffold(
      backgroundColor: p.background,
      body: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: SafeArea(
          child: ContentWidth(
            child: Column(
              children: [
                const PageHeader(title: 'Community Notes'),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Write a note": the note (up to 280 characters) and an optional source.
/// Pops with true when it was saved.
class WriteNoteScreen extends StatefulWidget {
  const WriteNoteScreen({super.key, required this.post});

  final Post post;

  @override
  State<WriteNoteScreen> createState() => _WriteNoteScreenState();
}

class _WriteNoteScreenState extends State<WriteNoteScreen> {
  final _body = TextEditingController();
  final _source = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    _source.dispose();
    super.dispose();
  }

  bool get _valid {
    final n = _body.text.trim().length;
    return n >= 10 && n <= 280;
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      await Api.addNote(widget.post.id, _body.text, source: _source.text);
      if (!mounted) return;
      showInfo(context, 'Note added');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  Widget _box(AppPalette p, TextEditingController c, String hint,
      {int maxLines = 1, int? maxLength}) {
    return CupertinoTextField(
      controller: c,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 4,
      maxLength: maxLength,
      placeholder: hint,
      placeholderStyle: TextStyle(color: p.subtext, fontSize: 16),
      style: TextStyle(color: p.text, fontSize: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: p.border, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final on = _valid && !_saving;
    return ColoredBox(
      color: p.background,
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
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Cancel',
                            style: TextStyle(color: p.text, fontSize: 16)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Write a note',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: on ? _save : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Opacity(
                          opacity: on ? 1 : 0.4,
                          child: Text('Submit',
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: p.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Add context to this post',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Explain what is missing or misleading. Stay neutral, '
                      'stick to the facts and add a source if you can.',
                      style: TextStyle(
                          color: p.subtext, fontSize: 15, height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    _box(p, _body, 'Write your note (10–280 characters)',
                        maxLines: 6, maxLength: 280),
                    const SizedBox(height: 12),
                    _box(p, _source, 'Source link (optional)'),
                    const SizedBox(height: 10),
                    Text(
                      '${_body.text.trim().length}/280',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: p.subtext, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
