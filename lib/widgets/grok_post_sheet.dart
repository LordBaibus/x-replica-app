import 'package:flutter/cupertino.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import 'ai_dialogs.dart' show AiGlyph;

/// "Explain this post": the AI helper reads the post and answers in a sheet.
/// Follow-up questions can be typed at the bottom.
Future<void> showGrokPostSheet(BuildContext context, Post post) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => _GrokSheet(post: post),
  );
}

class _Turn {
  _Turn(this.role, this.text);
  final String role; // user | assistant
  final String text;
}

class _GrokSheet extends StatefulWidget {
  const _GrokSheet({required this.post});

  final Post post;

  @override
  State<_GrokSheet> createState() => _GrokSheetState();
}

class _GrokSheetState extends State<_GrokSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Turn> _turns = [];
  bool _busy = false;
  int _run = 0; // bumped by "stop" so an old answer is ignored
  String? _error;

  String get _intro {
    final p = widget.post;
    final media = p.images.isEmpty ? '' : ' (it has ${p.images.length} picture(s))';
    return 'Explain this post by ${p.authorName} (@${p.username})$media. '
        'Say what it means, any context that helps, and keep it short.\n\n'
        '"${p.content}"';
  }

  @override
  void initState() {
    super.initState();
    _ask(_intro, shown: 'Explain this post');
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String prompt, {String? shown}) async {
    final run = ++_run;
    setState(() {
      _turns.add(_Turn('user', shown ?? prompt));
      _busy = true;
      _error = null;
    });
    _toEnd();

    // The first message always carries the post, so follow-ups know it.
    final history = <Map<String, String>>[
      {'role': 'user', 'content': _intro},
      for (var i = 1; i < _turns.length; i++)
        {'role': _turns[i].role, 'content': _turns[i].text},
    ];
    try {
      final answer = await AiAssist.chat(history);
      if (!mounted || run != _run) return;
      setState(() {
        _turns.add(_Turn('assistant', answer));
        _busy = false;
      });
    } catch (e) {
      if (!mounted || run != _run) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
    _toEnd();
  }

  void _stop() {
    _run++;
    setState(() => _busy = false);
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    _ask(text);
  }

  Widget _bubble(AppPalette p, _Turn t) {
    final mine = t.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: mine ? p.field : const Color(0x00000000),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          t.text,
          style: TextStyle(color: p.text, fontSize: 16, height: 1.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final post = widget.post;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: media.size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(bottom: media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      AiGlyph(size: 22, color: p.text),
                      const SizedBox(width: 8),
                      Text(
                        'Grok',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                          color: p.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 0.5, color: p.border),
                // The post that is being explained.
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${post.authorName}  @${post.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          post.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    children: [
                      for (final t in _turns) _bubble(p, t),
                      if (_busy) const _Dots(),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _error!,
                            style: TextStyle(color: p.danger, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 0.5, color: p.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.field,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: CupertinoTextField(
                            controller: _input,
                            placeholder: 'Ask Grok anything',
                            placeholderStyle:
                                TextStyle(color: p.subtext, fontSize: 16),
                            style: TextStyle(color: p.text, fontSize: 16),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _busy ? _stop : _submit,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.text,
                          ),
                          child: Icon(
                            _busy
                                ? CupertinoIcons.stop_fill
                                : CupertinoIcons.arrow_up,
                            size: 18,
                            color: p.background,
                          ),
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
    );
  }
}

/// Three pulsing dots while the answer is being written.
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 0, 10),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.subtext.withValues(
                    alpha: 0.25 + 0.6 * (((_c.value * 3) - i).clamp(0.0, 1.0)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
