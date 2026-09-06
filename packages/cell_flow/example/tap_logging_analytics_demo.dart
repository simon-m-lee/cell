// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.tap for logging and analytics without changing the pipeline.
///
/// ### Scenario
/// An e-commerce analytics system where:
/// 1. User actions flow through a reactive pipeline
/// 2. Flow.tap injects logging and analytics without modifying the data
/// 3. Metrics are collected transparently
/// 4. Performance monitoring is non-invasive
/// 5. Multiple tap patterns are demonstrated
/// 6. Analytics data is aggregated in real-time
///
/// ### Learning Objectives
/// - Understand how Flow.tap works
/// - See tap for non-invasive logging
/// - Use tap for analytics collection
/// - Monitor pipeline performance
/// - Track user behavior
/// - Debug without affecting production data
///
/// ### Expected Console Output
/// ```
/// ── Tap: Logging & Analytics Demo ────────────────────────────────────────────────
///
/// 1. Basic Tap - Logging User Actions
///    ────────────────────────────────────────────────────────
///    [User] Click: Product Viewed (iPhone 15)
///    [LOG] PRODUCT_VIEW: iPhone 15
///    [User] Click: Add to Cart (iPhone 15)
///    [LOG] CART_ADD: iPhone 15
///    [User] Click: Checkout
///    [LOG] CHECKOUT_START: 2 items
///
/// 2. Tap with Index - Tracking Session
///    ────────────────────────────────────────────────────────
///    [Session] Action #1: Page Load (home)
///    [Session] Action #2: Search (dart)
///    [Session] Action #3: Click (product)
///    [Session] Action #4: Cart (add)
///    Total actions: 4
///
/// 3. Analytics Tap - Metrics Collection
///    ────────────────────────────────────────────────────────
///    📊 Analytics: page_view
///    📊 Analytics: product_view
///    📊 Analytics: add_to_cart
///    📊 Analytics: checkout_start
///    📊 Metrics: 4 events in 2.3s
///
/// 4. Multiple Taps - Separating Concerns
///    ────────────────────────────────────────────────────────
///    [User] Order Placed: #ORD-1234
///    [LOG] 📝 ORDER_PLACED: #ORD-1234
///    [ANALYTICS] 📊 order_created
///    [PERFORMANCE] ⏱️  Order processing: 145ms
///    [AUDIT] 🔍 ORDER_AUDIT: #ORD-1234
///
/// 5. Tap with State - Running Totals
///    ────────────────────────────────────────────────────────
///    [Shop] View: Product A
///    [Shop] View: Product B
///    [Shop] View: Product C
///    [Stats] Total views: 3 | Unique products: 3 | Last: Product C
///
/// 6. Performance Monitoring with Tap
///    ────────────────────────────────────────────────────────
///    [Action] User Login
///    [PERF] ⏱️  start: 12:34:56.123
///    [Action] User Login - processing
///    [PERF] ⏱️  complete: 12:34:56.456 (333ms)
///    [Action] User Login - done
///    [PERF] ⏱️  Total duration: 333ms
///
/// 7. A/B Testing with Tap
///    ────────────────────────────────────────────────────────
///    [User] Checkout (Variant A)
///    [AB TEST] variant_a: checkout_start
///    [User] Checkout (Variant B)
///    [AB TEST] variant_b: checkout_start
///    [AB TEST] Conversion rate: 0.50 (2 conversions, 4 events)
///
/// 8. Error Tracking with Tap
///    ────────────────────────────────────────────────────────
///    [User] Submit: valid_order
///    [SUCCESS] ✅ Order processed: valid_order
///    [User] Submit: error_order
///    [ERROR] ❌ Payment failed: error_order
///    [TRACK] Success: 1, Error: 1
///
/// 9. Real-Time Dashboard Taps
///    ────────────────────────────────────────────────────────
///    📊 Dashboard: user_login
///    📊 Dashboard: product_view
///    📊 Dashboard: add_to_cart
///    📊 Dashboard: checkout
///    📊 Dashboard: Active: 4, Conversions: 1
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/tap.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/scan.dart';

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a user action in the system.
class UserAction {
  final String type;
  final String? target;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  UserAction({
    required this.type,
    this.target,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$type${target != null ? ' on $target' : ''}';
}

/// Represents a product.
class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  @override
  String toString() => '$name (\$${price.toStringAsFixed(2)})';
}

/// Represents an order.
class Order {
  final String id;
  final List<CartItem> items;
  final double total;
  final String status;

  Order({
    required this.id,
    required this.items,
    required this.total,
    this.status = 'pending',
  });

  @override
  String toString() => '#$id - $status (\$${total.toStringAsFixed(2)})';
}

/// Represents a cart item.
class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;

  @override
  String toString() => '${product.name} x$quantity';
}

/// Analytics event for tracking.
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.properties = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$name: ${properties.isNotEmpty ? properties.toString() : ''}';
}

/// Performance metric.
class PerformanceMetric {
  final String operation;
  final String phase;
  final int durationMs;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operation,
    required this.phase,
    required this.durationMs,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$operation: $phase (${durationMs}ms)';
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── Tap: Logging & Analytics Demo ────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Tap - Logging User Actions
  // ========================================================================

  print('1. Basic Tap - Logging User Actions');
  print('   ────────────────────────────────────────────────────────\n');

  final actionInput = Cell.ingress<String>();

  // Pipeline: actions → (tap logging) → (tap analytics)
  final tapLogging = Tap<String>(
        (value) => print('   [LOG] $value'),
  ).toHandle(source: actionInput.cell);

  final processed = tapLogging;

  final actionObserver = Cell.observe(
    source: processed.cell,
    effect: (Pulse p) {
      // The pipeline continues without modification
    },
  );

  print('   [User] Click: Product Viewed (iPhone 15)');
  await actionInput.emitAsync('PRODUCT_VIEW: iPhone 15');

  print('   [User] Click: Add to Cart (iPhone 15)');
  await actionInput.emitAsync('CART_ADD: iPhone 15');

  print('   [User] Click: Checkout');
  await actionInput.emitAsync('CHECKOUT_START: 2 items');

  await Future.delayed(const Duration(milliseconds: 50));

  actionObserver.stop();
  print('');

  // ========================================================================
  // 2. Tap with Index - Tracking Session
  // ========================================================================

  print('2. Tap with Index - Tracking Session');
  print('   ────────────────────────────────────────────────────────\n');

  final sessionInput = Cell.ingress<String>();

  final sessionTap = TapWithIndex<String>(
        (value, index) => print('   [Session] Action #${index + 1}: $value'),
  ).toHandle(source: sessionInput.cell);

  final sessionObserver = Cell.observe(
    source: sessionTap.cell,
    effect: (Pulse p) {},
  );

  final actions = ['Page Load (home)', 'Search (dart)', 'Click (product)', 'Cart (add)'];
  for (final action in actions) {
    await sessionInput.emitAsync(action);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  print('   Total actions: ${actions.length}');

  sessionObserver.stop();
  print('');

  // ========================================================================
  // 3. Analytics Tap - Metrics Collection
  // ========================================================================

  print('3. Analytics Tap - Metrics Collection');
  print('   ────────────────────────────────────────────────────────\n');

  final analyticsInput = Cell.ingress<String>();

  // Collect analytics
  final analyticsEvents = <String>[];

  final analyticsTap = Tap<String>(
        (value) {
      analyticsEvents.add(value);
      print('   📊 Analytics: $value');
    },
  ).toHandle(source: analyticsInput.cell);

  final analyticsObserver = Cell.observe(
    source: analyticsTap.cell,
    effect: (Pulse p) {},
  );

  final events = ['page_view', 'product_view', 'add_to_cart', 'checkout_start'];
  final startTime = DateTime.now();

  for (final event in events) {
    await analyticsInput.emitAsync(event);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  final elapsed = DateTime.now().difference(startTime);
  print('   📊 Metrics: ${analyticsEvents.length} events in ${elapsed.inMilliseconds}ms');

  analyticsObserver.stop();
  print('');

  // ========================================================================
  // 4. Multiple Taps - Separating Concerns
  // ========================================================================

  print('4. Multiple Taps - Separating Concerns');
  print('   ────────────────────────────────────────────────────────\n');

  final orderInput = Cell.ingress<Map<String, dynamic>>();

  // Tap 1: Logging
  final logTap = Tap<Map<String, dynamic>>(
        (order) => print('   [LOG] 📝 ORDER_PLACED: ${order['id']}'),
  ).toHandle(source: orderInput.cell);

  // Tap 2: Analytics
  final analyticsTap2 = Tap<Map<String, dynamic>>(
        (order) => print('   [ANALYTICS] 📊 order_created'),
  ).toHandle(source: logTap.cell);

  // Tap 3: Performance
  final perfTap = Tap<Map<String, dynamic>>(
        (order) => print('   [PERFORMANCE] ⏱️  Order processing: ${order['duration']}ms'),
  ).toHandle(source: analyticsTap2.cell);

  // Tap 4: Audit
  final auditTap = Tap<Map<String, dynamic>>(
        (order) => print('   [AUDIT] 🔍 ORDER_AUDIT: ${order['id']}'),
  ).toHandle(source: perfTap.cell);

  final orderObserver = Cell.observe(
    source: auditTap.cell,
    effect: (Pulse p) {
      final order = p.payload as Map<String, dynamic>;
      print('   [User] Order Placed: ${order['id']}');
    },
  );

  await orderInput.emitAsync({
    'id': 'ORD-1234',
    'amount': 149.99,
    'duration': 145,
  });

  await Future.delayed(const Duration(milliseconds: 50));

  orderObserver.stop();
  print('');

  // ========================================================================
  // 5. Tap with State - Running Totals
  // ========================================================================

  print('5. Tap with State - Running Totals');
  print('   ────────────────────────────────────────────────────────\n');

  final shopInput = Cell.ingress<String>();

  // Use TapState to maintain running totals
  final shopState = TapState<String, Map<String, dynamic>>(
    {'views': 0, 'products': <String>{}, 'last': null},
        (state, value) {
      final products = Set<String>.from(state['products'] as Set<String>);
      products.add(value);
      return {
        'views': state['views'] + 1,
        'products': products,
        'last': value,
      };
    },
  ).toHandle(source: shopInput.cell);

  final shopObserver = Cell.observe(
    source: shopState.cell,
    effect: (Pulse p) {
      final state = p.payload as Map<String, dynamic>;
      print('   [Shop] View: ${state['last']}');
      print('   [Stats] Total views: ${state['views']} | '
          'Unique products: ${(state['products'] as Set<String>).length} | '
          'Last: ${state['last']}');
    },
  );

  final products = ['Product A', 'Product B', 'Product C'];
  for (final product in products) {
    await shopInput.emitAsync(product);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  await Future.delayed(const Duration(milliseconds: 50));

  shopObserver.stop();
  print('');

  // ========================================================================
  // 6. Performance Monitoring with Tap
  // ========================================================================

  print('6. Performance Monitoring with Tap');
  print('   ────────────────────────────────────────────────────────\n');

  final perfInput = Cell.ingress<String>();
  final perfState = <String, DateTime>{};

  // Start timing
  final startTap = Tap<String>(
        (action) {
      perfState[action] = DateTime.now();
      print('   [PERF] ⏱️  start: ${DateTime.now().toIso8601String().substring(11, 19)}.${DateTime.now().millisecond}');
    },
  ).toHandle(source: perfInput.cell);

  // Process action (simulated)
  final processMap = MapValue<String, String>(
        (action) {
      print('   [Action] $action - processing');
      return action;
    },
  ).toHandle(source: startTap.cell);

  // End timing
  final endTap = Tap<String>(
        (action) {
      final start = perfState[action];
      if (start != null) {
        final duration = DateTime.now().difference(start);
        print('   [PERF] ⏱️  complete: ${DateTime.now().toIso8601String().substring(11, 19)}.${DateTime.now().millisecond} (${duration.inMilliseconds}ms)');
      }
    },
  ).toHandle(source: processMap.cell);

  final perfObserver = Cell.observe(
    source: endTap.cell,
    effect: (Pulse p) {
      print('   [Action] ${p.payload} - done');
      final start = perfState[p.payload];
      if (start != null) {
        final duration = DateTime.now().difference(start);
        print('   [PERF] ⏱️  Total duration: ${duration.inMilliseconds}ms');
      }
    },
  );

  await perfInput.emitAsync('User Login');
  await Future.delayed(const Duration(milliseconds: 333));
  await perfInput.emitAsync('Data Load');
  await Future.delayed(const Duration(milliseconds: 222));

  await Future.delayed(const Duration(milliseconds: 50));

  perfObserver.stop();
  print('');

  // ========================================================================
  // 7. A/B Testing with Tap
  // ========================================================================

  print('7. A/B Testing with Tap');
  print('   ────────────────────────────────────────────────────────\n');

  final abInput = Cell.ingress<String>();
  final abMetrics = <String, int>{'A': 0, 'B': 0};
  final abConversions = <String, int>{'A': 0, 'B': 0};

  final abTap = Tap<String>(
        (variant) {
      final key = variant.contains('variant_a') ? 'A' : 'B';
      abMetrics[key] = (abMetrics[key] ?? 0) + 1;
      print('   [AB TEST] variant_${key.toLowerCase()}: ${variant.split(':')[1] ?? 'checkout_start'}');
    },
  ).toHandle(source: abInput.cell);

  final abObserver = Cell.observe(
    source: abTap.cell,
    effect: (Pulse p) {
      final variant = p.payload as String;
      if (variant.contains('conversion')) {
        final key = variant.contains('variant_a') ? 'A' : 'B';
        abConversions[key] = (abConversions[key] ?? 0) + 1;
      }
    },
  );

  // Simulate A/B test
  await abInput.emitAsync('variant_a:checkout_start');
  await Future.delayed(const Duration(milliseconds: 50));
  await abInput.emitAsync('variant_b:checkout_start');
  await Future.delayed(const Duration(milliseconds: 50));
  await abInput.emitAsync('variant_a:conversion');
  await Future.delayed(const Duration(milliseconds: 50));
  await abInput.emitAsync('variant_b:checkout_start');

  await Future.delayed(const Duration(milliseconds: 50));

  for (final entry in abMetrics.entries) {
    final conversions = abConversions[entry.key] ?? 0;
    final rate = entry.value > 0 ? conversions / entry.value : 0;
    print('   [AB TEST] variant_${entry.key.toLowerCase()}: ${entry.value} events, '
        '${conversions} conversions (${(rate * 100).toInt()}% rate)');
  }

  abObserver.stop();
  print('');

  // ========================================================================
  // 8. Error Tracking with Tap
  // ========================================================================

  print('8. Error Tracking with Tap');
  print('   ────────────────────────────────────────────────────────\n');

  final errorInput = Cell.ingress<String>();
  var successCount = 0;
  var errorCount = 0;

  // Track successes
  final successTap = Tap<String>(
        (value) {
      successCount++;
      print('   [SUCCESS] ✅ Order processed: $value');
    },
  ).toHandle(source: errorInput.cell);

  // Track errors
  final errorTap = Tap<String>(
        (value) {
      errorCount++;
      print('   [ERROR] ❌ Payment failed: $value');
    },
  ).toHandle(source: errorInput.cell);

  // Use filter to separate success and error
  final successFilter = Filter<String>(
        (value) => value != 'error_order',
  ).toHandle(source: successTap.cell);

  final errorFilter = Filter<String>(
        (value) => value == 'error_order',
  ).toHandle(source: errorTap.cell);

  // Merge both streams
  final errorObserver = Cell.observe(
    source: successFilter.cell,
    effect: (Pulse p) {
      // Success path
    },
  );

  final errorObserver2 = Cell.observe(
    source: errorFilter.cell,
    effect: (Pulse p) {
      // Error path
    },
  );

  await errorInput.emitAsync('valid_order');
  await Future.delayed(const Duration(milliseconds: 50));
  await errorInput.emitAsync('error_order');
  await Future.delayed(const Duration(milliseconds: 50));
  await errorInput.emitAsync('valid_order');

  await Future.delayed(const Duration(milliseconds: 50));

  print('   [TRACK] Success: $successCount, Error: $errorCount');

  errorObserver.stop();
  errorObserver2.stop();
  print('');

  // ========================================================================
  // 9. Real-Time Dashboard Taps
  // ========================================================================

  print('9. Real-Time Dashboard Taps');
  print('   ────────────────────────────────────────────────────────\n');

  final dashboardInput = Cell.ingress<String>();
  final dashboardMetrics = <String, int>{};
  var activeUsers = 0;
  var conversions = 0;

  final dashboardTap = Tap<String>(
        (event) {
      dashboardMetrics[event] = (dashboardMetrics[event] ?? 0) + 1;
      print('   📊 Dashboard: $event');

      if (event == 'user_login') activeUsers++;
      if (event == 'user_logout') activeUsers = max(0, activeUsers - 1);
      if (event == 'conversion') conversions++;
    },
  ).toHandle(source: dashboardInput.cell);

  final dashboardObserver = Cell.observe(
    source: dashboardTap.cell,
    effect: (Pulse p) {},
  );

  final dashboardEvents = ['user_login', 'product_view', 'add_to_cart', 'checkout', 'conversion'];
  for (final event in dashboardEvents) {
    await dashboardInput.emitAsync(event);
    await Future.delayed(const Duration(milliseconds: 80));
  }

  await Future.delayed(const Duration(milliseconds: 50));

  print('   📊 Dashboard: Active: $activeUsers, Conversions: $conversions');

  dashboardObserver.stop();
  print('');

  // ========================================================================
  // 10. Tap All - Debugging Every Pulse
  // ========================================================================

  print('10. Tap All - Debugging Every Pulse');
  print('   ────────────────────────────────────────────────────────\n');

  final debugInput = Cell.ingress<Object>();

  final debugTap = TapAll(
        (pulse) {
      print('   [DEBUG] Pulse: type=${pulse.type}, payload=${pulse.payload}, priority=${pulse.priority}');
    },
  ).toHandle(source: debugInput.cell);

  final debugObserver = Cell.observe(
    source: debugTap.cell,
    effect: (Pulse p) {},
  );

  await debugInput.emitAsync('Hello, World!');
  await Future.delayed(const Duration(milliseconds: 50));
  await debugInput.emitAsync(42);
  await Future.delayed(const Duration(milliseconds: 50));
  await debugInput.emitAsync({'key': 'value'});

  await Future.delayed(const Duration(milliseconds: 50));

  debugObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Tap for Logging & Analytics');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Tap Pattern              │  Use Case                                │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Basic Tap               │  Logging user actions                     │
  │  TapWithIndex            │  Session/sequence tracking                │
  │  Multiple Taps           │  Separate concerns (log, analytics, perf) │
  │  TapState                │  Running totals and state tracking        │
  │  Performance Tap         │  Timing and monitoring                    │
  │  A/B Testing Tap         │  Experiment tracking                      │
  │  Error Tracking Tap      │  Success/error counting                   │
  │  Dashboard Tap           │  Real-time metrics                        │
  │  TapAll                  │  Debugging every pulse                    │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Tap injects side effects without changing the pipeline
  🔹 Perfect for logging, analytics, and monitoring
  🔹 Multiple taps can be chained for different concerns
  🔹 TapState maintains state across taps
  🔹 TapWithIndex provides position information
  🔹 TapAll sees every pulse (including type mismatches)
  🔹 Non-invasive - data flows through unchanged
  🔹 Zero performance impact on the actual pipeline

  Key Benefits:
  - Add logging without modifying business logic
  - Collect analytics transparently
  - Monitor performance in production
  - Debug without changing code
  - A/B test without affecting users
  - Track errors and success rates
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}