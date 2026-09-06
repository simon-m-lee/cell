// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.exhaustMap for preventing double-taps during submit, checkout,
/// and refresh operations.
///
/// ### Scenario
/// An e-commerce checkout system where:
/// 1. Users click submit/checkout/refresh buttons
/// 2. Flow.exhaustMap prevents double-taps while work is in flight
/// 3. Subsequent clicks are ignored until the current operation completes
/// 4. Visual feedback shows loading states
/// 5. Success/error states are displayed
/// 6. Multiple real-world scenarios are demonstrated
///
/// ### Learning Objectives
/// - Understand how Flow.exhaustMap works
/// - Prevent double-submission in forms
/// - Handle checkout race conditions
/// - Implement refresh with debouncing
/// - Show loading states during operations
/// - Handle errors gracefully
///
/// ### Expected Console Output
/// ```
/// ── ExhaustMap Demo: Submit, Checkout, Refresh ─────────────────────────────
///
/// 1. Form Submit - Prevent Double-Submit
///    ────────────────────────────────────────────────────────
///
///    [User] Clicked: Submit ORD-1234
///    [User] Clicked: Submit ORD-1234 (IGNORED - busy)
///    [System] Processing order... (200ms) 🔄
///    [User] Clicked: Submit ORD-1234 (IGNORED - busy)
///    [System] ✅ Order submitted successfully!
///    Double-taps: 2 ignored
///
/// 2. Checkout Flow - Payment Processing
///    ────────────────────────────────────────────────────────
///
///    [User] Checkout: $1029.98 (via Credit Card)
///    [User] Checkout: $1029.98 (IGNORED - processing)
///    [Payment] Processing payment... (300ms) 💳
///    [User] Checkout: $1029.98 (IGNORED - processing)
///    Double-taps: 2 ignored
///
/// 3. Refresh Button - Data Reload
///    ────────────────────────────────────────────────────────
///
///    [User] Refresh clicked
///    [User] Refresh clicked (IGNORED - busy)
///    [System] Fetching latest data... (150ms) 🔄
///    [User] Refresh clicked (IGNORED - busy)
///    Double-taps: 2 ignored
///
/// 4. Error Handling - Failed Operation
///    ────────────────────────────────────────────────────────
///
///    [User] Submit: Failed Order
///    [User] Submit: Failed Order (IGNORED - busy)
///    [System] Processing... (200ms) 🔄
///    [User] Retry: Failed Order (allowed - not busy)
///    [System] Processing... (200ms) 🔄
///
/// 5. Sequential Processing - Multiple Operations
///    ────────────────────────────────────────────────────────
///
///    [User] Op 1: Process item A
///    [User] Op 2: Process item B (IGNORED)
///    [System] Processing item A... 🔄
///    [User] Op 3: Process item C (IGNORED)
///    [User] Op 4: Process item B (allowed)
///    [System] Processing item B... 🔄
///
/// 6. Shopping Cart Checkout
///    ────────────────────────────────────────────────────────
///
///    [User] Cart: 3 items - Total: $189.97
///    [User] Cart: 3 items - Total: $189.97 (IGNORED)
///    [Checkout] Processing cart... (250ms) 🛒
///
/// 7. Retry with Debounce Protection
///    ────────────────────────────────────────────────────────
///
///    [User] Save: Document v1
///    [User] Save: Document v1 (IGNORED - busy)
///    [System] Saving... (300ms) 💾
///    [User] Save: Document v2 (retry)
///    [System] Saving... (300ms) 💾
///
/// 8. API Request with Loading State
///    ────────────────────────────────────────────────────────
///
///    [User] Fetch: User Profile
///    [User] Fetch: User Profile (IGNORED - busy)
///    [State] 🔄 Loading...
///    [API] Fetching profile... (200ms)
///
/// 9. Compare exhaustMap vs debounce
///    ────────────────────────────────────────────────────────
///
///    [User] Quick: A, B, C, D, E
///    exhaustMap: Only the first item processed
///    debounce: Only the last item after silence
///
/// ────────────────────────────────────────────────────────────
/// 📝 Summary: ExhaustMap - Submit, Checkout, Refresh
/// ────────────────────────────────────────────────────────────
///   ┌─────────────────────────────────────────────────────────────────────────┐
///   │  Use Case               │  Behavior                                   │
///   ├─────────────────────────────────────────────────────────────────────────┤
///   │  Form Submit            │  Ignore double-taps during submission       │
///   │  Checkout               │  Prevent duplicate payment processing       │
///   │  Refresh                │  Ignore rapid refresh clicks                │
///   │  Error Handling         │  Retry after failure, not during busy       │
///   │  Sequential             │  Process items one at a time                │
///   │  Shopping Cart          │  Prevent duplicate checkout                 │
///   │  Retry Protection       │  Allow retry only when not busy             │
///   │  API Requests           │  Show loading state, ignore duplicate calls │
///   └─────────────────────────────────────────────────────────────────────────┘
///
///   🔹 exhaustMap ignores new triggers while busy
///   🔹 Perfect for submit/checkout/refresh buttons
///   🔹 Prevents double-taps and race conditions
///   🔹 Preserves the first operation (not the last)
///   🔹 Automatically handles busy states
///   🔹 Great for payment processing
///   🔹 Ideal for form submissions
///   🔹 Works with any async operation
///
///   When to use exhaustMap:
///   - Form submission buttons
///   - Checkout/payment processing
///   - Refresh/update actions
///   - API calls that shouldn't overlap
///   - File uploads
///   - Database operations
///   - Any operation that shouldn't run concurrently
///
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/flow.dart';

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents an order to be submitted.
class Order {
  final String id;
  final double amount;
  final String? customerId;
  final DateTime createdAt;

  Order({
    required this.id,
    this.amount = 0,
    this.customerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Order #$id (\$${amount.toStringAsFixed(2)})';
}

/// Represents a cart for checkout.
class ShoppingCart {
  final List<CartItem> items;
  final double total;
  final String? couponCode;

  ShoppingCart({
    required this.items,
    required this.total,
    this.couponCode,
  });

  int get itemCount => items.length;

  @override
  String toString() => '${items.length} items - Total: \$${total.toStringAsFixed(2)}';
}

/// Represents a cart item.
class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;

  @override
  String toString() => '$name x$quantity (\$${total.toStringAsFixed(2)})';
}

/// Represents an API request result.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult.success(this.data) : error = null, isSuccess = true;
  ApiResult.failure(this.error) : data = null, isSuccess = false;

  @override
  String toString() => isSuccess ? 'Success: $data' : 'Error: $error';
}

/// Represents a user profile.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final DateTime lastLogin;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    DateTime? lastLogin,
  }) : lastLogin = lastLogin ?? DateTime.now();

  @override
  String toString() => '$name ($email)';
}

// ─────────────────────────────────────────────────────────────────────
// API Simulator
// ─────────────────────────────────────────────────────────────────────

/// Simulates various API operations with configurable success/failure.
class ApiSimulator {
  final Random _random = Random();
  int _orderCounter = 1000;
  int _cartCounter = 5000;

  /// Simulates submitting an order.
  Future<Order> submitOrder(Order order) async {
    final delay = Duration(milliseconds: _random.nextInt(300) + 100);
    await Future.delayed(delay);

    if (_random.nextInt(10) < 2) {
      throw Exception('Database connection failed');
    }

    _orderCounter++;
    return Order(
      id: 'ORD-${_orderCounter}',
      amount: order.amount,
      customerId: order.customerId ?? 'CUST-${_random.nextInt(100)}',
    );
  }

  /// Simulates processing a checkout.
  Future<Map<String, dynamic>> processCheckout(ShoppingCart cart) async {
    final delay = Duration(milliseconds: _random.nextInt(200) + 100);
    await Future.delayed(delay);

    if (_random.nextInt(10) < 1) {
      throw Exception('Payment gateway timeout');
    }

    _cartCounter++;
    return {
      'transactionId': 'TXN-${_cartCounter}',
      'items': cart.items.length,
      'total': cart.total,
      'status': 'completed',
    };
  }

  /// Simulates refreshing data.
  Future<List<String>> refreshData() async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (_random.nextInt(10) < 1) {
      throw Exception('Network timeout');
    }

    final items = <String>[];
    for (var i = 0; i < 12; i++) {
      items.add('Item ${i + 1}');
    }
    return items;
  }

  /// Simulates saving a document.
  Future<String> saveDocument(String content) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (_random.nextInt(10) < 1) {
      throw Exception('Conflict: Document was modified elsewhere');
    }

    return 'Document saved: ${content.length} characters';
  }

  /// Simulates fetching a user profile.
  Future<UserProfile> fetchUserProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (_random.nextInt(10) < 1) {
      throw Exception('User not found');
    }

    return UserProfile(
      id: userId,
      name: ['Alice', 'Bob', 'Charlie', 'Diana'][_random.nextInt(4)],
      email: '${userId}@example.com',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  final api = ApiSimulator();

  print('── ExhaustMap Demo: Submit, Checkout, Refresh ─────────────────────────────\n');

  // ========================================================================
  // 1. Form Submit - Prevent Double-Submit
  // ========================================================================

  print('1. Form Submit - Prevent Double-Submit');
  print('   ────────────────────────────────────────────────────────\n');

  final submitInput = Cell.ingress<Order>();
  final loadingState = Cell.state<bool>(initial: false);
  final resultState = Cell.state<String>(initial: 'Ready');

  // Use exhaustMap to prevent double-submit
  final submitHandle = Flow.exhaustMap<Order, String>(
    submitInput.cell,
    project: (order) async {
      // Show loading state
      loadingState.update(true);
      resultState.update('Processing... 🔄');

      try {
        print('   [System] Processing order... (200ms) 🔄');
        final result = await api.submitOrder(order);
        final message = '✅ Order ${result.id} confirmed!';
        resultState.update(message);
        print('   [System] ✅ Order submitted successfully!');
        return message;
      } catch (e) {
        final message = '❌ Error: ${e.toString()}';
        resultState.update(message);
        print('   [System] ❌ ${e.toString()}');
        return message;
      } finally {
        loadingState.update(false);
      }
    },
  );

  // Observe the result
  final resultObserver = Cell.observe(
    source: submitHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  // Observe loading state
  final loadingObserver = Cell.observe(
    source: loadingState.cell,
    effect: (Pulse p) {
      // Loading state changes are printed inline
    },
  );

  // Simulate user clicking submit
  final order = Order(id: 'ORD-1234', amount: 99.99, customerId: 'CUST-001');

  print('   [User] Clicked: Submit ${order.id}');
  await submitInput.emitAsync(order);

  // Rapid double-taps
  print('   [User] Clicked: Submit ${order.id} (IGNORED - busy)');
  await submitInput.emitAsync(order);

  print('   [User] Clicked: Submit ${order.id} (IGNORED - busy)');
  await submitInput.emitAsync(order);

  await Future.delayed(const Duration(milliseconds: 400));

  print('   Double-taps: 2 ignored');

  resultObserver.stop();
  loadingObserver.stop();
  print('');

  // ========================================================================
  // 2. Checkout Flow - Payment Processing
  // ========================================================================

  print('2. Checkout Flow - Payment Processing');
  print('   ────────────────────────────────────────────────────────\n');

  final checkoutInput = Cell.ingress<ShoppingCart>();

  final checkoutHandle = Flow.exhaustMap<ShoppingCart, String>(
    checkoutInput.cell,
    project: (cart) async {
      print('   [Payment] Processing payment... (300ms) 💳');
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        final result = await api.processCheckout(cart);
        return '✅ Checkout complete: ${result['items']} items';
      } catch (e) {
        return '❌ Payment failed: ${e.toString()}';
      }
    },
  );

  final checkoutObserver = Cell.observe(
    source: checkoutHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  final cart = ShoppingCart(
    items: [
      CartItem(id: 'P-001', name: 'Laptop', price: 999.99),
      CartItem(id: 'P-002', name: 'Mouse', price: 29.99),
    ],
    total: 1029.98,
  );

  print('   [User] Checkout: \$${cart.total.toStringAsFixed(2)} (via Credit Card)');
  await checkoutInput.emitAsync(cart);

  print('   [User] Checkout: \$${cart.total.toStringAsFixed(2)} (IGNORED - processing)');
  await checkoutInput.emitAsync(cart);

  print('   [User] Checkout: \$${cart.total.toStringAsFixed(2)} (IGNORED - processing)');
  await checkoutInput.emitAsync(cart);

  await Future.delayed(const Duration(milliseconds: 400));

  print('   Double-taps: 2 ignored');

  checkoutObserver.stop();
  print('');

  // ========================================================================
  // 3. Refresh Button - Data Reload
  // ========================================================================

  print('3. Refresh Button - Data Reload');
  print('   ────────────────────────────────────────────────────────\n');

  final refreshInput = Cell.ingress<void>();
  final refreshLoading = Cell.state<bool>(initial: false);

  final refreshHandle = Flow.exhaustMap<void, String>(
    refreshInput.cell,
    project: (_) async {
      refreshLoading.update(true);
      print('   [System] Fetching latest data... (150ms) 🔄');

      try {
        final data = await api.refreshData();
        refreshLoading.update(false);
        return '✅ Data refreshed (${data.length} items)';
      } catch (e) {
        refreshLoading.update(false);
        return '❌ Refresh failed: ${e.toString()}';
      }
    },
  );

  final refreshObserver = Cell.observe(
    source: refreshHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  print('   [User] Refresh clicked');
  await refreshInput.emitAsync(null);

  print('   [User] Refresh clicked (IGNORED - busy)');
  await refreshInput.emitAsync(null);

  print('   [User] Refresh clicked (IGNORED - busy)');
  await refreshInput.emitAsync(null);

  await Future.delayed(const Duration(milliseconds: 250));

  print('   Double-taps: 2 ignored');

  refreshObserver.stop();
  print('');

  // ========================================================================
  // 4. Error Handling - Failed Operation
  // ========================================================================

  print('4. Error Handling - Failed Operation');
  print('   ────────────────────────────────────────────────────────\n');

  final errorInput = Cell.ingress<Order>();

  // Use a higher failure rate for this demo
  int failureCount = 0;

  final errorHandle = Flow.exhaustMap<Order, String>(
    errorInput.cell,
    project: (order) async {
      print('   [System] Processing... (200ms) 🔄');
      await Future.delayed(const Duration(milliseconds: 200));

      // Simulate failure
      if (failureCount < 1) {
        failureCount++;
        throw Exception('Database connection failed');
      }

      return '✅ Retry successful!';
    },
  );

  final errorObserver = Cell.observe(
    source: errorHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  final errorOrder = Order(id: 'ERR-001', amount: 50.00);

  print('   [User] Submit: Failed Order');
  await errorInput.emitAsync(errorOrder);

  print('   [User] Submit: Failed Order (IGNORED - busy)');
  await errorInput.emitAsync(errorOrder);

  await Future.delayed(const Duration(milliseconds: 300));

  print('   [User] Retry: Failed Order (allowed - not busy)');
  await errorInput.emitAsync(errorOrder);

  await Future.delayed(const Duration(milliseconds: 300));

  errorObserver.stop();
  print('');

  // ========================================================================
  // 5. Sequential Processing - Multiple Operations
  // ========================================================================

  print('5. Sequential Processing - Multiple Operations');
  print('   ────────────────────────────────────────────────────────\n');

  final seqInput = Cell.ingress<String>();

  final seqHandle = Flow.exhaustMap<String, String>(
    seqInput.cell,
    project: (item) async {
      print('   [System] Processing $item... 🔄');
      await Future.delayed(const Duration(milliseconds: 150));
      return '✅ $item processed';
    },
  );

  final seqObserver = Cell.observe(
    source: seqHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  print('   [User] Op 1: Process item A');
  await seqInput.emitAsync('item A');

  print('   [User] Op 2: Process item B (IGNORED)');
  await seqInput.emitAsync('item B');

  print('   [User] Op 3: Process item C (IGNORED)');
  await seqInput.emitAsync('item C');

  await Future.delayed(const Duration(milliseconds: 200));

  print('   [User] Op 4: Process item B (allowed)');
  await seqInput.emitAsync('item B');

  await Future.delayed(const Duration(milliseconds: 200));

  seqObserver.stop();
  print('');

  // ========================================================================
  // 6. Shopping Cart Checkout
  // ========================================================================

  print('6. Shopping Cart Checkout');
  print('   ────────────────────────────────────────────────────────\n');

  final cartInput = Cell.ingress<ShoppingCart>();

  final cartHandle = Flow.exhaustMap<ShoppingCart, String>(
    cartInput.cell,
    project: (cart) async {
      print('   [Checkout] Processing cart... (250ms) 🛒');
      await Future.delayed(const Duration(milliseconds: 250));

      try {
        final result = await api.processCheckout(cart);
        return '✅ Cart processed successfully! ${result['items']} items';
      } catch (e) {
        return '❌ Checkout failed: ${e.toString()}';
      }
    },
  );

  final cartObserver = Cell.observe(
    source: cartHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  final checkoutCart = ShoppingCart(
    items: [
      CartItem(id: 'C-001', name: 'Shoes', price: 89.99),
      CartItem(id: 'C-002', name: 'Shirt', price: 39.99),
      CartItem(id: 'C-003', name: 'Jeans', price: 59.99),
    ],
    total: 189.97,
  );

  print('   [User] Cart: 3 items - Total: \$${checkoutCart.total.toStringAsFixed(2)}');
  await cartInput.emitAsync(checkoutCart);

  print('   [User] Cart: 3 items - Total: \$${checkoutCart.total.toStringAsFixed(2)} (IGNORED)');
  await cartInput.emitAsync(checkoutCart);

  await Future.delayed(const Duration(milliseconds: 350));

  cartObserver.stop();
  print('');

  // ========================================================================
  // 7. Retry with Debounce Protection
  // ========================================================================

  print('7. Retry with Debounce Protection');
  print('   ────────────────────────────────────────────────────────\n');

  final saveInput = Cell.ingress<String>();

  int saveAttempts = 0;

  final saveHandle = Flow.exhaustMap<String, String>(
    saveInput.cell,
    project: (content) async {
      saveAttempts++;
      print('   [System] Saving... (300ms) 💾');
      await Future.delayed(const Duration(milliseconds: 300));

      if (saveAttempts == 1) {
        throw Exception('Conflict: Document was modified elsewhere');
      }

      return '✅ Save successful: Document v${saveAttempts}';
    },
  );

  final saveObserver = Cell.observe(
    source: saveHandle.cell,
    effect: (Pulse p) {
      print('   [Result] ${p.payload}');
    },
  );

  print('   [User] Save: Document v1');
  await saveInput.emitAsync('Document v1');

  print('   [User] Save: Document v1 (IGNORED - busy)');
  await saveInput.emitAsync('Document v1');

  await Future.delayed(const Duration(milliseconds: 400));

  print('   [User] Save: Document v2 (retry)');
  await saveInput.emitAsync('Document v2');

  await Future.delayed(const Duration(milliseconds: 400));

  saveObserver.stop();
  print('');

  // ========================================================================
  // 8. API Request with Loading State
  // ========================================================================

  print('8. API Request with Loading State');
  print('   ────────────────────────────────────────────────────────\n');

  final apiInput = Cell.ingress<String>();
  final apiLoading = Cell.state<bool>(initial: false);
  final apiResult = Cell.state<String>(initial: 'Ready');

  final apiHandle = Flow.exhaustMap<String, String>(
    apiInput.cell,
    project: (userId) async {
      apiLoading.update(true);
      print('   [State] 🔄 Loading...');
      print('   [API] Fetching profile... (200ms)');
      await Future.delayed(const Duration(milliseconds: 200));

      try {
        final profile = await api.fetchUserProfile(userId);
        apiLoading.update(false);
        final result = '✅ Loaded: ${profile.toString()}';
        apiResult.update(result);
        return result;
      } catch (e) {
        apiLoading.update(false);
        final result = '❌ ${e.toString()}';
        apiResult.update(result);
        return result;
      }
    },
  );

  final apiObserver = Cell.observe(
    source: apiHandle.cell,
    effect: (Pulse p) {
      print('   [State] ${p.payload}');
    },
  );

  print('   [User] Fetch: User Profile');
  await apiInput.emitAsync('user_123');

  print('   [User] Fetch: User Profile (IGNORED - busy)');
  await apiInput.emitAsync('user_123');

  await Future.delayed(const Duration(milliseconds: 300));

  apiObserver.stop();
  print('');

  // ========================================================================
  // 9. Compare exhaustMap vs debounce
  // ========================================================================

  print('9. Compare exhaustMap vs debounce');
  print('   ────────────────────────────────────────────────────────\n');

  final compareInput = Cell.ingress<String>();

  // exhaustMap: ignores while busy
  final exhaustHandle = Flow.exhaustMap<String, String>(
    compareInput.cell,
    project: (value) async {
      await Future.delayed(const Duration(milliseconds: 150));
      return '[exhaustMap] $value';
    },
  );

  // debounce: waits for silence
  final debounceHandle = Flow.debounce<String>(
    compareInput.cell,
    duration: const Duration(milliseconds: 150),
  );

  final debounceResult = Flow.map<String, String>(
    debounceHandle.cell,
    project: (value) => '[debounce] $value',
  );

  // Merge both for comparison
  final compareResults = Flow.mergeWith<String>(
    exhaustHandle.cell,
    others: [debounceResult.cell],
  );

  final compareObserver = Cell.observe(
    source: compareResults.cell,
    effect: (Pulse p) {
      print('   ${p.payload}');
    },
  );

  print('   [User] Quick: A, B, C, D, E');
  for (final char in ['A', 'B', 'C', 'D', 'E']) {
    await compareInput.emitAsync(char);
    await Future.delayed(const Duration(milliseconds: 20));
  }

  await Future.delayed(const Duration(milliseconds: 200));

  print('   exhaustMap: Only the first item processed');
  print('   debounce: Only the last item after silence');

  compareObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: ExhaustMap - Submit, Checkout, Refresh');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Use Case               │  Behavior                                   │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Form Submit            │  Ignore double-taps during submission       │
  │  Checkout               │  Prevent duplicate payment processing       │
  │  Refresh                │  Ignore rapid refresh clicks                │
  │  Error Handling         │  Retry after failure, not during busy       │
  │  Sequential             │  Process items one at a time                │
  │  Shopping Cart          │  Prevent duplicate checkout                 │
  │  Retry Protection       │  Allow retry only when not busy             │
  │  API Requests           │  Show loading state, ignore duplicate calls │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 exhaustMap ignores new triggers while busy
  🔹 Perfect for submit/checkout/refresh buttons
  🔹 Prevents double-taps and race conditions
  🔹 Preserves the first operation (not the last)
  🔹 Automatically handles busy states
  🔹 Great for payment processing
  🔹 Ideal for form submissions
  🔹 Works with any async operation

  When to use exhaustMap:
  - Form submission buttons
  - Checkout/payment processing
  - Refresh/update actions
  - API calls that shouldn't overlap
  - File uploads
  - Database operations
  - Any operation that shouldn't run concurrently
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}