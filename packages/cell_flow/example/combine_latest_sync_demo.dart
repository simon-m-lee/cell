// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A real-life practical executable walkthrough demonstrating the use of
/// Flow.combineLatest for real-time data synchronization and aggregation.
///
/// ### Scenario
/// A real-time dashboard and monitoring system where:
/// 1. Multiple data sources update independently
/// 2. combineLatest combines the latest values from all sources
/// 3. Real-time UI updates when any source changes
/// 4. Data consistency is maintained across sources
/// 5. Complex aggregations are computed reactively
/// 6. Multiple combine patterns are demonstrated
///
/// ### Learning Objectives
/// - Understand how Flow.combineLatest works
/// - Combine multiple reactive sources
/// - Build real-time dashboards
/// - Maintain data consistency
/// - Handle partial updates
/// - Create complex aggregations
///
/// ### Expected Console Output
/// ```
/// ── Real-Time Data Sync Demo ──────────────────────────────────────────────
///
/// 1. Basic combineLatest - Two Sources
///    ────────────────────────────────────────────────────────
///    [Source A] Updated: 10
///    [Source B] Updated: hello
///    [Combined] A: 10, B: hello
///    [Source A] Updated: 20
///    [Combined] A: 20, B: hello
///
/// 2. Real-Time Dashboard Metrics
///    ────────────────────────────────────────────────────────
///    📊 Dashboard State:
///    - Users: 1,234
///    - Requests: 45.6/s
///    - Response: 23ms
///    - Errors: 1.2%
///    [Update] Dashboard refreshed
///
/// 3. Multi-Source Form Validation
///    ────────────────────────────────────────────────────────
///    [Form] Email: 'test@example.com' ✅ Valid
///    [Form] Password: 'pass123' ✅ Valid
///    [Form] Confirm: 'pass123' ✅ Valid
///    [Form] Form is VALID and ready to submit
///
/// 4. Financial Price Aggregation
///    ────────────────────────────────────────────────────────
///    📈 Portfolio Value: $1,234.56
///    - AAPL: $150.25 (2.3% ↗)
///    - GOOGL: $2,800.50 (1.2% ↗)
///    - TSLA: $700.75 (0.5% ↘)
///    Portfolio updated at 12:34:56
///
/// 5. System Health Monitor
///    ────────────────────────────────────────────────────────
///    🏥 System Health: HEALTHY
///    - CPU: 45.2% ✅
///    - Memory: 62.8% ✅
///    - Disk: 78.5% ⚠️
///    - Network: 234 Mbps ✅
///    [Alert] Disk usage approaching limit
///
/// 6. Multi-Source Search
///    ────────────────────────────────────────────────────────
///    🔍 Search: "dart"
///    Filters: [type: book, sort: relevance]
///    Results: 42 items found
///    Query: 'dart' (book) - 42 results
///
/// 7. User Preferences Sync
///    ────────────────────────────────────────────────────────
///    User: alice@example.com
///    Theme: dark
///    Language: en-US
///    Notifications: on
///    Preferences saved at 12:34:56
///
/// 8. Real-Time Chat Aggregation
///    ────────────────────────────────────────────────────────
///    💬 Chat Summary:
///    - Total Messages: 1,234
///    - Active Users: 56
///    - Unread: 12
///    - Last Message: "Hello everyone!"
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:math';
import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/combine_latest.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/from_stream.dart';
import 'package:cell_flow/src/instruction/map.dart';

// ignore_for_file: unused_element, unused_field, unused_local_variable

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a dashboard metric.
class DashboardMetric {
  final String name;
  final double value;
  final String unit;
  final String status;
  final DateTime timestamp;

  DashboardMetric({
    required this.name,
    required this.value,
    this.unit = '',
    this.status = 'normal',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$name: ${value.toStringAsFixed(1)}$unit ($status)';
}

/// Represents a form field with validation.
class FormField<T> {
  final T value;
  final bool isValid;
  final String? error;
  final DateTime timestamp;

  FormField({
    required this.value,
    this.isValid = true,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'Field($value) - ${isValid ? "✅" : "❌"} ${error ?? ""}';
}

/// Represents a stock price.
class StockPrice {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final DateTime timestamp;

  StockPrice({
    required this.symbol,
    required this.price,
    this.change = 0,
    this.changePercent = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get changeIndicator => change >= 0 ? '↗' : '↘';

  @override
  String toString() => '$symbol: \$${price.toStringAsFixed(2)} (${changePercent.toStringAsFixed(1)}% $changeIndicator)';
}

/// Represents a system health check.
class SystemHealth {
  final String component;
  final double value;
  final String status;
  final String threshold;
  final DateTime timestamp;

  SystemHealth({
    required this.component,
    required this.value,
    required this.status,
    required this.threshold,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHealthy => status == 'healthy';
  bool get isWarning => status == 'warning';
  bool get isCritical => status == 'critical';

  @override
  String toString() => '$component: ${value.toStringAsFixed(1)}% ($status)';
}

/// Represents a chat message.
class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    DateTime? timestamp,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '$userName: $content';
}

/// Represents search query with filters.
class SearchQuery {
  final String text;
  final String type;
  final String sortBy;
  final int limit;

  SearchQuery({
    this.text = '',
    this.type = 'all',
    this.sortBy = 'relevance',
    this.limit = 20,
  });

  @override
  String toString() => "'$text' (type: $type, sort: $sortBy)";
}

// ─────────────────────────────────────────────────────────────────────
// Data Source Simulators
// ─────────────────────────────────────────────────────────────────────

/// Simulates a data source with periodic updates.
class DataSourceSimulator<T> {
  final StreamController<T> _controller;
  Timer? _timer;
  final List<T> _values;
  int _index = 0;
  final Duration interval;

  DataSourceSimulator({
    required List<T> initialValues,
    this.interval = const Duration(seconds: 1),
  })  : _values = initialValues,
        _controller = StreamController<T>.broadcast();

  Stream<T> get stream => _controller.stream;

  void start() {
    _timer = Timer.periodic(interval, (_) {
      if (_values.isEmpty) return;
      _index = (_index + 1) % _values.length;
      _controller.add(_values[_index]);
    });
    // Emit initial value
    if (_values.isNotEmpty) {
      _controller.add(_values[0]);
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }

  void update(T value) {
    _values[_index] = value;
    _controller.add(value);
  }
}

/// Simulates a stock price source.
class StockSimulator {
  final Random _random = Random();
  final Map<String, double> _prices = {};
  final Map<String, double> _prevPrices = {};
  final StreamController<StockPrice> _controller;
  Timer? _timer;

  StockSimulator() : _controller = StreamController<StockPrice>.broadcast();

  Stream<StockPrice> get stream => _controller.stream;

  void start() {
    // Initialize stocks
    final stocks = ['AAPL', 'GOOGL', 'TSLA', 'MSFT', 'AMZN'];
    for (final symbol in stocks) {
      _prices[symbol] = 100 + _random.nextDouble() * 500;
      _prevPrices[symbol] = _prices[symbol]!;
    }

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      for (final symbol in _prices.keys) {
        final change = (_random.nextDouble() - 0.5) * 10;
        _prevPrices[symbol] = _prices[symbol]!;
        _prices[symbol] = _prices[symbol]! + change;

        final stock = StockPrice(
          symbol: symbol,
          price: _prices[symbol]!,
          change: change,
          changePercent: (change / _prevPrices[symbol]!) * 100,
        );
        _controller.add(stock);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── Real-Time Data Sync Demo ──────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic combineLatest - Two Sources
  // ========================================================================

  print('1. Basic combineLatest - Two Sources');
  print('   ────────────────────────────────────────────────────────\n');

  final sourceA = Cell.ingress<int>();
  final sourceB = Cell.ingress<String>();

  // CombineLatestWith takes 2 type parameters: <S, R>
  // S is the source type (int), R is the result type (String)
  final combined = Flow.combineLatestWith<int, String>(
    sourceA.cell,
    others: [sourceB.cell],
    combine: (a, latest) {
      final bValue = latest.isNotEmpty ? latest[0] as String : 'empty';
      return 'A: $a, B: $bValue';
    },
  );

  final combinedObserver = Cell.observe(
    source: combined.cell,
    effect: (Pulse p) {
      print('   [Combined] ${p.payload}');
    },
  );

  print('   [Source A] Updated: 10');
  await sourceA.emitAsync(10);

  print('   [Source B] Updated: hello');
  await sourceB.emitAsync('hello');

  print('   [Source A] Updated: 20');
  await sourceA.emitAsync(20);

  await Future.delayed(const Duration(milliseconds: 100));

  combinedObserver.stop();
  print('');

  // ========================================================================
  // 2. Real-Time Dashboard Metrics
  // ========================================================================

  print('2. Real-Time Dashboard Metrics');
  print('   ────────────────────────────────────────────────────────\n');

  final usersMetric = Cell.ingress<int>();
  final requestsMetric = Cell.ingress<double>();
  final responseMetric = Cell.ingress<int>();
  final errorsMetric = Cell.ingress<double>();

  // Combine all metrics into a dashboard state
  final dashboard = Flow.combineLatestWith<int, Map<String, dynamic>>(
    usersMetric.cell,
    others: [requestsMetric.cell, responseMetric.cell, errorsMetric.cell],
    combine: (users, latest) {
      return {
        'users': users,
        'requests': latest[0] as double? ?? 0.0,
        'response': latest[1] as int? ?? 0,
        'errors': latest[2] as double? ?? 0.0,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final dashboardObserver = Cell.observe(
    source: dashboard.cell,
    effect: (Pulse p) {
      final state = p.payload as Map<String, dynamic>;
      print('   📊 Dashboard State:');
      print('   - Users: ${state['users']}');
      print('   - Requests: ${(state['requests'] as double).toStringAsFixed(1)}/s');
      print('   - Response: ${state['response']}ms');
      print('   - Errors: ${(state['errors'] as double).toStringAsFixed(1)}%');
      print('   [Update] Dashboard refreshed');
    },
  );

  // Simulate metric updates
  await usersMetric.emitAsync(1234);
  await Future.delayed(const Duration(milliseconds: 100));
  await requestsMetric.emitAsync(45.6);
  await Future.delayed(const Duration(milliseconds: 100));
  await responseMetric.emitAsync(23);
  await Future.delayed(const Duration(milliseconds: 100));
  await errorsMetric.emitAsync(1.2);

  await Future.delayed(const Duration(milliseconds: 200));

  dashboardObserver.stop();
  print('');

  // ========================================================================
  // 3. Multi-Source Form Validation
  // ========================================================================

  print('3. Multi-Source Form Validation');
  print('   ────────────────────────────────────────────────────────\n');

  final emailInput = Cell.ingress<String>();
  final passwordInput = Cell.ingress<String>();
  final confirmInput = Cell.ingress<String>();

  // Combine form fields for validation
  final formValidation = Flow.combineLatestWith<String, Map<String, dynamic>>(
    emailInput.cell,
    others: [passwordInput.cell, confirmInput.cell],
    combine: (email, latest) {
      final password = latest[0] as String? ?? '';
      final confirm = latest[1] as String? ?? '';

      final isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
      final isPasswordValid = password.length >= 6;
      final doPasswordsMatch = password == confirm;

      return {
        'email': email,
        'password': password,
        'confirm': confirm,
        'emailValid': isEmailValid,
        'passwordValid': isPasswordValid,
        'passwordsMatch': doPasswordsMatch,
        'isValid': isEmailValid && isPasswordValid && doPasswordsMatch,
      };
    },
  );

  final formObserver = Cell.observe(
    source: formValidation.cell,
    effect: (Pulse p) {
      final state = p.payload as Map<String, dynamic>;
      print('   [Form] Email: \'${state['email']}\' ${state['emailValid'] ? '✅' : '❌'} Valid');
      print('   [Form] Password: \'${'*' * (state['password'] as String).length}\' ${state['passwordValid'] ? '✅' : '❌'} Valid');
      print('   [Form] Confirm: \'${'*' * (state['confirm'] as String).length}\' ${state['passwordsMatch'] ? '✅' : '❌'} Valid');

      if (state['isValid'] as bool) {
        print('   [Form] Form is VALID and ready to submit');
      } else {
        print('   [Form] Form is INVALID - please fix errors');
      }
    },
  );

  // Simulate form input
  await emailInput.emitAsync('test@example.com');
  await Future.delayed(const Duration(milliseconds: 100));
  await passwordInput.emitAsync('pass123');
  await Future.delayed(const Duration(milliseconds: 100));
  await confirmInput.emitAsync('pass123');

  await Future.delayed(const Duration(milliseconds: 200));

  formObserver.stop();
  print('');

  // ========================================================================
  // 4. Financial Price Aggregation
  // ========================================================================

  print('4. Financial Price Aggregation');
  print('   ────────────────────────────────────────────────────────\n');

  final stockSimulator = StockSimulator();

  // Bridge the stock stream
  final stockInput = Cell.ingress<void>();
  final stockHandle = Flow.fromStream<StockPrice>(
    stockInput.cell,
    stream: stockSimulator.stream,
  );

  // Create individual stock streams by filtering
  final aaplStream = Flow.filter<StockPrice>(
    stockHandle.cell,
    test: (stock) => stock.symbol == 'AAPL',
  );

  final googlStream = Flow.filter<StockPrice>(
    stockHandle.cell,
    test: (stock) => stock.symbol == 'GOOGL',
  );

  final tslaStream = Flow.filter<StockPrice>(
    stockHandle.cell,
    test: (stock) => stock.symbol == 'TSLA',
  );

  // Combine all stock prices into a portfolio
  final portfolio = Flow.combineLatestWith<StockPrice, Map<String, dynamic>>(
    aaplStream.cell,
    others: [googlStream.cell, tslaStream.cell],
    combine: (aapl, latest) {
      final googl = latest[0] as StockPrice?;
      final tsla = latest[1] as StockPrice?;

      final stocks = [aapl, googl, tsla].whereType<StockPrice>().toList();
      final totalValue = stocks.fold(0.0, (sum, s) => sum + s.price);
      final avgChange = stocks.isEmpty ? 0.0 : stocks.fold(0.0, (sum, s) => sum + s.changePercent) / stocks.length;

      return {
        'stocks': stocks,
        'totalValue': totalValue,
        'avgChange': avgChange,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final portfolioObserver = Cell.observe(
    source: portfolio.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final stocks = data['stocks'] as List<StockPrice>;

      print('   📈 Portfolio Value: \$${(data['totalValue'] as double).toStringAsFixed(2)}');
      for (final stock in stocks) {
        print('   - ${stock.symbol}: \$${stock.price.toStringAsFixed(2)} (${stock.changePercent.toStringAsFixed(1)}% ${stock.changeIndicator})');
      }
      print('   Portfolio updated at ${DateTime.now().toIso8601String().substring(11, 19)}');
    },
  );

  // Start the stock simulator
  await stockInput.emitAsync(null);
  stockSimulator.start();

  await Future.delayed(const Duration(seconds: 6));

  stockSimulator.stop();
  portfolioObserver.stop();
  print('');

  // ========================================================================
  // 5. System Health Monitor
  // ========================================================================

  print('5. System Health Monitor');
  print('   ────────────────────────────────────────────────────────\n');

  final cpuInput = Cell.ingress<SystemHealth>();
  final memoryInput = Cell.ingress<SystemHealth>();
  final diskInput = Cell.ingress<SystemHealth>();
  final networkInput = Cell.ingress<SystemHealth>();

  // Combine health metrics
  final healthMonitor = Flow.combineLatestWith<SystemHealth, Map<String, dynamic>>(
    cpuInput.cell,
    others: [memoryInput.cell, diskInput.cell, networkInput.cell],
    combine: (cpu, latest) {
      final memory = latest[0] as SystemHealth?;
      final disk = latest[1] as SystemHealth?;
      final network = latest[2] as SystemHealth?;

      final components = [cpu, memory, disk, network].whereType<SystemHealth>().toList();
      final healthy = components.every((c) => c.isHealthy);
      final warning = components.any((c) => c.isWarning);
      final critical = components.any((c) => c.isCritical);

      String overallStatus;
      if (critical) {
        overallStatus = 'CRITICAL';
      } else if (warning) {
        overallStatus = 'WARNING';
      } else if (healthy) {
        overallStatus = 'HEALTHY';
      } else {
        overallStatus = 'UNKNOWN';
      }

      // Generate alerts
      final alerts = <String>[];
      for (final component in components) {
        if (component.isWarning) {
          alerts.add('${component.component} usage approaching limit (${component.value.toStringAsFixed(1)}%)');
        }
        if (component.isCritical) {
          alerts.add('🚨 ${component.component} usage exceeded threshold (${component.value.toStringAsFixed(1)}%)');
        }
      }

      return {
        'components': components,
        'status': overallStatus,
        'alerts': alerts,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final healthObserver = Cell.observe(
    source: healthMonitor.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final status = data['status'] as String;
      final components = data['components'] as List<SystemHealth>;
      final alerts = data['alerts'] as List<String>;

      final statusIcon = status == 'HEALTHY' ? '✅' : status == 'WARNING' ? '⚠️' : '🚨';
      print('   🏥 System Health: $statusIcon $status');

      for (final component in components) {
        final icon = component.isHealthy ? '✅' : component.isWarning ? '⚠️' : '🚨';
        print('   - ${component.component}: ${component.value.toStringAsFixed(1)}% $icon');
      }

      for (final alert in alerts) {
        if (alert.contains('🚨')) {
          print('   $alert');
        } else {
          print('   [Alert] $alert');
        }
      }
    },
  );

  // Simulate health metrics
  await cpuInput.emitAsync(SystemHealth(
    component: 'CPU',
    value: 45.2,
    status: 'healthy',
    threshold: '80%',
  ));

  await memoryInput.emitAsync(SystemHealth(
    component: 'Memory',
    value: 62.8,
    status: 'healthy',
    threshold: '90%',
  ));

  await diskInput.emitAsync(SystemHealth(
    component: 'Disk',
    value: 78.5,
    status: 'warning',
    threshold: '75%',
  ));

  await networkInput.emitAsync(SystemHealth(
    component: 'Network',
    value: 234.0,
    status: 'healthy',
    threshold: '1000 Mbps',
  ));

  await Future.delayed(const Duration(milliseconds: 200));

  healthObserver.stop();
  print('');

  // ========================================================================
  // 6. Multi-Source Search
  // ========================================================================

  print('6. Multi-Source Search');
  print('   ────────────────────────────────────────────────────────\n');

  final searchText = Cell.ingress<String>();
  final searchType = Cell.ingress<String>();
  final searchSort = Cell.ingress<String>();

  // Combine search parameters
  final searchCombined = Flow.combineLatestWith<String, Map<String, dynamic>>(
    searchText.cell,
    others: [searchType.cell, searchSort.cell],
    combine: (text, latest) {
      final type = latest[0] as String? ?? 'all';
      final sort = latest[1] as String? ?? 'relevance';

      // Simulate search results based on parameters
      final resultCount = text.isEmpty ? 0 : 10 + text.length * 5;

      return {
        'query': text,
        'type': type,
        'sort': sort,
        'results': resultCount,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final searchObserver = Cell.observe(
    source: searchCombined.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   🔍 Search: "${data['query']}"');
      print('   Filters: [type: ${data['type']}, sort: ${data['sort']}]');
      print('   Results: ${data['results']} items found');
      print('   Query: \'${data['query']}\' (${data['type']}) - ${data['results']} results');
    },
  );

  // Simulate search updates
  await searchText.emitAsync('dart');
  await Future.delayed(const Duration(milliseconds: 100));
  await searchType.emitAsync('book');
  await Future.delayed(const Duration(milliseconds: 100));
  await searchSort.emitAsync('relevance');

  await Future.delayed(const Duration(milliseconds: 200));

  searchObserver.stop();
  print('');

  // ========================================================================
  // 7. User Preferences Sync
  // ========================================================================

  print('7. User Preferences Sync');
  print('   ────────────────────────────────────────────────────────\n');

  final userEmail = Cell.ingress<String>();
  final userTheme = Cell.ingress<String>();
  final userLanguage = Cell.ingress<String>();
  final userNotifications = Cell.ingress<bool>();

  // Combine user preferences
  final preferences = Flow.combineLatestWith<String, Map<String, dynamic>>(
    userEmail.cell,
    others: [userTheme.cell, userLanguage.cell, userNotifications.cell],
    combine: (email, latest) {
      final theme = latest[0] as String? ?? 'light';
      final language = latest[1] as String? ?? 'en-US';
      final notifications = latest[2] as bool? ?? true;

      return {
        'email': email,
        'theme': theme,
        'language': language,
        'notifications': notifications,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final prefObserver = Cell.observe(
    source: preferences.cell,
    effect: (Pulse p) {
      final prefs = p.payload as Map<String, dynamic>;
      print('   User: ${prefs['email']}');
      print('   Theme: ${prefs['theme']}');
      print('   Language: ${prefs['language']}');
      print('   Notifications: ${prefs['notifications'] ? "on" : "off"}');
      print('   Preferences saved at ${DateTime.now().toIso8601String().substring(11, 19)}');
    },
  );

  // Simulate preference updates
  await userEmail.emitAsync('alice@example.com');
  await Future.delayed(const Duration(milliseconds: 100));
  await userTheme.emitAsync('dark');
  await Future.delayed(const Duration(milliseconds: 100));
  await userLanguage.emitAsync('en-US');
  await Future.delayed(const Duration(milliseconds: 100));
  await userNotifications.emitAsync(true);

  await Future.delayed(const Duration(milliseconds: 200));

  prefObserver.stop();
  print('');

  // ========================================================================
  // 8. Real-Time Chat Aggregation
  // ========================================================================

  print('8. Real-Time Chat Aggregation');
  print('   ────────────────────────────────────────────────────────\n');

  final chatSimulator = _ChatSimulator();
  final chatInput = Cell.ingress<void>();

  final chatHandle = Flow.fromStream<ChatMessage>(
    chatInput.cell,
    stream: chatSimulator.stream,
  );

  // Create aggregated metrics
  final chatCount = Cell.state<int>(initial: 0);
  final activeUsers = Cell.state<Set<String>>(initial: {});
  final unreadCount = Cell.state<int>(initial: 0);
  final lastMessage = Cell.state<String>(initial: 'No messages yet');

  // Update metrics from chat stream
  final chatAggregator = Flow.map<ChatMessage, Map<String, dynamic>>(
    chatHandle.cell,
    project: (message) {
      // Update counts
      chatCount.update((chatCount.cell.value ?? 0) + 1);

      final users = Set<String>.from(activeUsers.cell.value ?? {});
      users.add(message.userId);
      activeUsers.update(users);

      if (!message.isRead) {
        unreadCount.update((unreadCount.cell.value ?? 0) + 1);
      }

      lastMessage.update(message.content);

      return {
        'totalMessages': chatCount.cell.value ?? 0,
        'activeUsers': activeUsers.cell.value?.length ?? 0,
        'unread': unreadCount.cell.value ?? 0,
        'lastMessage': message.content,
        'timestamp': DateTime.now().toIso8601String(),
      };
    },
  );

  final chatObserver = Cell.observe(
    source: chatAggregator.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   💬 Chat Summary:');
      print('   - Total Messages: ${data['totalMessages']}');
      print('   - Active Users: ${data['activeUsers']}');
      print('   - Unread: ${data['unread']}');
      print('   - Last Message: "${data['lastMessage']}"');
    },
  );

  // Start chat simulation
  await chatInput.emitAsync(null);
  chatSimulator.start();

  await Future.delayed(const Duration(seconds: 4));

  chatSimulator.stop();
  chatObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Real-Time Data Sync with Flow.combineLatest');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Use Case                  │  Benefit                                 │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Dashboard Metrics         │  Combine multiple metrics                │
  │  Form Validation           │  Validate multiple fields                │
  │  Portfolio Aggregation     │  Aggregate stock prices                  │
  │  Health Monitoring         │  Monitor system components               │
  │  Search Filters            │  Combine search parameters               │
  │  User Preferences          │  Sync user settings                      │
  │  Chat Aggregation          │  Aggregate chat metrics                  │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 combineLatest emits when ANY source changes
  🔹 Latest values from all sources are combined
  🔹 Perfect for real-time dashboards
  🔹 Maintains data consistency across sources
  🔹 Handles partial updates gracefully
  🔹 Type-safe with generic parameters
  🔹 Works with any number of sources
  🔹 Reactive and declarative

  When to use combineLatest:
  - Multiple independent sources
  - Real-time data synchronization
  - Dashboard and monitoring
  - Form validation
  - Search with filters
  - User preferences
  - Aggregated metrics
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Internal Helpers
// ─────────────────────────────────────────────────────────────────────

/// Simulates a chat message stream.
class _ChatSimulator {
  final StreamController<ChatMessage> _controller;
  Timer? _timer;
  final Random _random = Random();
  int _messageCount = 0;
  final List<String> _users = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];
  final List<String> _messages = [
    'Hello everyone!',
    'How is everyone doing?',
    'Great weather today!',
    'Did anyone see the latest update?',
    'I have a question about the API',
    'Thanks for the help!',
    'That fixed the issue',
    'New release coming soon',
    'Can we schedule a meeting?',
    'I agree with that proposal',
    'Let me think about that',
    'Good point!',
    'I will look into it',
    'This is awesome!',
    'Thanks for sharing',
  ];

  _ChatSimulator() : _controller = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get stream => _controller.stream;

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _messageCount++;
      final user = _users[_random.nextInt(_users.length)];
      final message = _messages[_random.nextInt(_messages.length)];
      final isRead = _random.nextBool();

      final chatMessage = ChatMessage(
        id: 'msg_$_messageCount',
        userId: 'user_${_users.indexOf(user)}',
        userName: user,
        content: message,
        isRead: isRead,
      );

      _controller.add(chatMessage);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a combineLatest transformation.
  static FlowHandle combineLatestWith<S, R>(
      Cell source, {
        required List<Cell> others,
        required R Function(S sourceValue, List<Object?> latest) combine,
        CombineErrorHandler? onError,
      }) {
    final instruction = CombineLatestWith<S, R>(
      others,
      combine,
      onError: onError,
    );
    return instruction.toHandle(source: source);
  }

  /// Creates a filter transformation.
  static FlowHandle filter<S>(
      Cell source, {
        required bool Function(S value) test,
      }) {
    final instruction = Filter<S>(test);
    return instruction.toHandle(source: source);
  }

  /// Creates a map transformation.
  static FlowHandle map<S, T>(
      Cell source, {
        required T Function(S value) project,
      }) {
    final instruction = MapValue<S, T>(project);
    return instruction.toHandle(source: source);
  }

  /// Creates a fromStream bridge with the specified stream.
  static FlowHandle fromStream<S>(
      Cell source, {
        required Stream<S> stream,
        StreamErrorHandler? onError,
        bool emitErrorPulse = true,
      }) {
    final instruction = FromStream<S>(
      stream,
      onError: onError,
      emitErrorPulse: emitErrorPulse,
    );
    return instruction.toHandle(source: source);
  }

  /// Creates a state cell.
  static StateHandle<T> state<T>({
    required T initial,
  }) {
    return Cell.state<T>(initial: initial);
  }
}

/// Error handler callback for combine operations.
typedef CombineErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// Error handler callback for stream operations.
typedef StreamErrorHandler = void Function(Object error, StackTrace? stackTrace);

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

Pulse _errorPayload(Object error, Pulse sourcePulse, Cell? cell, String step) {
  return Pulse(
    error,
    source: cell ?? sourcePulse.source,
    type: 'error',
    priority: sourcePulse.priority,
    step: step,
  );
}