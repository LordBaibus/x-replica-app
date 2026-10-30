import 'package:flutter_test/flutter_test.dart';
import 'package:x_replica/core/validators.dart';

void main() {
  group('email', () {
    test('accepts a normal address', () {
      expect(Validators.email('jai@example.com'), isNull);
      expect(Validators.email('  jai@example.com  '), isNull);
    });
    test('rejects empty and malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('jai'), isNotNull);
      expect(Validators.email('jai@'), isNotNull);
      expect(Validators.email('jai@example'), isNotNull);
      expect(Validators.email('j ai@example.com'), isNotNull);
    });
  });

  group('password', () {
    test('needs at least 6 characters', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('username', () {
    test('accepts letters, digits and underscore (3-15)', () {
      expect(Validators.username('jai_01'), isNull);
      expect(Validators.username('ABC'), isNull); // mixed case is allowed
      expect(Validators.username('a' * 15), isNull);
    });
    test('rejects too short, too long and bad characters', () {
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('a' * 16), isNotNull);
      expect(Validators.username('jai.01'), isNotNull);
      expect(Validators.username('jai 01'), isNotNull);
      expect(Validators.username('jai@01'), isNotNull);
    });
  });

  group('displayName and bio', () {
    test('display name must not be blank or over 50 chars', () {
      expect(Validators.displayName('Jai'), isNull);
      expect(Validators.displayName('   '), isNotNull);
      expect(Validators.displayName('x' * 51), isNotNull);
    });
    test('bio is capped at 160 characters', () {
      expect(Validators.bio('x' * 160), isNull);
      expect(Validators.bio('x' * 161), isNotNull);
    });
  });

  group('newPassword', () {
    test('valid change', () {
      expect(
        Validators.newPassword(current: 'oldpass', next: 'newpass1', confirm: 'newpass1'),
        isNull,
      );
    });
    test('requires the current password', () {
      expect(
        Validators.newPassword(current: '', next: 'newpass1', confirm: 'newpass1'),
        isNotNull,
      );
    });
    test('rejects a short new password', () {
      expect(
        Validators.newPassword(current: 'oldpass', next: '123', confirm: '123'),
        isNotNull,
      );
    });
    test('rejects reuse of the current password', () {
      expect(
        Validators.newPassword(current: 'samepass', next: 'samepass', confirm: 'samepass'),
        isNotNull,
      );
    });
    test('rejects a mismatched confirmation', () {
      expect(
        Validators.newPassword(current: 'oldpass', next: 'newpass1', confirm: 'newpass2'),
        isNotNull,
      );
    });
  });

  group('otp', () {
    test('accepts exactly six digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp(' 042913 '), isNull);
    });
    test('rejects short, long and non-numeric codes', () {
      expect(Validators.otp(''), isNotNull);
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('1234567'), isNotNull);
      expect(Validators.otp('12a456'), isNotNull);
    });
  });
}
