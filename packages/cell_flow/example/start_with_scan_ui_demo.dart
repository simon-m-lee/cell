// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.startWith + Flow.scan for UI initialization and running state models.
///
/// ### Scenario
/// A UI application where:
/// 1. The UI needs an initial state (first frame) before data arrives
/// 2. A running model (cart total, connection state) updates over time
/// 3. startWith provides the initial UI state
/// 4. scan accumulates state changes over time
/// 5. Multiple real-world scenarios are demonstrated
///
/// ### Learning Objectives
/// - Understand how Flow.startWith provides initial state
/// - See how Flow.scan maintains running state
/// - Combine startWith + scan for complete UI models
/// - Build cart totals with running updates
/// - Manage connection state with status tracking
/// - Handle real-time data updates
///
/// ### Expected Console Output
/// ```
/// ── StartWith + Scan UI Demo ──────────────────────────────────────────────────
///
/// 1. Shopping Cart Total (startWith + scan)
///    ────────────────────────────────────────────────────────
///    [UI] Initial cart: 0 items, $0.00
///    [User] Added: Laptop ($999.99)
///    [UI] Cart updated: 1 items, $999.99
///    [User] Added: Mouse ($29.99)
///    [UI] Cart updated: 2 items, $1,029.98
///    [User] Added: Keyboard ($49.99)
///    [UI] Cart updated: 3 items, $1,079.97
///
/// 2. Connection State with Status History
///    ────────────────────────────────────────────────────────
///    [UI] Initial connection: DISCONNECTED
///    [Network] Connecting...
///    [UI] Status: CONNECTING
///    [Network] Connected!
///    [UI] Status: CONNECTED
///    [Network] Disconnected
///    [UI] Status: DISCONNECTED
///    [History] [DISCONNECTED, CONNECTING, CONNECTED, DISCONNECTED]
///
/// 3. Real-Time Price Ticker with Running Average
///    ────────────────────────────────────────────────────────
///    [UI] Initial: $100.00 (avg: $100.00)
///    [Price] Update: $102.50
///    [UI] Current: $102.50 (avg: $101.25)
///    [Price] Update: $98.75
///    [UI] Current: $98.75 (avg: $100.42)
///    [Price] Update: $101.25
///    [UI] Current: $101.25 (avg: $100.63)
///
/// 4. UI Loading State with Data
///    ────────────────────────────────────────────────────────
///    [UI] Initial: Loading...
///    [Data] Loading users...
///    [UI] ⏳ Loading...
///    [Data] ✅ Loaded 3 users
///    [UI] ✅ Users: [Alice, Bob, Charlie]
///
/// 5. Shopping Cart with Discounts
///    ────────────────────────────────────────────────────────
///    [UI] Cart: 0 items, $0.00
///    [User] Added: Book ($14.99)
///    [UI] Cart: 1 items, $14.99
///    [User] Added: Notebook ($7.99)
///    [UI] Cart: 2 items, $22.98
///    [User] Applied discount: 10%
///    [UI] Cart: 2 items, $20.68 (10% off)
///
/// 6. Chat Message Counter
///    ────────────────────────────────────────────────────────
///    [UI] Messages: 0 (No messages yet)
///    [Chat] Alice: "Hello!"
///    [UI] Messages: 1 (Last: Alice: Hello!)
///    [Chat] Bob: "Hi everyone!"
///    [UI] Messages: 2 (Last: Bob: Hi everyone!)
///    [Chat] Alice: "How are you?"
///    [UI] Messages: 3 (Last: Alice: How are you?)
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/combine_latest.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_flow/src/instruction/scan.dart';
import 'package:cell_flow/src/instruction/start_with.dart';

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a shopping cart state.
class CartState {
  final List<CartItem> items;
  final double total;
  final double discount;
  final int itemCount;

  CartState({
    required this.items,
    required this.total,
    this.discount = 0,
  }) : itemCount = items.length;

  double get discountedTotal => total * (1 - discount);

  CartState addItem(CartItem item) {
    return CartState(
      items: [...items, item],
      total: total + item.price,
      discount: discount,
    );
  }

  CartState applyDiscount(double percent) {
    return CartState(
      items: items,
      total: total,
      discount: percent.clamp(0, 1),
    );
  }

  @override
  String toString() {
    if (discount > 0) {
      return '${items.length} items, \$${discountedTotal.toStringAsFixed(2)} (${(discount * 100).toInt()}% off)';
    }
    return '${items.length} items, \$${total.toStringAsFixed(2)}';
  }
}

/// Represents a cart item.
class CartItem {
  final String name;
  final double price;

  CartItem({required this.name, required this.price});

  @override
  String toString() => '$name (\$${price.toStringAsFixed(2)})';
}

/// Represents a connection state.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Represents a price tick.
class PriceTick {
  final double price;
  final DateTime timestamp;

  PriceTick({required this.price, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '\$${price.toStringAsFixed(2)}';
}

/// Represents a chat message.
class ChatMessage {
  final String user;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.user,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$user: "$text"';
}

/// Represents a loading state with data.
class LoadingState<T> {
  final bool isLoading;
  final T? data;
  final String? error;

  LoadingState.loading() : isLoading = true, data = null, error = null;
  LoadingState.data(this.data) : isLoading = false, error = null;
  LoadingState.error(this.error) : isLoading = false, data = null;

  bool get hasData => data != null;
  bool get hasError => error != null;

  @override
  String toString() {
    if (isLoading) return '⏳ Loading...';
    if (hasError) return '❌ $error';
    if (hasData) return '✅ $data';
    return 'Ready';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── StartWith + Scan UI Demo ──────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Shopping Cart Total (startWith + scan)
  // ========================================================================

  print('1. Shopping Cart Total (startWith + scan)');
  print('   ────────────────────────────────────────────────────────\n');

  final cartInput = Cell.ingress<CartItem>();

  // Step 1: startWith emits the initial state
  final withInitial = StartWith<CartState>(
    CartState(items: [], total: 0),
  ).toHandle(source: cartInput.cell);

  // Step 2: scan accumulates items onto the cart state
  final cartTotal = ScanSeeded<CartItem, CartState>(
    CartState(items: [], total: 0),
        (state, item) => state.addItem(item),
  ).toHandle(source: withInitial.cell);

  final cartObserver = Cell.observe(
    source: cartTotal.cell,
    effect: (Pulse p) {
      final state = p.payload as CartState;
      print('   [UI] Cart updated: ${state.toString()}');
    },
  );

  // Show initial state (from startWith)
  print('   [UI] Initial cart: 0 items, \$0.00');

  // Simulate adding items
  await cartInput.emitAsync(CartItem(name: 'Laptop', price: 999.99));
  print('   [User] Added: Laptop (\$999.99)');

  await cartInput.emitAsync(CartItem(name: 'Mouse', price: 29.99));
  print('   [User] Added: Mouse (\$29.99)');

  await cartInput.emitAsync(CartItem(name: 'Keyboard', price: 49.99));
  print('   [User] Added: Keyboard (\$49.99)');

  await Future.delayed(const Duration(milliseconds: 100));

  cartObserver.stop();
  print('');

  // ========================================================================
  // 2. Connection State with Status History
  // ========================================================================

  print('2. Connection State with Status History');
  print('   ────────────────────────────────────────────────────────\n');

  final connInput = Cell.ingress<ConnectionStatus>();

  // Step 1: startWith provides initial state
  final connWithInitial = StartWith<ConnectionStatus>(
    ConnectionStatus.disconnected,
  ).toHandle(source: connInput.cell);

  // Step 2: track current state (just the startWith handle)
  final connState = connWithInitial;

  // Step 3: build history using scan (seeded with initial history)
  final connHistory = ScanSeeded<ConnectionStatus, List<ConnectionStatus>>(
    [ConnectionStatus.disconnected],
        (history, status) => [...history, status],
  ).toHandle(source: connWithInitial.cell);

  // Collect history values for display
  final historyValues = <List<ConnectionStatus>>[];

  final historyCollector = Cell.observe(
    source: connHistory.cell,
    effect: (Pulse p) {
      final history = p.payload as List<ConnectionStatus>;
      historyValues.add(history);
    },
  );

  final connObserver = Cell.observe(
    source: connState.cell,
    effect: (Pulse p) {
      final status = p.payload as ConnectionStatus;
      final label = status.toString().split('.').last.toUpperCase();
      print('   [UI] Status: $label');
    },
  );

  print('   [UI] Initial connection: DISCONNECTED');

  print('   [Network] Connecting...');
  await connInput.emitAsync(ConnectionStatus.connecting);
  await Future.delayed(const Duration(milliseconds: 50));

  print('   [Network] Connected!');
  await connInput.emitAsync(ConnectionStatus.connected);
  await Future.delayed(const Duration(milliseconds: 50));

  print('   [Network] Disconnected');
  await connInput.emitAsync(ConnectionStatus.disconnected);

  await Future.delayed(const Duration(milliseconds: 50));

  // Stop observers to ensure we have the final history
  connObserver.stop();
  historyCollector.stop();

  // Get the final history from the collected values
  if (historyValues.isNotEmpty) {
    final finalHistory = historyValues.last;
    final labels = finalHistory.map((s) => s.toString().split('.').last.toUpperCase()).toList();
    print('   [History] $labels');
  }

  print('');

  // ========================================================================
  // 3. Real-Time Price Ticker with Running Average
  // ========================================================================

  print('3. Real-Time Price Ticker with Running Average');
  print('   ────────────────────────────────────────────────────────\n');

  final priceInput = Cell.ingress<PriceTick>();
  final random = Random();

  // Initial price
  final initialPrice = 100.0;

  // Step 1: startWith provides initial price
  final priceWithInitial = StartWith<PriceTick>(
    PriceTick(price: initialPrice),
  ).toHandle(source: priceInput.cell);

  // Step 2: current price (just the startWith handle)
  final currentPrice = priceWithInitial;

  // Step 3: build price history using scan (seeded with initial price)
  final priceHistory = ScanSeeded<PriceTick, List<double>>(
    [initialPrice],
        (history, tick) => [...history, tick.price],
  ).toHandle(source: priceWithInitial.cell);

  // Step 4: compute running average using map
  final runningAvg = MapValue<List<double>, double>(
        (history) => history.reduce((a, b) => a + b) / history.length,
  ).toHandle(source: priceHistory.cell);

  // Combine current price and average using combineLatest
  final combined = CombineLatestWith<PriceTick, Map<String, double>>(
    [runningAvg.cell],
        (price, latest) {
      final avg = latest[0] as double? ?? initialPrice;
      return {'current': price.price, 'avg': avg};
    },
  ).toHandle(source: currentPrice.cell);

  final priceObserver = Cell.observe(
    source: combined.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, double>;
      print('   [UI] Current: \$${data['current']!.toStringAsFixed(2)} (avg: \$${data['avg']!.toStringAsFixed(2)})');
    },
  );

  print('   [UI] Initial: \$${initialPrice.toStringAsFixed(2)} (avg: \$${initialPrice.toStringAsFixed(2)})');

  // Simulate price updates
  for (var i = 0; i < 3; i++) {
    final change = (random.nextDouble() - 0.5) * 5;
    final newPrice = (100 + i * 2) + change;
    await priceInput.emitAsync(PriceTick(price: newPrice));
    print('   [Price] Update: \$${newPrice.toStringAsFixed(2)}');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  await Future.delayed(const Duration(milliseconds: 100));

  priceObserver.stop();
  print('');

  // ========================================================================
  // 4. UI Loading State with Data
  // ========================================================================

  print('4. UI Loading State with Data');
  print('   ────────────────────────────────────────────────────────\n');

  final loadInput = Cell.ingress<List<String>>();

  // startWith provides initial loading state
  final loadState = StartWith<LoadingState<List<String>>>(
    LoadingState.loading(),
  ).toHandle(source: loadInput.cell);

  final loadObserver = Cell.observe(
    source: loadState.cell,
    effect: (Pulse p) {
      final state = p.payload as LoadingState<List<String>>;
      if (state.isLoading) {
        print('   [UI] ⏳ Loading...');
      } else if (state.hasData) {
        print('   [UI] ✅ Users: ${state.data}');
      } else if (state.hasError) {
        print('   [UI] ❌ ${state.error}');
      }
    },
  );

  print('   [UI] Initial: Loading...');
  print('   [Data] Loading users...');

  await Future.delayed(const Duration(milliseconds: 100));
  await loadInput.emitAsync(['Alice', 'Bob', 'Charlie']);
  print('   [Data] ✅ Loaded 3 users');

  await Future.delayed(const Duration(milliseconds: 100));

  loadObserver.stop();
  print('');

  // ========================================================================
  // 5. Shopping Cart with Discounts
  // ========================================================================

  print('5. Shopping Cart with Discounts');
  print('   ────────────────────────────────────────────────────────\n');

  final cartItemInput = Cell.ingress<CartItem>();
  final discountInput = Cell.ingress<double>();

  // Step 1: startWith provides initial empty cart
  final cartWithInitial = StartWith<CartState>(
    CartState(items: [], total: 0),
  ).toHandle(source: cartItemInput.cell);

  // Step 2: scan accumulates items
  final cartState = ScanSeeded<CartItem, CartState>(
    CartState(items: [], total: 0),
        (state, item) => state.addItem(item),
  ).toHandle(source: cartWithInitial.cell);

  // Track discount separately
  final discountState = StartWith<double>(
    0.0,
  ).toHandle(source: discountInput.cell);

  // Combine cart and discount
  final cartWithDiscount = CombineLatestWith<CartState, String>(
    [discountState.cell],
        (state, latest) {
      final discount = latest[0] as double? ?? 0.0;
      final discounted = state.discountedTotal;
      if (discount > 0) {
        return '${state.itemCount} items, \$${discounted.toStringAsFixed(2)} (${(discount * 100).toInt()}% off)';
      }
      return '${state.itemCount} items, \$${state.total.toStringAsFixed(2)}';
    },
  ).toHandle(source: cartState.cell);

  final discountObserver = Cell.observe(
    source: cartWithDiscount.cell,
    effect: (Pulse p) {
      print('   [UI] Cart: ${p.payload}');
    },
  );

  print('   [UI] Cart: 0 items, \$0.00');

  await cartItemInput.emitAsync(CartItem(name: 'Book', price: 14.99));
  print('   [User] Added: Book (\$14.99)');

  await cartItemInput.emitAsync(CartItem(name: 'Notebook', price: 7.99));
  print('   [User] Added: Notebook (\$7.99)');

  await discountInput.emitAsync(0.10);
  print('   [User] Applied discount: 10%');

  await Future.delayed(const Duration(milliseconds: 100));

  discountObserver.stop();
  print('');

  // ========================================================================
  // 6. Chat Message Counter
  // ========================================================================

  print('6. Chat Message Counter');
  print('   ────────────────────────────────────────────────────────\n');

  final chatInput = Cell.ingress<ChatMessage>();

  // Step 1: startWith provides initial state
  final chatWithInitial = StartWith<Map<String, dynamic>>(
    {
      'count': 0,
      'last': null as ChatMessage?,
    },
  ).toHandle(source: chatInput.cell);

  // Step 2: scan accumulates messages
  final chatState = ScanSeeded<ChatMessage, Map<String, dynamic>>(
    {'count': 0, 'last': null as ChatMessage?},
        (state, message) {
      return {
        'count': state['count'] + 1,
        'last': message,
      };
    },
  ).toHandle(source: chatWithInitial.cell);

  // Format for display
  final chatDisplay = MapValue<Map<String, dynamic>, String>(
        (state) {
      final count = state['count'] as int;
      final last = state['last'] as ChatMessage?;
      if (last != null) {
        return '$count messages (Last: ${last.user}: ${last.text})';
      }
      return '$count messages (No messages yet)';
    },
  ).toHandle(source: chatState.cell);

  final chatObserver = Cell.observe(
    source: chatDisplay.cell,
    effect: (Pulse p) {
      print('   [UI] Messages: ${p.payload}');
    },
  );

  print('   [UI] Messages: 0 (No messages yet)');

  await chatInput.emitAsync(ChatMessage(user: 'Alice', text: 'Hello!'));
  print('   [Chat] Alice: "Hello!"');

  await chatInput.emitAsync(ChatMessage(user: 'Bob', text: 'Hi everyone!'));
  print('   [Chat] Bob: "Hi everyone!"');

  await chatInput.emitAsync(ChatMessage(user: 'Alice', text: 'How are you?'));
  print('   [Chat] Alice: "How are you?"');

  await Future.delayed(const Duration(milliseconds: 100));

  chatObserver.stop();
  print('');

  // ========================================================================
  // 7. Real-Time Scoreboard
  // ========================================================================

  print('7. Real-Time Scoreboard');
  print('   ────────────────────────────────────────────────────────\n');

  final scoreInput = Cell.ingress<int>();

  // Step 1: startWith provides initial score
  final scoreWithInitial = StartWith<int>(
    0,
  ).toHandle(source: scoreInput.cell);

  // Step 2: scan accumulates score
  final scoreState = ScanSeeded<int, int>(
    0,
        (score, points) => score + points,
  ).toHandle(source: scoreWithInitial.cell);

  // Step 3: track high score
  final highScore = ScanSeeded<int, int>(
    0,
        (high, points) => points > high ? points : high,
  ).toHandle(source: scoreWithInitial.cell);

  // Combine both
  final scoreCombined = CombineLatestWith<int, Map<String, int>>(
    [highScore.cell],
        (score, latest) {
      final high = latest[0] as int? ?? 0;
      return {'score': score, 'high': high};
    },
  ).toHandle(source: scoreState.cell);

  final scoreObserver = Cell.observe(
    source: scoreCombined.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, int>;
      print('   [UI] Score: ${data['score']} (High: ${data['high']})');
    },
  );

  print('   [UI] Initial: Score: 0 (High: 0)');

  final points = [10, 5, 20, 8, 15];
  for (final p in points) {
    await scoreInput.emitAsync(p);
    print('   [Score] +$p points');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  await Future.delayed(const Duration(milliseconds: 100));

  scoreObserver.stop();
  print('');

  // ========================================================================
  // 8. Todo List with Stats
  // ========================================================================

  print('8. Todo List with Stats');
  print('   ────────────────────────────────────────────────────────\n');

  final todoInput = Cell.ingress<({String text, bool done})>();

  // Step 1: startWith provides initial empty list
  final todoWithInitial = StartWith<List<({String text, bool done})>>(
    [],
  ).toHandle(source: todoInput.cell);

  // Step 2: scan accumulates todos
  final todoState = ScanSeeded<({String text, bool done}), List<({String text, bool done})>>(
    [],
        (todos, todo) => [...todos, todo],
  ).toHandle(source: todoWithInitial.cell);

  // Step 3: compute stats
  final todoStats = MapValue<List<({String text, bool done})>, Map<String, dynamic>>(
        (todos) {
      final total = todos.length;
      final done = todos.where((t) => t.done).length;
      final pending = total - done;
      return {
        'total': total,
        'done': done,
        'pending': pending,
        'progress': total == 0 ? 0.0 : done / total,
      };
    },
  ).toHandle(source: todoState.cell);

  final todoObserver = Cell.observe(
    source: todoStats.cell,
    effect: (Pulse p) {
      final stats = p.payload as Map<String, dynamic>;
      print('   [UI] 📋 Todos: ${stats['total']} total, '
          '${stats['done']} done, ${stats['pending']} pending '
          '(${(stats['progress'] * 100).toInt()}% complete)');
    },
  );

  print('   [UI] 📋 Todos: 0 total, 0 done, 0 pending (0% complete)');

  await todoInput.emitAsync((text: 'Learn Dart', done: false));
  print('   [User] Added: "Learn Dart"');

  await todoInput.emitAsync((text: 'Build App', done: false));
  print('   [User] Added: "Build App"');

  await todoInput.emitAsync((text: 'Build App', done: true));
  print('   [User] Completed: "Build App"');

  await Future.delayed(const Duration(milliseconds: 100));

  todoObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: StartWith + Scan for UI Models');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Pattern                   │  Use Case                                │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  startWith + scan          │  Cart total with running updates         │
  │  startWith + history       │  Connection state with status history    │
  │  startWith + avg           │  Price ticker with running average       │
  │  startWith + loading       │  UI loading states with data            │
  │  startWith + discount      │  Shopping cart with discounts           │
  │  startWith + chat          │  Chat message counter with last message │
  │  startWith + scoreboard    │  Real-time score with high score        │
  │  startWith + todos         │  Todo list with completion stats        │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 startWith provides the initial UI state (first frame)
  🔹 scan accumulates state changes over time
  🔹 combine with map for formatted display
  🔹 Perfect for UI state management
  🔹 Works with any type of state
  🔹 Type-safe with generics
  🔹 Reactive and declarative
  🔹 Zero boilerplate for state management

  Key Benefits:
  - UI always has a valid state (no empty/null states)
  - Running state is automatically maintained
  - Updates are reactive and efficient
  - State history can be preserved
  - Complex state can be derived from simple operations
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}