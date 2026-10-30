import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_mark.dart';
import 'onboarding_kit.dart';

/// What "Set Up" on your own profile opens: pick a profile picture, pick a
/// header, describe yourself. Every step can be skipped. Pops with `true`.
class ProfileSetupFlow extends StatefulWidget {
  const ProfileSetupFlow({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileSetupFlow> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<ProfileSetupFlow> {
  static const _emojis = [
    '😍', '😂', '🙄', '❤️', '🥺', '😭', '💔', '🤯', '🤔', '🔥', '🥳', '😎',
  ];
  static const _colors = [
    Color(0xFFF5F5F5),
    Color(0xFFDDF1FD),
    Color(0xFFE7E5FB),
    Color(0xFFFDE4EE),
    Color(0xFFFFF7D6),
    Color(0xFFE1F6EA),
    Color(0xFFD9F5F7),
  ];

  int _step = 0; // 0 picture, 1 header, 2 bio
  bool _busy = false;

  PickedImage? _photo;
  String? _emoji;
  Color? _bg;
  PickedImage? _header;
  late final TextEditingController _bio =
      TextEditingController(text: widget.profile.bio);

  final _avatarKey = GlobalKey();

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  bool get _hasAvatar => _photo != null || _emoji != null || _bg != null;

  Future<PickedImage?> _pick() async {
    try {
      return await pickGalleryImage();
    } catch (e) {
      if (mounted) showError(context, e);
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    final img = await _pick();
    if (img != null && mounted) {
      setState(() {
        _photo = img;
        _emoji = null;
        _bg = null;
      });
    }
  }

  Future<void> _pickHeader() async {
    final img = await _pick();
    if (img != null && mounted) setState(() => _header = img);
  }

  /// Turns the emoji-on-colour preview into a PNG.
  Future<PickedImage?> _renderEmoji() async {
    final ctx = _avatarKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return PickedImage(Uint8List.view(data.buffer), 'png');
  }

  Future<void> _guard(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skip() {
    if (_step >= 2) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _nextPicture() => _guard(() async {
        final img = _photo ?? await _renderEmoji();
        if (img != null) {
          final url = await Api.uploadImage(
            bucket: AppConfig.avatarsBucket,
            image: img,
          );
          await Api.updateMyProfile({'avatar_url': url});
        }
        if (mounted) setState(() => _step = 1);
      });

  Future<void> _nextHeader() => _guard(() async {
        final img = _header;
        if (img != null) {
          final url = await Api.uploadImage(
            bucket: AppConfig.avatarsBucket,
            image: img,
          );
          await Api.updateMyProfile({'header_url': url});
        }
        if (mounted) setState(() => _step = 2);
      });

  Future<void> _finish() => _guard(() async {
        await Api.updateMyProfile({'bio': _bio.text.trim()});
        if (mounted) Navigator.of(context).pop(true);
      });

  // ---- UI ----------------------------------------------------------------

  Widget _logo() => const BrandMark(size: 30);

  Widget _skipLink(AppPalette p) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'Skip for now',
            style: TextStyle(
              color: p.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );

  Widget _circleChoice(AppPalette p, {required Widget child, required VoidCallback onTap, bool selected = false, Color? fill}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? p.accent : p.subtext.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _bigAvatar(AppPalette p) {
    const size = 190.0;
    Widget content;
    final photo = _photo;
    if (photo != null) {
      content = Image.memory(photo.bytes, width: size, height: size, fit: BoxFit.cover);
    } else if (_hasAvatar) {
      content = RepaintBoundary(
        key: _avatarKey,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: _bg ?? _colors[1],
          child: Text(
            _emoji ?? '',
            style: const TextStyle(fontSize: 96, decoration: TextDecoration.none),
          ),
        ),
      );
    } else {
      content = Container(
        width: size,
        height: size,
        alignment: Alignment.bottomCenter,
        color: const Color(0xFFCFD9DE),
        child: const Icon(
          CupertinoIcons.person_fill,
          size: 150,
          color: Color(0xFF687684),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickPhoto,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: ClipOval(child: content),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 8,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.background, width: 3),
                ),
                child: const Icon(CupertinoIcons.add, size: 22, color: Color(0xFFFFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pictureStep(AppPalette p) {
    return OnboardingScaffold(
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _back,
        child: Text('Cancel', style: TextStyle(color: p.text, fontSize: 17)),
      ),
      center: _logo(),
      title: 'Pick a profile picture',
      subtitle: 'Have a favorite selfie? Upload it now.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            _bigAvatar(p),
            const SizedBox(height: 26),
            Text(
              'You can also create your own.',
              style: TextStyle(color: p.subtext, fontSize: 17),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _circleChoice(
                    p,
                    onTap: _pickPhoto,
                    child: Icon(CupertinoIcons.camera, size: 26, color: p.text),
                  ),
                  for (final e in _emojis) ...[
                    const SizedBox(width: 12),
                    _circleChoice(
                      p,
                      selected: _photo == null && _emoji == e,
                      onTap: () => setState(() {
                        _photo = null;
                        _emoji = e;
                      }),
                      child: Text(
                        e,
                        style: const TextStyle(
                          fontSize: 28,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (var i = 0; i < _colors.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    _circleChoice(
                      p,
                      fill: _colors[i],
                      selected: _photo == null && _bg == _colors[i],
                      onTap: () => setState(() {
                        _photo = null;
                        _bg = _colors[i];
                      }),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlackButton(
            label: 'Next',
            busy: _busy,
            onPressed: _hasAvatar ? _nextPicture : null,
          ),
          _skipLink(p),
        ],
      ),
    );
  }

  Widget _headerStep(AppPalette p) {
    final header = _header;
    final profile = widget.profile;
    final avatar = _photo != null
        ? ClipOval(
            child: Image.memory(_photo!.bytes, width: 92, height: 92, fit: BoxFit.cover),
          )
        : Avatar(url: profile.avatarUrl, name: profile.name, size: 92);

    return OnboardingScaffold(
      onBack: _back,
      center: _logo(),
      title: 'Pick a header',
      subtitle: 'People who visit your profile will see it. Show your style.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickHeader,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        color: const Color(0xFFCFD9DE),
                        alignment: Alignment.center,
                        child: header != null
                            ? Image.memory(
                                header.bytes,
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.camera, size: 30, color: p.accent),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Upload',
                                    style: TextStyle(color: p.accent, fontSize: 18),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: -46,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: p.background,
                          shape: BoxShape.circle,
                        ),
                        child: avatar,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 54, 12, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@${profile.username}',
                        style: TextStyle(color: p.subtext, fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlackButton(
            label: 'Next',
            busy: _busy,
            onPressed: header != null ? _nextHeader : null,
          ),
          _skipLink(p),
        ],
      ),
    );
  }

  Widget _bioStep(AppPalette p) {
    final left = 160 - _bio.text.runes.length;
    final canNext = _bio.text.trim().isNotEmpty;
    return OnboardingScaffold(
      onBack: _back,
      center: _logo(),
      title: 'Describe yourself',
      subtitle: 'What makes you special? Don\'t think too hard, just have fun with it.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border, width: 1)),
                ),
                child: CupertinoTextField(
                  controller: _bio,
                  autofocus: true,
                  placeholder: 'Your bio',
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 160,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  onChanged: (_) => setState(() {}),
                  cursorColor: p.accent,
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                  style: TextStyle(color: p.text, fontSize: 19, height: 1.3),
                  placeholderStyle: TextStyle(color: p.subtext, fontSize: 19),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$left',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: p.subtext, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text('Skip for now', style: TextStyle(color: p.text, fontSize: 17)),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 92,
            child: _SmallPill(
              label: 'Next',
              busy: _busy,
              onPressed: canNext ? _finish : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: switch (_step) {
        0 => _pictureStep(p),
        1 => _headerStep(p),
        _ => _bioStep(p),
      },
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onPressed != null && !busy;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onPressed == null ? const Color(0xFFD2D2D2) : p.text,
          borderRadius: BorderRadius.circular(22),
        ),
        child: busy
            ? CupertinoActivityIndicator(color: p.background)
            : Text(
                label,
                style: TextStyle(
                  color: onPressed == null ? const Color(0xFF7A7570) : p.background,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
