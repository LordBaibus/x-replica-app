import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../services/account_sessions.dart';
import '../services/api.dart';
import '../services/moderation.dart';
import '../services/user_prefs.dart';
import '../services/saved_accounts.dart';
import '../widgets/app_text_field.dart';
import '../widgets/avatar.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pill_button.dart';
import '../widgets/responsive.dart';
import '../widgets/state_views.dart';
import 'otp_screen.dart';

/// Which step of the signed-out flow is showing.
enum _AuthView {
  /// "Log in to ..." with the accounts used on this device.
  picker,

  /// Email + password (or just the password for a chosen account).
  login,

  /// "Create an account" landing page.
  createLanding,

  /// Email address (the code and the remaining steps come next).
  createForm,
}

/// Signed-out flow, laid out like X's: saved-account picker, log-in form,
/// "Create an account" landing and the sign-up form.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.addAccount = false,
    this.startAtCreate = false,
  });

  /// Opened from the account switcher while another account is signed in:
  /// starts on the log-in form, has a back arrow, and closes itself once the
  /// new account is in. The first account stays saved on the phone.
  final bool addAccount;

  /// With [addAccount]: open on "Create an account" instead of the log-in form.
  final bool startAtCreate;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthView _view = _AuthView.login;
  bool _loaded = false;
  List<SavedAccount> _accounts = const [];

  /// Account picked from the list: only the password is asked.
  SavedAccount? _chosen;

  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final list = await SavedAccounts.load();
    if (!mounted) return;
    setState(() {
      _accounts = list;
      _view = widget.addAccount
          ? (widget.startAtCreate ? _AuthView.createLanding : _AuthView.login)
          : (list.isEmpty ? _AuthView.login : _AuthView.picker);
      _loaded = true;
    });
  }

  // ---- navigation --------------------------------------------------------

  _AuthView get _rootView => widget.addAccount || _accounts.isEmpty
      ? _AuthView.login
      : _AuthView.picker;

  bool get _atRoot => _view == _rootView && _chosen == null;

  void _go(_AuthView view) {
    setState(() {
      _view = view;
      _error = null;
    });
  }

  void _back() {
    if (widget.addAccount && _atRoot) {
      Navigator.of(context).maybePop();
      return;
    }
    switch (_view) {
      case _AuthView.createForm:
        _go(_AuthView.createLanding);
      case _AuthView.createLanding:
      case _AuthView.login:
        setState(() => _chosen = null);
        _go(_rootView);
      case _AuthView.picker:
        break;
    }
  }

  Future<void> _choose(SavedAccount account) async {
    if (_busy) return;
    // A saved login opens the account without asking for the password.
    if (account.canSwitch && !widget.addAccount) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await AccountSessions.switchTo(account);
        return; // AuthGate shows the app.
      } catch (_) {
        // Expired: fall through to the password form.
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    }
    _email.text = account.email;
    _password.clear();
    setState(() => _chosen = account);
    _go(_AuthView.login);
  }

  void _addAnother() {
    _email.clear();
    _password.clear();
    setState(() => _chosen = null);
    _go(_AuthView.login);
  }

  Future<void> _removeAccount(SavedAccount account) async {
    final ok = await confirm(
      context,
      title: 'Remove ${account.name}?',
      message: 'You will need to enter the email and password again to log '
          'back in on this device.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await SavedAccounts.remove(account.email);
    await _loadAccounts();
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final problem = Validators.email(_email.text) ??
        (_password.text.isEmpty ? 'Enter your password.' : null);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // Adding an account while another one is open: forget the open account's
    // cached data first, so nothing of it leaks into the new one.
    if (widget.addAccount) {
      UserPrefs.instance.reset();
      Moderation.instance.reset();
    }
    try {
      await Api.signIn(email: _email.text, password: _password.text);
      // AuthGate swaps to the app automatically; close this page.
      if (widget.addAccount && mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (widget.addAccount) {
        unawaited(UserPrefs.instance.load());
        unawaited(Moderation.instance.reload());
      }
      await _handleError(e, signingUp: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// First step of creating an account: email the 6-digit code. The rest
  /// (birthday, name, username, password ...) is asked after it is verified.
  Future<void> _submitCreate() async {
    FocusScope.of(context).unfocus();
    final problem = Validators.email(_email.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await Api.emailRegistered(_email.text)) {
        if (mounted) setState(() => _error = 'Email has already been taken.');
        return;
      }
      await Api.sendEmailCode(_email.text);
      if (!mounted) return;
      await _openCodeScreen(OtpPurpose.signUp);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isUnconfirmed(Object e) =>
      e is AuthException && e.message.toLowerCase().contains('not confirmed');

  /// Logging in with an address that was never confirmed sends a new code and
  /// opens the code screen instead of just showing an error.
  Future<void> _handleError(Object e, {required bool signingUp}) async {
    if (!signingUp && _isUnconfirmed(e)) {
      try {
        await Api.resendSignUpCode(_email.text);
        if (mounted) await _openCodeScreen(OtpPurpose.signUp);
      } catch (e2) {
        if (mounted) setState(() => _error = friendlyError(e2));
      }
      return;
    }
    if (mounted) setState(() => _error = friendlyError(e));
  }

  Future<void> _openCodeScreen(OtpPurpose purpose) async {
    await Navigator.of(context).push(
      appRoute<void>(OtpScreen(email: _email.text.trim(), purpose: purpose)),
    );
    // Back from the reset-password code screen: offer log-in again.
    if (mounted && purpose == OtpPurpose.resetPassword) {
      setState(() {
        _view = _AuthView.login;
        _error = null;
      });
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    if (Validators.email(_email.text) != null) {
      setState(() => _error =
          'Enter your email address above, then tap "Forgot password?".');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.sendPasswordResetCode(_email.text);
      if (!mounted) return;
      await _openCodeScreen(OtpPurpose.resetPassword);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- shared pieces -----------------------------------------------------

  Widget _title(AppPalette p, String text,
      {bool logo = false, TextAlign align = TextAlign.start}) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: p.text,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        children: [
          TextSpan(text: text),
          if (logo) ...[
            const TextSpan(text: ' '),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: BrandMark(size: 30),
            ),
          ],
        ],
      ),
      textAlign: align,
    );
  }

  Widget _subtitle(AppPalette p, String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          text,
          style: TextStyle(color: p.subtext, fontSize: 18, height: 1.3),
        ),
      );

  Widget _errorText(AppPalette p) {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        _error!,
        style: TextStyle(color: p.danger, fontSize: 14, height: 1.3),
      ),
    );
  }

  Widget _orDivider(AppPalette p) {
    final line = Expanded(
      child: Container(height: 0.5, color: p.subtext.withValues(alpha: 0.45)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR', style: TextStyle(color: p.subtext, fontSize: 15)),
        ),
        line,
      ],
    );
  }

  Widget _wideButton(String label, VoidCallback? onPressed,
      {PillStyle style = PillStyle.inverse, IconData? icon}) {
    return SizedBox(
      width: double.infinity,
      child: PillButton(
        label: label,
        icon: icon,
        style: style,
        height: 50,
        fontSize: 17,
        onPressed: onPressed,
      ),
    );
  }

  Widget _bottomBar(AppPalette p, String label, VoidCallback onPressed) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: _wideButton(
        _busy ? 'Please wait…' : label,
        _busy ? null : onPressed,
      ),
    );
  }

  /// Rounded dark card used for accounts and "Add another account".
  Widget _card(AppPalette p,
      {required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border, width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _accountCard(AppPalette p, SavedAccount a,
      {VoidCallback? onTap, VoidCallback? onRemove}) {
    return _card(
      p,
      onTap: onTap,
      child: Row(
        children: [
          Avatar(url: a.avatarUrl, name: a.name, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '@${a.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.subtext, fontSize: 15),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(AppIcons.trash, size: 22, color: p.text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(AppPalette p, Widget child) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.background,
          border: Border.all(color: p.border, width: 1),
        ),
        child: child,
      );

  // ---- the four views ----------------------------------------------------

  Widget _pickerView(AppPalette p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(p, 'Log in to', logo: true),
          _subtitle(p, 'Continue with your existing accounts'),
          const SizedBox(height: 30),
          for (final a in _accounts) ...[
            _accountCard(
              p,
              a,
              onTap: () => _choose(a),
              onRemove: () => _removeAccount(a),
            ),
            const SizedBox(height: 12),
          ],
          _card(
            p,
            onTap: _addAnother,
            child: Row(
              children: [
                Icon(AppIcons.add, size: 26, color: p.text),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Add another account',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // The ways to sign in on the real thing: Google, Apple, phone.
                // (This project signs in with email and password.)
                _chip(
                  p,
                  const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _chip(
                  p,
                  PlatformInfo.isIOS
                      ? Text(
                          '\uF8FF',
                          style: TextStyle(
                            color: p.text,
                            fontSize: 17,
                            height: 1,
                          ),
                        )
                      : Icon(CupertinoIcons.leaf_arrow_circlepath,
                          size: 15, color: p.text),
                ),
                const SizedBox(width: 4),
                _chip(p, Icon(CupertinoIcons.phone_fill, size: 14, color: p.text)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _orDivider(p),
          const SizedBox(height: 26),
          _wideButton(
            'Create a new account',
            () => _go(_AuthView.createLanding),
            style: PillStyle.outline,
          ),
        ],
      ),
    );
  }

  Widget _loginView(AppPalette p) {
    final chosen = _chosen;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(p, 'Log in to', logo: true),
                _subtitle(
                  p,
                  chosen == null
                      ? 'Enter your email and password'
                      : 'Enter your password',
                ),
                const SizedBox(height: 26),
                if (chosen != null) ...[
                  _accountCard(p, chosen),
                  const SizedBox(height: 14),
                ] else ...[
                  AppTextField(
                    controller: _email,
                    placeholder: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icon(AppIcons.mail, size: 18, color: p.subtext),
                  ),
                  const SizedBox(height: 12),
                ],
                AppTextField(
                  controller: _password,
                  placeholder: 'Password',
                  obscureText: true,
                  autocorrect: false,
                  autofocus: chosen != null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _submitLogin(),
                  prefixIcon: Icon(AppIcons.lock, size: 18, color: p.subtext),
                ),
                _errorText(p),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : _forgotPassword,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(color: p.accent, fontSize: 15),
                    ),
                  ),
                ),
                if (_atRoot) ...[
                  const SizedBox(height: 22),
                  _orDivider(p),
                  const SizedBox(height: 22),
                  _wideButton(
                    'Create a new account',
                    () => _go(_AuthView.createLanding),
                    style: PillStyle.outline,
                  ),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(p, 'Log in', _submitLogin),
      ],
    );
  }

  Widget _createLandingView(AppPalette p) {
    return Column(
      children: [
        Expanded(
          child: ScrollSafeCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 76),
                const SizedBox(height: 26),
                _title(p, 'Create an account', align: TextAlign.center),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _wideButton(
            'Create an account with email',
            () => _go(_AuthView.createForm),
            icon: AppIcons.mail,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Text(
            'Educational project — not affiliated with any social network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.subtext, fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _createFormView(AppPalette p) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(p, 'Create your account'),
                _subtitle(
                  p,
                  "Enter your email. We'll send you a 6-digit code to verify it.",
                ),
                const SizedBox(height: 26),
                AppTextField(
                  controller: _email,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _submitCreate(),
                  prefixIcon: Icon(AppIcons.mail, size: 18, color: p.subtext),
                ),
                _errorText(p),
              ],
            ),
          ),
        ),
        _bottomBar(p, 'Next', _submitCreate),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget content;
    if (!_loaded) {
      content = const SizedBox.shrink();
    } else {
      switch (_view) {
        case _AuthView.picker:
          content = _pickerView(p);
        case _AuthView.login:
          content = _loginView(p);
        case _AuthView.createLanding:
          content = _createLandingView(p);
        case _AuthView.createForm:
          content = _createFormView(p);
      }
    }

    final showBack = _loaded && (!_atRoot || widget.addAccount);

    return PopScope(
      // System back walks back through the steps instead of closing the app.
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AdaptiveScaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: ContentWidth(
            maxWidth: 480,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showBack
                        ? GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _back,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Icon(
                                AppIcons.back,
                                size: 24,
                                color: p.text,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
