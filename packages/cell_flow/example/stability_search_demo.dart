// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';
import 'package:cell_flow/flow.dart';

/// A complete walkthrough demonstrating user-input stabilization and
/// debounced API calls using the Cell Framework's Flow.debounce operator.
///
/// ### Scenario
/// A search-as-you-type feature where:
/// 1. User types in a search box
/// 2. Input is stabilized (debounced) to avoid excessive API calls
/// 3. Each stabilized input triggers an API call
/// 4. Results are displayed
/// 5. Loading states are shown
/// 6. Error handling is included
/// 7. Latest search cancels previous pending requests
///
/// ### Learning Objectives
/// - Understand how Flow.debounce works
/// - See debounce in a real-world search scenario
/// - Learn how to chain debounce with other operators
/// - Understand loading state management
/// - See error handling in reactive streams
/// - Learn about asyncMapLatest for request cancellation
///
/// ### Expected Console Output
/// ```
/// ── Search Demo ────────────────────────────────────────────────────────
///
/// [User] Searching for: 'd'
/// [User] Searching for: 'da'
/// [User] Searching for: 'dar'
/// [User] Searching for: 'dart'
/// [Debounce] Stabilized search: 'dart'
/// [API] Simulating API call: dart (200ms)
/// [Result] Found: Dart programming language
///
/// ── Rapid Typing Demo ────────────────────────────────────────────────
///
/// [User] Searching for: 'f'
/// [User] Searching for: 'fl'
/// [User] Searching for: 'flu'
/// [User] Searching for: 'flut'
/// [User] Searching for: 'flutt'
/// [User] Searching for: 'flutter'
/// [Debounce] Stabilized search: 'flutter'
/// [API] Simulating API call: flutter (500ms)
/// [Result] Found: Flutter framework
///
/// ── Cancellation Demo ─────────────────────────────────────────────────
///
/// [User] Searching for: 'a'
/// [API] Simulating API call: a (800ms)
/// [User] Searching for: 'ab'
/// [API] Simulating API call: ab (400ms)
/// [User] Searching for: 'abc'
/// [API] Simulating API call: abc (200ms)
/// [Result] Found: ABC
/// [Cancellation] Previous requests were automatically cancelled
///
/// ── Error Handling Demo ──────────────────────────────────────────────
///
/// [User] Searching for: 'error'
/// [Debounce] Stabilized search: 'error'
/// [API] Simulating API call: error (300ms) - WILL FAIL!
/// [Error] API Error: Simulated API failure
/// [Result] Error occurred during search
///
/// ── Finished ──────────────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Search Demo ────────────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Search with Debounce
  // ========================================================================

  print('1. Basic Search with Flow.debounce\n');

  // Create an input cell for user search queries
  final searchInput = Cell.ingress<String>();

  // Build the search pipeline using Flow.debounce
  // Step 1: Debounce user input (wait 300ms of silence)
  final debouncedHandle = Flow.debounce<String>(
    searchInput.cell,
    duration: const Duration(milliseconds: 300),
  );

  // Step 2: Tap to log the stabilized search query
  final tappedHandle = Flow.tap<String>(
    debouncedHandle.cell,
    onValue: (query) => print('   [Debounce] Stabilized search: \'$query\''),
  );

  // Step 3: Perform the API call with asyncMapLatest (cancels previous requests)
  final apiHandle = Flow.asyncMapLatest<String, String>(
    tappedHandle.cell,
    mapper: (query) async {
      print('   [API] Simulating API call: $query (200ms)');
      await Future.delayed(const Duration(milliseconds: 200));
      return 'Found: $query programming language';
    },
  );

  // Observe the results
  final observer = Cell.observe(
    source: apiHandle.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  // Simulate user typing
  print('   [User] Searching for: \'d\'');
  await searchInput.emitAsync('d');

  print('   [User] Searching for: \'da\'');
  await searchInput.emitAsync('da');

  print('   [User] Searching for: \'dar\'');
  await searchInput.emitAsync('dar');

  print('   [User] Searching for: \'dart\'');
  await searchInput.emitAsync('dart');

  // Wait for results
  await Future.delayed(const Duration(milliseconds: 400));

  observer.stop();
  print('');

  // ========================================================================
  // 2. Rapid Typing Demo (Shows debounce in action)
  // ========================================================================

  print('2. Rapid Typing Demo (shows debounce in action)\n');

  final rapidInput = Cell.ingress<String>();

  final rapidDebounce = Flow.debounce<String>(
    rapidInput.cell,
    duration: const Duration(milliseconds: 300),
  );

  final rapidApi = Flow.asyncMapLatest<String, String>(
    rapidDebounce.cell,
    mapper: (query) async {
      print('   [API] Simulating API call: $query (500ms)');
      await Future.delayed(const Duration(milliseconds: 500));
      return 'Found: $query framework';
    },
  );

  final rapidObserver = Cell.observe(
    source: rapidApi.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  // Rapid typing simulation (all within debounce window)
  final queries = ['f', 'fl', 'flu', 'flut', 'flutt', 'flutter'];
  for (final q in queries) {
    print('   [User] Searching for: \'$q\'');
    await rapidInput.emitAsync(q);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // Wait for debounce to fire and API to complete
  await Future.delayed(const Duration(milliseconds: 900));

  rapidObserver.stop();
  print('');

  // ========================================================================
  // 3. Cancellation Demo (asyncMapLatest cancels previous requests)
  // ========================================================================

  print('3. Cancellation Demo (asyncMapLatest cancels previous requests)\n');

  final cancelInput = Cell.ingress<String>();

  final cancelDebounce = Flow.debounce<String>(
    cancelInput.cell,
    duration: const Duration(milliseconds: 100),
  );

  final cancelApi = Flow.asyncMapLatest<String, String>(
    cancelDebounce.cell,
    mapper: (query) async {
      // Different delays to show cancellation
      final delay = query == 'a' ? 800 : (query == 'ab' ? 400 : 200);
      print('   [API] Simulating API call: $query (${delay}ms)');
      await Future.delayed(Duration(milliseconds: delay));
      return query.toUpperCase();
    },
  );

  final cancelObserver = Cell.observe(
    source: cancelApi.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  // Emit sequence with increasing specificity
  print('   [User] Searching for: \'a\'');
  await cancelInput.emitAsync('a');
  await Future.delayed(const Duration(milliseconds: 200));

  print('   [User] Searching for: \'ab\'');
  await cancelInput.emitAsync('ab');
  await Future.delayed(const Duration(milliseconds: 200));

  print('   [User] Searching for: \'abc\'');
  await cancelInput.emitAsync('abc');
  await Future.delayed(const Duration(milliseconds: 300));

  print('   [Result] Only the latest query result was emitted');
  print('   [Cancellation] Previous requests were automatically cancelled');

  await Future.delayed(const Duration(milliseconds: 100));
  cancelObserver.stop();
  print('');

  // ========================================================================
  // 4. Error Handling Demo
  // ========================================================================

  print('4. Error Handling Demo\n');

  final errorInput = Cell.ingress<String>();

  int errorCounter = 0;

  final errorDebounce = Flow.debounce<String>(
    errorInput.cell,
    duration: const Duration(milliseconds: 200),
  );

  final errorApi = Flow.asyncMapWithFallback<String, String>(
    errorDebounce.cell,
    mapper: (query) async {
      if (query == 'error') {
        errorCounter++;
        print('   [API] Simulating API call: $query (300ms) - WILL FAIL!');
        await Future.delayed(const Duration(milliseconds: 300));
        throw Exception('Simulated API failure');
      }
      await Future.delayed(const Duration(milliseconds: 100));
      return 'Success: $query';
    },
    fallback: 'Error occurred during search',
  );

  final errorObserver = Cell.observe(
    source: errorApi.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  print('   [User] Searching for: \'error\'');
  await errorInput.emitAsync('error');
  await Future.delayed(const Duration(milliseconds: 500));

  errorObserver.stop();
  print('');

  // ========================================================================
  // 5. Comprehensive Demo with Loading State
  // ========================================================================

  print('5. Comprehensive Demo with Loading State\n');

  final loadingInput = Cell.ingress<String>();

  // Create a loading state cell
  final loadingState = Cell.state<bool>(
    initial: false,
    evolve: (host, pulse) => Pulse(pulse.payload),
  );

  // Step 1: Debounce
  final loadDebounce = Flow.debounce<String>(
    loadingInput.cell,
    duration: const Duration(milliseconds: 200),
  );

  // Step 2: Set loading to true
  final loadTap = Flow.tap<String>(
    loadDebounce.cell,
    onValue: (_) => loadingState.update(true),
  );

  // Step 3: API call with asyncMapLatest
  final loadApi = Flow.asyncMapLatest<String, String>(
    loadTap.cell,
    mapper: (query) async {
      print('   [API] Fetching: $query');
      await Future.delayed(const Duration(milliseconds: 400));
      if (query.isEmpty) {
        throw Exception('Empty query not allowed');
      }
      return 'Result: $query';
    },
  );

  // Step 4: Set loading to false (on success or error)
  final loadResult = Flow.tap<String>(
    loadApi.cell,
    onValue: (_) => loadingState.update(false),
  );

  // Observers
  final resultObserver = Cell.observe(
    source: loadResult.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  final loadingObserver = Cell.observe(
    source: loadingState.cell,
    effect: (Pulse p) {
      final isLoading = p.payload;
      if (isLoading == true) {
        print('   [Loading] ...');
      }
    },
  );

  print('   [User] Searching for: \'loading demo\'');
  await loadingInput.emitAsync('loading demo');
  await Future.delayed(const Duration(milliseconds: 500));

  resultObserver.stop();
  loadingObserver.stop();
  print('');

  // ========================================================================
  // 6. Search with Validation Demo
  // ========================================================================

  print('6. Search with Validation (minimum length)\n');

  final validInput = Cell.ingress<String>();

  // Step 1: Debounce
  final validDebounce = Flow.debounce<String>(
    validInput.cell,
    duration: const Duration(milliseconds: 150),
  );

  // Step 2: Filter by minimum length (3 characters)
  final validFilter = Flow.filter<String>(
    validDebounce.cell,
    test: (query) => query.length >= 3,
  );

  // Step 3: API call
  final validApi = Flow.asyncMapLatest<String, String>(
    validFilter.cell,
    mapper: (query) async {
      print('   [API] Valid search: $query');
      await Future.delayed(const Duration(milliseconds: 200));
      return 'Valid result for: $query';
    },
  );

  // Step 4: Map to add a checkmark
  final validMapped = Flow.map<String, String>(
    validApi.cell,
    project: (result) => '✅ $result',
  );

  // Step 5: Tap to log validation pass
  final validResult = Flow.tap<String>(
    validMapped.cell,
    onValue: (result) => print('   [Validation] Passed: $result'),
  );

  final validObserver = Cell.observe(
    source: validResult.cell,
    effect: (Pulse p) => print('   [Result] ${p.payload}'),
  );

  print('   [User] Searching for: \'a\' (too short - should be ignored)');
  await validInput.emitAsync('a');
  await Future.delayed(const Duration(milliseconds: 200));

  print('   [User] Searching for: \'ab\' (too short - should be ignored)');
  await validInput.emitAsync('ab');
  await Future.delayed(const Duration(milliseconds: 200));

  print('   [User] Searching for: \'abc\' (valid - should process)');
  await validInput.emitAsync('abc');
  await Future.delayed(const Duration(milliseconds: 300));

  validObserver.stop();
  print('');

  // ========================================================================
  // 7. Debounce with Loading Indicator (Enhanced)
  // ========================================================================

  print('7. Debounce with Loading Indicator (Enhanced)\n');

  final enhancedInput = Cell.ingress<String>();

  // Track request count
  int requestCount = 0;

  // Step 1: Debounce
  final enhDebounce = Flow.debounce<String>(
    enhancedInput.cell,
    duration: const Duration(milliseconds: 250),
  );

  // Step 2: Tap to log with request count
  final enhTap = Flow.tap<String>(
    enhDebounce.cell,
    onValue: (query) {
      requestCount++;
      print('   [Debounce] Stabilized search #$requestCount: \'$query\'');
    },
  );

  // Step 3: API call with fallback
  final enhApi = Flow.asyncMapWithFallback<String, String>(
    enhTap.cell,
    mapper: (query) async {
      print('   [API] Processing: $query');
      await Future.delayed(const Duration(milliseconds: 300));
      if (query.contains('fail')) {
        throw Exception('Simulated failure');
      }
      return 'Results for "$query" (request #$requestCount)';
    },
    fallback: '⚠️ Search failed, please try again',
  );

  final enhancedObserver = Cell.observe(
    source: enhApi.cell,
    effect: (Pulse p) {
      final result = p.payload;
      if (result.toString().startsWith('⚠️')) {
        print('   [Result] ❌ $result');
      } else {
        print('   [Result] ✅ $result');
      }
    },
  );

  print('   [User] Searching for: \'hello\'');
  await enhancedInput.emitAsync('hello');
  await Future.delayed(const Duration(milliseconds: 300));

  print('   [User] Searching for: \'hello world\'');
  await enhancedInput.emitAsync('hello world');
  await Future.delayed(const Duration(milliseconds: 300));

  print('   [User] Searching for: \'fail test\' (triggers error)');
  await enhancedInput.emitAsync('fail test');
  await Future.delayed(const Duration(milliseconds: 400));

  enhancedObserver.stop();
  print('');

  // ========================================================================
  // 8. Debounce vs Throttle Comparison
  // ========================================================================

  print('8. Debounce vs Throttle Comparison\n');

  final compareInput = Cell.ingress<String>();

  // Debounce: waits for silence
  final debounceCompare = Flow.debounce<String>(
    compareInput.cell,
    duration: const Duration(milliseconds: 100),
  );

  final debounceResult = Flow.map<String, String>(
    debounceCompare.cell,
    project: (value) => '[Debounce] $value',
  );

  // Throttle: limits rate (emits immediately, then at intervals)
  final throttleCompare = Flow.throttle<String>(
    compareInput.cell,
    duration: const Duration(milliseconds: 100),
    leading: true,
  );

  final throttleResult = Flow.map<String, String>(
    throttleCompare.cell,
    project: (value) => '[Throttle] $value',
  );

  final dObs = Cell.observe(
    source: debounceResult.cell,
    effect: (Pulse p) => print('   ${p.payload}'),
  );
  final tObs = Cell.observe(
    source: throttleResult.cell,
    effect: (Pulse p) => print('   ${p.payload}'),
  );

  print('   Rapid emissions: A, B, C, D, E');
  for (final char in ['A', 'B', 'C', 'D', 'E']) {
    await compareInput.emitAsync(char);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 150));

  dObs.stop();
  tObs.stop();
  print('');

  print('── Finished ──────────────────────────────────────────────────────────');
}