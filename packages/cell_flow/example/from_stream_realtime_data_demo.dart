// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A complete walkthrough demonstrating the use of Flow.fromStream for
/// bridging external real-time data into reactive pipelines.
///
/// ### Scenario
/// A real-time data processing system where:
/// 1. External data sources (WebSocket, SSE, sensors) are bridged via Stream
/// 2. Real-time data flows through reactive pipelines
/// 3. Data is transformed, filtered, and aggregated in real-time
/// 4. Multiple data sources are combined and synchronized
/// 5. Real-time dashboards and monitoring are built
/// 6. Data quality and anomaly detection are applied
///
/// ### Learning Objectives
/// - Understand how Flow.fromStream bridges external data sources
/// - See real-time data processing with reactive pipelines
/// - Learn about stream transformations and filtering
/// - Handle real-time data quality and anomalies
/// - Build real-time dashboards with reactive updates
/// - Combine multiple data streams
///
/// ### Expected Console Output
/// ```
/// ── Real-Time Data Pipeline Demo ──────────────────────────────────────────
///
/// 1. Basic Stream Bridge - WebSocket Data
///    ────────────────────────────────────────────────────────
///
///    [WebSocket] Connected to wss://api.example.com
///    [Pipeline] ✅ WebSocket data #1 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #2 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #3 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #4 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #5 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #6 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #7 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #8 processed
///    [Trace] MapValue
///    [Pipeline] ✅ WebSocket data #9 processed
///    [Trace] MapValue
///    [WebSocket] Disconnected
///
/// 2. Real-Time Sensor Data Processing
///    ────────────────────────────────────────────────────────
///
///    [Sensor] Starting sensor: SENSOR-001
///    [Filtered] ✅ Valid sensor reading: 31.9°C
///    [Filtered] ✅ Valid sensor reading: 21.7°C
///    [Filtered] ✅ Valid sensor reading: 28.6°C
///    [Filtered] ✅ Valid sensor reading: 26.6°C
///    [Filtered] ✅ Valid sensor reading: 21.1°C
///    [Sensor] Stopped sensor: SENSOR-001
///
/// 3. Real-Time Dashboard Updates
///    ────────────────────────────────────────────────────────
///
///    [WebMetrics] Starting web metrics collection
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      1
///     - Requests/sec:      2
///     - Avg Response:    293ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      2
///     - Requests/sec:      4
///     - Avg Response:    429ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      3
///     - Requests/sec:      6
///     - Avg Response:    487ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      4
///     - Requests/sec:      8
///     - Avg Response:    547ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      5
///     - Requests/sec:     10
///     - Avg Response:    596ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      6
///     - Requests/sec:     12
///     - Avg Response:    538ms
///     - Error Rate:     0.0%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      7
///     - Requests/sec:     14
///     - Avg Response:    566ms
///     - Error Rate:    14.3%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      8
///     - Requests/sec:     16
///     - Avg Response:    550ms
///     - Error Rate:    12.5%
///
///    [Dashboard] 📊 Live Metrics Updated:
///     - Active Users:      9
///     - Requests/sec:     18
///     - Avg Response:    503ms
///     - Error Rate:    11.1%
///
///    [WebMetrics] Stopped web metrics collection
///
/// 4. Multiple Stream Aggregation
///    ────────────────────────────────────────────────────────
///
///    [Sensor] Starting sensor: SENSOR-002
///    [Sensor] Starting sensor: SENSOR-003
///    [Sensor] Stopped sensor: SENSOR-002
///    [Sensor] Stopped sensor: SENSOR-003
///
/// 5. Anomaly Detection Pipeline
///    ────────────────────────────────────────────────────────
///
///    [SystemMetrics] Starting system metrics collection
///    [Anomaly] ✅ Normal metric: disk_usage = 50.0%
///    [Anomaly] ✅ Normal metric: memory_usage = 48.0%
///    [Anomaly] ✅ Normal metric: disk_usage = 0.0%
///    [Anomaly] ✅ Normal metric: disk_usage = 47.0%
///    [Anomaly] ✅ Normal metric: memory_usage = 23.0%
///    [Anomaly] ✅ Normal metric: network_io = 41.0%
///    [Anomaly] ✅ Normal metric: network_io = 85.0%
///    [SystemMetrics] Stopped system metrics collection
///
/// 6. Real-Time Data Quality Pipeline
///    ────────────────────────────────────────────────────────
///
///    [Sensor] Starting sensor: SENSOR-QUALITY
///    [Quality] ✅ Data quality check passed: 1 records
///    [Quality] ✅ Completeness score: 100.0%
///    [Quality] ✅ Data quality check passed: 2 records
///    [Quality] ✅ Completeness score: 100.0%
///    [Quality] ✅ Data quality check passed: 3 records
///    [Quality] ✅ Completeness score: 100.0%
///    [Sensor] Stopped sensor: SENSOR-QUALITY
///
/// 7. Real-Time Data Enrichment Pipeline
///    ────────────────────────────────────────────────────────
///
///    [Sensor] Starting sensor: SENSOR-ENRICH
///    [Enriched] 📊 Sensor SENSOR-ENRICH:
///    - Temperature: 29.7°C
///    - Heat Index: 29.9°C
///    - Dew Point: 18.6°C
///    - Risk Level: LOW
///    - Location: Zone-ENRICH
///
///    [Enriched] 📊 Sensor SENSOR-ENRICH:
///    - Temperature: 33.5°C
///    - Heat Index: 33.7°C
///    - Dew Point: 25.0°C
///    - Risk Level: LOW
///    - Location: Zone-ENRICH
///
///    [Enriched] 📊 Sensor SENSOR-ENRICH:
///    - Temperature: 32.0°C
///    - Heat Index: 32.3°C
///    - Dew Point: 25.2°C
///    - Risk Level: LOW
///    - Location: Zone-ENRICH
///
///    [Sensor] Stopped sensor: SENSOR-ENRICH
///
/// 8. Real-Time Alert Aggregation
///    ────────────────────────────────────────────────────────
///
///    [Sensor] Starting sensor: SENSOR-ALERT-1
///    [Sensor] Starting sensor: SENSOR-ALERT-2
///    [Sensor] Stopped sensor: SENSOR-ALERT-1
///    [Sensor] Stopped sensor: SENSOR-ALERT-2
///
/// ────────────────────────────────────────────────────────────
/// 📝 Summary: Real-Time Data Pipeline with Flow.fromStream
/// ────────────────────────────────────────────────────────────
///   ┌─────────────────────────────────────────────────────────────────────────┐
///   │  Feature                   │  Benefit                                 │
///   ├─────────────────────────────────────────────────────────────────────────┤
///   │  Stream Bridging          │  Connect external data sources            │
///   │  Real-Time Processing     │  Process data as it arrives              │
///   │  Data Quality             │  Ensure data integrity                    │
///   │  Anomaly Detection        │  Identify issues in real-time            │
///   │  Dashboard Updates        │  Live visualization updates              │
///   │  Multiple Streams         │  Aggregate and combine data              │
///   │  Data Enrichment          │  Add context to real-time data          │
///   │  Alert Aggregation        │  Consolidate alerts from multiple sources │
///   └─────────────────────────────────────────────────────────────────────────┘
///
///   🔹 Use fromStream to bridge any Dart Stream into the reactive graph
///   🔹 Process real-time data with reactive operators
///   🔹 Combine multiple streams with synthesis
///   🔹 Detect anomalies with filter and map
///   🔹 Build real-time dashboards with aggregate state
///   🔹 Enrich data with additional context
///   🔹 Aggregate alerts from multiple sources
///   🔹 Full provenance tracking across the pipeline
///
///   Supported Stream Sources:
///   - WebSocket connections
///   - Server-Sent Events (SSE)
///   - Hardware sensors
///   - File watchers
///   - Database change streams
///   - Network sockets
///   - Third-party SDKs
///
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cell_flow/flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/from_stream.dart';
import 'package:cell_flow/src/instruction/map.dart';

import 'throttle_rate_limiting_demo.dart';

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a sensor reading.
class SensorReading {
  final String sensorId;
  final double temperature;
  final double humidity;
  final double pressure;
  final DateTime timestamp;
  final String status;

  SensorReading({
    required this.sensorId,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    DateTime? timestamp,
    this.status = 'normal',
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isAnomaly => temperature > 35 || temperature < 0 || humidity > 95;

  Map<String, dynamic> toJson() => {
    'sensorId': sensorId,
    'temperature': temperature,
    'humidity': humidity,
    'pressure': pressure,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'isAnomaly': isAnomaly,
  };

  @override
  String toString() =>
      'Sensor($sensorId): Temp: ${temperature.toStringAsFixed(1)}°C, Humidity: ${humidity.toStringAsFixed(1)}%, Pressure: ${pressure.toStringAsFixed(1)}hPa';
}

/// Represents a web metric event.
class WebMetric {
  final String sessionId;
  final String userId;
  final String page;
  final String action;
  final int duration;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  WebMetric({
    required this.sessionId,
    required this.userId,
    required this.page,
    required this.action,
    required this.duration,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'userId': userId,
    'page': page,
    'action': action,
    'duration': duration,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  @override
  String toString() => 'Metric($sessionId): $action on $page (${duration}ms)';
}

/// Represents a system metric.
class SystemMetric {
  final String metricName;
  final double value;
  final String unit;
  final String status;
  final DateTime timestamp;

  SystemMetric({
    required this.metricName,
    required this.value,
    this.unit = '',
    this.status = 'normal',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isAnomaly => value > 90 && status != 'normal';

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'value': value,
    'unit': unit,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'isAnomaly': isAnomaly,
  };

  @override
  String toString() => 'SystemMetric: $metricName = $value$unit';
}

/// Represents a real-time dashboard state.
class DashboardState {
  final int activeUsers;
  final int requestsPerSecond;
  final int avgResponseMs;
  final double errorRate;
  final DateTime timestamp;

  DashboardState({
    this.activeUsers = 0,
    this.requestsPerSecond = 0,
    this.avgResponseMs = 0,
    this.errorRate = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  DashboardState copyWith({
    int? activeUsers,
    int? requestsPerSecond,
    int? avgResponseMs,
    double? errorRate,
  }) {
    return DashboardState(
      activeUsers: activeUsers ?? this.activeUsers,
      requestsPerSecond: requestsPerSecond ?? this.requestsPerSecond,
      avgResponseMs: avgResponseMs ?? this.avgResponseMs,
      errorRate: errorRate ?? this.errorRate,
    );
  }

  @override
  String toString() {
    return '''
    - Active Users: ${activeUsers.toString().padLeft(6)}
    - Requests/sec: ${requestsPerSecond.toString().padLeft(6)}
    - Avg Response: ${avgResponseMs.toString().padLeft(6)}ms
    - Error Rate:  ${(errorRate * 100).toStringAsFixed(1).padLeft(6)}%''';
  }
}

// ─────────────────────────────────────────────────────────────────────
// External Data Source Simulators
// ─────────────────────────────────────────────────────────────────────

/// Simulates a WebSocket data stream.
class WebSocketSimulator {
  final StreamController<Map<String, dynamic>> _controller;
  Timer? _timer;
  int _messageCount = 0;

  WebSocketSimulator() : _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect() {
    print('   [WebSocket] Connected to wss://api.example.com');
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _messageCount++;
      _controller.add({
        'type': 'data',
        'id': _messageCount,
        'payload': {
          'message': 'WebSocket message $_messageCount',
          'timestamp': DateTime.now().toIso8601String(),
          'data': {'value': Random().nextInt(100), 'status': 'ok'},
        },
      });
    });
  }

  void disconnect() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
    print('   [WebSocket] Disconnected');
  }
}

/// Simulates a sensor data stream.
class SensorSimulator {
  final StreamController<SensorReading> _controller;
  Timer? _timer;
  final String sensorId;
  int _readingCount = 0;

  SensorSimulator(this.sensorId) : _controller = StreamController<SensorReading>.broadcast();

  Stream<SensorReading> get stream => _controller.stream;

  void start() {
    print('   [Sensor] Starting sensor: $sensorId');
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _readingCount++;
      final reading = SensorReading(
        sensorId: sensorId,
        temperature: 20 + Random().nextDouble() * 15,
        humidity: 40 + Random().nextDouble() * 30,
        pressure: 1010 + Random().nextDouble() * 10,
        status: Random().nextInt(10) < 2 ? 'warning' : 'normal',
      );
      _controller.add(reading);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
    print('   [Sensor] Stopped sensor: $sensorId');
  }
}

/// Simulates a web metrics stream.
class WebMetricSimulator {
  final StreamController<WebMetric> _controller;
  Timer? _timer;
  int _metricCount = 0;
  final List<String> _pages = ['/home', '/products', '/checkout', '/profile', '/dashboard'];
  final List<String> _actions = ['pageview', 'click', 'scroll', 'submit', 'navigate'];

  WebMetricSimulator() : _controller = StreamController<WebMetric>.broadcast();

  Stream<WebMetric> get stream => _controller.stream;

  void start() {
    print('   [WebMetrics] Starting web metrics collection');
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _metricCount++;
      final sessionId = 'session_${Random().nextInt(1000)}';
      final userId = 'user_${Random().nextInt(100)}';
      final page = _pages[Random().nextInt(_pages.length)];
      final action = _actions[Random().nextInt(_actions.length)];

      final metric = WebMetric(
        sessionId: sessionId,
        userId: userId,
        page: page,
        action: action,
        duration: Random().nextInt(1000) + 50,
        metadata: {
          'device': ['mobile', 'desktop', 'tablet'][Random().nextInt(3)],
          'referrer': Random().nextInt(10) < 3 ? 'google.com' : 'direct',
        },
      );
      _controller.add(metric);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
    print('   [WebMetrics] Stopped web metrics collection');
  }
}

/// Simulates a system metrics stream.
class SystemMetricSimulator {
  final StreamController<SystemMetric> _controller;
  Timer? _timer;
  final List<String> _metrics = ['cpu_usage', 'memory_usage', 'disk_usage', 'network_io', 'response_time'];
  final List<String> _units = ['%', '%', '%', 'MB/s', 'ms'];

  SystemMetricSimulator() : _controller = StreamController<SystemMetric>.broadcast();

  Stream<SystemMetric> get stream => _controller.stream;

  void start() {
    print('   [SystemMetrics] Starting system metrics collection');
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final index = Random().nextInt(_metrics.length);
      final metricName = _metrics[index];
      final unit = _units[index];
      // Occasionally create anomalies (>90%)
      final value = Random().nextInt(100).toDouble();
      final isAnomaly = value > 90 && Random().nextInt(10) < 3;
      final metric = SystemMetric(
        metricName: metricName,
        value: value,
        unit: unit,
        status: isAnomaly ? 'critical' : 'normal',
      );
      _controller.add(metric);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
    print('   [SystemMetrics] Stopped system metrics collection');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── Real-Time Data Pipeline Demo ──────────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Stream Bridge - WebSocket Data
  // ========================================================================

  print('1. Basic Stream Bridge - WebSocket Data');
  print('   ────────────────────────────────────────────────────────\n');

  final webSocket = WebSocketSimulator();
  final wsStream = webSocket.stream;

  // Bridge the WebSocket stream into the reactive graph
  final wsInput = Cell.ingress<void>();

  final wsHandle = Flow.fromStream<Map<String, dynamic>>(
    wsInput.cell,
    stream: wsStream,
    onError: (error, stack) {
      print('   [WebSocket] ⚠️ Error: $error');
    },
  );

  // Process the WebSocket data
  final wsProcessed = Flow.map<Map<String, dynamic>, String>(
    wsHandle.cell,
    project: (data) {
      final type = data['type'] as String;
      final id = data['id'] as int;
      return 'WebSocket $type #$id processed';
    },
  );

  final wsObserver = Cell.observe(
    source: wsProcessed.cell,
    effect: (Pulse p) {
      print('   [Pipeline] ✅ ${p.payload}');
      print('   [Trace] ${p.trace.join(' -> ')}');
    },
  );

  // Start the WebSocket
  await wsInput.emitAsync(null);
  webSocket.connect();

  await Future.delayed(const Duration(seconds: 2));

  webSocket.disconnect();
  wsObserver.stop();
  print('');

  // ========================================================================
  // 2. Real-Time Sensor Data Processing
  // ========================================================================

  print('2. Real-Time Sensor Data Processing');
  print('   ────────────────────────────────────────────────────────\n');

  final sensor = SensorSimulator('SENSOR-001');
  final sensorInput = Cell.ingress<void>();

  final sensorHandle = Flow.fromStream<SensorReading>(
    sensorInput.cell,
    stream: sensor.stream,
    onError: (error, stack) {
      print('   [Sensor] ⚠️ Error: $error');
    },
  );

  // Filter valid readings
  final validReadings = Flow.filter<SensorReading>(
    sensorHandle.cell,
    test: (reading) => !reading.isAnomaly,
  );

  // Detect anomalies (using map to capture both valid and anomaly)
  final anomalyDetected = Flow.map<SensorReading, String>(
    sensorHandle.cell,
    project: (reading) {
      if (reading.isAnomaly) {
        return '⚠️ Temperature anomaly detected: ${reading.temperature.toStringAsFixed(1)}°C';
      }
      return '✅ Valid sensor reading: ${reading.temperature.toStringAsFixed(1)}°C';
    },
  );

  final sensorObserver = Cell.observe(
    source: anomalyDetected.cell,
    effect: (Pulse p) {
      final message = p.payload as String;
      if (message.contains('anomaly')) {
        print('   [Alert] $message');
      } else {
        print('   [Filtered] $message');
      }
    },
  );

  // Start the sensor
  await sensorInput.emitAsync(null);
  sensor.start();

  await Future.delayed(const Duration(seconds: 3));

  sensor.stop();
  sensorObserver.stop();
  print('');

  // ========================================================================
  // 3. Real-Time Dashboard Updates
  // ========================================================================

  print('3. Real-Time Dashboard Updates');
  print('   ────────────────────────────────────────────────────────\n');

  final webMetrics = WebMetricSimulator();
  final metricsInput = Cell.ingress<void>();

  final metricsHandle = Flow.fromStream<WebMetric>(
    metricsInput.cell,
    stream: webMetrics.stream,
  );

  // Aggregate metrics into dashboard state
  var dashboardState = DashboardState();
  var totalMetrics = 0;
  var sumDuration = 0;
  var errorCount = 0;
  final activeSessions = <String>{};

  final dashboardUpdate = Flow.map<WebMetric, DashboardState>(
    metricsHandle.cell,
    project: (metric) {
      totalMetrics++;
      sumDuration += metric.duration;
      activeSessions.add(metric.sessionId);

      // Simulate errors (10% of metrics are errors)
      if (Random().nextInt(10) < 1) {
        errorCount++;
      }

      final avgResponse = totalMetrics > 0 ? sumDuration ~/ totalMetrics : 0;
      final errorRate = totalMetrics > 0 ? errorCount / totalMetrics : 0.0;

      dashboardState = dashboardState.copyWith(
        activeUsers: activeSessions.length,
        requestsPerSecond: (totalMetrics / 0.5).round(),
        avgResponseMs: avgResponse,
        errorRate: errorRate,
      );

      return dashboardState;
    },
  );

  final dashboardObserver = Cell.observe(
    source: dashboardUpdate.cell,
    effect: (Pulse p) {
      final state = p.payload as DashboardState;
      print('   [Dashboard] 📊 Live Metrics Updated:');
      print(state.toString());
      print('');
    },
  );

  // Start the web metrics
  await metricsInput.emitAsync(null);
  webMetrics.start();

  await Future.delayed(const Duration(seconds: 3));

  webMetrics.stop();
  dashboardObserver.stop();
  print('');

  // ========================================================================
  // 4. Multiple Stream Aggregation
  // ========================================================================

  print('4. Multiple Stream Aggregation');
  print('   ────────────────────────────────────────────────────────\n');

  final sensor2 = SensorSimulator('SENSOR-002');
  final sensor3 = SensorSimulator('SENSOR-003');

  final aggInput1 = Cell.ingress<void>();
  final aggInput2 = Cell.ingress<void>();
  final aggInput3 = Cell.ingress<void>();

  // Bridge all three sensors
  final sensorHandle1 = Flow.fromStream<SensorReading>(
    aggInput1.cell,
    stream: sensor2.stream,
  );

  final sensorHandle2 = Flow.fromStream<SensorReading>(
    aggInput2.cell,
    stream: sensor3.stream,
  );

  // Create a synthetic stream for temperature only
  final tempStream1 = Flow.map<SensorReading, (String, double, DateTime)>(
    sensorHandle1.cell,
    project: (reading) => (reading.sensorId, reading.temperature, reading.timestamp),
  );

  final tempStream2 = Flow.map<SensorReading, (String, double, DateTime)>(
    sensorHandle2.cell,
    project: (reading) => (reading.sensorId, reading.temperature, reading.timestamp),
  );

  // Aggregate multiple streams using synthesis
  final aggCell = Cell.synthesis<Pulse<Map<String, dynamic>>>(
    [tempStream1.cell, tempStream2.cell],
    aggregator: (sources, emit) {
      final s1 = (sources.elementAt(0) as ValueCell<(String, double, DateTime)>).value;
      final s2 = (sources.elementAt(1) as ValueCell<(String, double, DateTime)>).value;

      if (s1 == null || s2 == null) return null;

      final temps = {
        s1.$1: s1.$2,
        s2.$1: s2.$2,
      };

      return Pulse<Map<String, dynamic>>({
        'sensors': temps,
        'timestamp': DateTime.now().toIso8601String(),
        'count': temps.length,
        'avg_temp': temps.values.reduce((a, b) => a + b) / temps.length,
      });
    },
  );

  final aggObserver = Cell.observe(
    source: aggCell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      final temps = data['sensors'] as Map<String, double>;
      final avg = data['avg_temp'] as double;
      print('   [Aggregator] 📈 Combined Metrics:');
      print('   - Sensors: ${temps.keys.join(', ')}');
      print('   - Temperatures: ${temps.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}°C').join(', ')}');
      print('   - Average Temperature: ${avg.toStringAsFixed(1)}°C');
      print('   - Timestamp: ${data['timestamp']}');
      print('');
    },
  );

  // Start all sensors
  await aggInput1.emitAsync(null);
  await aggInput2.emitAsync(null);
  await aggInput3.emitAsync(null);

  sensor2.start();
  sensor3.start();

  await Future.delayed(const Duration(seconds: 2));

  sensor2.stop();
  sensor3.stop();
  aggObserver.stop();
  print('');

  // ========================================================================
  // 5. Anomaly Detection Pipeline
  // ========================================================================

  print('5. Anomaly Detection Pipeline');
  print('   ────────────────────────────────────────────────────────\n');

  final systemMetrics = SystemMetricSimulator();
  final anomalyInput = Cell.ingress<void>();

  final anomalyHandle = Flow.fromStream<SystemMetric>(
    anomalyInput.cell,
    stream: systemMetrics.stream,
  );

  // Detect anomalies in system metrics
  final anomalyDetector = Flow.map<SystemMetric, String>(
    anomalyHandle.cell,
    project: (metric) {
      if (metric.isAnomaly) {
        return '⚠️ Detected anomaly in metric: ${metric.metricName} - Value: ${metric.value.toStringAsFixed(1)}% (threshold: 90%)';
      }
      return '✅ Normal metric: ${metric.metricName} = ${metric.value.toStringAsFixed(1)}%';
    },
  );

  // Filter only anomalies for alerting
  final anomalyAlert = Flow.filter<String>(
    anomalyDetector.cell,
    test: (message) => message.contains('anomaly'),
  );

  final anomalyObserver = Cell.observe(
    source: anomalyAlert.cell,
    effect: (Pulse p) {
      final alert = p.payload as String;
      print('   [Alert] 🚨 $alert');
      print('   [Alert] 🚨 Alert sent to monitoring system');
    },
  );

  // Also observe normal metrics
  final normalObserver = Cell.observe(
    source: anomalyDetector.cell,
    effect: (Pulse p) {
      final message = p.payload as String;
      if (!message.contains('anomaly')) {
        print('   [Anomaly] $message');
      }
    },
  );

  // Start the system metrics
  await anomalyInput.emitAsync(null);
  systemMetrics.start();

  await Future.delayed(const Duration(seconds: 3));

  systemMetrics.stop();
  anomalyObserver.stop();
  normalObserver.stop();
  print('');

  // ========================================================================
  // 6. Real-Time Data Quality Pipeline
  // ========================================================================

  print('6. Real-Time Data Quality Pipeline');
  print('   ────────────────────────────────────────────────────────\n');

  final qualitySensor = SensorSimulator('SENSOR-QUALITY');
  final qualityInput = Cell.ingress<void>();

  final qualityHandle = Flow.fromStream<SensorReading>(
    qualityInput.cell,
    stream: qualitySensor.stream,
  );

  // Data quality checks
  int totalReadings = 0;
  int validReadings2 = 0;
  int invalidReadings2 = 0;
  double completenessScore = 0.0;

  final qualityPipeline = Flow.map<SensorReading, Map<String, dynamic>>(
    qualityHandle.cell,
    project: (reading) {
      totalReadings++;

      // Check data quality
      final isValid = reading.temperature >= -10 && reading.temperature <= 50 &&
          reading.humidity >= 0 && reading.humidity <= 100 &&
          reading.pressure >= 900 && reading.pressure <= 1100;

      if (isValid) {
        validReadings2++;
      } else {
        invalidReadings2++;
      }

      completenessScore = totalReadings > 0 ? (validReadings2 / totalReadings) * 100 : 0;

      return {
        'totalReadings': totalReadings,
        'validReadings2': validReadings2,
        'invalidReadings': invalidReadings2,
        'completenessScore': completenessScore,
        'isValid': isValid,
        'reading': reading,
      };
    },
  );

  // Separate valid and invalid readings
  final validStream = Flow.filter<Map<String, dynamic>>(
    qualityPipeline.cell,
    test: (data) => data['isValid'] as bool,
  );

  final qualityObserver = Cell.observe(
    source: validStream.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   [Quality] ✅ Data quality check passed: ${data['validReadings2']} records');
      print('   [Quality] ✅ Completeness score: ${(data['completenessScore'] as double).toStringAsFixed(1)}%');
    },
  );

  // Start the quality sensor
  await qualityInput.emitAsync(null);
  qualitySensor.start();

  await Future.delayed(const Duration(seconds: 2));

  qualitySensor.stop();
  qualityObserver.stop();
  print('');

  // ========================================================================
  // 7. Real-Time Data Enrichment Pipeline
  // ========================================================================

  print('7. Real-Time Data Enrichment Pipeline');
  print('   ────────────────────────────────────────────────────────\n');

  final enrichSensor = SensorSimulator('SENSOR-ENRICH');
  final enrichInput = Cell.ingress<void>();

  final enrichHandle = Flow.fromStream<SensorReading>(
    enrichInput.cell,
    stream: enrichSensor.stream,
  );

  // Enrich sensor data with additional context
  final enrichedData = Flow.map<SensorReading, Map<String, dynamic>>(
    enrichHandle.cell,
    project: (reading) {
      // Add calculated fields
      final heatIndex = reading.temperature + 0.5 * reading.humidity / 100;
      final dewPoint = reading.temperature - (100 - reading.humidity) / 5;

      return {
        'sensorId': reading.sensorId,
        'temperature': reading.temperature,
        'humidity': reading.humidity,
        'pressure': reading.pressure,
        'heatIndex': heatIndex,
        'dewPoint': dewPoint,
        'status': reading.status,
        'timestamp': reading.timestamp.toIso8601String(),
        'riskLevel': reading.isAnomaly ? 'HIGH' : 'LOW',
        'location': 'Zone-${reading.sensorId.split('-').last}',
      };
    },
  );

  final enrichObserver = Cell.observe(
    source: enrichedData.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   [Enriched] 📊 Sensor ${data['sensorId']}:');
      print('   - Temperature: ${(data['temperature'] as double).toStringAsFixed(1)}°C');
      print('   - Heat Index: ${(data['heatIndex'] as double).toStringAsFixed(1)}°C');
      print('   - Dew Point: ${(data['dewPoint'] as double).toStringAsFixed(1)}°C');
      print('   - Risk Level: ${data['riskLevel']}');
      print('   - Location: ${data['location']}');
      print('');
    },
  );

  // Start the enrichment sensor
  await enrichInput.emitAsync(null);
  enrichSensor.start();

  await Future.delayed(const Duration(seconds: 2));

  enrichSensor.stop();
  enrichObserver.stop();
  print('');

  // ========================================================================
  // 8. Real-Time Alert Aggregation
  // ========================================================================

  print('8. Real-Time Alert Aggregation');
  print('   ────────────────────────────────────────────────────────\n');

  final alertSensor1 = SensorSimulator('SENSOR-ALERT-1');
  final alertSensor2 = SensorSimulator('SENSOR-ALERT-2');
  final alertInput1 = Cell.ingress<void>();
  final alertInput2 = Cell.ingress<void>();

  final alertHandle1 = Flow.fromStream<SensorReading>(
    alertInput1.cell,
    stream: alertSensor1.stream,
  );

  final alertHandle2 = Flow.fromStream<SensorReading>(
    alertInput2.cell,
    stream: alertSensor2.stream,
  );

  // Detect alerts from each sensor
  final alertStream1 = Flow.filter<SensorReading>(
    alertHandle1.cell,
    test: (reading) => reading.isAnomaly,
  );

  final alertStream2 = Flow.filter<SensorReading>(
    alertHandle2.cell,
    test: (reading) => reading.isAnomaly,
  );

  // Aggregate alerts
  final alertAggregator = Cell.synthesis<Pulse<Map<String, dynamic>>>(
    [alertStream1.cell, alertStream2.cell],
    aggregator: (sources, emit) {
      final a1 = (sources.elementAt(0) as ValueCell<SensorReading>).value;
      final a2 = (sources.elementAt(1) as ValueCell<SensorReading>).value;

      final alerts = <String, double>{};
      if (a1 != null && a1.isAnomaly) {
        alerts[a1.sensorId] = a1.temperature;
      }
      if (a2 != null && a2.isAnomaly) {
        alerts[a2.sensorId] = a2.temperature;
      }

      if (alerts.isEmpty) return null;

      return Pulse<Map<String, dynamic>>({
        'alerts': alerts,
        'count': alerts.length,
        'timestamp': DateTime.now().toIso8601String(),
        'severity': alerts.length > 1 ? 'CRITICAL' : 'HIGH',
      });
    },
  );

  final alertObserver = Cell.observe(
    source: alertAggregator,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   [AlertAggregator] 🚨 ${data['severity']} ALERT:');
      final alerts = data['alerts'] as Map<String, double>;
      for (final entry in alerts.entries) {
        print('   - ${entry.key}: ${entry.value.toStringAsFixed(1)}°C');
      }
      print('   - Total Alerts: ${data['count']}');
      print('   - Timestamp: ${data['timestamp']}');
      print('');
    },
  );

  // Start both sensors
  await alertInput1.emitAsync(null);
  await alertInput2.emitAsync(null);

  alertSensor1.start();
  alertSensor2.start();

  await Future.delayed(const Duration(seconds: 2));

  alertSensor1.stop();
  alertSensor2.stop();
  alertObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Real-Time Data Pipeline with Flow.fromStream');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Feature                   │  Benefit                                 │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Stream Bridging          │  Connect external data sources            │
  │  Real-Time Processing     │  Process data as it arrives              │
  │  Data Quality             │  Ensure data integrity                    │
  │  Anomaly Detection        │  Identify issues in real-time            │
  │  Dashboard Updates        │  Live visualization updates              │
  │  Multiple Streams         │  Aggregate and combine data              │
  │  Data Enrichment          │  Add context to real-time data          │
  │  Alert Aggregation        │  Consolidate alerts from multiple sources │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 Use fromStream to bridge any Dart Stream into the reactive graph
  🔹 Process real-time data with reactive operators
  🔹 Combine multiple streams with synthesis
  🔹 Detect anomalies with filter and map
  🔹 Build real-time dashboards with aggregate state
  🔹 Enrich data with additional context
  🔹 Aggregate alerts from multiple sources
  🔹 Full provenance tracking across the pipeline

  Supported Stream Sources:
  - WebSocket connections
  - Server-Sent Events (SSE)
  - Hardware sensors
  - File watchers
  - Database change streams
  - Network sockets
  - Third-party SDKs
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
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

  /// Creates a synthesis cell.
  static FlowHandle synthesis(
      Iterable<Cell> sources, {
        required Pulse? Function(Iterable<Cell> cells, Pulse emit) aggregator,
      }) {
    final cell = Cell.synthesis<Pulse>(sources, aggregator: aggregator);
    return (
    cell: cell,
    emit: (input) => true,
    emitAsync: (input) async => true,
    ingest: (Pulse pulse, {bool serializedCompletion = true}) async => Future.value(),
    );
  }
}

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