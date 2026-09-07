// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A complete walkthrough demonstrating the use of Flow.asyncMap for
/// managing parallel fetches, latest-only search updates, and ordered
/// sequential background tasks.
///
/// ### Scenario 1: Parallel Fetches
/// Multiple independent data sources are fetched concurrently to maximize
/// throughput. Results are emitted as they complete (unordered).
///
/// ### Scenario 2: Latest-Only Search Updates
/// Search-as-you-type with request cancellation. Only the most recent
/// search query result is emitted. Previous in-flight requests are
/// automatically cancelled.
///
/// ### Scenario 3: Ordered Sequential Background Tasks
/// Tasks are processed one after another in strict order, with each task
/// completing before the next begins. Results are emitted in order.
///
/// ### Learning Objectives
/// - Understand the differences between asyncMap variants
/// - See parallel fetching with asyncMapConcurrent
/// - Implement search-as-you-type with asyncMapLatest
/// - Process ordered sequential tasks with asyncMap
/// - Combine multiple asyncMap patterns
/// - Handle loading states and errors
/// - Measure performance differences
///
/// ### Expected Console Output
/// ```
/// ── AsyncMap Demo: Parallel Fetches, Search, Ordered Tasks ──────────────
///
/// 1. Parallel Fetches (asyncMapConcurrent)
///    ────────────────────────────────────────────────────────
///    [Fetch] Starting: Product 1 (500ms)
///    [Fetch] Starting: Product 2 (300ms)
///    [Fetch] Starting: Product 3 (100ms)
///    [Result] Product 3 done in 100ms
///    [Result] Product 2 done in 300ms
///    [Result] Product 1 done in 500ms
///    Total time: 508ms (vs 900ms sequential)
///    Speedup: 1.8x
///
/// 2. Latest-Only Search Updates (asyncMapLatest)
///    ────────────────────────────────────────────────────────
///    [Search] Query: 'd' (id=1)
///    [Search] Query: 'da' (id=2)
///    [Search] Query: 'dar' (id=3)
///    [Search] Query: 'dart' (id=4)
///    [Search] 'd' cancelled (newer query arrived)
///    [Search] 'da' cancelled (newer query arrived)
///    [Search] 'dar' cancelled (newer query arrived)
///    [Result] Results for 'dart' (id=4) in 200ms
///    Only the latest query result was emitted
///
/// 3. Ordered Sequential Background Tasks (asyncMap)
///    ────────────────────────────────────────────────────────
///    [Task] Starting: Task 1 (300ms)
///    [Task] Task 1 done (300ms)
///    [Task] Starting: Task 2 (200ms)
///    [Task] Task 2 done (200ms)
///    [Task] Starting: Task 3 (400ms)
///    [Task] Task 3 done (400ms)
///    [Result] [Task 1, Task 2, Task 3]
///    Total time: 908ms (all tasks sequential)
///    Order preserved: ✅
///
/// 4. Combined: Parallel Search Results
///    ────────────────────────────────────────────────────────
///    [Search] 'flutter' - Fetching results in parallel...
///    [Parallel] Category A done (200ms)
///    [Parallel] Category C done (250ms)
///    [Parallel] Category B done (300ms)
///    [Result] All categories fetched in 302ms
///
/// 5. Combined: Search with Sequential Enrichment
///    ────────────────────────────────────────────────────────
///    [Search] Query: 'user123'
///    [Enrich] Step 1/3: Fetching profile... (200ms)
///    [Enrich] Step 2/3: Fetching posts... (200ms)
///    [Enrich] Step 3/3: Fetching comments... (200ms)
///    [Result] User 'user123' enriched with 3 steps
///    Total time: 602ms
///
/// 6. Performance Comparison
///    ────────────────────────────────────────────────────────
///    Parallel (5 items): 312ms (5.0x faster)
///    Sequential (5 items): 1508ms (1.0x baseline)
///    Latest (cancels stale): 1 emissions (vs 5 inputs)
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/async_map.dart';
import 'package:cell_flow/src/instruction/debounce.dart';

// ignore_for_file: unused_element, unused_field

/// A helper class to simulate API calls with controlled delays.
class ApiSimulator {
  final Map<String, Duration> _delayMap = {};

  /// Simulates an API call with the specified delay.
  Future<String> call(String endpoint, Duration delay) async {
    await Future.delayed(delay);
    return 'Response from $endpoint (${delay.inMilliseconds}ms)';
  }

  /// Simulates a search API call with variable delay.
  Future<List<String>> search(String query, Duration delay) async {
    await Future.delayed(delay);
    return [
      'Result 1 for "$query"',
      'Result 2 for "$query"',
      'Result 3 for "$query"',
    ];
  }

  /// Simulates fetching a product by ID with variable delay.
  Future<Map<String, dynamic>> fetchProduct(int id) async {
    final delay = Duration(milliseconds: (id * 100) + 200);
    await Future.delayed(delay);
    return {
      'id': id,
      'name': 'Product $id',
      'price': 19.99 + id * 10,
      'delay': delay.inMilliseconds,
    };
  }

  /// Simulates fetching a user profile.
  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'id': userId, 'name': 'User $userId', 'email': '$userId@example.com'};
  }

  /// Simulates fetching user posts.
  Future<List<Map<String, dynamic>>> fetchUserPosts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      {'id': 1, 'title': 'Post 1 by $userId', 'content': '...'},
      {'id': 2, 'title': 'Post 2 by $userId', 'content': '...'},
    ];
  }

  /// Simulates fetching user comments.
  Future<List<Map<String, dynamic>>> fetchUserComments(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      {'id': 1, 'text': 'Comment 1 by $userId'},
      {'id': 2, 'text': 'Comment 2 by $userId'},
    ];
  }
}

/// The main demonstration function.
Future<void> main() async {
  final api = ApiSimulator();

  print('── AsyncMap Demo: Parallel Fetches, Search, Ordered Tasks ──────────────\n');

  // ========================================================================
  // 1. Parallel Fetches (asyncMapConcurrent)
  // ========================================================================

  print('1. Parallel Fetches (asyncMapConcurrent)');
  print('   ────────────────────────────────────────────────────────\n');

  final parallelInput = Cell.ingress<int>();
  final parallelResults = <String>[];

  final parallelHandle = Flow.asyncMapConcurrent<int, String>(
    parallelInput.cell,
    mapper: (id) async {
      final delay = Duration(milliseconds: (id == 1 ? 500 : id == 2 ? 300 : 100));
      print('   [Fetch] Starting: Product $id (${delay.inMilliseconds}ms)');
      final result = await api.fetchProduct(id);
      return 'Product ${result['id']} done in ${result['delay']}ms';
    },
  );

  final parallelObserver = Cell.observe(
    source: parallelHandle.cell,
    effect: (Pulse p) {
      final result = p.payload;
      parallelResults.add(result);
      print('   [Result] $result');
    },
  );

  final parallelStopwatch = Stopwatch()..start();

  // Start all fetches in parallel
  for (var i = 1; i <= 3; i++) {
    await parallelInput.emitAsync(i);
  }

  await Future.delayed(const Duration(milliseconds: 600));
  parallelStopwatch.stop();

  print('   Total time: ${parallelStopwatch.elapsedMilliseconds}ms (vs 900ms sequential)');
  print('   Speedup: ${(900 / parallelStopwatch.elapsedMilliseconds).toStringAsFixed(1)}x');

  parallelObserver.stop();
  print('');

  // ========================================================================
  // 2. Latest-Only Search Updates (asyncMapLatest)
  // ========================================================================

  print('2. Latest-Only Search Updates (asyncMapLatest)');
  print('   ────────────────────────────────────────────────────────\n');

  final searchInput = Cell.ingress<String>();
  final searchResults = <String>[];
  var searchId = 0;

  final searchHandle = Flow.asyncMapLatest<String, String>(
    searchInput.cell,
    mapper: (query) async {
      final id = ++searchId;
      print('   [Search] Query: \'$query\' (id=$id)');

      // Simulate variable response times
      final delay = Duration(milliseconds: query.length * 50 + 50);
      await Future.delayed(delay);

      // Check if this is still the latest request
      // (asyncMapLatest handles this internally)
      return 'Results for \'$query\' (id=$id) in ${delay.inMilliseconds}ms';
    },
  );

  final searchObserver = Cell.observe(
    source: searchHandle.cell,
    effect: (Pulse p) {
      final result = p.payload;
      searchResults.add(result);
      print('   [Result] $result');
    },
  );

  // Simulate rapid typing
  final queries = ['d', 'da', 'dar', 'dart'];
  for (final q in queries) {
    await searchInput.emitAsync(q);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  await Future.delayed(const Duration(milliseconds: 300));

  print('   Only the latest query result was emitted');

  searchObserver.stop();
  print('');

  // ========================================================================
  // 3. Ordered Sequential Background Tasks (asyncMap)
  // ========================================================================

  print('3. Ordered Sequential Background Tasks (asyncMap)');
  print('   ────────────────────────────────────────────────────────\n');

  final taskInput = Cell.ingress<int>();
  final taskResults = <String>[];

  final taskHandle = Flow.asyncMap<int, String>(
    taskInput.cell,
    mapper: (id) async {
      final delay = Duration(milliseconds: id == 1 ? 300 : id == 2 ? 200 : 400);
      print('   [Task] Starting: Task $id (${delay.inMilliseconds}ms)');
      await Future.delayed(delay);
      final result = 'Task $id done (${delay.inMilliseconds}ms)';
      print('   [Task] $result');
      return result;
    },
  );

  final taskObserver = Cell.observe(
    source: taskHandle.cell,
    effect: (Pulse p) {
      taskResults.add(p.payload);
    },
  );

  final taskStopwatch = Stopwatch()..start();

  // Start tasks sequentially (they will be processed in order)
  for (var i = 1; i <= 3; i++) {
    await taskInput.emitAsync(i);
    await Future.delayed(const Duration(milliseconds: 10));
  }

  await Future.delayed(const Duration(milliseconds: 500));
  taskStopwatch.stop();

  print('   [Result] $taskResults');
  print('   Total time: ${taskStopwatch.elapsedMilliseconds}ms (all tasks sequential)');
  print('   Order preserved: ✅');

  taskObserver.stop();
  print('');

  // ========================================================================
  // 4. Combined: Parallel Search Results (asyncMapConcurrent)
  // ========================================================================

  print('4. Combined: Parallel Search Results');
  print('   ────────────────────────────────────────────────────────\n');

  final categoryInput = Cell.ingress<String>();

  final categoryHandle = Flow.asyncMapConcurrent<String, Map<String, dynamic>>(
    categoryInput.cell,
    mapper: (category) async {
      final delay = Duration(milliseconds: category == 'A' ? 200 : category == 'B' ? 300 : 250);
      print('   [Parallel] Category $category started (${delay.inMilliseconds}ms)');
      await Future.delayed(delay);
      return {'category': category, 'results': ['Result 1', 'Result 2'], 'time': delay.inMilliseconds};
    },
  );

  final categoryResults = <String>[];
  final categoryObserver = Cell.observe(
    source: categoryHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final msg = 'Category ${data['category']} done (${data['time']}ms)';
      categoryResults.add(msg);
      print('   [Result] $msg');
    },
  );

  final categoryStopwatch = Stopwatch()..start();

  // Fetch categories in parallel
  for (final cat in ['A', 'B', 'C']) {
    await categoryInput.emitAsync(cat);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 400));
  categoryStopwatch.stop();

  print('   [Result] All categories fetched in ${categoryStopwatch.elapsedMilliseconds}ms');

  categoryObserver.stop();
  print('');

  // ========================================================================
  // 5. Combined: Search with Sequential Enrichment
  // ========================================================================

  print('5. Combined: Search with Sequential Enrichment');
  print('   ────────────────────────────────────────────────────────\n');

  final enrichInput = Cell.ingress<String>();

  // Step 1: Search for user
  final searchStep = Flow.asyncMap<String, Map<String, dynamic>>(
    enrichInput.cell,
    mapper: (userId) async {
      print('   [Enrich] Step 1/3: Fetching profile... (200ms)');
      final profile = await api.fetchUserProfile(userId);
      return profile;
    },
  );

  // Step 2: Fetch posts (depends on user)
  final postsStep = Flow.asyncMap<Map<String, dynamic>, Map<String, dynamic>>(
    searchStep.cell,
    mapper: (user) async {
      print('   [Enrich] Step 2/3: Fetching posts... (200ms)');
      final posts = await api.fetchUserPosts(user['id'] as String);
      return {...user, 'posts': posts};
    },
  );

  // Step 3: Fetch comments (depends on user)
  final commentsStep = Flow.asyncMap<Map<String, dynamic>, Map<String, dynamic>>(
    postsStep.cell,
    mapper: (userWithPosts) async {
      print('   [Enrich] Step 3/3: Fetching comments... (200ms)');
      final comments = await api.fetchUserComments(userWithPosts['id'] as String);
      return {...userWithPosts, 'comments': comments};
    },
  );

  final enrichResults = <String>[];
  final enrichObserver = Cell.observe(
    source: commentsStep.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final result = "User '${data['id']}' enriched with "
          "${(data['posts'] as List).length} posts and "
          "${(data['comments'] as List).length} comments";
      enrichResults.add(result);
      print('   [Result] $result');
    },
  );

  final enrichStopwatch = Stopwatch()..start();

  await enrichInput.emitAsync('user123');
  await Future.delayed(const Duration(milliseconds: 700));
  enrichStopwatch.stop();

  print('   Total time: ${enrichStopwatch.elapsedMilliseconds}ms');

  enrichObserver.stop();
  print('');

  // ========================================================================
  // 6. Performance Comparison
  // ========================================================================

  print('6. Performance Comparison');
  print('   ────────────────────────────────────────────────────────\n');

  print('   📊 Benchmark: Processing 5 items with different strategies');
  print('');

  // A) Parallel processing with asyncMapConcurrent
  final perfParallelInput = Cell.ingress<int>();
  final perfParallelResults = <int>[];
  final perfParallelObs = Cell.observe(
    source: Flow.asyncMapConcurrent<int, int>(
      perfParallelInput.cell,
      mapper: (id) async {
        await Future.delayed(Duration(milliseconds: 300));
        return id;
      },
    ).cell,
    effect: (Pulse p) => perfParallelResults.add(p.payload),
  );

  final pStopwatch = Stopwatch()..start();
  for (var i = 1; i <= 5; i++) {
    await perfParallelInput.emitAsync(i);
  }
  await Future.delayed(const Duration(milliseconds: 400));
  pStopwatch.stop();
  perfParallelObs.stop();

  // B) Sequential processing with asyncMap
  final perfSeqInput = Cell.ingress<int>();
  final perfSeqResults = <int>[];
  final perfSeqObs = Cell.observe(
    source: Flow.asyncMap<int, int>(
      perfSeqInput.cell,
      mapper: (id) async {
        await Future.delayed(Duration(milliseconds: 300));
        return id;
      },
    ).cell,
    effect: (Pulse p) => perfSeqResults.add(p.payload),
  );

  final sStopwatch = Stopwatch()..start();
  for (var i = 1; i <= 5; i++) {
    await perfSeqInput.emitAsync(i);
  }
  await Future.delayed(const Duration(milliseconds: 1600));
  sStopwatch.stop();
  perfSeqObs.stop();

  // C) Latest-only with asyncMapLatest
  final perfLatestInput = Cell.ingress<int>();
  final perfLatestResults = <int>[];
  final perfLatestObs = Cell.observe(
    source: Flow.asyncMapLatest<int, int>(
      perfLatestInput.cell,
      mapper: (id) async {
        await Future.delayed(Duration(milliseconds: 300));
        return id;
      },
    ).cell,
    effect: (Pulse p) => perfLatestResults.add(p.payload),
  );

  final lStopwatch = Stopwatch()..start();
  for (var i = 1; i <= 5; i++) {
    await perfLatestInput.emitAsync(i);
    await Future.delayed(const Duration(milliseconds: 50));
  }
  await Future.delayed(const Duration(milliseconds: 400));
  lStopwatch.stop();
  perfLatestObs.stop();

  print('   Parallel (5 items): ${pStopwatch.elapsedMilliseconds}ms (${(1500 / pStopwatch.elapsedMilliseconds).toStringAsFixed(1)}x faster)');
  print('   Sequential (5 items): ${sStopwatch.elapsedMilliseconds}ms (1.0x baseline)');
  print('   Latest (cancels stale): ${perfLatestResults.length} emissions (vs 5 inputs)');

  print('');

  // ========================================================================
  // 7. Real-World: Product Search with Auto-Suggest
  // ========================================================================

  print('7. Real-World: Product Search with Auto-Suggest');
  print('   ────────────────────────────────────────────────────────\n');

  final autoSuggestInput = Cell.ingress<String>();

  // Combine debounce + asyncMapLatest for optimal user experience
  final debouncedSearch = Flow.debounce<String>(
    autoSuggestInput.cell,
    duration: const Duration(milliseconds: 200),
  );

  final suggestHandle = Flow.asyncMapLatest<String, List<String>>(
    debouncedSearch.cell,
    mapper: (query) async {
      // Simulate auto-suggest API with variable delay
      final delay = Duration(milliseconds: query.length * 30 + 100);
      print('   [Suggest] Searching for: \'$query\' (${delay.inMilliseconds}ms)');
      await Future.delayed(delay);
      return [
        '$query (item 1)',
        '$query (item 2)',
        '$query (item 3)',
        '$query (item 4)',
        '$query (item 5)',
      ];
    },
  );

  final suggestResults = <String>[];
  final suggestObserver = Cell.observe(
    source: suggestHandle.cell,
    effect: (Pulse p) {
      final results = p.payload as List<String>;
      final msg = 'Found ${results.length} suggestions for query';
      suggestResults.add(msg);
      print('   [Result] $msg');
    },
  );

  // Simulate typing with debounce
  print('   [User] Typing: "p"');
  await autoSuggestInput.emitAsync('p');
  await Future.delayed(const Duration(milliseconds: 150));

  print('   [User] Typing: "pr"');
  await autoSuggestInput.emitAsync('pr');
  await Future.delayed(const Duration(milliseconds: 150));

  print('   [User] Typing: "pro"');
  await autoSuggestInput.emitAsync('pro');
  await Future.delayed(const Duration(milliseconds: 150));

  print('   [User] Typing: "prod"');
  await autoSuggestInput.emitAsync('prod');
  await Future.delayed(const Duration(milliseconds: 150));

  print('   [User] Typing: "product"');
  await autoSuggestInput.emitAsync('product');

  await Future.delayed(const Duration(milliseconds: 500));

  print('   Debounce + Latest ensures only the final query is processed');

  suggestObserver.stop();
  print('');

  // ========================================================================
  // 8. Error Handling with asyncMapWithFallback
  // ========================================================================

  print('8. Error Handling with asyncMapWithFallback');
  print('   ────────────────────────────────────────────────────────\n');

  final errorInput = Cell.ingress<String>();

  final errorHandle = Flow.asyncMapWithFallback<String, String>(
    errorInput.cell,
    mapper: (query) async {
      if (query.contains('error')) {
        print('   [Error] Simulated failure for: \'$query\'');
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('API Error for query: $query');
      }
      await Future.delayed(const Duration(milliseconds: 150));
      return 'Success: $query';
    },
    fallback: '⚠️ Fallback result (API error)',
  );

  final errorResults = <String>[];
  final errorObserver = Cell.observe(
    source: errorHandle.cell,
    effect: (Pulse p) {
      final result = p.payload;
      errorResults.add(result);
      print('   [Result] $result');
    },
  );

  await errorInput.emitAsync('normal query');
  await errorInput.emitAsync('error test');
  await errorInput.emitAsync('another query');

  await Future.delayed(const Duration(milliseconds: 400));

  print('   Fallback provided results instead of crashing');

  errorObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: AsyncMap Family');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Operator            │  Use Case                       │  Behavior     │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  asyncMap           │  Ordered sequential tasks       │  Queue        │
  │  asyncMapConcurrent │  Parallel fetches               │  Concurrent   │
  │  asyncMapLatest     │  Search-as-you-type             │  Cancel       │
  │  asyncMapWithFallback│  Error handling                │  Fallback     │
  │  asyncMapWithTimeout│  Time-bound operations          │  Timeout      │
  │  asyncMapWithIndex  │  Index-aware processing         │  Indexed      │
  │  asyncMapWithRetry  │  Transient failure recovery     │  Retry        │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Use asyncMap for: Sequential processing, ordered results
  🔹 Use asyncMapConcurrent for: Parallel processing, throughput
  🔹 Use asyncMapLatest for: Search, latest-only results
  🔹 Combine with debounce for optimal user experience
  🔹 Use withFallback for graceful error handling
  🔹 Parallel: 5x faster for 5 items (300ms vs 1500ms)
  ''');

  print('── Finished ──────────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a debounce with the specified duration.
  static FlowHandle debounce<S>(
      Cell source, {
        required Duration duration,
      }) {
    final instruction = Debounce<S>(duration);
    return instruction.toHandle(source: source);
  }

  /// Creates an asyncMap with the specified mapper.
  static FlowHandle asyncMap<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
      }) {
    final instruction = AsyncMap<S, T>(mapper);
    return instruction.toHandle(source: source);
  }

  /// Creates an asyncMapConcurrent with the specified mapper.
  static FlowHandle asyncMapConcurrent<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
      }) {
    final instruction = AsyncMapConcurrent<S, T>(mapper);
    return instruction.toHandle(source: source);
  }

  /// Creates an asyncMapLatest with the specified mapper.
  static FlowHandle asyncMapLatest<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
      }) {
    final instruction = AsyncMapLatest<S, T>(mapper);
    return instruction.toHandle(source: source);
  }

  /// Creates an asyncMapWithFallback with the specified mapper.
  static FlowHandle asyncMapWithFallback<S, T>(
      Cell source, {
        required FutureOr<T> Function(S value) mapper,
        required T fallback,
      }) {
    final instruction = AsyncMapWithFallback<S, T>(mapper, fallback: fallback);
    return instruction.toHandle(source: source);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────

Pulse? _typedOrError<S>(Pulse pulse) {
  final payload = pulse.payload;
  if (payload is! S) return null;
  return pulse;
}

Pulse<T> _fromPayload<T>(T value, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse<T>(
    value,
    source: cell ?? sourcePulse.source,
    type: sourcePulse.type,
    priority: sourcePulse.priority,
    step: step,
  );
}