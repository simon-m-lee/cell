// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Persistence adapters + PersistedCell (load, write modes,
// debouncing, pause, restoration composition, failure handling).

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_persistence/cell_flutter_persistence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('InMemoryAdapter', () {
    test('read, write, delete round-trip', () async {
      final adapter = InMemoryAdapter<int>();
      expect(await adapter.read('k'), isNull);

      await adapter.write('k', 42);
      expect(await adapter.read('k'), 42);

      await adapter.delete('k');
      expect(await adapter.read('k'), isNull);
    });

    test('seeded contents are readable', () async {
      final adapter = InMemoryAdapter<int>.seeded({'k': 7});
      expect(await adapter.read('k'), 7);
      expect(adapter.contents, containsPair('k', 7));
    });
  });

  group('SharedPreferencesAdapter', () {
    late SharedPreferencesAsync prefs;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = SharedPreferencesAsync();
    });

    test('string round-trips', () async {
      final adapter = SharedPreferencesAdapter.string(prefs);
      await adapter.write('s', 'hello');
      expect(await adapter.read('s'), 'hello');
      await adapter.delete('s');
      expect(await adapter.read('s'), isNull);
    });

    test('int, bool, double round-trip', () async {
      final ints = SharedPreferencesAdapter.integer(prefs);
      final bools = SharedPreferencesAdapter.boolean(prefs);
      final doubles = SharedPreferencesAdapter.double_(prefs);

      await ints.write('i', 5);
      await bools.write('b', true);
      await doubles.write('d', 2.5);

      expect(await ints.read('i'), 5);
      expect(await bools.read('b'), true);
      expect(await doubles.read('d'), 2.5);
    });

    test('List<String> round-trips', () async {
      final adapter = SharedPreferencesAdapter.stringList(prefs);
      await adapter.write('l', ['a', 'b']);
      expect(await adapter.read('l'), ['a', 'b']);
    });

    test('custom types round-trip through JSON codecs', () async {
      final adapter = SharedPreferencesAdapter<Map<String, Object?>>(
        prefs: prefs,
        fromJson: (json) => (json as Map).cast<String, Object?>(),
        toJson: (value) => value,
      );
      await adapter.write('m', {'x': 1});
      expect(await adapter.read('m'), {'x': 1});
    });

    test('custom types without codecs throw UnsupportedError', () async {
      final adapter = SharedPreferencesAdapter<DateTime>(prefs: prefs);
      expect(() => adapter.write('d', DateTime(2020)), throwsUnsupportedError);
      expect(() => adapter.read('d'), throwsUnsupportedError);
    });
  });

  group('PersistedCell', () {
    test('factory produces a RestorableCell with the initial value', () {
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: InMemoryAdapter<int>(),
      );
      expect(persisted.cell, isA<RestorableCell<int>>());
      expect(persisted.cell.value, 0);
      expect(persisted.key, 'counter');
    });

    test('load restores the persisted value', () async {
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: InMemoryAdapter<int>.seeded({'counter': 9}),
      );
      expect(await persisted.load(), isTrue);
      expect(persisted.cell.value, 9);
    });

    test('load with no persisted data keeps the initial', () async {
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 3,
        adapter: InMemoryAdapter<int>(),
      );
      expect(await persisted.load(), isFalse);
      expect(persisted.cell.value, 3);
    });

    test('a failing adapter read is handled gracefully', () async {
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 1,
        adapter: _ThrowingAdapter<int>(),
      );
      expect(await persisted.load(), isFalse);
      expect(persisted.cell.value, 1);
    });

    test('immediate mode writes on every change', () async {
      final adapter = InMemoryAdapter<int>();
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.immediate,
      );
      persisted.start();

      persisted.cell.value = 1;
      persisted.cell.value = 2;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.contents['counter'], 2);
      persisted.dispose();
    });

    test('debounced mode writes after the quiet period', () async {
      final adapter = InMemoryAdapter<int>();
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.debounced,
        debounce: const Duration(milliseconds: 20),
      );
      persisted.start();

      persisted.cell.value = 1;
      expect(adapter.contents, isEmpty, reason: 'not written yet');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(adapter.contents['counter'], 1);
      persisted.dispose();
    });

    test('debounced mode coalesces bursts into one write', () async {
      var writes = 0;
      final adapter = _CountingAdapter<int>(onWrite: () {
        writes++;
      });
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.debounced,
        debounce: const Duration(milliseconds: 20),
      );
      persisted.start();

      persisted.cell.value = 1;
      persisted.cell.value = 2;
      persisted.cell.value = 3;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(writes, 1);
      expect(adapter.stored, 3);
      persisted.dispose();
    });

    test('onAppPause mode writes only on handleAppPaused', () async {
      final adapter = InMemoryAdapter<int>();
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.onAppPause,
      );
      persisted.start();

      persisted.cell.value = 5;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.contents, isEmpty);

      await persisted.handleAppPaused();
      expect(adapter.contents['counter'], 5);
      persisted.dispose();
    });

    test('persistNow writes immediately', () async {
      final adapter = InMemoryAdapter<int>();
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.onAppPause,
      );
      persisted.cell.value = 8;
      await persisted.persistNow();
      expect(adapter.contents['counter'], 8);
    });

    test('dispose stops writes and cancels debounce', () async {
      final adapter = InMemoryAdapter<int>();
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
        writeMode: WriteMode.debounced,
        debounce: const Duration(milliseconds: 20),
      );
      persisted.start();
      persisted.cell.value = 1;
      persisted.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(adapter.contents, isEmpty);
    });

    testWidgets('composes with CellRestorationScope (process kill)',
        (tester) async {
      final adapter = InMemoryAdapter<int>.seeded({'counter': 77});
      final persisted = persistedState<int>(
        restorationId: 'counter',
        initial: 0,
        adapter: adapter,
      );

      await tester.pumpWidget(MaterialApp(
        home: CellRestorationScope(
          restorationScopeId: 'persisted-scope',
          bucket: _bucketWith({'counter': 66}),
          child: _PersistedHost(persisted: persisted),
        ),
      ));

      // Restoration rewrote the cell with the bucket's value; the
      // adapter value is untouched (persistence is a separate layer).
      expect(persisted.cell.value, 66);
      expect(adapter.contents['counter'], 77);
    });
  });
}

class _ThrowingAdapter<T> implements CellPersistenceAdapter<T> {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<T?> read(String key) async => throw StateError('backend down');

  @override
  Future<void> write(String key, T value) async {}
}

class _CountingAdapter<T> implements CellPersistenceAdapter<T> {
  _CountingAdapter({this.onWrite});

  final void Function()? onWrite;
  T? stored;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<T?> read(String key) async => stored;

  @override
  Future<void> write(String key, T value) async {
    stored = value;
    onWrite?.call();
  }
}

class _PersistedHost extends StatefulWidget {
  const _PersistedHost({required this.persisted});

  final PersistedCell<int> persisted;

  @override
  State<_PersistedHost> createState() => _PersistedHostState();
}

class _PersistedHostState extends State<_PersistedHost> {
  @override
  void initState() {
    super.initState();
    CellRestorationScope.maybeOf(context)?.register(widget.persisted.cell);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Builds a root bucket holding [values] under the scope id
/// 'persisted-scope'.
RestorationBucket _bucketWith(Map<String, Object?> values) {
  return RestorationBucket.root(
    manager: TestWidgetsFlutterBinding.instance.restorationManager,
    rawData: <Object?, Object?>{
      'v': <Object?, Object?>{},
      'c': <Object?, Object?>{
        'persisted-scope': <Object?, Object?>{
          'v': values,
          'c': <Object?, Object?>{},
        },
      },
    },
  );
}
