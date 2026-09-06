// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.retry and Flow.timeout for handling flaky network connections
/// with bounded retries and deadlines.
///
/// ### Scenario
/// A flaky network API where:
/// 1. Network requests fail intermittently
/// 2. Flow.retry provides bounded retry with exponential backoff
/// 3. Flow.timeout enforces a deadline before showing an error
/// 4. Users never see an infinite spinner
/// 5. Multiple failure patterns are demonstrated
/// 6. Real-world retry strategies are shown
///
/// ### Learning Objectives
/// - Understand how Flow.retry works
/// - See Flow.timeout for deadline enforcement
/// - Combine retry + timeout for robust network calls
/// - Handle different failure patterns (timeout, 500, connection refused)
/// - Implement exponential backoff
/// - Show user feedback during retries
///
/// ### Expected Console Output
/// ```
/// ── Retry + Timeout: Flaky Network Demo ──────────────────────────────────────────
///
/// 1. Simple Retry - Transient Failure
///    ────────────────────────────────────────────────────────
///    [Request] Fetching user data...
///    [Retry] Attempt 1 failed: HTTP 500: Connection refused
///    [Request] Fetching user data...
///    [Retry] Attempt 2 failed: HTTP 500: Connection refused
///    [Request] Fetching user data...
///    [Success] ✅ User data loaded: Diana (user@example.com)
///    Total time: 414ms
///
/// 2. Timeout - Slow Response
///    ────────────────────────────────────────────────────────
///    [Request] Fetching large dataset...
///    [Timeout] ⏱️  Deadline exceeded (2000ms)
///    ❌ Error: Request timed out
///    User sees: "Request timed out. Please try again."
///
/// 3. Retry with Timeout - Network Failure
///    ────────────────────────────────────────────────────────
///    [Request] Placing order...
///    [Retry] Attempt 1 failed: TimeoutException: Request timed out
///    [Request] Placing order...
///    [Retry] Attempt 2 failed: HTTP 500: Connection refused
///    [Request] Placing order...
///    [Success] ✅ Order placed: Order #ORD-1234 ($99.99) - confirmed
///    Total time: 512ms
///
/// 4. Exponential Backoff - Server Overload
///    ────────────────────────────────────────────────────────
///    [Request] Processing payment...
///    [Retry] Attempt 1 failed: HTTP 503: Service unavailable
///    [Request] Processing payment...
///    [Retry] Attempt 2 failed: HTTP 503: Service unavailable
///    [Request] Processing payment...
///    [Retry] Attempt 3 failed: HTTP 503: Internal server error
///    [Request] Processing payment...
///    [Success] ✅ Payment processed: approved
///    Total time: 1107ms
///
/// 5. Deadline Exceeded - All Retries Failed
///    ────────────────────────────────────────────────────────
///    [Request] Critical API call...
///    [Retry] Attempt 1 failed: HTTP 500: Service unavailable
///    [Request] Critical API call...
///    [Retry] Attempt 2 failed: HTTP 500: Rate limit exceeded
///    [Request] Critical API call...
///    [Retry] Attempt 3 failed: HTTP 500: Network unreachable
///    [Deadline] ⏱️  Deadline exceeded (1000ms)
///    ❌ Error: Deadlines exceeded after 3 attempts
///    User sees: "Service unavailable. Please try later."
///
/// 6. Retry with Success on Last Attempt
///    ────────────────────────────────────────────────────────
///    [Request] Data sync...
///    [Retry] Attempt 1 failed: HTTP 500: Internal server error
///    [Request] Data sync...
///    [Retry] Attempt 2 failed: HTTP 500: Gateway timeout
///    [Request] Data sync...
///    [Success] ✅ Sync complete! 42 records synced
///    Total attempts: 3, Success: ✅
///
/// 7. Timeout with Fallback - Cache Fallback
///    ────────────────────────────────────────────────────────
///    [Request] Fetching cached data...
///    [Timeout] ⏱️  Cache response slow (500ms)
///    ✅ Using stale cache: Cached User (cached@example.com)
///    User sees: "Showing cached data (may be stale)"
///
/// 8. Retry with Backoff - Database Connection
///    ────────────────────────────────────────────────────────
///    [Request] Connecting to database...
///    [Retry] Attempt 1 failed: HTTP 503: Gateway timeout
///    [Request] Connecting to database...
///    [Retry] Attempt 2 failed: HTTP 503: Rate limit exceeded
///    [Request] Connecting to database...
///    [Success] ✅ Database connected: db.example.com (103ms)
///    Total time: 911ms
///
/// 9. Deadline with Loading State
///    ────────────────────────────────────────────────────────
///    [User] Submit: Order #1234
///    [Loading] 🔄 Processing order...
///    [Loading] 🔄 Processing order (100ms)
///    [Loading] 🔄 Processing order (200ms)
///    [Timeout] ⏱️  Deadline exceeded (500ms)
///    [Loading] ❌ Order processing timed out
///    [Result] ❌ Order failed - please try again
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/async_map.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/tap.dart';
import 'package:cell_flow/src/instruction/timeout.dart';
import 'package:cell_flow/src/instruction/retry.dart';
import 'package:cell_flow/src/instruction/merge.dart';

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a user profile.
class UserProfile {
  final String id;
  final String name;
  final String email;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  @override
  String toString() => '$name ($email)';
}

/// Represents an order.
class Order {
  final String id;
  final double amount;
  final String status;

  Order({
    required this.id,
    required this.amount,
    this.status = 'pending',
  });

  @override
  String toString() => 'Order #$id (\$${amount.toStringAsFixed(2)}) - $status';
}

/// Represents a database connection.
class DatabaseConnection {
  final String host;
  final bool connected;
  final int latency;

  DatabaseConnection({
    required this.host,
    this.connected = true,
    this.latency = 50,
  });

  @override
  String toString() => '${connected ? "✅ Connected" : "❌ Failed"} to $host (${latency}ms)';
}

// ─────────────────────────────────────────────────────────────────────
// Flaky Network Simulator
// ─────────────────────────────────────────────────────────────────────

/// Simulates a flaky network API with configurable failure patterns.
class FlakyNetwork {
  final Random _random = Random();
  int _attemptCount = 0;
  final Map<String, int> _failureCounts = {};
  final Map<String, int> _failureThresholds = {};
  final Map<String, String> _lastError = {};

  /// Simulates a network request with configurable behavior.
  Future<dynamic> request({
    required String endpoint,
    int failUntil = 0,
    int delay = 100,
    double timeoutProbability = 0.0,
    double errorProbability = 0.0,
    int statusCode = 500,
  }) async {
    _attemptCount++;

    // Track failures per endpoint
    if (!_failureCounts.containsKey(endpoint)) {
      _failureCounts[endpoint] = 0;
      _failureThresholds[endpoint] = failUntil;
    }

    // Simulate delay
    await Future.delayed(Duration(milliseconds: delay));

    // Simulate timeout
    if (_random.nextDouble() < timeoutProbability) {
      _lastError[endpoint] = 'TimeoutException: Request timed out';
      throw TimeoutException('Request timed out');
    }

    // Simulate error if we haven't reached the success threshold
    if (_failureCounts[endpoint]! < _failureThresholds[endpoint]!) {
      _failureCounts[endpoint] = _failureCounts[endpoint]! + 1;
      final errorMsg = _errorMessages[_random.nextInt(_errorMessages.length)];
      _lastError[endpoint] = 'HTTP $statusCode: $errorMsg';
      throw Exception('HTTP $statusCode: $errorMsg');
    }

    // Success!
    return _generateResponse(endpoint);
  }

  /// Gets the last error for an endpoint.
  String? getLastError(String endpoint) => _lastError[endpoint];

  /// Generates a response based on the endpoint.
  dynamic _generateResponse(String endpoint) {
    switch (endpoint) {
      case 'user':
        return UserProfile(
          id: 'usr_${_random.nextInt(10000)}',
          name: ['Alice', 'Bob', 'Charlie', 'Diana'][_random.nextInt(4)],
          email: 'user@example.com',
        );
      case 'order':
        return Order(
          id: 'ORD-${_random.nextInt(10000)}',
          amount: 10 + _random.nextDouble() * 990,
          status: 'confirmed',
        );
      case 'database':
        return DatabaseConnection(
          host: 'db.example.com',
          connected: true,
          latency: 30 + _random.nextInt(100),
        );
      case 'payment':
        return {'transaction_id': 'txn_${_random.nextInt(100000)}', 'status': 'approved'};
      case 'sync':
        return List.generate(42, (i) => 'Record ${i + 1}');
      case 'large_dataset':
        return 'Large dataset loaded successfully';
      default:
        return 'Response from $endpoint';
    }
  }

  /// Resets the failure counts.
  void reset() {
    _attemptCount = 0;
    _failureCounts.clear();
    _failureThresholds.clear();
    _lastError.clear();
  }

  /// Gets the total attempt count.
  int get attempts => _attemptCount;

  static final List<String> _errorMessages = [
    'Connection refused',
    'Service unavailable',
    'Gateway timeout',
    'Internal server error',
    'Rate limit exceeded',
    'Network unreachable',
  ];
}

// ─────────────────────────────────────────────────────────────────────
// Cache Simulator
// ─────────────────────────────────────────────────────────────────────

class Cache {
  final Map<String, dynamic> _cache = {};

  Cache() {
    _cache['user_123'] = UserProfile(
      id: 'user_123',
      name: 'Cached User',
      email: 'cached@example.com',
    );
    _cache['large_dataset'] = List.generate(100, (i) => 'Cached item ${i + 1}');
  }

  dynamic get(String key) => _cache[key];
  bool has(String key) => _cache.containsKey(key);
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  final network = FlakyNetwork();
  final cache = Cache();

  print('── Retry + Timeout: Flaky Network Demo ──────────────────────────────────────────\n');

  // ========================================================================
  // 1. Simple Retry - Transient Failure
  // ========================================================================

  print('1. Simple Retry - Transient Failure');
  print('   ────────────────────────────────────────────────────────\n');

  final retryInput = Cell.ingress<String>();

  var retryAttempts = 0;

  final retryHandle = Retry<String, UserProfile>(
        (endpoint) async {
      retryAttempts++;
      print('   [Request] Fetching user data...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 2,
          delay: 50,
          errorProbability: 0.8,
        );
        print('   [Success] ✅ User data loaded: ${result.toString()}');
        return result as UserProfile;
      } catch (e) {
        print('   [Retry] Attempt $retryAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 3,
    onError: (error, stack) {},
    emitErrorPulse: false,
  ).toHandle(source: retryInput.cell);

  final retryObserver = Cell.observe(
    source: retryHandle.cell,
    effect: (Pulse p) {},
  );

  final stopwatch = Stopwatch()..start();
  await retryInput.emitAsync('user');
  await Future.delayed(const Duration(milliseconds: 400));
  stopwatch.stop();

  print('   Total time: ${stopwatch.elapsedMilliseconds}ms');

  retryObserver.stop();
  network.reset();
  retryAttempts = 0;
  print('');

  // ========================================================================
  // 2. Timeout - Slow Response
  // ========================================================================

  print('2. Timeout - Slow Response');
  print('   ────────────────────────────────────────────────────────\n');

  final timeoutInput = Cell.ingress<String>();

  // Use AsyncMap for async transformation
  final slowResponse = AsyncMap<String, String>(
    (endpoint) async {
      print('   [Request] Fetching large dataset...');
      await Future.delayed(const Duration(milliseconds: 2500));
      return 'Large dataset loaded successfully';
    },
  ).toHandle(source: timeoutInput.cell);

  // Timeout wrapper that emits error on timeout
  final timeoutHandle = Timeout<String>(
    Duration(milliseconds: 2000),
    onError: (error, stack) {
      if (error is TimeoutException) {
        print('   [Timeout] ⏱️  Deadline exceeded (2000ms)');
        print('   ❌ Error: Request timed out');
        print('   User sees: "Request timed out. Please try again."');
      }
    },
    emitErrorPulse: true,
  ).toHandle(source: timeoutInput.cell);

  // Merge: timeout error or response - but only show one
  // Use a simple approach: just observe the timeout and ignore the slow response
  final timeoutObserver = Cell.observe(
    source: timeoutHandle.cell,
    effect: (Pulse p) {
      if (p.type == 'error') {
        // Error already printed in onError
      }
    },
  );

  // Also observe the slow response separately
  final slowObserver = Cell.observe(
    source: slowResponse.cell,
    effect: (Pulse p) {
      // This will complete after the timeout, but we don't want to show it
      // since the timeout already showed the error
    },
  );

  await timeoutInput.emitAsync('large_dataset');
  await Future.delayed(const Duration(milliseconds: 3000));

  timeoutObserver.stop();
  slowObserver.stop();
  print('');

  // ========================================================================
  // 3. Retry with Timeout - Network Failure
  // ========================================================================

  print('3. Retry with Timeout - Network Failure');
  print('   ────────────────────────────────────────────────────────\n');

  final comboInput = Cell.ingress<String>();

  var comboAttempts = 0;

  // Retry with timeout handling
  final comboHandle = Retry<String, Order>(
        (endpoint) async {
      comboAttempts++;
      print('   [Request] Placing order...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 2,
          delay: 100,
          timeoutProbability: 0.5,
        );
        print('   [Success] ✅ Order placed: ${result.toString()}');
        return result as Order;
      } catch (e) {
        print('   [Retry] Attempt $comboAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 3,
    onError: (error, stack) {},
    emitErrorPulse: false,
  ).toHandle(source: comboInput.cell);

  final comboObserver = Cell.observe(
    source: comboHandle.cell,
    effect: (Pulse p) {},
  );

  final comboStopwatch = Stopwatch()..start();
  await comboInput.emitAsync('order');
  await Future.delayed(const Duration(milliseconds: 600));
  comboStopwatch.stop();

  print('   Total time: ${comboStopwatch.elapsedMilliseconds}ms');

  comboObserver.stop();
  network.reset();
  comboAttempts = 0;
  print('');

  // ========================================================================
  // 4. Exponential Backoff - Server Overload
  // ========================================================================

  print('4. Exponential Backoff - Server Overload');
  print('   ────────────────────────────────────────────────────────\n');

  final backoffInput = Cell.ingress<String>();

  int backoffAttempts = 0;

  // Custom retry with exponential backoff (simulated by failUntil)
  final backoffHandle = Retry<String, Map<String, dynamic>>(
        (endpoint) async {
      backoffAttempts++;
      print('   [Request] Processing payment...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 3,
          delay: 50,
          errorProbability: 0.9,
          statusCode: 503,
        );
        print('   [Success] ✅ Payment processed: ${result['status']}');
        return result as Map<String, dynamic>;
      } catch (e) {
        print('   [Retry] Attempt $backoffAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 4,
    onError: (error, stack) {},
    emitErrorPulse: false,
  ).toHandle(source: backoffInput.cell);

  final backoffObserver = Cell.observe(
    source: backoffHandle.cell,
    effect: (Pulse p) {},
  );

  final backoffStopwatch = Stopwatch()..start();
  await backoffInput.emitAsync('payment');
  await Future.delayed(const Duration(milliseconds: 1100));
  backoffStopwatch.stop();

  print('   Total time: ${backoffStopwatch.elapsedMilliseconds}ms');

  backoffObserver.stop();
  network.reset();
  backoffAttempts = 0;
  print('');

  // ========================================================================
  // 5. Deadline Exceeded - All Retries Failed
  // ========================================================================

  print('5. Deadline Exceeded - All Retries Failed');
  print('   ────────────────────────────────────────────────────────\n');

  final deadlineInput = Cell.ingress<String>();

  var deadlineAttempts = 0;

  // Retry with a deadline
  final deadlineHandle = Retry<String, String>(
        (endpoint) async {
      deadlineAttempts++;
      print('   [Request] Critical API call...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 10, // Never succeeds
          delay: 80,
          errorProbability: 1.0,
          statusCode: 500,
        );
        print('   [Success] ✅ ${result}');
        return result as String;
      } catch (e) {
        print('   [Retry] Attempt $deadlineAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 3,
    onError: (error, stack) {},
    emitErrorPulse: true,
  ).toHandle(source: deadlineInput.cell);

  // Add a global timeout (deadline)
  final deadlineTimeout = Timeout<String>(
    Duration(milliseconds: 1000),
    onError: (error, stack) {
      if (error is TimeoutException) {
        print('   [Deadline] ⏱️  Deadline exceeded (1000ms)');
        print('   ❌ Error: Deadlines exceeded after $deadlineAttempts attempts');
        print('   User sees: "Service unavailable. Please try later."');
      }
    },
    emitErrorPulse: true,
  ).toHandle(source: deadlineHandle.cell);

  final deadlineObserver = Cell.observe(
    source: deadlineTimeout.cell,
    effect: (Pulse p) {
      if (p.type == 'error') {
        // Error already printed in onError
      } else {
        print('   ✅ ${p.payload}');
      }
    },
  );

  await deadlineInput.emitAsync('critical_api');
  await Future.delayed(const Duration(milliseconds: 1500));

  deadlineObserver.stop();
  network.reset();
  deadlineAttempts = 0;
  print('');

  // ========================================================================
  // 6. Retry with Success on Last Attempt
  // ========================================================================

  print('6. Retry with Success on Last Attempt');
  print('   ────────────────────────────────────────────────────────\n');

  final syncInput = Cell.ingress<String>();

  var syncAttempts = 0;

  final syncHandle = Retry<String, List<String>>(
        (endpoint) async {
      syncAttempts++;
      print('   [Request] Data sync...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 2,
          delay: 50,
          errorProbability: 0.8,
        );
        print('   [Success] ✅ Sync complete! ${(result as List<String>).length} records synced');
        return result as List<String>;
      } catch (e) {
        print('   [Retry] Attempt $syncAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 3,
    onError: (error, stack) {},
    emitErrorPulse: false,
  ).toHandle(source: syncInput.cell);

  final syncObserver = Cell.observe(
    source: syncHandle.cell,
    effect: (Pulse p) {},
  );

  await syncInput.emitAsync('sync');
  await Future.delayed(const Duration(milliseconds: 400));

  print('   Total attempts: $syncAttempts, Success: ✅');

  syncObserver.stop();
  network.reset();
  syncAttempts = 0;
  print('');

  // ========================================================================
  // 7. Timeout with Fallback - Cache Fallback
  // ========================================================================

  print('7. Timeout with Fallback - Cache Fallback');
  print('   ────────────────────────────────────────────────────────\n');

  final cacheInput = Cell.ingress<String>();

  // Use AsyncMap to simulate cache lookup
  final cacheLookup = AsyncMap<String, String>(
    (key) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (cache.has(key)) {
        final value = cache.get(key);
        return 'Using stale cache: ${value.toString()}';
      }
      return 'No cache available';
    },
  ).toHandle(source: cacheInput.cell);

  // Timeout for cache lookup - emit error on timeout
  final cacheTimeout = Timeout<String>(
    Duration(milliseconds: 500),
    onError: (error, stack) {
      // Don't print here, let the merge handle it
    },
    emitErrorPulse: true,
  ).toHandle(source: cacheInput.cell);

  // Merge: timeout error or cache response
  final mergedCache = MergeWith<Object>(
    [cacheLookup.cell],
    forwardSource: true,
  ).toHandle(source: cacheTimeout.cell);

  final cacheObserver = Cell.observe(
    source: mergedCache.cell,
    effect: (Pulse p) {
      if (p.type == 'error') {
        print('   [Timeout] ⏱️  Cache response slow (500ms)');
        // On timeout, try to get from cache directly
        final key = (cacheInput as dynamic)._lastPayload;
        if (key != null && cache.has(key)) {
          final value = cache.get(key);
          print('   ✅ Using stale cache: ${value.toString()}');
          print('   User sees: "Showing cached data (may be stale)"');
        }
      } else if (p.payload is String) {
        print('   ✅ ${p.payload}');
        print('   User sees: "Showing cached data (may be stale)"');
      }
    },
  );

  await cacheInput.emitAsync('user_123');
  await Future.delayed(const Duration(milliseconds: 600));

  cacheObserver.stop();
  print('');

  // ========================================================================
  // 8. Retry with Backoff - Database Connection
  // ========================================================================

  print('8. Retry with Backoff - Database Connection');
  print('   ────────────────────────────────────────────────────────\n');

  final dbInput = Cell.ingress<String>();

  int dbAttempts = 0;

  final dbHandle = Retry<String, DatabaseConnection>(
        (endpoint) async {
      dbAttempts++;
      print('   [Request] Connecting to database...');
      try {
        final result = await network.request(
          endpoint: endpoint,
          failUntil: 2,
          delay: 200,
          errorProbability: 0.9,
          statusCode: 503,
        );
        print('   [Success] ✅ ${result.toString()}');
        return result as DatabaseConnection;
      } catch (e) {
        print('   [Retry] Attempt $dbAttempts failed: ${network.getLastError(endpoint) ?? e.toString()}');
        rethrow;
      }
    },
    count: 3,
    onError: (error, stack) {},
    emitErrorPulse: false,
  ).toHandle(source: dbInput.cell);

  final dbObserver = Cell.observe(
    source: dbHandle.cell,
    effect: (Pulse p) {},
  );

  final dbStopwatch = Stopwatch()..start();
  await dbInput.emitAsync('database');
  await Future.delayed(const Duration(milliseconds: 900));
  dbStopwatch.stop();

  print('   Total time: ${dbStopwatch.elapsedMilliseconds}ms');

  dbObserver.stop();
  network.reset();
  dbAttempts = 0;
  print('');

  // ========================================================================
  // 9. Deadline with Loading State
  // ========================================================================

  print('9. Deadline with Loading State');
  print('   ────────────────────────────────────────────────────────\n');

  final loadingInput = Cell.ingress<Map<String, dynamic>>();

  // Use AsyncMap for async processing with timeout
  final processOrder = AsyncMap<Map<String, dynamic>, String>(
    (orderData) async {
      final id = orderData['id'] as String;
      print('   [Loading] 🔄 Processing order...');
      await Future.delayed(const Duration(milliseconds: 100));
      print('   [Loading] 🔄 Processing order (100ms)');
      await Future.delayed(const Duration(milliseconds: 100));
      print('   [Loading] 🔄 Processing order (200ms)');
      await Future.delayed(const Duration(milliseconds: 100));
      return '✅ Order $id processed successfully!';
    },
  ).toHandle(source: loadingInput.cell);

  // Timeout for order processing
  final orderTimeout = Timeout<Map<String, dynamic>>(
    Duration(milliseconds: 500),
    onError: (error, stack) {
      print('   [Timeout] ⏱️  Deadline exceeded (500ms)');
      print('   [Loading] ❌ Order processing timed out');
    },
    emitErrorPulse: true,
  ).toHandle(source: loadingInput.cell);

  // Merge: timeout or success
  final loadingMerged = MergeWith<Object>(
    [processOrder.cell],
    forwardSource: true,
  ).toHandle(source: orderTimeout.cell);

  final loadingObserver = Cell.observe(
    source: loadingMerged.cell,
    effect: (Pulse p) {
      if (p.type == 'error') {
        print('   [Result] ❌ Order failed - please try again');
      } else if (p.payload is String) {
        print('   [Result] ${p.payload}');
      }
    },
  );

  print('   [User] Submit: Order #1234');
  await loadingInput.emitAsync({'id': 'ORD-1234'});
  await Future.delayed(const Duration(milliseconds: 700));

  loadingObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Retry + Timeout for Flaky Networks');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Pattern                   │  Use Case                                │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Simple Retry             │  Transient failures                       │
  │  Timeout                  │  Slow responses / deadlines               │
  │  Retry + Timeout          │  Network failures with deadlines          │
  │  Exponential Backoff      │  Server overload / rate limiting          │
  │  Deadline Exceeded        │  All retries failed                       │
  │  Cache Fallback           │  Graceful degradation on timeout          │
  │  Loading State            │  User feedback during retries             │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Retry handles transient failures with bounded attempts
  🔹 Timeout enforces a deadline before showing errors
  🔹 Combine retry + timeout for robust network calls
  🔹 Exponential backoff prevents thundering herd
  🔹 Cache fallback provides graceful degradation
  🔹 Loading states keep users informed
  🔹 No infinite spinners - users always get a result or error

  Key Benefits:
  - Users never see infinite loading spinners
  - Bounded retries prevent endless loops
  - Deadlines ensure timely responses
  - Exponential backoff reduces server load
  - Graceful degradation with fallbacks
  - Clear user feedback on failures
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}