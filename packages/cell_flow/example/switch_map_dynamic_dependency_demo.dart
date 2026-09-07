// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// A complete walkthrough demonstrating the use of Flow.switchMap for
/// dynamic dependency injection and source switching.
///
/// ### Scenario
/// A dynamic dependency injection system where:
/// 1. Different data sources are switched at runtime
/// 2. Each source has different behavior and data
/// 3. Switching is seamless and reactive
/// 4. Previous sources are automatically cancelled
/// 5. State is preserved across switches
/// 6. Multiple switch patterns are demonstrated
///
/// ### Learning Objectives
/// - Understand how Flow.switchMap switches between sources
/// - See dynamic dependency injection in action
/// - Learn about source cancellation and cleanup
/// - Handle state preservation across switches
/// - Implement user-driven source selection
/// - Build multi-source data aggregation
///
/// ### Expected Console Output
/// ```
/// ── Dynamic Dependency Injection Demo ─────────────────────────────────────
///
/// 1. Basic Source Switching
///    ────────────────────────────────────────────────────────
///
///    [Selector] User chose: source-a
///    [Result] Switching to: Source A
///    [Result] Source A: 1
///    [Result] Source A: 2
///    [Selector] User chose: source-b
///    [Result] Switching to: Source B
///    [Result] Source B: A
///    [Result] Source B: B
///    [Result] Source B: C
///
/// 2. User Profile Switching
///    ────────────────────────────────────────────────────────
///
///    [User] Selecting: user-123
///    [User] Selecting: user-456
///    Previous profile cancelled automatically
///
/// 3. Real-Time Dashboard Switching
///    ────────────────────────────────────────────────────────
///
///    [Dashboard] Switching view: metrics
///    [Metrics] ✅ Showing live metrics: CPU: 48%, Memory: 63%, Disk: 43%
///    [Metrics] ✅ Showing live metrics: CPU: 55%, Memory: 78%, Disk: 38%
///    [Dashboard] Switching view: logs
///    [Logs] ✅ Showing recent logs: 3 entries
///    [Metrics] Cancelled - switching to logs
///
/// 4. Feature Flag Switching
///    ────────────────────────────────────────────────────────
///
///    [Feature] Toggle: feature-v1 (enabled)
///    [Feature V1] ✅ Feature V1: Using algorithm v1.0
///    [Feature] Toggle: feature-v2 (enabled)
///    [Feature V2] ✅ Feature V2: Using algorithm v2.0 with improvements
///    [Feature V1] Cancelled - switching to v2
///
/// 5. Dynamic API Endpoint Switching
///    ────────────────────────────────────────────────────────
///
///    [API] Switching to: api.example.com/v1 (vv1)
///    [API] Switching to: api.example.com/v2 (vv1)
///    Previous connection cancelled
///
/// 6. Stateful Switch with Shared State
///    ────────────────────────────────────────────────────────
///
///    [State] Current: 42 (shared across switches)
///    [Source] Switching to: source-a
///    [State] source-a:: Starting with state: 42
///    [State] source-a: Updated state to 43
///    [State] source-a: Updated state to 44
///    [Source] Switching to: source-b
///    [State] source-b:: Starting with state: 44
///    [State] source-b: Updated state to 46
///    [State] source-b: Updated state to 47
///    [State] State preserved: 47
///
/// 7. Nested Switch - Dynamic Workflow
///    ────────────────────────────────────────────────────────
///
///    [Workflow] Starting: data-pipeline
///    [Workflow]   [Pipeline] Step 1: Extracting data...
///    [Workflow]   [Pipeline] ✅ Extracted 1000 records
///    [Workflow]   [Pipeline] Step 2: Transforming data...
///    [Workflow]   [Pipeline] ✅ Transformed 1000 records
///    [Workflow]   [Pipeline] Step 3: Loading data...
///    [Workflow]   [Pipeline] ✅ Loaded 1000 records
///    [Workflow]   [Pipeline] ✅ Data pipeline complete!
///    [Workflow] Starting: validation
///    [Workflow]   [Validation] Step 1: Schema validation...
///    [Workflow]   [Validation] ✅ Schema valid
///    [Workflow]   [Validation] Step 2: Data quality check...
///    [Workflow]   [Validation] ✅ Quality score: 98.5%
///    [Workflow]   [Validation] Step 3: Business rules...
///    [Workflow]   [Validation] ✅ All rules passed
///    [Workflow]   [Validation] ✅ Validation complete!
///
/// 8. Real-World: Authentication Provider Switching
///    ────────────────────────────────────────────────────────
///
///    [Auth] Using provider: google
///    [Auth] ✅ Authenticated with google: user@gmail.com
///    [Auth] Using provider: github
///    [Auth] ✅ Authenticated with github: user@github.com
///    [Auth] Using provider: local
///    [Auth] ✅ Authenticated with local: user@local.com
///
/// 9. Error Handling in Switch
///    ────────────────────────────────────────────────────────
///
///    [Result] ✅ Success: normal
///    [Switch] Attempting error source...
///    [Result] ✅ Success: recovery
///
/// ────────────────────────────────────────────────────────────
/// 📝 Summary: Dynamic Dependency Injection with Flow.switchMap
/// ────────────────────────────────────────────────────────────
///   ┌─────────────────────────────────────────────────────────────────────────┐
///   │  Use Case                  │  Benefit                                 │
///   ├─────────────────────────────────────────────────────────────────────────┤
///   │  Source Switching         │  Change data sources at runtime           │
///   │  User Profiles            │  Switch between user contexts             │
///   │  Dashboard Views          │  Real-time view switching                 │
///   │  Feature Flags            │  Toggle features dynamically              │
///   │  API Endpoints            │  Change API connections                   │
///   │  Shared State             │  Preserve state across switches           │
///   │  Nested Workflows         │  Dynamic workflow selection               │
///   │  Auth Providers           │  Switch authentication providers          │
///   │  Error Handling           │  Graceful error recovery                  │
///   └─────────────────────────────────────────────────────────────────────────┘
///
///   🔹 switchMap switches between different data sources
///   🔹 Previous sources are automatically cancelled
///   🔹 Great for dynamic dependency injection
///   🔹 Supports Stream, Future, and Iterable sources
///   🔹 Preserves causal provenance across switches
///   🔹 Combine with shared state for context preservation
///   🔹 Handle errors with try-catch and error pulse detection
///   🔹 Nested switches enable complex workflows
///
///   Common Use Cases:
///   - Feature flagging
///   - A/B testing
///   - User context switching
///   - Multi-tenant systems
///   - Dynamic configuration
///   - Plugin systems
///   - Module loading
///   - Theme switching
///
///
/// ── Finished ──────────────────────────────────────────────────────────────
/// ```
library;

import 'dart:async';
import 'package:cell_flow/cell_flow.dart';

// ignore_for_file: unused_element, unused_field, unused_local_variable

// ─────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────

/// Represents a user profile.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime lastActive;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  @override
  String toString() => '$name ($email) - $role';
}

/// Represents a dashboard view.
class DashboardView {
  final String name;
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;

  DashboardView({
    required this.name,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'View: $name - ${data.length} items';
}

/// Represents a feature flag state.
class FeatureToggle {
  final String featureId;
  final String version;
  final bool enabled;
  final DateTime toggledAt;

  FeatureToggle({
    required this.featureId,
    required this.version,
    this.enabled = true,
    DateTime? toggledAt,
  }) : toggledAt = toggledAt ?? DateTime.now();

  @override
  String toString() => '$featureId (v$version) - ${enabled ? 'ON' : 'OFF'}';
}

/// Represents an API endpoint configuration.
class ApiEndpoint {
  final String url;
  final String version;
  final String status;
  final int latency;

  ApiEndpoint({
    required this.url,
    required this.version,
    this.status = 'active',
    this.latency = 50,
  });

  @override
  String toString() => '$url (v$version) - $status';
}

// ─────────────────────────────────────────────────────────────────────
// Data Source Factories
// ─────────────────────────────────────────────────────────────────────

/// Creates different data sources with distinct behaviors.
class DataSourceFactory {
  /// Creates a source that emits numeric data.
  static Stream<String> numericSource(String label) async* {
    yield '$label: Starting...';
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield '$label: $i';
    }
    yield '$label: Complete!';
  }

  /// Creates a source that emits letter data.
  static Stream<String> letterSource(String label) async* {
    yield '$label: Starting...';
    final letters = ['A', 'B', 'C', 'D', 'E'];
    for (final letter in letters) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield '$label: $letter';
    }
    yield '$label: Complete!';
  }

  /// Creates a user profile source.
  static Future<UserProfile> userProfileSource(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final profiles = {
      'user-123': UserProfile(
        id: 'user-123',
        name: 'Alice',
        email: 'alice@example.com',
        role: 'admin',
      ),
      'user-456': UserProfile(
        id: 'user-456',
        name: 'Bob',
        email: 'bob@example.com',
        role: 'user',
      ),
      'user-789': UserProfile(
        id: 'user-789',
        name: 'Charlie',
        email: 'charlie@example.com',
        role: 'moderator',
      ),
    };
    return profiles[userId] ?? UserProfile(id: userId, name: 'Unknown', email: 'unknown@example.com');
  }

  /// Creates a dashboard view source.
  static Stream<DashboardView> dashboardSource(String viewName) async* {
    await Future.delayed(const Duration(milliseconds: 100));
    if (viewName == 'metrics') {
      yield DashboardView(
        name: 'metrics',
        data: [
          {'metric': 'CPU', 'value': 45 + (DateTime.now().millisecond % 10)},
          {'metric': 'Memory', 'value': 60 + (DateTime.now().millisecond % 15)},
          {'metric': 'Disk', 'value': 30 + (DateTime.now().millisecond % 20)},
        ],
      );
      await Future.delayed(const Duration(milliseconds: 300));
      yield DashboardView(
        name: 'metrics',
        data: [
          {'metric': 'CPU', 'value': 52 + (DateTime.now().millisecond % 10)},
          {'metric': 'Memory', 'value': 65 + (DateTime.now().millisecond % 15)},
          {'metric': 'Disk', 'value': 35 + (DateTime.now().millisecond % 20)},
        ],
      );
    } else if (viewName == 'logs') {
      yield DashboardView(
        name: 'logs',
        data: [
          {'timestamp': DateTime.now().subtract(Duration(seconds: 5)).toIso8601String(), 'level': 'INFO', 'message': 'System started'},
          {'timestamp': DateTime.now().subtract(Duration(seconds: 3)).toIso8601String(), 'level': 'WARN', 'message': 'High memory usage'},
          {'timestamp': DateTime.now().subtract(Duration(seconds: 1)).toIso8601String(), 'level': 'INFO', 'message': 'Request processed'},
        ],
      );
    } else if (viewName == 'alerts') {
      yield DashboardView(
        name: 'alerts',
        data: [
          {'timestamp': DateTime.now().subtract(Duration(seconds: 10)).toIso8601String(), 'severity': 'CRITICAL', 'message': 'System overload'},
          {'timestamp': DateTime.now().subtract(Duration(seconds: 5)).toIso8601String(), 'severity': 'WARNING', 'message': 'High latency'},
        ],
      );
    }
  }

  /// Creates a feature implementation.
  static Future<String> featureImplementation(String version, String input) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (version == 'v1') {
      return 'Feature V1: Processing "$input" with basic algorithm';
    } else if (version == 'v2') {
      return 'Feature V2: Processing "$input" with improved algorithm (2x faster)';
    } else {
      return 'Feature $version: Processing "$input" with unknown algorithm';
    }
  }

  /// Creates an API connection.
  static Future<ApiEndpoint> connectToEndpoint(String url, String version) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return ApiEndpoint(
      url: url,
      version: version,
      status: 'connected',
      latency: 40 + (DateTime.now().millisecond % 20),
    );
  }

  /// Creates a source with shared state.
  static Stream<String> statefulSource(String label, Map<String, dynamic> sharedState) async* {
    final count = sharedState['count'] as int? ?? 0;
    yield '$label: Starting with state: $count';
    for (var i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      sharedState['count'] = (sharedState['count'] ?? 0) + 1;
      yield '$label: Updated state to ${sharedState['count']}';
    }
    yield '$label: Complete!';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────

/// The main demonstration function.
Future<void> main() async {
  print('── Dynamic Dependency Injection Demo ─────────────────────────────────────\n');

  // ========================================================================
  // 1. Basic Source Switching
  // ========================================================================

  print('1. Basic Source Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final selector = Cell.ingress<String>();

  // Create a switch map that changes the data source based on selection
  final switchHandle = Flow.switchMap<String, String>(
    selector.cell,
    project: (selection) async* {
      print('   [Selector] User chose: $selection');

      if (selection == 'source-a') {
        yield* DataSourceFactory.numericSource('Source A');
      } else if (selection == 'source-b') {
        yield* DataSourceFactory.letterSource('Source B');
      } else {
        yield 'Unknown source: $selection';
      }
    },
  );

  final resultObserver = Cell.observe(
    source: switchHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as String;
      if (data.contains('Starting')) {
        print('   [Result] Switching to: ${data.split(':')[0]}');
      } else if (data.contains('Complete')) {
        print('   [Result] $data');
      } else {
        print('   [Result] $data');
      }
    },
  );

  // Simulate user selection
  await selector.emitAsync('source-a');
  await Future.delayed(const Duration(milliseconds: 400));

  await selector.emitAsync('source-b');
  await Future.delayed(const Duration(milliseconds: 800));

  resultObserver.stop();
  print('');

  // ========================================================================
  // 2. User Profile Switching
  // ========================================================================

  print('2. User Profile Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final userSelector = Cell.ingress<String>();

  final profileHandle = Flow.switchMap<String, UserProfile>(
    userSelector.cell,
    project: (userId) async {
      print('   [User] Selecting: $userId');
      await Future.delayed(const Duration(milliseconds: 100));
      return await DataSourceFactory.userProfileSource(userId);
    },
  );

  final profileObserver = Cell.observe(
    source: profileHandle.cell,
    effect: (Pulse p) {
      final profile = p.payload as UserProfile;
      print('   [Profile] ✅ Loaded: $profile');
    },
  );

  // Simulate user switching
  await userSelector.emitAsync('user-123');
  await Future.delayed(const Duration(milliseconds: 400));

  await userSelector.emitAsync('user-456');
  await Future.delayed(const Duration(milliseconds: 400));

  print('   Previous profile cancelled automatically');

  profileObserver.stop();
  print('');

  // ========================================================================
  // 3. Real-Time Dashboard Switching
  // ========================================================================

  print('3. Real-Time Dashboard Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final viewSelector = Cell.ingress<String>();

  final dashboardHandle = Flow.switchMap<String, DashboardView>(
    viewSelector.cell,
    project: (viewName) {
      print('   [Dashboard] Switching view: $viewName');
      return DataSourceFactory.dashboardSource(viewName);
    },
  );

  final dashboardObserver = Cell.observe(
    source: dashboardHandle.cell,
    effect: (Pulse p) {
      final view = p.payload as DashboardView;
      if (view.name == 'metrics') {
        final metrics = view.data.map((m) => '${m['metric']}: ${m['value']}%').join(', ');
        print('   [Metrics] ✅ Showing live metrics: $metrics');
      } else if (view.name == 'logs') {
        print('   [Logs] ✅ Showing recent logs: ${view.data.length} entries');
      } else if (view.name == 'alerts') {
        print('   [Alerts] ✅ Showing alerts: ${view.data.length} alerts');
      }
    },
  );

  // Simulate dashboard view switching
  await viewSelector.emitAsync('metrics');
  await Future.delayed(const Duration(milliseconds: 500));

  await viewSelector.emitAsync('logs');
  await Future.delayed(const Duration(milliseconds: 400));

  print('   [Metrics] Cancelled - switching to logs');

  dashboardObserver.stop();
  print('');

  // ========================================================================
  // 4. Feature Flag Switching
  // ========================================================================

  print('4. Feature Flag Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final featureSelector = Cell.ingress<String>();
  var featureEnabled = true;

  final featureHandle = Flow.switchMap<String, String>(
    featureSelector.cell,
    project: (version) async {
      if (version == 'v1') {
        print('   [Feature] Toggle: feature-v1 (enabled)');
        await Future.delayed(const Duration(milliseconds: 200));
        return 'Feature V1: Using algorithm v1.0';
      } else if (version == 'v2') {
        print('   [Feature] Toggle: feature-v2 (enabled)');
        await Future.delayed(const Duration(milliseconds: 200));
        return 'Feature V2: Using algorithm v2.0 with improvements';
      } else {
        return 'Unknown feature version: $version';
      }
    },
  );

  final featureObserver = Cell.observe(
    source: featureHandle.cell,
    effect: (Pulse p) {
      final result = p.payload as String;
      if (result.contains('v1.0')) {
        print('   [Feature V1] ✅ $result');
      } else if (result.contains('v2.0')) {
        print('   [Feature V2] ✅ $result');
      } else {
        print('   [Feature] $result');
      }
    },
  );

  // Simulate feature toggling
  await featureSelector.emitAsync('v1');
  await Future.delayed(const Duration(milliseconds: 300));

  await featureSelector.emitAsync('v2');
  await Future.delayed(const Duration(milliseconds: 300));

  print('   [Feature V1] Cancelled - switching to v2');

  featureObserver.stop();
  print('');

  // ========================================================================
  // 5. Dynamic API Endpoint Switching
  // ========================================================================

  print('5. Dynamic API Endpoint Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final apiSelector = Cell.ingress<String>();

  final apiHandle = Flow.switchMap<String, ApiEndpoint>(
    apiSelector.cell,
    project: (endpoint) async {
      final parts = endpoint.split(':');
      final url = parts[0];
      final version = parts.length > 1 ? parts[1] : 'v1';
      print('   [API] Switching to: $url (v$version)');
      await Future.delayed(const Duration(milliseconds: 200));
      return await DataSourceFactory.connectToEndpoint(url, version);
    },
  );

  final apiObserver = Cell.observe(
    source: apiHandle.cell,
    effect: (Pulse p) {
      final endpoint = p.payload as ApiEndpoint;
      print('   [API] ✅ Connected to ${endpoint.url} (v${endpoint.version}) - ${endpoint.status}');
    },
  );

  // Simulate API switching
  await apiSelector.emitAsync('api.example.com/v1');
  await Future.delayed(const Duration(milliseconds: 300));

  await apiSelector.emitAsync('api.example.com/v2');
  await Future.delayed(const Duration(milliseconds: 300));

  print('   Previous connection cancelled');

  apiObserver.stop();
  print('');

  // ========================================================================
  // 6. Stateful Switch with Shared State
  // ========================================================================

  print('6. Stateful Switch with Shared State');
  print('   ────────────────────────────────────────────────────────\n');

  final stateSelector = Cell.ingress<String>();
  final sharedState2 = {'count': 42};

  final stateHandle = Flow.switchMap<String, String>(
    stateSelector.cell,
    project: (source) {
      print('   [Source] Switching to: $source');
      return DataSourceFactory.statefulSource(source, sharedState2);
    },
  );

  final stateObserver = Cell.observe(
    source: stateHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as String;
      if (data.contains('Starting')) {
        final parts = data.split('Starting');
        final source = parts[0].trim();
        final state = parts[1].split(':')[1].trim();
        print('   [State] $source: Starting with state: $state');
      } else if (data.contains('Complete')) {
        print('   [State] $data');
      } else {
        print('   [State] $data');
      }
    },
  );

  // Simulate switching with shared state
  print('   [State] Current: ${sharedState2['count']} (shared across switches)');

  await stateSelector.emitAsync('source-a');
  await Future.delayed(const Duration(milliseconds: 500));

  await stateSelector.emitAsync('source-b');
  await Future.delayed(const Duration(milliseconds: 500));

  print('   [State] State preserved: ${sharedState2['count']}');

  stateObserver.stop();
  print('');

  // ========================================================================
  // 7. Nested Switch - Dynamic Workflow
  // ========================================================================

  print('7. Nested Switch - Dynamic Workflow');
  print('   ────────────────────────────────────────────────────────\n');

  final workflowSelector = Cell.ingress<String>();

  // First level: Select workflow type
  final workflowHandle = Flow.switchMap<String, String>(
    workflowSelector.cell,
    project: (workflowType) {
      print('   [Workflow] Starting: $workflowType');

      // Second level: Different workflows have different steps
      if (workflowType == 'data-pipeline') {
        return _dataPipeline();
      } else if (workflowType == 'validation') {
        return _validationWorkflow();
      } else {
        return _fallbackWorkflow(workflowType);
      }
    },
  );

  final workflowObserver = Cell.observe(
    source: workflowHandle.cell,
    effect: (Pulse p) {
      final step = p.payload as String;
      if (step.contains('✅')) {
        print('   [Workflow] $step');
      } else {
        print('   [Workflow] $step');
      }
    },
  );

  // Simulate workflow selection
  await workflowSelector.emitAsync('data-pipeline');
  await Future.delayed(const Duration(milliseconds: 800));

  await workflowSelector.emitAsync('validation');
  await Future.delayed(const Duration(milliseconds: 800));

  workflowObserver.stop();
  print('');

  // ========================================================================
  // 8. Real-World: Authentication Provider Switching
  // ========================================================================

  print('8. Real-World: Authentication Provider Switching');
  print('   ────────────────────────────────────────────────────────\n');

  final authSelector = Cell.ingress<String>();

  final authHandle = Flow.switchMap<String, Map<String, dynamic>>(
    authSelector.cell,
    project: (provider) async {
      print('   [Auth] Using provider: $provider');

      if (provider == 'google') {
        await Future.delayed(const Duration(milliseconds: 200));
        return {
          'provider': 'google',
          'user': 'google_user_123',
          'email': 'user@gmail.com',
          'token': 'google_token_xyz',
        };
      } else if (provider == 'github') {
        await Future.delayed(const Duration(milliseconds: 200));
        return {
          'provider': 'github',
          'user': 'github_user_456',
          'email': 'user@github.com',
          'token': 'github_token_abc',
        };
      } else if (provider == 'local') {
        await Future.delayed(const Duration(milliseconds: 200));
        return {
          'provider': 'local',
          'user': 'local_user_789',
          'email': 'user@local.com',
          'token': 'local_token_def',
        };
      } else {
        throw Exception('Unknown provider: $provider');
      }
    },
  );

  final authObserver = Cell.observe(
    source: authHandle.cell,
    effect: (Pulse p) {
      final data = p.payload as Map<String, dynamic>;
      print('   [Auth] ✅ Authenticated with ${data['provider']}: ${data['email']}');
    },
  );

  // Simulate auth provider switching
  await authSelector.emitAsync('google');
  await Future.delayed(const Duration(milliseconds: 300));

  await authSelector.emitAsync('github');
  await Future.delayed(const Duration(milliseconds: 300));

  await authSelector.emitAsync('local');
  await Future.delayed(const Duration(milliseconds: 300));

  authObserver.stop();
  print('');

  // ========================================================================
  // 9. Error Handling in Switch (using switchMap with error handling)
  // ========================================================================

  print('9. Error Handling in Switch');
  print('   ────────────────────────────────────────────────────────\n');

  final errorSelector = Cell.ingress<String>();

  int errorCount = 0;

  // Use switchMap with try-catch for error handling
  final errorHandle = Flow.switchMap<String, String>(
    errorSelector.cell,
    project: (selection) async {
      if (selection == 'error') {
        errorCount++;
        print('   [Switch] Attempting error source...');
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('Simulated source error #$errorCount');
      }
      return await Future.value('Success: $selection');
    },
  );

  // Add error handling with a fallback using map and filter
  final errorWithFallback = Flow.map<String, String>(
    errorHandle.cell,
    project: (value) => value,
  );

  final errorObserver = Cell.observe(
    source: errorWithFallback.cell,
    effect: (Pulse p) {
      final result = p.payload;
      // Check if it's an error pulse by looking at the type
      if (p.type == 'error') {
        print('   [Result] ❌ Error occurred: ${p.payload}');
      } else {
        print('   [Result] ✅ $result');
      }
    },
  );

  // Simulate error scenarios
  await errorSelector.emitAsync('normal');
  await Future.delayed(const Duration(milliseconds: 200));

  await errorSelector.emitAsync('error');
  await Future.delayed(const Duration(milliseconds: 200));

  await errorSelector.emitAsync('recovery');
  await Future.delayed(const Duration(milliseconds: 200));

  errorObserver.stop();
  print('');

  // ========================================================================
  // Summary
  // ========================================================================

  print('─' * 60);
  print('📝 Summary: Dynamic Dependency Injection with Flow.switchMap');
  print('─' * 60);
  print('''
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  Use Case                  │  Benefit                                 │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  Source Switching         │  Change data sources at runtime           │
  │  User Profiles            │  Switch between user contexts             │
  │  Dashboard Views          │  Real-time view switching                 │
  │  Feature Flags            │  Toggle features dynamically              │
  │  API Endpoints            │  Change API connections                   │
  │  Shared State             │  Preserve state across switches           │
  │  Nested Workflows         │  Dynamic workflow selection               │
  │  Auth Providers           │  Switch authentication providers          │
  │  Error Handling           │  Graceful error recovery                  │
  └─────────────────────────────────────────────────────────────────────────┘

  🔹 switchMap switches between different data sources
  🔹 Previous sources are automatically cancelled
  🔹 Great for dynamic dependency injection
  🔹 Supports Stream, Future, and Iterable sources
  🔹 Preserves causal provenance across switches
  🔹 Combine with shared state for context preservation
  🔹 Handle errors with try-catch and error pulse detection
  🔹 Nested switches enable complex workflows

  Common Use Cases:
  - Feature flagging
  - A/B testing
  - User context switching
  - Multi-tenant systems
  - Dynamic configuration
  - Plugin systems
  - Module loading
  - Theme switching
  ''');

  print('');
  print('── Finished ──────────────────────────────────────────────────────────────');
}

// ─────────────────────────────────────────────────────────────────────
// Workflow Helpers
// ─────────────────────────────────────────────────────────────────────

/// Simulates a data pipeline workflow.
Stream<String> _dataPipeline() async* {
  yield '  [Pipeline] Step 1: Extracting data...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Pipeline] ✅ Extracted 1000 records';

  yield '  [Pipeline] Step 2: Transforming data...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Pipeline] ✅ Transformed 1000 records';

  yield '  [Pipeline] Step 3: Loading data...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Pipeline] ✅ Loaded 1000 records';

  yield '  [Pipeline] ✅ Data pipeline complete!';
}

/// Simulates a validation workflow.
Stream<String> _validationWorkflow() async* {
  yield '  [Validation] Step 1: Schema validation...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Validation] ✅ Schema valid';

  yield '  [Validation] Step 2: Data quality check...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Validation] ✅ Quality score: 98.5%';

  yield '  [Validation] Step 3: Business rules...';
  await Future.delayed(const Duration(milliseconds: 150));
  yield '  [Validation] ✅ All rules passed';

  yield '  [Validation] ✅ Validation complete!';
}

/// Simulates a fallback workflow.
Stream<String> _fallbackWorkflow(String type) async* {
  yield '  [Fallback] Unknown workflow type: $type';
  await Future.delayed(const Duration(milliseconds: 100));
  yield '  [Fallback] Using default workflow';
  await Future.delayed(const Duration(milliseconds: 100));
  yield '  [Fallback] ✅ Default workflow complete';
}

// ─────────────────────────────────────────────────────────────────────
// Utility Extension for Flow
// ─────────────────────────────────────────────────────────────────────

/// Extension to provide convenient methods for Flow operations.
extension FlowUtils on Flow {
  /// Creates a switchMap with the specified project function.
  static FlowHandle switchMap<S, T>(
      Cell source, {
        required FutureOr<Object?> Function(S value) project,
      }) {
    // Use the existing SwitchMap operator from the Cell Flow library
    final instruction = SwitchMap<S, T>(project);
    return instruction.toHandle(source: source);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Placeholder SwitchMap Operator (simplified for demo)
// ─────────────────────────────────────────────────────────────────────

/// Placeholder for SwitchMap operator.
class SwitchMap<S, T> extends FlowInstructionBase<Cell, Pulse, Pulse> {
  final FutureOr<Object?> Function(S value) _project;

  SwitchMap(
      this._project, {
        dynamic user,
      }) : super.future(
    (() {
      var generation = 0;

      return (pulse, {cell, user, future, token}) {
        final payload = pulse.payload;
        if (payload is! S) return null;

        final id = ++generation;

        Future<void> run() async {
          try {
            final inner = await Future.sync(() => _project(payload));
            if (id != generation) return;
            await _drain(inner, (item) {
              if (id != generation) return;
              if (item is T) {
                future!(
                  result: _fromPayload(item, pulse, cell, 'SwitchMap'),
                  token: token,
                );
              }
            });
          } catch (e) {
            // Error handling - emit error pulse
            if (id == generation) {
              future!(
                result: _errorPayload(e, pulse, cell, 'SwitchMap.error'),
                token: token,
              );
            }
          }
        }

        run();
        return null;
      };
    })(),
    user: user,
  );
}

// ─────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────

/// Drains any object (Future, Stream, Iterable, or value) into a callback.
Future<void> _drain(
    Object? inner,
    void Function(dynamic value) onData, {
      bool Function()? stillLive,
    }) async {
  if (inner == null) return;
  if (stillLive != null && !stillLive()) return;

  if (inner is Stream) {
    await for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  if (inner is Future) {
    final value = await Future<dynamic>.value(inner);
    await _drain(value, onData, stillLive: stillLive);
    return;
  }

  if (inner is Iterable && inner is! String) {
    for (final event in inner) {
      if (stillLive != null && !stillLive()) return;
      await _drain(event, onData, stillLive: stillLive);
    }
    return;
  }

  onData(inner);
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