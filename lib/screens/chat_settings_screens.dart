import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../services/api.dart';
import '../services/chat_passcode.dart';
import '../services/user_prefs.dart';
import '../widgets/dialog_card.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';

Future<T?> _push<T>(BuildContext c, Widget page) =>
    Navigator.of(c).push<T>(appRoute<T>(page));

// ===========================================================================
// Chat settings list
// ===========================================================================

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrefsPage(
      title: 'Chat',
      items: [
        const PGap(8),
        PNav(
          'Message Requests',
          icon: CupertinoIcons.envelope,
          open: (c) => _push<Object?>(c, const MessageRequestsScreen()),
        ),
        PNav(
          'Notifications',
          icon: CupertinoIcons.bell,
          open: (c) => _push<Object?>(c, const ChatNotificationsScreen()),
        ),
        PNav(
          'Audio and video calls',
          icon: CupertinoIcons.videocam,
          open: (c) => _push<Object?>(c, const CallsSettingsScreen()),
        ),
        PNav(
          'Change Passcode',
          icon: CupertinoIcons.lock,
          open: (c) => _push<Object?>(c, const PasscodeScreen()),
        ),
        PNav(
          'Data Usage',
          icon: CupertinoIcons.chart_bar,
          open: (c) => _push<Object?>(c, const ChatDataUsageScreen()),
        ),
        PNav(
          'Storage',
          icon: CupertinoIcons.folder,
          open: (c) => _push<Object?>(c, const ChatStorageScreen()),
        ),
        PNav(
          'Chat history',
          icon: CupertinoIcons.clock,
          open: (c) => _push<Object?>(c, const ChatHistoryScreen()),
        ),
        PNav(
          'Third Party Integrations',
          icon: CupertinoIcons.link,
          open: (c) => _push<Object?>(c, const ThirdPartyIntegrationsScreen()),
        ),
        PNav(
          'Troubleshooting',
          icon: CupertinoIcons.wrench,
          open: (c) => _push<Object?>(c, const ChatTroubleshootingScreen()),
        ),
      ],
    );
  }
}

// ===========================================================================
// Message Requests (real: enforced by the database)
// ===========================================================================

String dmLabel(String v) {
  switch (v) {
    case 'none':
      return 'No one';
    case 'verified':
      return 'Verified users';
    default:
      return 'Everyone';
  }
}

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  String _value = 'everyone';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.getDmSetting();
      if (mounted) {
        setState(() {
          _value = v;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _choose() async {
    final picked = await showCardDialog<String>(
      context,
      maxWidth: 420,
      builder: (ctx) => _DmDialog(initial: _value),
    );
    if (picked == null || picked == _value || !mounted) return;
    final before = _value;
    setState(() => _value = picked);
    try {
      await Api.setDmSetting(picked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _value = before);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Message Requests',
      child: ListView(
        children: [
          const SizedBox(height: 6),
          ValueRow(
            title: 'Allow requests from',
            value: _loaded ? dmLabel(_value) : '',
            menu: true,
            onTap: _loaded ? _choose : null,
          ),
          SettingsColumn(
            child: LinkText(
              'People you follow will always be able to message you. ',
              link: 'Learn more',
            ),
          ),
        ],
      ),
    );
  }
}

class _DmDialog extends StatefulWidget {
  const _DmDialog({required this.initial});

  final String initial;

  @override
  State<_DmDialog> createState() => _DmDialogState();
}

class _DmDialogState extends State<_DmDialog> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            'Allow message requests from',
            style: TextStyle(
              color: p.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        RadioRow(
          title: 'No one',
          selected: _value == 'none',
          padded: false,
          onTap: () => setState(() => _value = 'none'),
        ),
        RadioRow(
          title: 'Verified users',
          selected: _value == 'verified',
          padded: false,
          onTap: () => setState(() => _value = 'verified'),
        ),
        RadioRow(
          title: 'Everyone',
          selected: _value == 'everyone',
          padded: false,
          onTap: () => setState(() => _value = 'everyone'),
        ),
        const SizedBox(height: 14),
        DialogPillButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

// ===========================================================================
// Chat notifications / calls / troubleshooting (stored switches)
// ===========================================================================

class ChatNotificationsScreen extends StatelessWidget {
  const ChatNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Notifications',
      items: [
        PGap(8),
        PSwitch(
          'chat_push_only',
          'Enable push notifications for Chat only',
          desc: 'This will disable all other push notifications from X.',
        ),
      ],
    );
  }
}

class CallsSettingsScreen extends StatelessWidget {
  const CallsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Audio and video calls',
      items: [
        PGap(8),
        PSwitch(
          'calls_enabled',
          'Enable audio and video calling',
          desc: 'Let people call you through Chat.',
          def: true,
        ),
        PSwitch(
          'calls_relay',
          'Always relay calls',
          desc: 'Relay calls through X servers to avoid revealing your IP '
              'address to your contact. This will reduce call quality.',
        ),
        PValue(
          'calls_allow_from',
          'Allow calls from',
          options: ['Everyone', 'People you follow', 'No one'],
          def: 'People you follow',
          menu: true,
        ),
      ],
    );
  }
}

class ChatTroubleshootingScreen extends StatelessWidget {
  const ChatTroubleshootingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrefsPage(
      title: 'Troubleshooting',
      items: [
        PGap(8),
        PSwitch(
          'chat_debug_logs',
          'Enable debug logs',
          desc: 'Debug logs help find problems with Chat. They stay on this '
              'device.',
        ),
      ],
    );
  }
}

// ===========================================================================
// Data usage / Storage / History
// ===========================================================================

class ChatDataUsageScreen extends StatelessWidget {
  const ChatDataUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const options = ['WiFi + Cellular', 'WiFi only', 'Never'];
    return const PrefsPage(
      title: 'Data Usage',
      items: [
        PGap(8),
        PValue(
          'chat_dl_photos',
          'Photos',
          options: options,
          def: 'WiFi + Cellular',
          icon: CupertinoIcons.photo,
          menu: true,
        ),
        PValue(
          'chat_dl_videos',
          'Videos',
          options: options,
          def: 'WiFi + Cellular',
          icon: CupertinoIcons.videocam,
          menu: true,
        ),
        PValue(
          'chat_dl_documents',
          'Documents',
          options: options,
          def: 'WiFi + Cellular',
          icon: CupertinoIcons.doc,
          menu: true,
        ),
      ],
    );
  }
}

class ChatStorageScreen extends StatefulWidget {
  const ChatStorageScreen({super.key});

  @override
  State<ChatStorageScreen> createState() => _ChatStorageScreenState();
}

class _ChatStorageScreenState extends State<ChatStorageScreen> {
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  void _measure() {
    _bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
  }

  static String _size(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearMedia() async {
    final ok = await confirm(
      context,
      title: 'Clear media?',
      message: 'Downloaded photos and videos are removed from this device. '
          'They download again when you open them.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (!mounted) return;
      setState(_measure);
      showSuccess(context, 'Media cleared.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _resetChat() async {
    final ok = await confirm(
      context,
      title: 'Reset Chat?',
      message: 'This removes your Chat passcode from this device. You will '
          'set Chat up again the next time you open it.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ChatPasscode.clear();
      if (mounted) showSuccess(context, 'Chat was reset on this device.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = UserPrefs.instance;
    return SettingsFrame(
      title: 'Storage',
      child: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) {
          final keep = prefs.text('chat_keep_media', '30 days');
          return ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 48),
            children: [
              ValueRow(
                title: 'Keep Media',
                value: keep,
                menu: true,
                onTap: () async {
                  final v = await pickOption<String>(
                    context,
                    title: 'Keep Media',
                    selected: keep,
                    items: const [
                      PickItem('Forever', 'Forever'),
                      PickItem('1 year', '1 year'),
                      PickItem('30 days', '30 days'),
                      PickItem('7 days', '7 days'),
                    ],
                  );
                  if (v != null) await prefs.set('chat_keep_media', v);
                },
              ),
              ValueRow(
                title: 'Photos & Videos',
                value: _size(_bytes),
                chevron: false,
              ),
              ValueRow(
                title: 'Documents',
                value: '0 KB',
                chevron: false,
              ),
              ValueRow(
                title: 'Voice Messages',
                value: '0 KB',
                chevron: false,
              ),
              ValueRow(
                title: 'Clear Media',
                value: _size(_bytes),
                menu: true,
                onTap: _clearMedia,
              ),
              ValueRow(
                title: 'Reset Chat',
                danger: true,
                menu: true,
                onTap: _resetChat,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Chat history',
      child: ListView(
        children: [
          const SettingsSectionTitle('Archive'),
          ValueRow(
            title: 'Archived chats',
            value: '0 chats',
            onTap: () => _push<Object?>(
              context,
              const EmptyPage(
                title: 'Archived chats',
                heading: 'No archived chats',
                text: 'Chats you archive show up here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThirdPartyIntegrationsScreen extends StatelessWidget {
  const ThirdPartyIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyPage(
      title: 'Third Party Integrations',
      heading: 'No integrations',
      text: 'Apps with access to your chats will show here.',
    );
  }
}

// ===========================================================================
// Passcode (real: ChatPasscode)
// ===========================================================================

enum _PinStage { verify, create, confirm }

class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key});

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final _c = TextEditingController();
  final _focus = FocusNode();
  _PinStage _stage = _PinStage.create;
  String _first = '';
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    ChatPasscode.mode().then((m) {
      if (!mounted) return;
      setState(() {
        _stage = m == ChatSecurity.passcode ? _PinStage.verify : _PinStage.create;
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _entered(String code) async {
    switch (_stage) {
      case _PinStage.verify:
        final ok = await ChatPasscode.verify(code);
        if (!mounted) return;
        setState(() {
          if (ok) {
            _stage = _PinStage.create;
            _error = null;
          } else {
            _error = 'Wrong passcode. Try again.';
          }
        });
      case _PinStage.create:
        setState(() {
          _first = code;
          _stage = _PinStage.confirm;
          _error = null;
        });
      case _PinStage.confirm:
        if (code != _first) {
          setState(() {
            _stage = _PinStage.create;
            _error = 'The passcodes did not match. Start again.';
          });
        } else {
          try {
            await ChatPasscode.savePin(code);
            if (!mounted) return;
            showSuccess(context, 'Passcode saved.');
            Navigator.of(context).pop(true);
            return;
          } catch (e) {
            if (mounted) showError(context, e);
          }
        }
    }
    _c.clear();
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final title = switch (_stage) {
      _PinStage.verify => 'Enter Passcode',
      _PinStage.create => 'Create Passcode',
      _PinStage.confirm => 'Confirm Passcode',
    };
    final text = switch (_stage) {
      _PinStage.verify => 'Enter your current passcode to change it.',
      _PinStage.create => 'This passcode should be memorable and kept '
          'private. Without it, you will not be able to access your messages.',
      _PinStage.confirm => 'Enter the passcode again to confirm it.',
    };
    return SettingsFrame(
      title: '',
      showHandle: false,
      action: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => notify(
          context,
          title: 'About the passcode',
          message: 'The passcode locks the Chat tab on this device. It is '
              'saved on this device only, so ${AppConfig.appName} cannot '
              'recover it for you.',
        ),
        child: Icon(CupertinoIcons.question_circle, size: 26, color: p.text),
      ),
      child: _ready
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lock_fill, size: 54, color: p.text),
                      const SizedBox(height: 18),
                      BigHeading(title, center: true),
                      const SizedBox(height: 12),
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.subtext,
                          fontSize: 16,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 34),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _focus.requestFocus(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              width: 2,
                              height: 2,
                              child: Opacity(
                                opacity: 0,
                                child: CupertinoTextField(
                                  controller: _c,
                                  focusNode: _focus,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  showCursor: false,
                                  decoration: null,
                                  padding: EdgeInsets.zero,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  onChanged: (v) {
                                    if (v.length == 4) _entered(v);
                                  },
                                  style: const TextStyle(
                                    color: Color(0x00000000),
                                    fontSize: 1,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < _c.text.length
                                          ? p.text
                                          : const Color(0x00000000),
                                      border: Border.all(
                                        color: _error != null
                                            ? p.danger
                                            : p.text,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.danger, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : const Center(child: CupertinoActivityIndicator()),
    );
  }
}
