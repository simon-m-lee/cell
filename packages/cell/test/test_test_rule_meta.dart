// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:test/test.dart';
import 'package:cell/cell.dart';

void main() {
  group('DefaultValue', () {
    test('stores a primitive constant', () {
      const annotation = DefaultValue(42);
      expect(annotation.value, 42);
    });

    test('stores a string, bool, list, and map', () {
      expect(const DefaultValue('Unnamed').value, 'Unnamed');
      expect(const DefaultValue(true).value, isTrue);
      expect(const DefaultValue(['standard']).value, ['standard']);
      expect(const DefaultValue({'theme': 'light'}).value, {'theme': 'light'});
    });

    test('is a const annotation, not a TestRule', () {
      const annotation = DefaultValue(0);
      expect(annotation, isNot(isA<TestRule>()));
      expect(identical(const DefaultValue(1), const DefaultValue(1)), isTrue);
    });
  });

  group('MaxLength', () {
    group('direct field limit', () {
      test('allows a string at or under the limit', () {
        const rule = MaxLength(5);
        expect(rule.length, 5);
        expect(rule.hostLength, isNull);
        expect(rule.call(''), isTrue);
        expect(rule.call('abcde'), isTrue);
      });

      test('rejects a string over the limit', () {
        const rule = MaxLength(5);
        expect(rule.call('abcdef'), isFalse);
      });

      test('allows an iterable at or under the limit', () {
        const rule = MaxLength(3);
        expect(rule.call([1, 2, 3]), isTrue);
        expect(rule.call(<int>[]), isTrue);
        expect(rule.call({1, 2}), isTrue);
      });

      test('rejects an iterable over the limit', () {
        const rule = MaxLength(3);
        expect(rule.call([1, 2, 3, 4]), isFalse);
      });

      test('passes non-string, non-iterable objects', () {
        const rule = MaxLength(1);
        expect(rule.call(42), isTrue);
        expect(rule.call(null), isTrue);
        expect(rule.call({'k': 'v'}), isTrue);
      });
    });

    group('hostLength', () {
      test('rejects when the host iterable exceeds hostLength', () {
        const rule = MaxLength(100, hostLength: 2);
        expect(rule.call('ok', host: ['a', 'b', 'c']), isFalse);
      });

      test('allows a host iterable at the hostLength', () {
        const rule = MaxLength(100, hostLength: 2);
        expect(rule.call('ok', host: ['a', 'b']), isTrue);
      });

      test('ignores a non-iterable host and still checks the object', () {
        const rule = MaxLength(3, hostLength: 1);
        expect(rule.call('abc', host: 'not-a-list'), isTrue);
        expect(rule.call('abcd', host: 'not-a-list'), isFalse);
      });
    });

    group('composite field + container', () {
      test('rejects an over-long element even when the host is in quota', () {
        const rule = MaxLength(3, hostLength: 5);
        expect(rule.call('abcd', host: ['a', 'b']), isFalse);
      });

      test('rejects an over-long host even when the element is in quota', () {
        const rule = MaxLength(10, hostLength: 2);
        expect(rule.call('ok', host: ['a', 'b', 'c']), isFalse);
      });

      test('allows when both the element and the host are in quota', () {
        const rule = MaxLength(5, hostLength: 3);
        expect(rule.call('hello', host: ['a', 'b', 'c']), isTrue);
      });

      test('checks a list object against length when no host is passed', () {
        const rule = MaxLength(2, hostLength: 10);
        expect(rule.call(['a', 'b']), isTrue);
        expect(rule.call(['a', 'b', 'c']), isFalse);
      });
    });

    group('host-only', () {
      test('stores the sentinel direct length and the host limit', () {
        const rule = MaxLength.host(2);
        expect(rule.hostLength, 2);
        expect(rule.length, greaterThan(1 << 50));
      });

      test('does not limit the annotated object', () {
        const rule = MaxLength.host(2);
        expect(rule.call('a' * 100, host: ['x']), isTrue);
      });

      test('rejects an over-long host container', () {
        const rule = MaxLength.host(2);
        expect(rule.call('ignored', host: [1, 2, 3]), isFalse);
      });

      test('passes when the host is absent', () {
        const rule = MaxLength.host(1);
        expect(rule.call('anything'), isTrue);
      });
    });
  });

  group('ValueRange', () {
    test('stores inclusive bounds', () {
      const rule = ValueRange(min: 1, max: 120);
      expect(rule.min, 1);
      expect(rule.max, 120);
    });

    test('allows integers on the inclusive bounds', () {
      const rule = ValueRange(min: 1, max: 120);
      expect(rule.call(1), isTrue);
      expect(rule.call(120), isTrue);
      expect(rule.call(42), isTrue);
    });

    test('rejects integers outside the range', () {
      const rule = ValueRange(min: 1, max: 120);
      expect(rule.call(0), isFalse);
      expect(rule.call(121), isFalse);
      expect(rule.call(-5), isFalse);
    });

    test('allows doubles on a unit interval', () {
      const rule = ValueRange(min: 0.0, max: 1.0);
      expect(rule.call(0.0), isTrue);
      expect(rule.call(1.0), isTrue);
      expect(rule.call(0.5), isTrue);
      expect(rule.call(-0.01), isFalse);
      expect(rule.call(1.01), isFalse);
    });

    test('passes null and non-numeric values', () {
      const rule = ValueRange(min: 0, max: 1);
      expect(rule.call(null), isTrue);
      expect(rule.call('0'), isTrue);
      expect(rule.call(true), isTrue);
    });

    test('always fails numbers when min is greater than max', () {
      const rule = ValueRange(min: 10, max: 1);
      expect(rule.call(5), isFalse);
      expect(rule.call(10), isFalse);
      expect(rule.call(1), isFalse);
      expect(rule.call('skip'), isTrue);
    });
  });

  group('EntryPattern', () {
    test('stores pattern flags with documented defaults', () {
      const rule = EntryPattern(pattern: r'^[a-z]+$');
      expect(rule.pattern, r'^[a-z]+$');
      expect(rule.caseSensitive, isFalse);
      expect(rule.allowEmpty, isFalse);
      expect(rule.allowNull, isFalse);
    });

    test('matches a non-empty string against the pattern', () {
      const rule = EntryPattern(pattern: r'^\d{3}-\d{2}-\d{4}$');
      expect(rule.call('123-45-6789'), isTrue);
      expect(rule.call('123456789'), isFalse);
    });

    test('is case-insensitive by default', () {
      const rule = EntryPattern(pattern: r'^[a-z]+$');
      expect(rule.call('ABC'), isTrue);
      expect(rule.call('AbC'), isTrue);
    });

    test('honors caseSensitive: true', () {
      const rule = EntryPattern(pattern: r'^[a-z]+$', caseSensitive: true);
      expect(rule.call('abc'), isTrue);
      expect(rule.call('ABC'), isFalse);
    });

    test('rejects null unless allowNull is true', () {
      const deny = EntryPattern(pattern: r'^x$');
      const allow = EntryPattern(pattern: r'^x$', allowNull: true);
      expect(deny.call(null), isFalse);
      expect(allow.call(null), isTrue);
    });

    test('rejects empty strings unless allowEmpty is true', () {
      const deny = EntryPattern(pattern: r'^x$');
      const allow = EntryPattern(pattern: r'^x$', allowEmpty: true);
      expect(deny.call(''), isFalse);
      expect(allow.call(''), isTrue);
    });

    test('passes non-string objects', () {
      const rule = EntryPattern(pattern: r'^x$');
      expect(rule.call(123), isTrue);
      expect(rule.call(['x']), isTrue);
    });
  });

  group('Values', () {
    test('allows members of the whitelist', () {
      const rule = Values(['pending', 'approved', 'rejected']);
      expect(rule.values, ['pending', 'approved', 'rejected']);
      expect(rule.call('pending'), isTrue);
      expect(rule.call('approved'), isTrue);
    });

    test('rejects values not in the whitelist', () {
      const rule = Values(['pending', 'approved', 'rejected']);
      expect(rule.call('draft'), isFalse);
      expect(rule.call(''), isFalse);
    });

    test('rejects null unless null is listed', () {
      const deny = Values(['a']);
      const allow = Values([null, 'a']);
      expect(deny.call(null), isFalse);
      expect(allow.call(null), isTrue);
      expect(allow.call('a'), isTrue);
    });

    test('matches numeric option sets by ==', () {
      const rule = Values([1, 2, 3, 5, 8]);
      expect(rule.call(5), isTrue);
      expect(rule.call(4), isFalse);
      expect(rule.call(5.0), isTrue);
    });
  });

  group('EmailPattern', () {
    test('uses the documented default flags', () {
      const rule = EmailPattern();
      expect(rule.caseSensitive, isFalse);
      expect(rule.allowEmpty, isFalse);
      expect(rule.allowNull, isTrue);
      expect(rule.pattern, contains('@'));
    });

    test('accepts typical email addresses', () {
      const rule = EmailPattern();
      expect(rule.call('user@example.com'), isTrue);
      expect(rule.call('first.last+tag@sub.example.co'), isTrue);
      expect(rule.call('USER@EXAMPLE.COM'), isTrue);
    });

    test('rejects malformed addresses and empty strings', () {
      const rule = EmailPattern();
      expect(rule.call('not-an-email'), isFalse);
      expect(rule.call('user@'), isFalse);
      expect(rule.call('@example.com'), isFalse);
      expect(rule.call(''), isFalse);
    });

    test('allows null by default and can reject it', () {
      expect(const EmailPattern().call(null), isTrue);
      expect(const EmailPattern(allowNull: false).call(null), isFalse);
    });

    test('accepts a custom corporate pattern', () {
      const rule = EmailPattern(
        pattern: r'^[a-z.]+@corporate\.com$',
        allowNull: true,
      );
      expect(rule.call('ada.lovelace@corporate.com'), isTrue);
      expect(rule.call('ada@other.com'), isFalse);
      expect(rule.call(null), isTrue);
    });
  });

  group('WebsiteUrlPattern', () {
    test('uses the documented default flags', () {
      const rule = WebsiteUrlPattern();
      expect(rule.caseSensitive, isFalse);
      expect(rule.allowEmpty, isFalse);
      expect(rule.allowNull, isTrue);
    });

    test('accepts typical web addresses', () {
      const rule = WebsiteUrlPattern();
      expect(rule.call('example.com'), isTrue);
      expect(rule.call('https://example.com'), isTrue);
      expect(rule.call('http://www.example.com/path'), isTrue);
      expect(rule.call('https://sub.example.co.uk/a/b'), isTrue);
    });

    test('rejects empty strings and non-urls', () {
      const rule = WebsiteUrlPattern();
      expect(rule.call(''), isFalse);
      expect(rule.call('not a url'), isFalse);
    });

    test('allows null by default and can reject it', () {
      expect(const WebsiteUrlPattern().call(null), isTrue);
      expect(const WebsiteUrlPattern(allowNull: false).call(null), isFalse);
    });

    test('accepts a custom pattern', () {
      const rule = WebsiteUrlPattern(
        pattern: r'^https:\/\/corporate\.com\/[a-z]+$',
        allowNull: true,
      );
      expect(rule.call('https://corporate.com/about'), isTrue);
      expect(rule.call('http://corporate.com/about'), isFalse);
      expect(rule.call(null), isTrue);
    });
  });

  group('TestRule composition', () {
    test('MaxLength is a TestRule', () {
      expect(const MaxLength(1), isA<TestRule>());
      expect(const ValueRange(min: 0, max: 1), isA<TestRule>());
      expect(const EntryPattern(pattern: r'^x$'), isA<TestRule>());
      expect(const Values([1]), isA<TestRule>());
      expect(const EmailPattern(), isA<EntryPattern>());
      expect(const WebsiteUrlPattern(), isA<EntryPattern>());
    });

    test('MaxLength + ValueRange short-circuits on the first failure', () {
      final pipeline = const MaxLength(3) + const ValueRange(min: 0, max: 10);
      expect(pipeline.call('ab'), isTrue);
      expect(pipeline.call('abcd'), isFalse);
      expect(pipeline.call(5), isTrue);
      expect(pipeline.call(11), isFalse);
    });
  });
}
