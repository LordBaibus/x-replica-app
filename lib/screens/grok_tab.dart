import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/grok_history.dart';
import '../services/user_prefs.dart';
import '../services/image_picker_service.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/avatar.dart';
import '../widgets/responsive.dart';
import 'compose_post_screen.dart';

/// What the next message will do.
enum _Mode { chat, imagine, edit }

/// The Grok tab: chat, "Create Images", "Edit Image", "Hire A Bot" (roles)
/// and voice mode. Everything runs on the same AI key as the composer's AI
/// button, through the Supabase Edge Function `ai-assist`. Conversations are
/// saved on the phone.
class GrokTab extends StatefulWidget {
  const GrokTab({super.key, required this.me, required this.onOpenDrawer});

  final Profile? me;
  final VoidCallback onOpenDrawer;

  @override
  State<GrokTab> createState() => _GrokTabState();
}

class _GrokTabState extends State<GrokTab> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  final List<GrokMsg> _messages = [];
  String? _chatId;
  bool _busy = false;
  _Mode _mode = _Mode.chat;

  // Hire A Bot: a role Grok plays in this chat.
  String? _botName;
  String? _botPrompt;

  // Photo attached to the next message (chat: "look at this", edit: the
  // picture to change).
  PickedImage? _attachment;

  // "Link your Grok account": a test of the AI connection.
  bool _linked = false;
  bool _linking = false;

  bool _promoHidden = false;

  // Voice.
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  bool _ttsReady = false;
  bool _voice = false; // voice mode (talk back and forth)
  bool _listening = false;
  bool _speaking = false;
  bool _handled = false; // this listening round was already processed
  bool _autoSend = false;
  String _base = '';
  int _emptyTurns = 0;

  static const _promoKey = 'grok_promo_hidden';

  static const _bots = <(String, String)>[
    (
      'Study buddy',
      'a patient study buddy. Explain simply, give small examples and quiz '
          'the user when it helps.'
    ),
    (
      'Code helper',
      'a friendly senior programmer. Give short, correct answers and small '
          'code snippets.'
    ),
    (
      'Fitness coach',
      'an encouraging fitness coach. Give safe, practical workout and habit '
          'advice.'
    ),
    (
      'Travel planner',
      'a travel planner. Suggest realistic plans with places, timing and '
          'budget tips.'
    ),
    (
      'Chef',
      'a home-cooking chef. Suggest recipes with simple steps and swaps for '
          'missing ingredients.'
    ),
    (
      'Writing coach',
      'a writing coach. Improve the user’s text while keeping their '
          'voice, and say briefly why.'
    ),
    (
      'Comedian',
      'a witty comedian. Keep answers short, playful and kind.'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPromo();
  }

  Future<void> _loadPromo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && prefs.getBool(_promoKey) == true) {
        setState(() => _promoHidden = true);
      }
    } catch (_) {}
  }

  Future<void> _hidePromo() async {
    setState(() => _promoHidden = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promoKey, true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopAudio(quiet: true);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _setInput(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // ------------------------------------------------------------- history

  Future<void> _save() async {
    final id = _chatId;
    if (id == null || _messages.isEmpty) return;
    // Settings > AI & Third-party Collaborators > remember conversation history.
    if (!UserPrefs.instance.flag('grok_remember', true)) return;
    final first =
        _messages.firstWhere((m) => m.fromUser, orElse: () => _messages.first);
    var title = first.text.replaceAll('\n', ' ').trim();
    if (title.length > 40) title = '${title.substring(0, 40)}…';
    await GrokHistory.save(GrokChat(
      id: id,
      title: title.isEmpty ? 'New chat' : title,
      updatedAt: DateTime.now(),
      messages: List.of(_messages),
    ));
  }

  void _newChat() {
    if (_busy) return;
    _stopAudio();
    _focus.unfocus();
    setState(() {
      _messages.clear();
      _chatId = null;
      _mode = _Mode.chat;
      _attachment = null;
      _input.clear();
    });
  }

  Future<void> _openHistory() async {
    final p = AppPalette.of(context);
    final picked = await showCupertinoModalPopup<GrokChat>(
      context: context,
      builder: (ctx) => DefaultTextStyle(
        style: TextStyle(
          color: p.text,
          fontSize: 16,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w400,
        ),
        child: const _HistorySheet(),
      ),
    );
    if (picked == null || !mounted) return;
    _stopAudio();
    setState(() {
      _messages
        ..clear()
        ..addAll(picked.messages);
      _chatId = picked.id;
      _mode = _Mode.chat;
      _attachment = null;
    });
    _scrollDown();
  }

  // ------------------------------------------------------------- sending

  String get _placeholder => switch (_mode) {
        _Mode.chat => 'Ask anything',
        _Mode.imagine => 'Describe an image',
        _Mode.edit => 'Describe the change',
      };

  Future<void> _send() async {
    if (_busy) return;
    final att = _attachment;
    var text = _input.text.trim();
    final mode = _mode;

    if (mode == _Mode.edit) {
      if (att == null) {
        showInfo(context, 'Add a picture to edit first.');
        return;
      }
      if (text.isEmpty) {
        showInfo(context, 'Describe the change you want.');
        return;
      }
    } else if (text.isEmpty) {
      if (att == null) return;
      text = 'What is in this picture?';
    }

    _input.clear();
    _chatId ??= DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _messages.add(GrokMsg.user(text, attachment: att?.bytes));
      _busy = true;
      _attachment = null;
    });
    _scrollDown();

    String? spoken;
    try {
      if (mode == _Mode.imagine) {
        final img = await AiAssist.generateImage(text);
        _messages.add(GrokMsg.image(text, img.bytes));
      } else if (mode == _Mode.edit) {
        final img = await AiAssist.editImage(text, att!);
        _messages.add(GrokMsg.image(text, img.bytes));
        // Lets the user keep changing the result.
        _attachment = img;
      } else {
        // Only text goes to the model; the newest photo goes along with it.
        final history = [
          for (final m in _messages)
            if (m.fromUser || !m.isImage)
              {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
        ];
        final tail =
            history.length > 20 ? history.sublist(history.length - 20) : history;
        final reply = await AiAssist.chat(
          tail,
          persona: _botPrompt,
          image: att,
        );
        _messages.add(GrokMsg.bot(reply));
        spoken = reply;
      }
      await _save();
    } catch (e) {
      if (_voice) _stopAudio();
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
    if (_voice && spoken != null && mounted) {
      await _speak(spoken);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showInfo(context, 'Copied to clipboard');
  }

  void _asPost(String text) {
    final t = text.length > 280 ? text.substring(0, 280) : text;
    Navigator.of(context).push(
      appRoute(ComposePostScreen(initialText: t), fullscreen: true),
    );
  }

  // --------------------------------------------------------------- cards

  Future<void> _linkAccount() async {
    if (_linking) return;
    if (_linked) {
      showInfo(context, 'Grok is connected and ready.');
      return;
    }
    setState(() => _linking = true);
    try {
      await AiAssist.chat([
        {'role': 'user', 'content': 'Reply with the single word: ok'},
      ]);
      if (!mounted) return;
      setState(() => _linked = true);
      showSuccess(context, 'Grok is connected');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _hireBot() async {
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Hire A Bot'),
        message: const Text('Pick a role for Grok to play in this chat.'),
        actions: [
          for (var i = 0; i < _bots.length; i++)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(_bots[i].$1),
            ),
          if (_botName != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(-1),
              child: const Text('Dismiss the bot'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked < 0) {
        _botName = null;
        _botPrompt = null;
      } else {
        _botName = _bots[picked].$1;
        _botPrompt = _bots[picked].$2;
        _mode = _Mode.chat;
      }
    });
    _focus.requestFocus();
  }

  void _createImages() {
    setState(() {
      _mode = _Mode.imagine;
      _attachment = null;
    });
    _focus.requestFocus();
  }

  Future<PickedImage?> _chooseSource() async {
    final src = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(0),
            child: const Text('Photo library'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(1),
            child: const Text('Camera'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (src == null) return null;
    try {
      return src == 0 ? await pickGalleryImage() : await pickCameraImage();
    } catch (e) {
      if (mounted) showError(context, e);
      return null;
    }
  }

  Future<void> _attach() async {
    final img = await _chooseSource();
    if (img == null || !mounted) return;
    if (img.extension == 'gif') {
      showInfo(context, 'GIFs can’t be used here. Pick a photo.');
      return;
    }
    setState(() => _attachment = img);
  }

  Future<void> _editImage() async {
    final img = await _chooseSource();
    if (img == null || !mounted) return;
    if (img.extension == 'gif') {
      showInfo(context, 'GIFs can’t be edited. Pick a photo.');
      return;
    }
    setState(() {
      _attachment = img;
      _mode = _Mode.edit;
    });
    _focus.requestFocus();
  }

  // --------------------------------------------------------------- voice

  Future<bool> _ensureSpeech() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {
          if (mounted && _listening) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    if (!_sttReady && mounted) {
      showInfo(
        context,
        'Voice needs microphone and speech access. Allow it in Settings.',
      );
    }
    return _sttReady;
  }

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    try {
      if (PlatformInfo.isIOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        );
      }
      void done() {
        _speaking = false;
        if (mounted) {
          setState(() {});
          if (_voice) _listen(auto: true);
        }
      }

      _tts.setCompletionHandler(done);
      _tts.setErrorHandler((_) => done());
      _tts.setCancelHandler(() {
        _speaking = false;
        if (mounted) setState(() {});
      });
    } catch (_) {}
    _ttsReady = true;
  }

  Future<void> _listen({required bool auto}) async {
    if (!mounted || _busy || _listening) return;
    if (!await _ensureSpeech()) {
      if (_voice && mounted) setState(() => _voice = false);
      return;
    }
    _handled = false;
    _autoSend = auto;
    _base = auto ? '' : _input.text.trim();
    if (auto) _input.clear();
    setState(() => _listening = true);
    try {
      await _stt.listen(
        onResult: _onSpeech,
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  void _onSpeech(SpeechRecognitionResult r) {
    if (!mounted) return;
    final words = r.recognizedWords.trim();
    _setInput([_base, words].where((s) => s.isNotEmpty).join(' '));
    setState(() {});
    if (r.finalResult && !_handled) {
      _handled = true;
      _afterListen();
    }
  }

  void _onSpeechStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    // The final text can arrive just after the status, so wait a moment.
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !_listening) return;
      if (!_handled) {
        _handled = true;
        _afterListen();
      } else {
        setState(() => _listening = false);
      }
    });
  }

  void _afterListen() {
    if (!mounted) return;
    setState(() => _listening = false);
    if (!(_voice && _autoSend)) return;
    final text = _input.text.trim();
    if (text.isEmpty) {
      if (++_emptyTurns >= 3) {
        _stopAudio();
        showInfo(context, 'Voice mode paused. Tap Speak to continue.');
        return;
      }
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _voice && !_busy && !_speaking && !_listening) {
          _listen(auto: true);
        }
      });
    } else {
      _emptyTurns = 0;
      _send();
    }
  }

  Future<void> _speak(String text) async {
    await _ensureTts();
    if (!mounted || !_voice) return;
    setState(() => _speaking = true);
    try {
      await _tts.speak(text.length > 900 ? text.substring(0, 900) : text);
    } catch (_) {
      _speaking = false;
      if (mounted) {
        setState(() {});
        if (_voice) _listen(auto: true);
      }
    }
  }

  Future<void> _readAloud(String text) async {
    await _ensureTts();
    try {
      await _tts.stop();
      setState(() => _speaking = true);
      await _tts.speak(text.length > 900 ? text.substring(0, 900) : text);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  /// Stops voice mode, dictation and any spoken answer.
  void _stopAudio({bool quiet = false}) {
    _voice = false;
    _handled = true;
    _emptyTurns = 0;
    try {
      if (_sttReady) _stt.cancel();
      if (_ttsReady) _tts.stop();
    } catch (_) {}
    _listening = false;
    _speaking = false;
    if (!quiet && mounted) setState(() {});
  }

  Future<void> _toggleVoice() async {
    if (_voice) {
      _stopAudio();
      return;
    }
    if (_busy) return;
    if (!await _ensureSpeech()) return;
    _focus.unfocus();
    _emptyTurns = 0;
    setState(() {
      _voice = true;
      if (_mode != _Mode.chat) _mode = _Mode.chat;
      _attachment = null;
    });
    _listen(auto: true);
  }

  Future<void> _toggleDictation() async {
    if (_voice || _busy) return;
    if (_listening) {
      try {
        await _stt.stop();
      } catch (_) {}
      return;
    }
    await _listen(auto: false);
  }

  // --------------------------------------------------------------- build

  Widget _header(AppPalette p) {
    Widget icon(IconData i, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 44,
            child: Icon(i, size: 23, color: p.text),
          ),
        );
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenDrawer,
              child: Avatar(
                url: widget.me?.avatarUrl,
                name: widget.me?.name ?? '',
                size: 32,
              ),
            ),
            const Spacer(),
            if (_messages.isNotEmpty) icon(AppIcons.compose, _newChat),
            icon(CupertinoIcons.clock, _openHistory),
          ],
        ),
      ),
    );
  }

  Widget _promo(AppPalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(
        border: Border.all(color: p.border, width: 1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Try Grok for free',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hidePromo,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(AppIcons.close, size: 18, color: p.subtext),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Ask questions, make and edit pictures, and talk out loud.',
              style: TextStyle(color: p.subtext, fontSize: 15, height: 1.3),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _hidePromo();
              _focus.requestFocus();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: p.text,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'Try for free',
                style: TextStyle(
                  color: p.background,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(
    AppPalette p, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool tinted = false,
  }) {
    final fg = tinted ? p.accent : p.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tinted ? p.accent.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: tinted ? p.accent.withValues(alpha: 0.45) : p.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 24, color: fg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.subtext, fontSize: 12.5, height: 1.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cards(AppPalette p) {
    final cards = <Widget>[
      _featureCard(
        p,
        icon: _linked
            ? CupertinoIcons.checkmark_alt_circle
            : CupertinoIcons.link,
        title: _linked ? 'Grok linked' : 'Link your Grok account',
        subtitle: _linking
            ? 'Checking…'
            : (_linked ? 'Connected and ready' : 'Tap to connect'),
        tinted: true,
        onTap: _linkAccount,
      ),
      _featureCard(
        p,
        icon: CupertinoIcons.person_2,
        title: _botName == null ? 'Hire A Bot' : 'Bot: $_botName',
        subtitle: 'Pick a role for Grok',
        onTap: _hireBot,
      ),
      _featureCard(
        p,
        icon: CupertinoIcons.paintbrush,
        title: 'Create Images',
        subtitle: 'Describe it, Grok draws it',
        onTap: _createImages,
      ),
      _featureCard(
        p,
        icon: CupertinoIcons.photo,
        title: 'Edit Image',
        subtitle: 'Change a photo with words',
        onTap: _editImage,
      ),
      _featureCard(
        p,
        icon: CupertinoIcons.waveform,
        title: 'Try Voice Mode',
        subtitle: 'Talk, Grok talks back',
        onTap: _toggleVoice,
      ),
    ];
    return SizedBox(
      height: textScaledHeight(context, 124),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _empty(AppPalette p, bool keyboardOpen) {
    return Column(
      children: [
        if (!_promoHidden && !keyboardOpen) _promo(p),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FittedBox(
                child: AiGlyph(
                  size: 120,
                  color: p.subtext.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
        ),
        if (!keyboardOpen) _cards(p),
        if (!keyboardOpen) const SizedBox(height: 10),
      ],
    );
  }

  Widget _action(AppPalette p, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, top: 8, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: p.subtext),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: p.subtext, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _bubble(AppPalette p, GrokMsg m, double maxWidth) {
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: () => _copy(m.text),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.82),
            margin: const EdgeInsets.only(left: 40, bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.attachment != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Image.memory(m.attachment!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                Text(
                  m.text,
                  style: TextStyle(color: p.text, fontSize: 16, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (m.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(m.image!, fit: BoxFit.cover),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Image: “${m.text}” (pictures aren’t kept after you leave '
                  'the chat)',
                  style: TextStyle(color: p.subtext, fontSize: 14),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.text,
            style: TextStyle(color: p.text, fontSize: 16, height: 1.45),
          ),
          Row(
            children: [
              _action(p, CupertinoIcons.square_on_square, 'Copy',
                  () => _copy(m.text)),
              _action(p, CupertinoIcons.speaker_2, 'Listen',
                  () => _readAloud(m.text)),
              _action(p, AppIcons.compose, 'Post', () => _asPost(m.text)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(AppPalette p, IconData icon, String label, VoidCallback onClear) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: p.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(AppIcons.close, size: 12, color: p.subtext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(AppPalette p, IconData icon, VoidCallback? onTap,
      {bool active = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active ? p.text : p.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: active ? p.background : p.text),
      ),
    );
  }

  Widget _inputBox(AppPalette p) {
    final hasInput = _input.text.trim().isNotEmpty || _attachment != null;
    final canSend = hasInput && !_busy && !_voice;
    final att = _attachment;

    final chips = <Widget>[
      if (_mode == _Mode.imagine)
        _chip(p, CupertinoIcons.paintbrush, 'Create Images',
            () => setState(() => _mode = _Mode.chat)),
      if (_mode == _Mode.edit)
        _chip(p, CupertinoIcons.photo, 'Edit Image', () {
          setState(() {
            _mode = _Mode.chat;
            _attachment = null;
          });
        }),
      if (_botName != null)
        _chip(p, CupertinoIcons.person_2, _botName!, () {
          setState(() {
            _botName = null;
            _botPrompt = null;
          });
        }),
    ];

    final String status = !_voice
        ? ''
        : _listening
            ? 'Listening…'
            : _busy
                ? 'Thinking…'
                : _speaking
                    ? 'Speaking…'
                    : 'Voice mode';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        decoration: BoxDecoration(
          color: p.field,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (att != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(att.bytes,
                          width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _attachment = null;
                          if (_mode == _Mode.edit) _mode = _Mode.chat;
                        }),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: p.text,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(AppIcons.close,
                              size: 12, color: p.background),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: chips),
              ),
            if (_voice)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                child: Row(
                  children: [
                    AiGlyph(size: 18, color: p.text),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_listening && _input.text.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _input.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: CupertinoTextField(
                  controller: _input,
                  focusNode: _focus,
                  placeholder: _placeholder,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: p.accent,
                  decoration: null,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  style: TextStyle(color: p.text, fontSize: 17),
                  placeholderStyle: TextStyle(color: p.subtext, fontSize: 17),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Row(
              children: [
                _roundButton(
                  p,
                  CupertinoIcons.paperclip,
                  (_voice || _busy) ? null : _attach,
                ),
                const SizedBox(width: 8),
                _roundButton(
                  p,
                  CupertinoIcons.mic,
                  (_voice || _busy) ? null : _toggleDictation,
                  active: _listening && !_voice,
                ),
                const Spacer(),
                if (canSend)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _send,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.text,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(CupertinoIcons.arrow_up,
                          size: 20, color: p.background),
                    ),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleVoice,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: p.text,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _voice
                                ? CupertinoIcons.stop_fill
                                : CupertinoIcons.waveform,
                            size: 18,
                            color: p.background,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _voice ? 'Stop' : 'Speak',
                            style: TextStyle(
                              color: p.background,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // The tabs live in an IndexedStack: when this one is hidden, stop talking
    // and listening.
    if (!TickerMode.of(context) && (_voice || _listening || _speaking)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stopAudio();
      });
    }

    // The Scaffold above removes the keyboard from MediaQuery, so ask the
    // window itself (physical pixels).
    final view = View.of(context);
    final keyboardOpen = view.viewInsets.bottom / view.devicePixelRatio > 0;
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              _header(p),
              Expanded(
                child: _messages.isEmpty
                    ? _empty(p, keyboardOpen)
                    : ListView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: _messages.length + (_busy ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  const CupertinoActivityIndicator(),
                                  const SizedBox(width: 10),
                                  Text(
                                    _mode == _Mode.chat
                                        ? 'Thinking…'
                                        : (_mode == _Mode.edit
                                            ? 'Editing…'
                                            : 'Imagining…'),
                                    style: TextStyle(
                                        color: p.subtext, fontSize: 15),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _bubble(p, _messages[i], box.maxWidth);
                        },
                      ),
              ),
              _inputBox(p),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin separator line under the header.
class HairlineBox extends StatelessWidget {
  const HairlineBox({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AppPalette.of(context).border);
}

/// Saved conversations: tap one to open it, ✕ to delete it.
class _HistorySheet extends StatefulWidget {
  const _HistorySheet();

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<GrokChat>? _chats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await GrokHistory.load();
    if (mounted) setState(() => _chats = list);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final chats = _chats;
    Widget body;
    if (chats == null) {
      body = const Center(child: CupertinoActivityIndicator());
    } else if (chats.isEmpty) {
      body = Center(
        child: Text(
          'No saved chats yet.',
          style: TextStyle(color: p.subtext, fontSize: 16),
        ),
      );
    } else {
      body = ListView.builder(
        padding: EdgeInsets.only(bottom: media.padding.bottom + 12),
        itemCount: chats.length,
        itemBuilder: (context, i) {
          final c = chats[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeago.format(c.updatedAt),
                          style: TextStyle(color: p.subtext, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await GrokHistory.delete(c.id);
                      _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(AppIcons.close, size: 18, color: p.subtext),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: media.size.height * 0.7,
        width: double.infinity,
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('Close',
                        style: TextStyle(color: p.text, fontSize: 17)),
                  ),
                  Expanded(
                    child: Text(
                      'History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Container(height: 0.5, color: p.border),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
