import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../services/api.dart';
import '../widgets/app_text_field.dart';
import 'onboarding_kit.dart';

/// Why the code was sent.
enum OtpPurpose {
  /// Verify the email address while creating an account.
  signUp,

  /// Forgot password: verify the code, then choose a new password.
  resetPassword,
}

/// Enter the 6-digit code that Supabase emailed (replaces confirmation links).
///
/// * [OtpPurpose.signUp]: a correct code verifies the address and signs the
///   user in; `AuthGate` then shows the remaining sign-up steps.
/// * [OtpPurpose.resetPassword]: a correct code signs the user in with a
///   recovery session, then this screen asks for the new password.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.email, required this.purpose});

  final String email;
  final OtpPurpose purpose;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;

  /// Supabase allows one email per user every 60 seconds by default.
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Timer? _timer;
  int _cooldown = _resendSeconds;
  int _step = 0; // 0 = enter the code, 1 = choose a new password (reset only)
  bool _busy = false;
  String? _error;

  bool get _isReset => widget.purpose == OtpPurpose.resetPassword;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = _resendSeconds;
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

  String _codeError(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('expired') || m.contains('invalid')) {
        return 'That code is wrong or has expired. Check it or request a new one.';
      }
    }
    return friendlyError(e);
  }

  Future<void> _verify() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final problem = Validators.otp(_code.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = _code.text.trim();
      if (_isReset) {
        await Api.verifyRecoveryCode(email: widget.email, code: code);
        if (!mounted) return;
        setState(() {
          _step = 1;
          _busy = false;
        });
      } else {
        await Api.verifyEmailCode(email: widget.email, code: code);
        if (!mounted) return;
        // The session now exists, so AuthGate shows the sign-up steps
        // underneath; close this screen (and anything above the gate).
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _codeError(e);
      });
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isReset) {
        await Api.sendPasswordResetCode(widget.email);
      } else {
        await Api.sendEmailCode(widget.email);
      }
      if (!mounted) return;
      _code.clear();
      setState(_startCooldown);
      showInfo(context, 'We sent a new code to ${widget.email}.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final problem = Validators.password(_password.text) ??
        (_password.text != _confirm.text ? 'The passwords do not match.' : null);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.setNewPassword(_password.text);
      if (!mounted) return;
      showSuccess(context, 'Password updated.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  /// Leaving the password step abandons the reset: the recovery session that
  /// the code created is closed again.
  Future<void> _cancelReset() async {
    if (_busy) return;
    await Api.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final choosingPassword = _isReset && _step == 1;
    return PopScope(
      // Once the recovery code is accepted the user must finish or cancel.
      canPop: !choosingPassword && !_busy,
      child: choosingPassword ? _passwordStep() : _codeStep(),
    );
  }

  Widget _codeStep() {
    final p = AppPalette.of(context);
    final ready = _code.text.length == _codeLength;

    return OnboardingScaffold(
      title: 'We sent you a code',
      subtitle: _isReset
          ? 'If an account exists for ${widget.email}, we sent it a 6-digit '
              'code. Enter it below to reset your password.'
          : 'Enter it below to verify ${widget.email}.',
      onBack: _busy ? null : () => Navigator.of(context).maybePop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BigTextField(
              controller: _code,
              placeholder: 'Verification code',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              fontSize: 28,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              onChanged: (v) {
                setState(() => _error = null);
                // Submit automatically as soon as the last digit is typed.
                if (v.length == _codeLength) _verify();
              },
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) FieldError(_error!),
            const SizedBox(height: 22),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (_cooldown > 0 || _busy) ? null : _resend,
              child: Text(
                _cooldown > 0
                    ? "Didn't receive email? Resend in ${_cooldown}s"
                    : "Didn't receive email? Resend code",
                style: TextStyle(
                  color: _cooldown > 0 ? p.subtext : p.accent,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Can't find it? Check your spam folder.",
              style: TextStyle(color: p.subtext, fontSize: 13),
            ),
          ],
        ),
      ),
      bottom: BlackButton(
        label: 'Next',
        busy: _busy,
        onPressed: ready ? _verify : null,
      ),
    );
  }

  Widget _passwordStep() {
    final p = AppPalette.of(context);
    return OnboardingScaffold(
      title: 'Choose a new password',
      subtitle: 'Your email is verified. Pick a new password '
          '(at least 6 characters).',
      onBack: _busy ? null : _cancelReset,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _password,
              placeholder: 'New password',
              obscureText: true,
              autocorrect: false,
              autofocus: true,
              textInputAction: TextInputAction.next,
              prefixIcon: Icon(AppIcons.lock, size: 18, color: p.subtext),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _confirm,
              placeholder: 'Confirm new password',
              obscureText: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _savePassword(),
              prefixIcon: Icon(AppIcons.lock, size: 18, color: p.subtext),
            ),
            if (_error != null) FieldError(_error!),
          ],
        ),
      ),
      bottom: BlackButton(
        label: 'Update password',
        busy: _busy,
        onPressed: _savePassword,
      ),
    );
  }
}
