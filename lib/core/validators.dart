/// Plain-Dart input validators (unit-tested in test/validators_test.dart).
/// Each returns an error message, or null when the value is valid.
class Validators {
  Validators._();

  static final RegExp _usernameRe = RegExp(r'^[A-Za-z0-9_]{3,15}$');
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Enter a password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// The 6-digit code from the confirmation / reset email.
  static String? otp(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter the 6-digit code.';
    }
    return null;
  }

  static String? username(String value) {
    final v = value.trim();
    if (!_usernameRe.hasMatch(v)) {
      return 'Username must be 3–15 characters: letters, numbers or _';
    }
    return null;
  }

  static String? displayName(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your name.';
    if (v.length > 50) return 'Name must be 50 characters or fewer.';
    return null;
  }

  static String? bio(String value) {
    if (value.length > 160) return 'Bio must be 160 characters or fewer.';
    return null;
  }

  static String? newPassword({
    required String current,
    required String next,
    required String confirm,
  }) {
    if (current.isEmpty) return 'Enter your current password.';
    final pw = password(next);
    if (pw != null) return pw;
    if (next == current) {
      return 'New password must be different from the current one.';
    }
    if (next != confirm) return 'The new passwords do not match.';
    return null;
  }
}
