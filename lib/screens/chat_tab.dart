import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/chat_passcode.dart';
import '../widgets/chat_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'conversations_view.dart';

enum _Stage { loading, intro, create, confirm, unlock, inbox }

/// The Chat tab: "Welcome to the new X Chat" → Create Passcode → Confirm
/// Passcode → inbox. Once a passcode exists it is asked once per app start.
class ChatTab extends StatefulWidget {
  const ChatTab({
    super.key,
    this.me,
    this.onOpenDrawer,
    this.onOpenSettings,
  });

  final Profile? me;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSettings;

  @override
  State<ChatTab> createState() => ChatTabState();
}

class ChatTabState extends State<ChatTab> {
  _Stage _stage = _Stage.loading;
  String _firstPin = '';
  String? _error;
  int _attempt = 0;
  final GlobalKey<ConversationsViewState> _inbox =
      GlobalKey<ConversationsViewState>();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    ChatSecurity mode;
    try {
      mode = await ChatPasscode.mode();
    } catch (_) {
      mode = ChatSecurity.device;
    }
    if (!mounted) return;
    setState(() {
      switch (mode) {
        case ChatSecurity.none:
          _stage = _Stage.intro;
        case ChatSecurity.device:
          _stage = _Stage.inbox;
        case ChatSecurity.passcode:
          _stage = ChatPasscode.isUnlocked ? _Stage.inbox : _Stage.unlock;
      }
    });
  }

  /// Refreshes the inbox when the tab comes into view.
  void reload() => _inbox.currentState?.reload();

  Future<void> _useDevice() async {
    try {
      await ChatPasscode.useDevice();
    } catch (_) {}
    if (mounted) setState(() => _stage = _Stage.inbox);
  }

  Future<void> _forgot() async {
    final ok = await confirm(
      context,
      title: 'Reset passcode?',
      message: 'You will set up Chat again with a new passcode.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok) return;
    await ChatPasscode.clear();
    if (mounted) setState(() => _stage = _Stage.intro);
  }

  Future<void> _onConfirmed(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _error = "Passcodes don't match. Try again.";
        _attempt++;
      });
      return;
    }
    try {
      await ChatPasscode.savePin(pin);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (mounted) setState(() => _stage = _Stage.inbox);
  }

  Future<void> _onUnlock(String pin) async {
    final ok = await ChatPasscode.verify(pin);
    if (!mounted) return;
    if (ok) {
      setState(() => _stage = _Stage.inbox);
    } else {
      setState(() {
        _error = 'Incorrect passcode. Try again.';
        _attempt++;
      });
    }
  }

  // ---- Welcome screen ------------------------------------------------------

  Widget _feature(AppPalette p, IconData? icon, Widget? glyph, String title,
      String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: glyph ?? Icon(icon, size: 26, color: p.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: p.subtext, fontSize: 16, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(AppPalette p) {
    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatHeader(
              me: widget.me,
              onAvatar: widget.onOpenDrawer ?? () {},
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => notify(
                  context,
                  title: 'About X Chat',
                  message: 'X Chat is where you send direct messages. A '
                      'passcode keeps your chat closed on this device.',
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.question_circle,
                    size: 26,
                    color: p.text,
                  ),
                ),
              ),
            ),
            const HairlineDivider(),
            Expanded(
              child: ContentWidth(
                maxWidth: 600,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to the new X Chat',
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 40),
                              _feature(
                                p,
                                CupertinoIcons.lock,
                                null,
                                'End-to-end encryption',
                                'Messages are end-to-end encrypted across all '
                                    'your devices.',
                              ),
                              _feature(
                                p,
                                CupertinoIcons.checkmark_shield,
                                null,
                                'State-of-the-art privacy',
                                'There’s no way for anyone, including X, to '
                                    'read your messages.',
                              ),
                              _feature(
                                p,
                                null,
                                PasscodeGlyph(size: 24, color: p.text),
                                'Set passcode',
                                'In order to secure your messages, you’ll need '
                                    'to set up a passcode.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          label: 'Create Passcode',
                          style: PillStyle.inverse,
                          height: 52,
                          fontSize: 17,
                          onPressed: () =>
                              setState(() => _stage = _Stage.create),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _useDevice,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Let device manage my passcode',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.subtext, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
    const keep =
        'This passcode should be memorable and kept private. Without it, you '
        'will not be able to access your messages.';

    switch (_stage) {
      case _Stage.loading:
        return PlainScaffold(child: const LoadingView());
      case _Stage.intro:
        return _intro(p);
      case _Stage.create:
        return PasscodeEntry(
          key: const ValueKey('create'),
          title: 'Create Passcode',
          description: keep,
          onBack: () => setState(() => _stage = _Stage.intro),
          onComplete: (pin) => setState(() {
            _firstPin = pin;
            _error = null;
            _stage = _Stage.confirm;
          }),
        );
      case _Stage.confirm:
        return PasscodeEntry(
          key: ValueKey('confirm$_attempt'),
          title: 'Confirm Passcode',
          description: keep,
          error: _error,
          onBack: () => setState(() {
            _error = null;
            _stage = _Stage.create;
          }),
          onComplete: _onConfirmed,
        );
      case _Stage.unlock:
        return PasscodeEntry(
          key: ValueKey('unlock$_attempt'),
          title: 'Enter Passcode',
          description: 'Enter your passcode to open your messages.',
          error: _error,
          footer: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _forgot,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Forgot passcode?',
                style: TextStyle(color: p.accent, fontSize: 15),
              ),
            ),
          ),
          onComplete: _onUnlock,
        );
      case _Stage.inbox:
        return ConversationsView(
          key: _inbox,
          me: widget.me,
          onOpenDrawer: widget.onOpenDrawer,
          onOpenSettings: widget.onOpenSettings,
        );
    }
  }
}

/// The small rounded square with two dots and a bar (the passcode symbol).
class PasscodeGlyph extends StatelessWidget {
  const PasscodeGlyph({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.13;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: size * 0.09),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: dot * 0.8),
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: dot * 0.9),
          Container(
            width: dot,
            height: size * 0.34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(dot / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four empty circles that fill as digits are typed (hidden number field).
class PasscodeEntry extends StatefulWidget {
  const PasscodeEntry({
    super.key,
    required this.title,
    required this.description,
    required this.onComplete,
    this.onBack,
    this.error,
    this.footer,
  });

  final String title;
  final String description;
  final ValueChanged<String> onComplete;
  final VoidCallback? onBack;
  final String? error;
  final Widget? footer;

  @override
  State<PasscodeEntry> createState() => _PasscodeEntryState();
}

class _PasscodeEntryState extends State<PasscodeEntry> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    if (value.length == 4 && !_done) {
      _done = true;
      FocusScope.of(context).unfocus();
      Future<void>.microtask(() => widget.onComplete(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final typed = _controller.text.length;

    return PlainScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.onBack == null
                    ? null
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onBack,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            CupertinoIcons.arrow_left,
                            size: 24,
                            color: p.text,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _focus.requestFocus(),
                child: ContentWidth(
                  maxWidth: 560,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      child: Column(
                      children: [
                        const SizedBox(height: 40),
                        PasscodeGlyph(size: 44, color: p.text),
                        const SizedBox(height: 28),
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.subtext,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                width: 52,
                                height: 52,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: p.subtext,
                                    width: 2,
                                  ),
                                ),
                                child: i < typed
                                    ? Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: p.text,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                        if (widget.error != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            widget.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.danger, fontSize: 15),
                          ),
                        ],
                        if (widget.footer != null) widget.footer!,
                        // Hidden field that receives the digits.
                        SizedBox(
                          width: 1,
                          height: 1,
                          child: Opacity(
                            opacity: 0,
                            child: CupertinoTextField(
                              controller: _controller,
                              focusNode: _focus,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              showCursor: false,
                              enableInteractiveSelection: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              onChanged: _changed,
                            ),
                          ),
                        ),
                      ],
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
