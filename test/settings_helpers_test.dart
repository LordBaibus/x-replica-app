import 'package:flutter_test/flutter_test.dart';
import 'package:x_replica/core/countries.dart';
import 'package:x_replica/screens/account_screens.dart'
    show labelName, normalizePhone, phoneLooksValid;
import 'package:x_replica/services/moderation.dart';
import 'package:x_replica/widgets/settings_parts.dart' show maskEmail;

void main() {
  group('maskEmail', () {
    test('keeps two letters and the domain', () {
      expect(maskEmail('lordbaibus@gmail.com'), 'lo********@gmail.com');
    });
    test('short names keep one letter', () {
      expect(maskEmail('ab@x.com'), startsWith('a'));
      expect(maskEmail('ab@x.com'), endsWith('@x.com'));
    });
    test('not an email is returned as is', () {
      expect(maskEmail('nope'), 'nope');
    });
  });

  group('countries', () {
    test('flag emoji comes from the ISO code', () {
      expect(Countries.philippines.flag, '\u{1F1F5}\u{1F1ED}');
    });
    test('list is alphabetical and has Philippines', () {
      final names = Countries.all.map((c) => c.name).toList();
      final sorted = [...names]..sort();
      expect(names, sorted);
      expect(Countries.byName('Philippines')?.dialCode, '+63');
    });
    test('splitPhone finds the longest matching dial code', () {
      final split = Countries.splitPhone('+63 9051234567');
      expect(split, isNotNull);
      expect(split!.$1.name, 'Philippines');
      expect(split.$2, '9051234567');
      expect(Countries.splitPhone('9051234567'), isNull);
    });
  });

  group('phone numbers', () {
    final ph = Countries.philippines;
    test('adds the dial code and drops a leading 0', () {
      expect(normalizePhone('0905 123 4567', ph), '+63 9051234567');
      expect(normalizePhone('905-123-4567', ph), '+63 9051234567');
    });
    test('keeps a number that already starts with +', () {
      expect(normalizePhone('+1 415 555 0100', ph), '+14155550100');
    });
    test('validity needs 8 to 15 digits', () {
      expect(phoneLooksValid('905 123 4567', ph), isTrue);
      expect(phoneLooksValid('12', ph), isFalse);
      expect(phoneLooksValid('', ph), isFalse);
    });
  });

  group('profile labels', () {
    test('names', () {
      expect(labelName('parody'), 'Parody');
      expect(labelName('fan'), 'Fan');
      expect(labelName('commentary'), 'Commentary');
      expect(labelName(null), 'None');
    });
  });

  group('muted words', () {
    test('normalise', () {
      expect(Moderation.normalizeWord('  HeLLo '), 'hello');
    });
    test('whole word match only', () {
      expect(Moderation.wordHits('I love art today', 'art'), isTrue);
      expect(Moderation.wordHits('what a party', 'art'), isFalse);
      expect(Moderation.wordHits('Art!', 'art'), isTrue);
      expect(Moderation.wordHits('#art is life', 'art'), isTrue);
    });
    test('phrases and special characters are escaped', () {
      expect(Moderation.wordHits('buy now (limited)', 'buy now'), isTrue);
      expect(Moderation.wordHits('a+b', 'a+b'), isTrue);
      expect(Moderation.wordHits('anything', ''), isFalse);
    });
  });
}
