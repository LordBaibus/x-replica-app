import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/widgets.dart';

import '../core/app_icons.dart';
import '../core/app_palette.dart';
import '../core/ui_helpers.dart';
import '../core/validators.dart';
import '../services/api.dart';
import '../widgets/app_text_field.dart';
import '../widgets/responsive.dart';

/// Change the account password (the current one is verified first).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
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

  Future<void> _submit() async {
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
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() {
        _busy = false;
        // Wrong current password surfaces as an invalid-login error.
        _error = msg == 'Wrong email or password.'
            ? 'Your current password is incorrect.'
            : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    Widget field(TextEditingController c, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppTextField(
            controller: c,
            placeholder: hint,
            obscureText: true,
            autocorrect: false,
            prefixIcon: Icon(AppIcons.lock, size: 18, color: p.subtext),
          ),
        );

    return AdaptiveScaffold(
      backgroundColor: AppPalette.of(context).background,
      appBar: const AdaptiveAppBar(title: 'Change password'),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 480,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter your current password, then choose a new one '
                  '(at least 6 characters).',
                  style: TextStyle(color: p.subtext, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 18),
                field(_current, 'Current password'),
                field(_next, 'New password'),
                field(_confirm, 'Confirm new password'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: p.danger, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 6),
                AdaptiveButton(
                  color: AppPalette.of(context).accent,
                  textColor: const Color(0xFFFFFFFF),
                  onPressed: _busy ? null : _submit,
                  enabled: !_busy,
                  label: _busy ? 'Updating…' : 'Update password',
                  style: AdaptiveButtonStyle.filled,
                  size: AdaptiveButtonSize.large,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
