import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_palette.dart';
import '../core/config.dart';
import '../core/countries.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/user_prefs.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_mark.dart';
import '../widgets/person_tile.dart';
import '../widgets/plain_scaffold.dart';
import '../widgets/search_pill.dart';
import '../widgets/settings_fields.dart';
import '../widgets/settings_kit.dart';
import '../widgets/settings_parts.dart';
import 'settings_screen.dart' show logOutWithConfirm;

Future<T?> _push<T>(BuildContext c, Widget page, {bool full = false}) =>
    Navigator.of(c).push<T>(appRoute<T>(page, fullscreen: full));

/// "+63 905 123 4567" for what a person typed. Keeps a leading "+" number as
/// it is, otherwise adds the dial code of [country] (and drops a leading 0).
String normalizePhone(String raw, Country country) {
  final text = raw.trim();
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (text.startsWith('+')) return '+$digits';
  final national = digits.startsWith('0') ? digits.substring(1) : digits;
  return '${country.dialCode} $national';
}

/// Valid when the whole number (with dial code) has 8-15 digits.
bool phoneLooksValid(String raw, Country country) {
  final n = normalizePhone(raw, country);
  final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 8 && digits.length <= 15;
}

String labelName(String? label) {
  switch (label) {
    case 'commentary':
      return 'Commentary';
    case 'fan':
      return 'Fan';
    case 'parody':
      return 'Parody';
    default:
      return 'None';
  }
}

// ===========================================================================
// Account
// ===========================================================================

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Profile? _me;
  String? _phone;

  @override
  void initState() {
    super.initState();
    SettingsHandle.load();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.getProfile(Api.uid);
      String? phone;
      try {
        phone = await Api.getPhone();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _me = me;
        _phone = phone;
      });
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await _push<Object?>(context, page);
    if (!mounted) return;
    await SettingsHandle.refresh();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return SettingsFrame(
      title: 'Account information',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          const SizedBox(height: 6),
          ValueRow(
            title: 'Username',
            value: me == null ? null : '@${me.username}',
            onTap: me == null
                ? null
                : () => _open(UpdateUsernameScreen(
                      current: me.username,
                      displayName: me.name,
                    )),
          ),
          ValueRow(
            title: 'Phone',
            value: _phone ?? 'Add',
            onTap: () => _open(PhoneScreen(
              existing: _phone,
              country: me?.country,
            )),
          ),
          ValueRow(
            title: 'Email',
            value: Api.email,
            onTap: () => _open(const EmailChangeScreen()),
          ),
          ValueRow(
            title: 'Country',
            value: me?.country ?? 'Select',
            onTap: () => _open(CountryScreen(selected: me?.country)),
          ),
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinkText(
                'Select the country you live in. ',
                link: 'Learn more',
              ),
            ),
          ),
          ValueRow(
            title: 'Automation',
            description: 'Manage your automated account.',
            onTap: () async {
              await openAutomation(context);
              if (mounted) _load();
            },
          ),
          ValueRow(
            title: 'Parody, commentary and fan account',
            description: 'Manage your parody, commentary and fan account.',
            onTap: () async {
              await openPcf(context);
              if (mounted) _load();
            },
          ),
          CenterAction(
            text: 'Log out',
            onTap: () => logOutWithConfirm(context),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Update username
// ===========================================================================

class UpdateUsernameScreen extends StatefulWidget {
  const UpdateUsernameScreen({
    super.key,
    required this.current,
    required this.displayName,
  });

  final String current;
  final String displayName;

  @override
  State<UpdateUsernameScreen> createState() => _UpdateUsernameScreenState();
}

class _UpdateUsernameScreenState extends State<UpdateUsernameScreen> {
  final _c = TextEditingController();
  Timer? _debounce;
  bool? _available;
  bool _busy = false;
  String? _error;
  List<String> _suggestions = const [];

  String get _value => _c.text.trim();

  bool get _same => _value.toLowerCase() == widget.current.toLowerCase();

  bool get _canDone =>
      Validators.username(_value) == null &&
      !_same &&
      _available == true &&
      !_busy;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  Future<void> _loadSuggestions() async {
    final rnd = Random();
    final bases = <String>{
      _cut(widget.current.replaceAll(RegExp(r'[^A-Za-z0-9_]'), ''), 12),
      _cut(
        widget.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
        12,
      ),
    }..removeWhere((b) => b.length < 3);
    final candidates = <String>{};
    for (final b in bases) {
      for (var i = 0; i < 4; i++) {
        candidates.add('$b${rnd.nextInt(900) + 100}');
      }
    }
    final list = candidates.toList();
    final free = await Future.wait(list.map((u) async {
      try {
        return await Api.usernameAvailable(u);
      } catch (_) {
        return false;
      }
    }));
    final out = <String>[];
    for (var i = 0; i < list.length && out.length < 3; i++) {
      if (free[i]) out.add(list[i]);
    }
    if (mounted) setState(() => _suggestions = out);
  }

  void _changed(String _) {
    _debounce?.cancel();
    final problem = _value.isEmpty ? null : Validators.username(_value);
    setState(() {
      _available = null;
      _error = problem;
    });
    if (problem != null || _value.isEmpty || _same) return;
    final asked = _value;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await Api.usernameAvailable(asked);
        if (!mounted || asked != _value) return;
        setState(() {
          _available = free;
          _error = free ? null : 'That username has been taken. Please choose another.';
        });
      } catch (e) {
        if (!mounted || asked != _value) return;
        setState(() => _error = friendlyError(e));
      }
    });
  }

  void _useSuggestion(String s) {
    _c.text = s;
    _c.selection = TextSelection.collapsed(offset: s.length);
    _changed(s);
  }

  Future<void> _save() async {
    if (!_canDone) return;
    setState(() => _busy = true);
    try {
      await Api.changeUsername(_value);
      await SettingsHandle.refresh();
      if (!mounted) return;
      showSuccess(context, 'Username updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Update username',
      action: HeaderAction(
        label: 'Done',
        enabled: _canDone,
        busy: _busy,
        onPressed: _save,
      ),
      child: FormBody(
        children: [
          const SizedBox(height: 18),
          Text(
            'Current',
            style: TextStyle(
              color: p.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.current,
            style: TextStyle(color: p.text, fontSize: 18),
          ),
          const SizedBox(height: 22),
          UnderlineField(
            label: 'New',
            controller: _c,
            placeholder: 'Username',
            autofocus: true,
            maxLength: 15,
            errorText: _error,
            onChanged: _changed,
            onSubmitted: (_) => _save(),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(
                  'Suggestions:',
                  style: TextStyle(color: p.subtext, fontSize: 15),
                ),
                for (var i = 0; i < _suggestions.length; i++)
                  GestureDetector(
                    onTap: () => _useSuggestion(_suggestions[i]),
                    child: Text(
                      i == _suggestions.length - 1
                          ? _suggestions[i]
                          : '${_suggestions[i]},',
                      style: TextStyle(color: p.accent, fontSize: 15),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Phone
// ===========================================================================

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, this.existing, this.country});

  final String? existing;
  final String? country;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _c = TextEditingController();
  late Country _country;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _country = Countries.byName(widget.country) ?? Countries.philippines;
    final existing = widget.existing;
    if (existing != null) {
      final split = Countries.splitPhone(existing);
      if (split != null) _country = split.$1;
      _c.text = existing;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _valid => phoneLooksValid(_c.text, _country);

  Future<void> _pickCountry() async {
    final picked = await _push<Country>(
      context,
      const CountryScreen(saveToProfile: false, showDial: true),
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      await Api.savePhone(normalizePhone(_c.text, _country));
      if (!mounted) return;
      showSuccess(context, 'Phone number saved.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: 'Remove phone number?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.savePhone(null);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: '',
      showHandle: false,
      child: FormBody(
        children: [
          const SizedBox(height: 12),
          const BigHeading('Add your phone number'),
          const SizedBox(height: 28),
          UnderlineField(
            controller: _c,
            placeholder: '${_country.dialCode} 905 123 4567',
            keyboardType: TextInputType.phone,
            autofocus: widget.existing == null,
            maxLength: 20,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            prefix: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickCountry,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 4),
                    Icon(CupertinoIcons.chevron_down, size: 14, color: p.subtext),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: PillAction(
              label: widget.existing == null ? 'Continue' : 'Save',
              kind: _valid ? PillKind.black : PillKind.grey,
              busy: _busy,
              onPressed: _valid ? _save : null,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'By continuing, you agree to receive transactional messaging '
            'about your account.',
            style: TextStyle(color: p.subtext, fontSize: 14, height: 1.3),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            CenterAction(text: 'Remove phone number', onTap: _remove),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Country
// ===========================================================================

class CountryScreen extends StatefulWidget {
  const CountryScreen({
    super.key,
    this.selected,
    this.saveToProfile = true,
    this.showDial = false,
  });

  final String? selected;

  /// true: the choice is stored as my country; false: just returned.
  final bool saveToProfile;
  final bool showDial;

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  Future<void> _pick(Country c) async {
    setState(() => _selected = c.name);
    if (widget.saveToProfile) {
      try {
        await Api.setCountry(c.name);
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final list = Countries.all;
    return SettingsFrame(
      title: 'Country',
      showHandle: widget.saveToProfile,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 48),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          return CheckRow(
            title: widget.showDial ? '${c.flag}  ${c.name}  ${c.dialCode}' : c.name,
            selected: c.name == _selected,
            onTap: () => _pick(c),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Email
// ===========================================================================

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  String get _value => _c.text.trim();

  bool get _canDone =>
      Validators.email(_value) == null &&
      _value.toLowerCase() != Api.email.toLowerCase();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canDone || _busy) return;
    final email = _value;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await Api.emailRegistered(email)) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'That email is already used by another account.';
        });
        return;
      }
      await Api.requestEmailChange(email);
      if (!mounted) return;
      setState(() => _busy = false);
      final ok = await _push<bool>(
        context,
        VerifyCodeScreen(
          email: email,
          onConfirm: (code) => Api.confirmEmailChange(email: email, code: code),
          onResend: () => Api.requestEmailChange(email),
        ),
        full: true,
      );
      if (ok == true && mounted) {
        showSuccess(context, 'Email updated.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Update email',
      action: HeaderAction(
        label: 'Done',
        enabled: _canDone,
        busy: _busy,
        onPressed: _save,
      ),
      child: FormBody(
        children: [
          const SizedBox(height: 18),
          Text(
            'Current',
            style: TextStyle(
              color: p.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(Api.email, style: TextStyle(color: p.text, fontSize: 18)),
          const SizedBox(height: 22),
          UnderlineField(
            label: 'New',
            controller: _c,
            placeholder: 'Email address',
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          Text(
            'We will email a 6-digit code to the new address to confirm it.',
            style: TextStyle(color: p.subtext, fontSize: 14, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Verification code ("We sent you a code")
// ===========================================================================

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({
    super.key,
    required this.email,
    required this.onConfirm,
    required this.onResend,
    this.heading = 'We sent you a code',
  });

  final String email;
  final Future<void> Function(String code) onConfirm;
  final Future<void> Function() onResend;
  final String heading;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 60;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  bool get _ready => _code.text.length == 6;

  Future<void> _confirm() async {
    if (!_ready || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_code.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      var msg = friendlyError(e);
      if (e is AuthException) {
        final m = e.message.toLowerCase();
        if (m.contains('expired') || m.contains('invalid')) {
          msg = 'That code is wrong or has expired.';
        }
      }
      setState(() {
        _busy = false;
        _error = msg;
      });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    if (_cooldown > 0) {
      showInfo(context, 'You can ask for another code in $_cooldown seconds.');
      return;
    }
    try {
      await widget.onResend();
      if (!mounted) return;
      _code.clear();
      setState(_startCooldown);
      showSuccess(context, 'We sent you a new code.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PlainScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                const Center(child: BrandMark(size: 44)),
                const SizedBox(height: 28),
                BigHeading(widget.heading),
                const SizedBox(height: 10),
                Text(
                  'Enter the verification code sent to '
                  '${maskEmail(widget.email)}.',
                  style: TextStyle(color: p.subtext, fontSize: 16, height: 1.3),
                ),
                const SizedBox(height: 30),
                CodeBoxes(
                  controller: _code,
                  hasError: _error != null,
                  onChanged: (_) => setState(() => _error = null),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.danger, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 22),
                Center(
                  child: GestureDetector(
                    onTap: _resend,
                    child: Text(
                      "Didn't receive code?",
                      style: TextStyle(color: p.accent, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                PillAction(
                  label: 'Confirm',
                  fullWidth: true,
                  kind: _ready ? PillKind.blue : PillKind.grey,
                  busy: _busy,
                  onPressed: _ready ? _confirm : null,
                ),
                const SizedBox(height: 22),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(false),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: p.text,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          decorationColor: p.text,
                        ),
                      ),
                    ),
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

// ===========================================================================
// Passwords
// ===========================================================================

/// "Forgot password?" for a signed-in account: emails a code, checks it and
/// lets the person choose a new password. Resolves to true when it worked.
Future<bool> startForgotPassword(BuildContext context) async {
  final email = Api.email;
  if (email.isEmpty) return false;
  try {
    await Api.sendPasswordResetCode(email);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
  if (!context.mounted) return false;
  final verified = await _push<bool>(
    context,
    VerifyCodeScreen(
      email: email,
      onConfirm: (code) => Api.verifyRecoveryCode(email: email, code: code),
      onResend: () => Api.sendPasswordResetCode(email),
    ),
    full: true,
  );
  if (verified != true || !context.mounted) return false;
  final done = await _push<bool>(context, const SetNewPasswordScreen());
  return done == true;
}

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready => _next.text.isNotEmpty && _confirm.text.isNotEmpty;

  Future<void> _save() async {
    if (!_ready || _busy) return;
    final problem = Validators.password(_next.text) ??
        (_next.text != _confirm.text ? 'The passwords do not match.' : null);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.setNewPassword(_next.text);
      if (!mounted) return;
      showSuccess(context, 'Password updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'New password',
      action: HeaderAction(
        label: 'Done',
        enabled: _ready,
        busy: _busy,
        onPressed: _save,
      ),
      child: FormBody(
        children: [
          const SizedBox(height: 18),
          UnderlineField(
            label: 'New password',
            controller: _next,
            placeholder: 'At least 6 characters',
            obscure: true,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 22),
          UnderlineField(
            label: 'Confirm password',
            controller: _confirm,
            obscure: true,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      _current.text.isNotEmpty &&
      _next.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  Future<void> _save() async {
    if (!_ready || _busy) return;
    FocusScope.of(context).unfocus();
    final problem = Validators.newPassword(
      current: _current.text,
      next: _next.text,
      confirm: _confirm.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      showSuccess(context, 'Password updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() {
        _busy = false;
        _error = msg == 'Wrong email or password.'
            ? 'Your current password is incorrect.'
            : msg;
      });
    }
  }

  Future<void> _forgot() async {
    final done = await startForgotPassword(context);
    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Update password',
      action: HeaderAction(
        label: 'Done',
        enabled: _ready,
        busy: _busy,
        onPressed: _save,
      ),
      child: FormBody(
        children: [
          const SizedBox(height: 18),
          UnderlineField(
            label: 'Current password',
            controller: _current,
            obscure: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _forgot,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Forgot password?',
                style: TextStyle(color: p.accent, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),
          UnderlineField(
            label: 'New password',
            controller: _next,
            placeholder: 'At least 6 characters',
            obscure: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 22),
          UnderlineField(
            label: 'Confirm password',
            controller: _confirm,
            obscure: true,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

/// "Confirm your password": asks again before sensitive actions. Resolves to
/// true when the password was right.
Future<bool> confirmPasswordGate(BuildContext context) async {
  final ok = await _push<bool>(context, const ConfirmPasswordScreen(), full: true);
  return ok == true;
}

class ConfirmPasswordScreen extends StatefulWidget {
  const ConfirmPasswordScreen({super.key});

  @override
  State<ConfirmPasswordScreen> createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_c.text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.verifyPassword(_c.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() {
        _busy = false;
        _error = msg == 'Wrong email or password.'
            ? 'Your password is incorrect.'
            : msg;
      });
    }
  }

  Future<void> _forgot() async {
    final done = await startForgotPassword(context);
    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: '',
      showHandle: false,
      closeIcon: true,
      child: FormBody(
        bottom: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: PillAction(
            label: 'Confirm',
            fullWidth: true,
            kind: _c.text.isEmpty ? PillKind.grey : PillKind.blue,
            busy: _busy,
            onPressed: _c.text.isEmpty ? null : _confirm,
          ),
        ),
        children: [
          const SizedBox(height: 12),
          const BigHeading('Confirm your password'),
          const SizedBox(height: 10),
          Text(
            'Please enter your password to continue.',
            style: TextStyle(color: p.subtext, fontSize: 16),
          ),
          const SizedBox(height: 24),
          UnderlineField(
            label: 'Password',
            controller: _c,
            obscure: true,
            autofocus: true,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _forgot,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Forgot password?',
                style: TextStyle(color: p.accent, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Label info pages (Automation / Parody, commentary and fan)
// ===========================================================================

class LabelInfoScreen extends StatelessWidget {
  const LabelInfoScreen({super.key, required this.automation, this.next});

  /// true: "Automated account labels" (teal); false: PCF (blue).
  final bool automation;

  /// Page to open in place of this one after "Got it".
  final Widget Function()? next;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = automation ? const Color(0xFF00A98F) : p.accent;
    final title = automation
        ? 'Automated Account Labels'
        : 'Parody, Commentary and Fan Labels';

    Widget h(String t) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 8),
          child: Text(
            t,
            style: TextStyle(
              color: p.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

    Widget para(String t) => Text(
          t,
          style: TextStyle(color: p.text, fontSize: 16, height: 1.35),
        );

    Widget step(int n, String t) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: para(t)),
            ],
          ),
        );

    Widget mock() {
      final badge = automation ? 'Automated' : 'Parody account';
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Avatar(url: null, name: 'Sample', size: 44),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        automation ? 'Weather Updates' : 'Daily Fan Page',
                        style: TextStyle(
                          color: p.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        automation ? '@weather_updates' : '@daily_fan_page',
                        style: TextStyle(color: p.subtext, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              automation
                  ? 'Sunny skies today. High of 31°C, light breeze.'
                  : 'Big news tonight, you will not believe what happened!',
              style: TextStyle(color: p.text, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return PlainScaffold(
      child: Column(
        children: [
          Container(
            color: color,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 22,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SettingsColumn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: automation
                        ? [
                            h("What's an automated account?"),
                            para('Automated accounts post on their own, for '
                                'example weather alerts or news feeds. A label '
                                'on the profile and on every post tells people '
                                'the account is run by a program, and shows '
                                'which account manages it.'),
                            mock(),
                            h('Do I need to label my account?'),
                            para('If your account posts automatically, yes. '
                                'Labelling it keeps people informed and keeps '
                                'your account in good standing.'),
                            h('How do I label my account?'),
                            step(1, 'Open Settings and privacy, then Your '
                                'account, then Automation.'),
                            step(2, 'Tap "Set a managing account" and choose the '
                                'account that runs it.'),
                            step(3, 'Your profile and posts now show the '
                                'Automated label.'),
                          ]
                        : [
                            h("What's a PCF account?"),
                            para('PCF stands for parody, commentary and fan. '
                                'These accounts are not the official account of '
                                'the person or brand they talk about. A label '
                                'on the profile and on every post makes that '
                                'clear.'),
                            mock(),
                            h('Do I need to label my account?'),
                            para('If your account imitates, comments on or '
                                'celebrates someone else, yes. Labelling it '
                                'keeps people from being misled.'),
                            h('How do I label my account?'),
                            step(1, 'Open Settings and privacy, then Your '
                                'account, then Parody, commentary and fan '
                                'account.'),
                            step(2, 'Tap Profile Label and choose Commentary, '
                                'Fan or Parody.'),
                            step(3, 'Confirm. A label can only be changed once '
                                'every 48 hours.'),
                          ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          Container(
            color: p.background,
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            child: ContentBottom(
              child: PillAction(
                label: 'Got it',
                fullWidth: true,
                kind: automation ? PillKind.teal : PillKind.blue,
                onPressed: () {
                  final n = next;
                  if (n != null) {
                    Navigator.of(context)
                        .pushReplacement(appRoute<Object?>(n()));
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a bottom button at a sensible width on tablets.
class ContentBottom extends StatelessWidget {
  const ContentBottom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: child,
        ),
      );
}

// ===========================================================================
// Automation
// ===========================================================================

/// Opens the info page the first time, then the real page.
Future<void> openAutomation(BuildContext context) async {
  final prefs = UserPrefs.instance;
  if (!prefs.flag('seen_automation_info')) {
    await prefs.set('seen_automation_info', true);
    if (!context.mounted) return;
    await _push<Object?>(
      context,
      LabelInfoScreen(
        automation: true,
        next: () => const AutomationScreen(),
      ),
      full: true,
    );
  } else {
    await _push<Object?>(context, const AutomationScreen());
  }
}

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  Profile? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.getProfile(Api.uid);
      if (mounted) setState(() => _me = me);
    } catch (_) {}
  }

  Future<void> _choose() async {
    final picked = await _push<Profile>(context, const ManagingAccountPicker());
    if (picked == null || !mounted) return;
    final ok = await confirm(
      context,
      title: 'Set @${picked.username} as managing account?',
      message: 'Your account will be labelled as automated and managed by '
          '@${picked.username}.',
      confirmLabel: 'Set',
    );
    if (!ok || !mounted) return;
    try {
      await Api.setManagingAccount(picked.id);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: 'Remove the managing account?',
      message: 'Your account will no longer be labelled as automated.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Api.setManagingAccount(null);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final managed = _me?.managedByUsername;
    return SettingsFrame(
      title: 'Automation',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
              child: Text(
                'Manage your automated account.',
                style: TextStyle(color: p.subtext, fontSize: 16),
              ),
            ),
          ),
          const SettingsDivider(),
          ValueRow(
            title: 'Set a managing account',
            value: managed == null ? null : '@$managed',
            onTap: _choose,
          ),
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinkText(
                'An automated account is run by a program. Choose the '
                'account of the person who manages it and your profile will '
                'show an "Automated" label. ',
                link: 'Learn more',
                onLink: () => _push<Object?>(
                  context,
                  const LabelInfoScreen(automation: true),
                  full: true,
                ),
              ),
            ),
          ),
          if (managed != null)
            CenterAction(text: 'Remove managing account', onTap: _remove),
        ],
      ),
    );
  }
}

class ManagingAccountPicker extends StatefulWidget {
  const ManagingAccountPicker({super.key});

  @override
  State<ManagingAccountPicker> createState() => _ManagingAccountPickerState();
}

class _ManagingAccountPickerState extends State<ManagingAccountPicker> {
  final _c = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final r = await Api.findAccounts(q);
        if (!mounted || q != _c.text) return;
        setState(() {
          _results = r;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SettingsFrame(
      title: 'Managing account',
      showHandle: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SearchPill(
              controller: _c,
              placeholder: 'Search for an account',
              onChanged: _changed,
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CupertinoActivityIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _c.text.trim().isEmpty
                              ? 'Search for the account that manages yours.'
                              : 'No accounts found.',
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final r in _results)
                            PersonTile(
                              profile: r,
                              onTap: () => Navigator.of(context).pop(r),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Parody, commentary and fan account
// ===========================================================================

Future<void> openPcf(BuildContext context) async {
  final prefs = UserPrefs.instance;
  if (!prefs.flag('seen_pcf_info')) {
    await prefs.set('seen_pcf_info', true);
    if (!context.mounted) return;
    await _push<Object?>(
      context,
      LabelInfoScreen(automation: false, next: () => const PcfScreen()),
      full: true,
    );
  } else {
    await _push<Object?>(context, const PcfScreen());
  }
}

class PcfScreen extends StatefulWidget {
  const PcfScreen({super.key});

  @override
  State<PcfScreen> createState() => _PcfScreenState();
}

class _PcfScreenState extends State<PcfScreen> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.getProfile(Api.uid);
      if (mounted) setState(() => _label = me.profileLabel);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Add profile label',
      child: ListView(
        children: [
          const SizedBox(height: 6),
          ValueRow(
            title: 'Profile Label',
            value: labelName(_label),
            onTap: () async {
              await _push<Object?>(
                context,
                ChooseLabelScreen(current: _label),
              );
              await _load();
            },
          ),
          SettingsColumn(
            child: LinkText(
              'Displays this label on your profile. ',
              link: 'Learn more',
              onLink: () => _push<Object?>(
                context,
                const LabelInfoScreen(automation: false),
                full: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChooseLabelScreen extends StatefulWidget {
  const ChooseLabelScreen({super.key, this.current});

  final String? current;

  @override
  State<ChooseLabelScreen> createState() => _ChooseLabelScreenState();
}

class _ChooseLabelScreenState extends State<ChooseLabelScreen> {
  late String? _selected = widget.current;
  bool _busy = false;

  Future<void> _pick(String? value) async {
    if (_busy) return;
    if (value == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await confirm(
      context,
      title: 'Are you sure?',
      message: 'Once updated, further updates will be locked for 48 hours.',
      confirmLabel: 'Yes',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.setProfileLabel(value);
      if (!mounted) return;
      setState(() => _selected = value);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFrame(
      title: 'Choose Profile Label',
      child: ListView(
        children: [
          const SizedBox(height: 6),
          CheckRow(
            title: 'Commentary',
            selected: _selected == 'commentary',
            onTap: () => _pick('commentary'),
          ),
          CheckRow(
            title: 'Fan',
            selected: _selected == 'fan',
            onTap: () => _pick('fan'),
          ),
          CheckRow(
            title: 'Parody',
            selected: _selected == 'parody',
            onTap: () => _pick('parody'),
          ),
          CheckRow(
            title: 'None',
            selected: _selected == null,
            onTap: () => _pick(null),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Deactivate
// ===========================================================================

class DeactivateScreen extends StatefulWidget {
  const DeactivateScreen({super.key});

  @override
  State<DeactivateScreen> createState() => _DeactivateScreenState();
}

class _DeactivateScreenState extends State<DeactivateScreen> {
  Profile? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.getProfile(Api.uid).then((m) {
      if (mounted) setState(() => _me = m);
    }).catchError((Object _) {});
  }

  Future<void> _deactivate() async {
    if (_busy) return;
    if (!await confirmPasswordGate(context) || !mounted) return;
    final ok = await confirm(
      context,
      title: 'Deactivate your account?',
      message: 'Your profile and posts will be hidden. Sign in again to '
          'restore your account.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await Api.deactivateAccount();
      navigator.popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final me = _me;
    final app = AppConfig.appName;

    Widget h(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 6),
          child: Text(
            t,
            style: TextStyle(
              color: p.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

    return SettingsFrame(
      title: 'Deactivate account',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          SettingsColumn(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Avatar(url: me?.avatarUrl, name: me?.name ?? '', size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          me == null ? '' : '@${me.username}',
                          style: TextStyle(color: p.subtext, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                h('This will deactivate your account'),
                LinkText(
                  "You're about to start the process of deactivating your "
                  '$app account. Your display name, @username, and public '
                  'profile will no longer be viewable on $app. ',
                  color: p.subtext,
                ),
                h('What else you should know'),
                LinkText(
                  'You can restore your account by signing in again. '
                  'Until then your posts and profile stay hidden. ',
                  link: 'Learn more',
                ),
                const SizedBox(height: 14),
                LinkText(
                  'If you just want to change your @username, you do not '
                  'need to deactivate your account. Edit it in your ',
                  link: 'settings',
                  onLink: () => Navigator.of(context).maybePop(),
                  after: '.',
                ),
              ],
            ),
          ),
          CenterAction(
            text: 'Deactivate',
            topPadding: 34,
            onTap: _deactivate,
          ),
        ],
      ),
    );
  }
}
