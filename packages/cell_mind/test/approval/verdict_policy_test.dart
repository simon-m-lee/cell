// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_mind/cell_mind.dart';
import 'package:test/test.dart';

void main() {
  final host = Cell.ingress<int>(
      context: Context.fromEntries([
    Ontology.domains.entry('finance'),
  ])).cell;

  group('VerdictPolicy', () {
    test('verdictPolicy returns the authored verdict', () {
      final policy = verdictPolicy((object, {required host, arguments}) {
        return object is Pulse ? const Defer('approval') : const Accept();
      });
      expect(
        policy.call(Pulse<int>(1), host: host),
        isA<Defer>(),
      );
      expect(policy.call('text', host: host), isA<Accept>());
    });

    test('+ short-circuits on Accept', () {
      final first = verdictPolicy(
        (object, {required host, arguments}) => const Accept(),
      );
      final second = verdictPolicy(
        (object, {required host, arguments}) => const Reject('never'),
      );
      final calls = <int>[];
      final composite = first +
          verdictPolicy(
            (object, {required host, arguments}) {
              calls.add(1);
              return second.call(object, host: host);
            },
          );
      expect(composite.call(Pulse<int>(1), host: host), isA<Accept>());
      expect(calls, isEmpty, reason: 'The second policy never runs.');
    });

    test('+ short-circuits on Reject', () {
      final first = verdictPolicy(
        (object, {required host, arguments}) => const Reject('blocked'),
      );
      final composite = first +
          verdictPolicy(
            (object, {required host, arguments}) => const Accept(),
          );
      final verdict = composite.call(Pulse<int>(1), host: host);
      expect(verdict, isA<Reject>());
      expect((verdict as Reject).reason, 'blocked');
    });

    test('+ propagates Defer through', () {
      final first = verdictPolicy(
        (object, {required host, arguments}) => const Defer('first', {'n': 1}),
      );
      final composite = first +
          verdictPolicy(
            (object, {required host, arguments}) => const Reject('fallback'),
          );
      final verdict = composite.call(Pulse<int>(1), host: host);
      expect(verdict, isA<Reject>());
      expect((verdict as Reject).reason, 'fallback');
    });

    test('+ chains three left-associatively', () {
      final composite = verdictPolicy(
            (object, {required host, arguments}) => const Defer('a'),
          ) +
          verdictPolicy(
            (object, {required host, arguments}) => const Defer('b'),
          ) +
          verdictPolicy(
            (object, {required host, arguments}) => const Reject('last'),
          );
      final verdict = composite.call(Pulse<int>(1), host: host);
      expect((verdict as Reject).reason, 'last');
    });

    test('call passes host and arguments through', () {
      late Cell seenHost;
      late dynamic seenArguments;
      final policy = verdictPolicy(
        (object, {required host, arguments}) {
          seenHost = host;
          seenArguments = arguments;
          return const Accept();
        },
      );
      final marker = Object();
      policy.call(marker, host: host, arguments: marker);
      expect(seenHost, host);
      expect(identical(seenArguments, marker), isTrue);
    });
  });
}
