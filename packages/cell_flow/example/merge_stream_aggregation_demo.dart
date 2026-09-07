// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A complete walkthrough demonstrating stream merging using the Cell Framework.
///
/// ### Overview
/// This demo shows how to merge multiple data streams into a single unified stream
/// using a shared ingress bus pattern. Instead of using `Flow.mergeWith` directly
/// (which can drop events when sinks aren't ready), this demo uses a fan-in pattern
/// where all sources are observed and their events are forwarded to a shared bus.
///
/// ### Architecture Pattern: Fan-In Bus
/// ```
///                    ┌─────────────┐
///     Source A ──────┤             │
///                    │             │
///     Source B ──────┤   Shared    ├───► Unified Stream
///                    │   Bus       │
///     Source C ──────┤             │
///                    └─────────────┘
/// ```
///
/// ### Scenarios Demonstrated
/// 1. **Basic Merge** - Combine two simple string sources
/// 2. **Event Aggregation** - Merge different event types (User, System, Business)
/// 3. **Log Aggregation** - Combine log entries from multiple sources
/// 4. **IoT Sensor Data** - Merge readings from temperature, humidity, pressure sensors
/// 5. **Financial Streams** - Combine market data with news updates
/// 6. **User Activity** - Track user actions from multiple sources
/// 7. **Type-Aware Transformation** - Handle different data types in one stream
/// 8. **Real-Time Dashboard** - Aggregate events for live dashboard updates
///
/// ### Learning Objectives
/// - Understand the fan-in pattern for merging streams
/// - Learn how to merge multiple event types
/// - See real-time event aggregation in action
/// - Handle different data types in a unified stream
/// - Build reactive dashboards with merged streams
/// - Preserve source identity in merged streams
///
/// ### Expected Console Output
/// ```
/// ── Stream Merging Demo ──────────────────────────────────────────────────────
///
/// 1. Basic Merge - Two Sources
///    ────────────────────────────────────────────────────────
///    [Source A] Event: A-1
///    [Merged] A-1
///    [Source B] Event: B-1
///    [Merged] B-1
///    [Source A] Event: A-2
///    [Merged] A-2
///
/// 2. Real-Time Event Aggregation
///    ────────────────────────────────────────────────────────
///    [User] user_001: click on home
///    [Aggregator] 📊 Total events: 1
///    [System] CPU: 45.2% (normal)
///    [Aggregator] 📊 Total events: 2
///    [Business] order_created
///    [Aggregator] 📊 Total events: 3
///
/// 3. Multi-Source Log Aggregation
///    ────────────────────────────────────────────────────────
///    [App Log] Generating logs...
///    [Aggregated Logs] INFO: User logged in
///    [Error Log] ERROR: Database connection failed
///    [Aggregated Logs] INFO: API request /users
///
/// 4. IoT Sensor Data Merge
///    ────────────────────────────────────────────────────────
///    [SENSOR-01] Temperature: 23.5
///    [SENSOR-02] Humidity: 45.2
///    [SENSOR-03] Pressure: 1013.2
///    [Merged] All sensors active
///
/// 5. Financial Data Streams
///    ────────────────────────────────────────────────────────
///    [Market] AAPL: $150.25 ↑
///    [News] Breaking: Tech sector rally
///
/// 6. User Activity Streams
///    ────────────────────────────────────────────────────────
///    [user_001] click on 'home'
///    [user_002] scroll
///    [Activity] Stream completed
///
/// 7. Merge with Transformation Pipeline
///    ────────────────────────────────────────────────────────
///    🔢 Integer: 42 -> 84
///    📝 String: "hello world" -> HELLO WORLD
///    📊 Double: 3.14 -> 4.71
///
/// 8. Real-Time Dashboard with Multiple Sources
///    ────────────────────────────────────────────────────────
///    📊 Dashboard Update:
///    - Total Events: 1
///    - User Events: 1
///    - System Events: 0
///    - Business Events: 0
///    📊 Dashboard Update:
///    - Total Events: 2
///    - User Events: 1
///    - System Events: 1
///    - Business Events: 0
///    📊 Dashboard Update:
///    - Total Events: 3
///    - User Events: 1
///    - System Events: 1
///    - Business Events: 1
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;



import 'dart:async';

import 'package:cell_flow/cell_flow.dart';

// ─────────────────────────────────────────────────────────────────────
// Event Models
// ─────────────────────────────────────────────────────────────────────

/// Base class for all events in the demo.
///
/// Every event carries a [source] identifier and a [type] string,
/// allowing downstream processors to distinguish between different
/// event sources and categories.
///
/// ### Usage
/// Extend this class to create specific event types:
/// ```dart
/// class MyEvent extends Event {
///   MyEvent() : super(source: 'MySource', type: 'my_type');
/// }
/// ```
abstract class Event {
  /// The identifier of the source that emitted this event.
  final String source;

  /// The semantic type of this event (e.g., 'click', 'temperature').
  final String type;

  Event({required this.source, required this.type});

  @override
  String toString() => '[$source] $type';
}

/// Represents a user activity event.
///
/// Emitted when a user performs an action like clicking, scrolling,
/// or viewing content. Used for user behavior analytics and activity
/// tracking.
///
/// ### Example
/// ```dart
/// final event = UserActivity(
///   userId: 'user_001',
///   action: 'click',
///   target: 'home',
/// );
/// ```
class UserActivity extends Event {
  /// The unique identifier of the user performing the action.
  final String userId;

  /// The type of action performed (e.g., 'click', 'scroll', 'view').
  final String action;

  /// The target of the action (e.g., 'home', 'products', 'cart').
  final String? target;

  UserActivity({
    required this.userId,
    required this.action,
    this.target,
  }) : super(source: 'UserActivity', type: action);

  @override
  String toString() =>
      '[User] $userId: $action${target != null ? ' on $target' : ''}';
}

/// Represents a system metric event.
///
/// Emitted when system metrics like CPU usage, memory usage, or
/// temperature change. Used for system monitoring and health checks.
///
/// ### Example
/// ```dart
/// final event = SystemMetricEvent(
///   metricName: 'CPU',
///   value: 45.2,
///   unit: '%',
/// );
/// ```
class SystemMetricEvent extends Event {
  /// The name of the metric (e.g., 'CPU', 'Memory', 'Disk').
  final String metricName;

  /// The current value of the metric.
  final double value;

  /// The unit of measurement (e.g., '%', 'MB/s', '°C').
  final String unit;

  SystemMetricEvent({
    required this.metricName,
    required this.value,
    this.unit = '',
  }) : super(source: 'SystemMetric', type: metricName);

  @override
  String toString() =>
      '[System] $metricName: ${value.toStringAsFixed(1)}$unit (normal)';
}

/// Represents a business event.
///
/// Emitted when business operations occur like order creation,
/// payment processing, or shipping updates. Used for business
/// analytics and monitoring.
///
/// ### Example
/// ```dart
/// final event = BusinessEvent(eventType: 'order_created');
/// ```
class BusinessEvent extends Event {
  /// The type of business event (e.g., 'order_created', 'payment_processed').
  final String eventType;

  BusinessEvent({required this.eventType})
      : super(source: 'Business', type: eventType);

  @override
  String toString() => '[Business] $eventType';
}

/// Represents an IoT sensor reading event.
///
/// Emitted when sensors report measurements like temperature,
/// humidity, or pressure. Used for IoT monitoring and automation.
///
/// ### Example
/// ```dart
/// final event = SensorReadingEvent(
///   sensorId: 'SENSOR-01',
///   sensorType: 'Temperature',
///   value: 23.5,
/// );
/// ```
class SensorReadingEvent extends Event {
  /// The unique identifier of the sensor (e.g., 'SENSOR-01').
  final String sensorId;

  /// The type of measurement (e.g., 'Temperature', 'Humidity').
  final String sensorType;

  /// The measured value.
  final double value;

  SensorReadingEvent({
    required this.sensorId,
    required this.sensorType,
    required this.value,
  }) : super(source: 'Sensor', type: sensorType);

  @override
  String toString() => '[$sensorId] $sensorType: ${value.toStringAsFixed(1)}';
}

/// Represents a financial market event.
///
/// Emitted when stock prices change. Used for market monitoring
/// and financial analytics.
///
/// ### Example
/// ```dart
/// final event = MarketEvent(
///   symbol: 'AAPL',
///   price: 150.25,
///   change: 2.3,
/// );
/// ```
class MarketEvent extends Event {
  /// The stock symbol (e.g., 'AAPL', 'GOOGL').
  final String symbol;

  /// The current price of the stock.
  final double price;

  /// The change in price from the previous value.
  final double change;

  MarketEvent({
    required this.symbol,
    required this.price,
    required this.change,
  }) : super(source: 'Market', type: 'price_update');

  @override
  String toString() =>
      '[Market] $symbol: \$${price.toStringAsFixed(2)} ${change >= 0 ? '↑' : '↓'}';
}

// ─────────────────────────────────────────────────────────────────────
// Fan-In Pattern Implementation
// ─────────────────────────────────────────────────────────────────────

/// Fan-in pattern: Forward all events from multiple sources to a single bus.
///
/// This function implements the **Fan-In Pattern**, a common architectural
/// pattern for merging multiple data streams. It observes all source cells
/// and forwards their events to a shared ingress bus.
///
/// ### Why Use Fan-In Instead of Flow.mergeWith?
/// `Flow.mergeWith` can drop events if the downstream sink isn't ready
/// (e.g., the cell hasn't been armed with a pulse). The fan-in pattern
/// is more reliable for merging streams where sources are independent
/// and events must not be lost.
///
/// ### How It Works
/// 1. For each source cell, an observer is attached.
/// 2. When a source emits a pulse, the observer checks the payload type.
/// 3. If the payload matches type [T], it's forwarded to the bus.
/// 4. All sources share the same bus, creating a unified stream.
///
/// ### Example
/// ```dart
/// final bus = Cell.ingress<String>();
/// final source1 = Cell.ingress<String>();
/// final source2 = Cell.ingress<String>();
/// _fanIn<String>([source1.cell, source2.cell], bus);
/// // Now source1 and source2 events are merged into bus
/// ```
///
/// ### Type Parameters:
/// - [T]: The common type of events to forward to the bus.
///
/// ### Parameters:
/// - [sources]: List of source cells to observe.
/// - [bus]: The shared ingress bus to forward events to.
void _fanIn<T>(List<Cell> sources, IngressHandle<T> bus) {
  for (final source in sources) {
    // Observe each source and forward matching events to the bus
    Cell.observe(
      source: source,
      effect: (Pulse p) {
        final payload = p.payload;
        if (payload is T) bus.emit(payload);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
///
/// This function runs through 8 different merging scenarios to demonstrate
/// the versatility of stream merging patterns in real-world applications.
///
/// ### Demo Scenarios:
/// 1. **Basic Merge** - Shows simple merging of two string streams
/// 2. **Event Aggregation** - Merges different event types with aggregation
/// 3. **Log Aggregation** - Combines logs from multiple sources with filtering
/// 4. **IoT Sensor Data** - Merges readings from different sensors
/// 5. **Financial Streams** - Combines market data with news
/// 6. **User Activity** - Tracks user actions from multiple sources
/// 7. **Type-Aware Transformation** - Handles different types in one stream
/// 8. **Real-Time Dashboard** - Aggregates events for dashboard updates
Future<void> main() async {
  print('── Stream Merging Demo ──────────────────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Merge - Two Sources
  // ========================================================================

  print('1. Basic Merge - Two Sources');
  print('   ────────────────────────────────────────────────────────');

  // Create two source cells and a shared bus
  final sourceA = Cell.ingress<String>();
  final sourceB = Cell.ingress<String>();
  final bus1 = Cell.ingress<String>();

  // Fan-in: forward both sources to the shared bus
  _fanIn<String>([sourceA.cell, sourceB.cell], bus1);

  // Observe the merged stream
  final obs1 = Cell.observe(
    source: bus1.cell,
    effect: (Pulse p) => print('   [Merged] ${p.payload}'),
  );

  print('   [Source A] Event: A-1');
  await sourceA.emitAsync('A-1');

  print('   [Source B] Event: B-1');
  await sourceB.emitAsync('B-1');

  print('   [Source A] Event: A-2');
  await sourceA.emitAsync('A-2');

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs1.stop();
  print('');

  // ========================================================================
  // 2. Real-Time Event Aggregation
  // ========================================================================

  print('2. Real-Time Event Aggregation');
  print('   ────────────────────────────────────────────────────────');

  // Create sources for different event types
  final users = Cell.ingress<Event>();
  final system = Cell.ingress<Event>();
  final business = Cell.ingress<Event>();
  final bus2 = Cell.ingress<Event>();

  // Fan-in all events to a shared bus
  _fanIn<Event>([users.cell, system.cell, business.cell], bus2);

  // Track total event count for aggregation
  var eventCount = 0;

  // Observe the merged stream with aggregation
  final obs2 = Cell.observe(
    source: bus2.cell,
    effect: (Pulse p) {
      eventCount++;
      print('   ${p.payload}');
      print('   [Aggregator] 📊 Total events: $eventCount');
      print('   [Aggregator] 📋 Last event: ${p.payload}');
    },
  );

  // Emit events from different sources
  await users.emitAsync(
    UserActivity(userId: 'user_001', action: 'click', target: 'home'),
  );
  await system.emitAsync(
    SystemMetricEvent(metricName: 'CPU', value: 45.2, unit: '%'),
  );
  await business.emitAsync(BusinessEvent(eventType: 'order_created'));

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs2.stop();
  print('');

  // ========================================================================
  // 3. Multi-Source Log Aggregation
  // ========================================================================

  print('3. Multi-Source Log Aggregation');
  print('   ────────────────────────────────────────────────────────');

  // Create log sources from different systems
  final log1 = Cell.ingress<String>();
  final log2 = Cell.ingress<String>();
  final log3 = Cell.ingress<String>();
  final bus3 = Cell.ingress<String>();

  // Fan-in all logs to a shared bus
  _fanIn<String>([log1.cell, log2.cell, log3.cell], bus3);

  print('   [App Log] Generating logs...');

  // Observe the merged logs with filtering
  final obs3 = Cell.observe(
    source: bus3.cell,
    effect: (Pulse p) {
      final line = p.payload as String;
      if (line.contains('ERROR')) {
        print('   [Error Log] $line');
      } else {
        print('   [Aggregated Logs] $line');
      }
    },
  );

  await log1.emitAsync('INFO: User logged in');
  await log2.emitAsync('ERROR: Database connection failed');
  await log3.emitAsync('INFO: API request /users');

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs3.stop();
  print('');

  // ========================================================================
  // 4. IoT Sensor Data Merge
  // ========================================================================

  print('4. IoT Sensor Data Merge');
  print('   ────────────────────────────────────────────────────────');

  // Create sensor sources
  final s1 = Cell.ingress<SensorReadingEvent>();
  final s2 = Cell.ingress<SensorReadingEvent>();
  final s3 = Cell.ingress<SensorReadingEvent>();
  final bus4 = Cell.ingress<SensorReadingEvent>();

  // Fan-in all sensors to a shared bus
  _fanIn<SensorReadingEvent>([s1.cell, s2.cell, s3.cell], bus4);

  // Observe the merged sensor readings
  final obs4 = Cell.observe(
    source: bus4.cell,
    effect: (Pulse p) {
      final e = p.payload as SensorReadingEvent;
      print('   [${e.sensorId}] ${e.sensorType}: ${e.value.toStringAsFixed(1)}');
    },
  );

  await s1.emitAsync(SensorReadingEvent(
      sensorId: 'SENSOR-01', sensorType: 'Temperature', value: 23.5));
  await s2.emitAsync(SensorReadingEvent(
      sensorId: 'SENSOR-02', sensorType: 'Humidity', value: 45.2));
  await s3.emitAsync(SensorReadingEvent(
      sensorId: 'SENSOR-03', sensorType: 'Pressure', value: 1013.2));

  await Future<void>.delayed(const Duration(milliseconds: 20));

  print('   [Merged] All sensors active');

  obs4.stop();
  print('');

  // ========================================================================
  // 5. Financial Data Streams
  // ========================================================================

  print('5. Financial Data Streams');
  print('   ────────────────────────────────────────────────────────');

  // Create market and news sources
  final market = Cell.ingress<Object>();
  final news = Cell.ingress<Object>();
  final bus5 = Cell.ingress<Object>();

  // Fan-in market and news to a shared bus
  _fanIn<Object>([market.cell, news.cell], bus5);

  // Observe the merged financial stream
  final obs5 = Cell.observe(
    source: bus5.cell,
    effect: (Pulse p) {
      final data = p.payload;
      if (data is MarketEvent) {
        print(
          '   [Market] ${data.symbol}: \$${data.price.toStringAsFixed(2)} ${data.change >= 0 ? '↑' : '↓'}',
        );
      } else {
        print('   [News] $data');
      }
    },
  );

  await market.emitAsync(
    MarketEvent(symbol: 'AAPL', price: 150.25, change: 2.3),
  );
  await news.emitAsync('Breaking: Tech sector rally');

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs5.stop();
  print('');

  // ========================================================================
  // 6. User Activity Streams
  // ========================================================================

  print('6. User Activity Streams');
  print('   ────────────────────────────────────────────────────────');

  // Create a user activity source
  final activity = Cell.ingress<UserActivity>();

  // Observe user activities directly (no fan-in needed for single source)
  final obs6 = Cell.observe(
    source: activity.cell,
    effect: (Pulse p) {
      final e = p.payload as UserActivity;
      print(
        '   [${e.userId}] ${e.action}${e.target != null ? " on '${e.target}'" : ''}',
      );
    },
  );

  await activity.emitAsync(
    UserActivity(userId: 'user_001', action: 'click', target: 'home'),
  );
  await activity.emitAsync(UserActivity(userId: 'user_002', action: 'scroll'));

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs6.stop();
  print('   [Activity] Stream completed');
  print('');

  // ========================================================================
  // 7. Merge with Transformation Pipeline
  // ========================================================================

  print('7. Merge with Transformation Pipeline');
  print('   ────────────────────────────────────────────────────────');

  // Create sources for different data types
  final ni = Cell.ingress<Object>();
  final si = Cell.ingress<Object>();
  final di = Cell.ingress<Object>();
  final bus7 = Cell.ingress<Object>();

  // Fan-in all types to a shared bus
  _fanIn<Object>([ni.cell, si.cell, di.cell], bus7);

  // Observe with type-aware transformation
  final obs7 = Cell.observe(
    source: bus7.cell,
    effect: (Pulse p) {
      final data = p.payload;
      if (data is int) print('   🔢 Integer: $data -> ${data * 2}');
      if (data is String) {
        print('   📝 String: "$data" -> ${data.toUpperCase()}');
      }
      if (data is double) {
        print('   📊 Double: $data -> ${(data * 1.5).toStringAsFixed(2)}');
      }
    },
  );

  await ni.emitAsync(42);
  await si.emitAsync('hello world');
  await di.emitAsync(3.14);

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs7.stop();
  print('');

  // ========================================================================
  // 8. Real-Time Dashboard with Multiple Sources
  // ========================================================================

  print('8. Real-Time Dashboard with Multiple Sources');
  print('   ────────────────────────────────────────────────────────');

  // Create dashboard event sources
  final du = Cell.ingress<Event>();
  final ds = Cell.ingress<Event>();
  final db = Cell.ingress<Event>();
  final bus8 = Cell.ingress<Event>();

  // Fan-in all dashboard events to a shared bus
  _fanIn<Event>([du.cell, ds.cell, db.cell], bus8);

  // Track dashboard metrics
  var total = 0, uc = 0, sc = 0, bc = 0;

  // Observe the dashboard stream with metrics
  final obs8 = Cell.observe(
    source: bus8.cell,
    effect: (Pulse p) {
      final event = p.payload as Event;
      total++;
      if (event is UserActivity) uc++;
      if (event is SystemMetricEvent) sc++;
      if (event is BusinessEvent) bc++;
      print('   📊 Dashboard Update:');
      print('   - Total Events: $total');
      print('   - User Events: $uc');
      print('   - System Events: $sc');
      print('   - Business Events: $bc');
    },
  );

  await du.emitAsync(
    UserActivity(userId: 'user_001', action: 'click', target: 'home'),
  );
  await ds.emitAsync(
    SystemMetricEvent(metricName: 'CPU', value: 45.2, unit: '%'),
  );
  await db.emitAsync(BusinessEvent(eventType: 'order_created'));

  await Future<void>.delayed(const Duration(milliseconds: 20));

  obs8.stop();

  print('\n── Finished ──────────────────────────────────────────────────────────────');
}