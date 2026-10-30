import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/topics.dart';
import '../core/ui_helpers.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/image_picker_service.dart';
import '../widgets/suggested_list.dart';
import 'onboarding_kit.dart';
import '../core/x_icons.dart';

/// The steps that follow the email code, in the order X shows them.
enum _Step {
  birthday,
  name,
  username,
  password,
  contacts,
  photo,
  interests,
  suggested,
  search,
}

/// Runs [task] with a busy indicator and shows any error.
Future<void> _run(
  BuildContext context,
  void Function(bool busy) setBusy,
  Future<void> Function() task,
) async {
  setBusy(true);
  try {
    await task();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
  if (context.mounted) setBusy(false);
}

/// Finishes account creation after the email address is verified:
/// birthday → name → username → password → find friends → profile picture →
/// interests → who to follow → search. Every step is saved as it is
/// completed; [onFinished] is called after the last one (with the text typed
/// on the search step, if any).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.profile,
    required this.onFinished,
  });

  final Profile profile;
  final void Function(String? searchQuery) onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  _Step _step = _Step.birthday;
  DateTime? _birthday;
  String _name = '';
  late Set<String> _interests;

  @override
  void initState() {
    super.initState();
    _interests = {...widget.profile.interests};
  }

  void _go(_Step step) => setState(() => _step = step);

  void _next() {
    if (_step.index < _Step.values.length - 1) {
      _go(_Step.values[_step.index + 1]);
    }
  }

  void _back() {
    if (_step == _Step.birthday) {
      _leave();
    } else if (_step.index > 0) {
      _go(_Step.values[_step.index - 1]);
    }
  }

  Future<void> _leave() async {
    final ok = await confirm(
      context,
      title: 'Leave sign-up?',
      message: 'You will be logged out. Create an account again with the same '
          'email to pick up where you left off.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (ok && mounted) await Api.signOut();
  }

  Future<void> _finish(String? query) async {
    await Api.updateMyProfile({'onboarded': true});
    widget.onFinished(query);
  }

  Widget _stepWidget() {
    switch (_step) {
      case _Step.birthday:
        return _BirthdayStep(
          initial: _birthday,
          onBack: _back,
          onSubmit: (d) async {
            await Api.saveBirthday(d);
            _birthday = d;
            _next();
          },
        );
      case _Step.name:
        return _NameStep(
          initial: _name,
          onBack: _back,
          onSubmit: (n) async {
            await Api.updateMyProfile({'display_name': n.trim()});
            _name = n.trim();
            _next();
          },
        );
      case _Step.username:
        return _UsernameStep(
          name: _name,
          current: widget.profile.username,
          onBack: _back,
          onSubmit: (u) async {
            await Api.updateMyProfile({'username': u});
            _next();
          },
        );
      case _Step.password:
        return _PasswordStep(
          onBack: _back,
          onSubmit: (pw) async {
            await Api.setNewPassword(pw);
            _next();
          },
        );
      case _Step.contacts:
        return _ContactsStep(onNext: _next);
      case _Step.photo:
        return _PhotoStep(
          onBack: _back,
          onSubmit: (img) async {
            if (img != null) {
              final url = await Api.uploadImage(
                bucket: AppConfig.avatarsBucket,
                image: img,
              );
              await Api.updateMyProfile({'avatar_url': url});
            }
            _next();
          },
        );
      case _Step.interests:
        return _InterestsStep(
          initial: _interests,
          onSubmit: (ids) async {
            await Api.updateMyProfile({'interests': ids.toList()});
            _interests = ids;
            _next();
          },
        );
      case _Step.suggested:
        return _SuggestedStep(onBack: _back, onNext: _next);
      case _Step.search:
        return _SearchStep(onSubmit: _finish);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _stepWidget(),
        ),
      ),
    );
  }
}

// ===========================================================================
// 1. Birthday
// ===========================================================================

class _BirthdayStep extends StatefulWidget {
  const _BirthdayStep({
    required this.initial,
    required this.onBack,
    required this.onSubmit,
  });

  final DateTime? initial;
  final VoidCallback onBack;
  final Future<void> Function(DateTime date) onSubmit;

  @override
  State<_BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<_BirthdayStep> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final DateTime _max = DateTime.now();
  DateTime? _picked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  int _age(DateTime d) {
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      age--;
    }
    return age;
  }

  bool get _tooYoung => _picked != null && _age(_picked!) < 13;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = _picked;
    final dark = p.background.computeLuminance() < 0.5;

    return OnboardingScaffold(
      title: "When's your birthday?",
      subtitle: "Your birthday won't be shown publicly",
      onBack: widget.onBack,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: d == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_months[d.month - 1]} ${d.day}, ${d.year}',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 32,
                        height: 1.2,
                      ),
                    ),
                    if (_tooYoung)
                      FieldError(
                        'You must be at least 13 years old to use '
                        '${AppConfig.appName}.',
                      ),
                  ],
                ),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                dateOrder: DatePickerDateOrder.mdy,
                initialDateTime: widget.initial ?? _max,
                maximumDate: _max,
                minimumYear: 1900,
                onDateTimeChanged: (v) =>
                    setState(() => _picked = DateTime(v.year, v.month, v.day)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          BlackButton(
            label: 'Continue',
            busy: _busy,
            onPressed: (d == null || _tooYoung)
                ? null
                : () => _run(
                      context,
                      (b) => setState(() => _busy = b),
                      () => widget.onSubmit(d),
                    ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 2. Name
// ===========================================================================

class _NameStep extends StatefulWidget {
  const _NameStep({
    required this.initial,
    required this.onBack,
    required this.onSubmit,
  });

  final String initial;
  final VoidCallback onBack;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _valid => _c.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid || _busy) return;
    _run(context, (b) => setState(() => _busy = b),
        () => widget.onSubmit(_c.text));
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: "What's your name?",
      onBack: widget.onBack,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: BigTextField(
            controller: _c,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ),
      bottom: BlackButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _valid ? _submit : null,
      ),
    );
  }
}

// ===========================================================================
// 3. Username
// ===========================================================================

enum _Avail { checking, ok, taken, tooShort }

class _UsernameStep extends StatefulWidget {
  const _UsernameStep({
    required this.name,
    required this.current,
    required this.onBack,
    required this.onSubmit,
  });

  /// Name typed on the previous step (suggestions are built from it).
  final String name;

  /// Username the account has right now (made from the email at sign-up).
  final String current;
  final VoidCallback onBack;
  final Future<void> Function(String username) onSubmit;

  @override
  State<_UsernameStep> createState() => _UsernameStepState();
}

class _UsernameStepState extends State<_UsernameStep> {
  static const _minLength = 4;
  static const _maxLength = 15;
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  late final TextEditingController _c;
  late final List<String> _suggestions;
  Timer? _debounce;
  _Avail _avail = _Avail.checking;
  bool _typed = false;
  bool _busy = false;

  static String _clean(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

  @override
  void initState() {
    super.initState();
    final base = _clean(widget.name);
    var start = base.length >= _minLength ? base : widget.current;
    if (start.length > _maxLength) start = start.substring(0, _maxLength);
    _c = TextEditingController(text: start);
    _suggestions = _makeSuggestions(base.isEmpty ? widget.current : base);
    _evaluate(start);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  List<String> _makeSuggestions(String base) {
    final rnd = math.Random();
    final stem = base.length > 11 ? base.substring(0, 11) : base;
    final out = <String>{};
    while (out.length < 3) {
      final extra = 2 + rnd.nextInt(3); // 2-4 random characters
      final suffix = String.fromCharCodes(
        List.generate(
          extra,
          (_) => _alphabet.codeUnitAt(rnd.nextInt(_alphabet.length)),
        ),
      );
      out.add('${stem.isEmpty ? 'user' : stem}$suffix');
    }
    return out.toList();
  }

  void _evaluate(String v) {
    _debounce?.cancel();
    if (v.length < _minLength) {
      _avail = _Avail.tooShort;
      return;
    }
    if (v.toLowerCase() == widget.current.toLowerCase()) {
      _avail = _Avail.ok;
      return;
    }
    _avail = _Avail.checking;
    _debounce = Timer(const Duration(milliseconds: 350), () => _check(v));
  }

  Future<void> _check(String v) async {
    var free = true;
    try {
      free = await Api.usernameAvailable(v);
    } catch (_) {
      // Offline check failed: the server still rejects duplicates on save.
    }
    if (!mounted || v != _c.text) return;
    setState(() => _avail = free ? _Avail.ok : _Avail.taken);
  }

  void _onChanged(String v) {
    _typed = true;
    setState(() => _evaluate(v));
  }

  void _pick(String s) {
    _c.text = s;
    _c.selection = TextSelection.collapsed(offset: s.length);
    _onChanged(s);
  }

  void _submit() {
    if (_avail != _Avail.ok || _busy) return;
    _run(context, (b) => setState(() => _busy = b),
        () => widget.onSubmit(_c.text));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    String? error;
    if (_avail == _Avail.taken) {
      error = 'That username has been taken. Please choose another.';
    } else if (_avail == _Avail.tooShort && _typed) {
      error = 'Your username must be at least $_minLength characters.';
    }

    return OnboardingScaffold(
      title: 'Give yourself a username',
      onBack: widget.onBack,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BigTextField(
              controller: _c,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                LengthLimitingTextInputFormatter(_maxLength),
              ],
              prefix: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '@',
                  style: TextStyle(color: p.text, fontSize: 32, height: 1.25),
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
            ),
            if (error != null) FieldError(error),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in _suggestions)
                  OutlineChip(label: s, compact: true, onTap: () => _pick(s)),
              ],
            ),
          ],
        ),
      ),
      bottom: BlackButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _avail == _Avail.ok ? _submit : null,
      ),
    );
  }
}

// ===========================================================================
// 4. Password
// ===========================================================================

class _PasswordStep extends StatefulWidget {
  const _PasswordStep({required this.onBack, required this.onSubmit});

  final VoidCallback onBack;
  final Future<void> Function(String password) onSubmit;

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep> {
  final _c = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _valid => _c.text.length >= 8;

  void _submit() {
    if (!_valid || _busy) return;
    _run(context, (b) => setState(() => _busy = b),
        () => widget.onSubmit(_c.text));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return OnboardingScaffold(
      title: 'Choose a password',
      subtitle: 'Passwords should be hard to guess and at least 8 characters long.',
      onBack: widget.onBack,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: BigTextField(
            controller: _c,
            placeholder: 'Password',
            obscureText: _hide,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            suffix: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _hide = !_hide),
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(
                  _hide ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 26,
                  color: p.subtext,
                ),
              ),
            ),
          ),
        ),
      ),
      bottom: BlackButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _valid ? _submit : null,
      ),
    );
  }
}

// ===========================================================================
// 5. Find your friends (contacts)
// ===========================================================================

class _ContactsStep extends StatelessWidget {
  const _ContactsStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // NOTE: reading the phone's address book needs a contacts plugin and a
    // permission prompt, which are outside the Flutter + adaptive_platform_ui
    // + Supabase-only scope of this project. The screen is shown (as on X)
    // and both buttons simply continue.
    return OnboardingScaffold(
      showTopBar: false,
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Expanded(child: _ContactsArt()),
          const SizedBox(height: 26),
          Text(
            'Find your friends',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.text,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
            child: Text(
              '${AppConfig.appName} needs access to your contacts to find '
              'your friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.subtext,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 34),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.lock_fill, size: 15, color: p.subtext),
              const SizedBox(width: 6),
              Text(
                'Your contacts are always kept safe and secure',
                style: TextStyle(
                  color: p.subtext,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlackButton(label: 'Skip for now', soft: true, onPressed: onNext),
          const SizedBox(height: 12),
          BlackButton(label: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

/// Grey "contact list" skeleton that fades out towards the bottom.
class _ContactsArt extends StatelessWidget {
  const _ContactsArt();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bar = p.subtext.withValues(alpha: 0.22);

    Widget row(double w1, double w2) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: bar, shape: BoxShape.circle),
              ),
              const SizedBox(width: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: w1,
                    height: 13,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: w2,
                    height: 13,
                    decoration: BoxDecoration(
                      color: bar,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, 0.5, 1],
        ).createShader(rect),
        child: Container(
          decoration: BoxDecoration(
            color: p.field,
            borderRadius: BorderRadius.circular(44),
          ),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                row(110, 190),
                row(80, 48),
                row(150, 100),
                row(80, 110),
                row(80, 110),
                row(120, 90),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 6. Profile picture
// ===========================================================================

class _PhotoStep extends StatefulWidget {
  const _PhotoStep({required this.onBack, required this.onSubmit});

  final VoidCallback onBack;
  final Future<void> Function(PickedImage? image) onSubmit;

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  PickedImage? _img;
  bool _busy = false;

  Future<void> _pick() async {
    try {
      final img = await pickGalleryImage();
      if (img != null && mounted) setState(() => _img = img);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _submit(PickedImage? img) {
    if (_busy) return;
    _run(context, (b) => setState(() => _busy = b),
        () => widget.onSubmit(img));
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    const size = 190.0;

    return OnboardingScaffold(
      title: 'Set a profile picture',
      subtitle: 'Have a favorite selfie? Upload it now.',
      onBack: widget.onBack,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: img != null
              ? ClipOval(
                  child: Image.memory(
                    img.bytes,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: size,
                  height: size,
                  alignment: Alignment.bottomCenter,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3E8EA),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 150,
                        color: const Color(0xFFFFFFFF).withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (img == null) ...[
            BlackButton(
              label: 'Skip',
              outlined: true,
              onPressed: _busy ? null : () => _submit(null),
            ),
            const SizedBox(height: 12),
            BlackButton(label: 'Add profile photo', onPressed: _pick),
          ] else ...[
            BlackButton(
              label: 'Choose a different photo',
              outlined: true,
              onPressed: _busy ? null : _pick,
            ),
            const SizedBox(height: 12),
            BlackButton(
              label: 'Continue',
              busy: _busy,
              onPressed: () => _submit(img),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// 7. Interests
// ===========================================================================

class _InterestsStep extends StatefulWidget {
  const _InterestsStep({required this.initial, required this.onSubmit});

  final Set<String> initial;
  final Future<void> Function(Set<String> ids) onSubmit;

  @override
  State<_InterestsStep> createState() => _InterestsStepState();
}

class _InterestsStepState extends State<_InterestsStep> {
  late final Set<String> _selected = {...widget.initial};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showTopBar: false,
      title: 'Pick your interests',
      subtitle: 'Select 3 topics to continue',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: InterestChips(
          selected: _selected,
          onToggle: (id) => setState(() {
            if (!_selected.remove(id)) _selected.add(id);
          }),
        ),
      ),
      bottom: BlackButton(
        label: 'Continue',
        busy: _busy,
        onPressed: _selected.length >= 3
            ? () => _run(
                  context,
                  (b) => setState(() => _busy = b),
                  () => widget.onSubmit({..._selected}),
                )
            : null,
      ),
    );
  }
}

/// All topics as selectable chips (also used by the "edit topics" page).
class InterestChips extends StatelessWidget {
  const InterestChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final t in Topics.all)
          OutlineChip(
            label: t.label,
            icon: t.icon,
            selected: selected.contains(t.id),
            onTap: () => onToggle(t.id),
          ),
      ],
    );
  }
}

// ===========================================================================
// 8. Suggested accounts
// ===========================================================================

class _SuggestedStep extends StatelessWidget {
  const _SuggestedStep({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Suggested for you',
      subtitle: 'Follow 3 or more accounts',
      onBack: onBack,
      child: const Padding(
        padding: EdgeInsets.only(top: 10),
        child: SuggestedList(bottomPadding: 12),
      ),
      bottom: BlackButton(label: 'Continue', onPressed: onNext),
    );
  }
}

// ===========================================================================
// 9. Try searching
// ===========================================================================

class _SearchStep extends StatefulWidget {
  const _SearchStep({required this.onSubmit});

  final Future<void> Function(String? query) onSubmit;

  @override
  State<_SearchStep> createState() => _SearchStepState();
}

class _SearchStepState extends State<_SearchStep> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit(String? q) {
    if (_busy) return;
    _run(context, (b) => setState(() => _busy = b), () => widget.onSubmit(q));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final has = _c.text.trim().isNotEmpty;

    return OnboardingScaffold(
      title: 'Try searching to get started',
      trailing: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : () => _submit(null),
        child: Text(
          'Skip',
          style: TextStyle(
            color: p.subtext,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: CupertinoTextField(
            controller: _c,
            placeholder: 'Search ${AppConfig.appName}',
            autocorrect: false,
            cursorColor: p.accent,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _submit(v.trim());
            },
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: XIcon(XIcons.search, size: 22, color: p.text),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: p.subtext.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            style: TextStyle(color: p.text, fontSize: 18),
            placeholderStyle: TextStyle(color: p.subtext, fontSize: 18),
          ),
        ),
      ),
      bottom: BlackButton(
        label: 'Search',
        busy: _busy,
        onPressed: has ? () => _submit(_c.text.trim()) : null,
      ),
    );
  }
}
