import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import 'avatar.dart';

/// Create, replace or delete my Note. Resolves to true when something
/// changed (so the caller reloads the strip).
Future<bool> showMyNoteSheet(
  BuildContext context, {
  required Profile? me,
  required StatusNote? current,
}) async {
  final changed = await showCupertinoModalPopup<bool>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _MyNoteSheet(me: me, current: current),
  );
  return changed ?? false;
}

/// Somebody else's Note, with a box to answer it as a direct message.
Future<void> showNoteSheet(BuildContext context, StatusNote note) {
  final parent = context;
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _NoteSheet(note: note, parent: parent),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 560),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          media.viewInsets.bottom + media.padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _t(Color c, double size, {FontWeight w = FontWeight.w400}) =>
    TextStyle(
      color: c,
      fontSize: size,
      fontWeight: w,
      decoration: TextDecoration.none,
    );

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    required this.color,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onTap != null && !busy;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : null,
            borderRadius: BorderRadius.circular(22),
            border: filled ? null : Border.all(color: p.border, width: 1),
          ),
          child: busy
              ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
              : Text(
                  label,
                  style: _t(
                    filled ? const Color(0xFFFFFFFF) : color,
                    16,
                    w: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My note
// ---------------------------------------------------------------------------

class _MyNoteSheet extends StatefulWidget {
  const _MyNoteSheet({required this.me, required this.current});

  final Profile? me;
  final StatusNote? current;

  @override
  State<_MyNoteSheet> createState() => _MyNoteSheetState();
}

class _MyNoteSheetState extends State<_MyNoteSheet> {
  late final TextEditingController _c =
      TextEditingController(text: widget.current?.content ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _text => _c.text.trim();

  Future<void> _share() async {
    if (_text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.setStatusNote(_text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete note?',
      message: 'People will no longer see it.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.deleteStatusNote();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cur = widget.current;
    final len = _text.runes.length;
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(
                url: widget.me?.avatarUrl,
                name: widget.me?.name ?? 'You',
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cur == null ? 'Share a thought' : 'Your note',
                      style: _t(p.text, 18, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cur == null
                          ? 'Visible to your followers for 24 hours.'
                          : 'Posted ${timeago.format(cur.createdAt)} · '
                              '${cur.timeLeft}',
                      style: _t(p.subtext, 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _c,
            autofocus: true,
            maxLength: StatusNote.maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            placeholder: 'What’s on your mind?',
            placeholderStyle: _t(p.subtext, 17),
            style: _t(p.text, 17),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$len/${StatusNote.maxLength}',
                style: _t(len >= StatusNote.maxLength ? p.danger : p.subtext, 13),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Pill(
            label: cur == null ? 'Share' : 'Replace note',
            color: p.accent,
            busy: _busy,
            onTap: (_text.isEmpty || len > StatusNote.maxLength) ? null : _share,
          ),
          if (cur != null) ...[
            const SizedBox(height: 10),
            _Pill(
              label: 'Delete note',
              color: p.danger,
              filled: false,
              onTap: _busy ? null : _delete,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Somebody else's note
// ---------------------------------------------------------------------------

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.note, required this.parent});

  final StatusNote note;
  final BuildContext parent;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _c = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final parent = widget.parent;
    try {
      await Api.replyToStatusNote(widget.note, text);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (parent.mounted) showSuccess(parent, 'Reply sent');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final n = widget.note;
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(
                url: n.avatarUrl,
                name: n.name,
                size: 44,
                square: Avatar.isSquare(n.verified),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(p.text, 16, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${n.username} · ${timeago.format(n.createdAt)} · '
                      '${n.timeLeft}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(p.subtext, 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              n.content,
              textAlign: TextAlign.center,
              style: _t(p.text, 19, w: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _c,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  placeholder: 'Reply to ${n.name}…',
                  placeholderStyle: _t(p.subtext, 16),
                  style: _t(p.text, 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _c.text.trim().isEmpty ? null : _send,
                child: Opacity(
                  opacity: _c.text.trim().isEmpty ? 0.45 : 1,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(color: p.accent, shape: BoxShape.circle),
                    child: _sending
                        ? const CupertinoActivityIndicator(
                            color: Color(0xFFFFFFFF))
                        : const Icon(
                            CupertinoIcons.arrow_up,
                            size: 22,
                            color: Color(0xFFFFFFFF),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your reply goes to their messages.',
            textAlign: TextAlign.center,
            style: _t(p.subtext, 12),
          ),
        ],
      ),
    );
  }
}
