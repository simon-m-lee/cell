// =============================================================================
// Practical executable walkthrough – Cell.valve
// Conditional Signal Propagation · Circuit Breaker · Gate Control
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

// ─────────────────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────────────────

/// Represents a system event with priority and category.
class SystemEvent {
  final String id;
  final String category;
  final int priority; // 0-100, higher = more important
  final String message;
  final DateTime timestamp;

  SystemEvent({
    required this.id,
    required this.category,
    required this.priority,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '[${category.toUpperCase()}] $message (priority: $priority)';
}

/// Represents a user action.
class UserAction {
  final String userId;
  final String action;
  final Map<String, dynamic> data;

  UserAction({
    required this.userId,
    required this.action,
    this.data = const {},
  });

  @override
  String toString() => 'User $userId -> $action';
}

/// Represents a data packet with sensitivity level.
class DataPacket {
  final String id;
  final String payload;
  final Sensitivity sensitivity;

  DataPacket({
    required this.id,
    required this.payload,
    this.sensitivity = Sensitivity.public,
  });

  @override
  String toString() => 'Packet $id (${sensitivity.name}): $payload';
}

// ─────────────────────────────────────────────────────────────────────────
// State Classes
// ─────────────────────────────────────────────────────────────────────────

/// State for rate limiter
class RateLimiterState {
  int count = 0;
  DateTime windowStart = DateTime.now();
}

/// State for toggleable gate
class GateState {
  bool isOpen = true;
}

// ─────────────────────────────────────────────────────────────────────────
// Custom Valve Implementation
// ─────────────────────────────────────────────────────────────────────────

/// Creates a valve cell using Cell.fromNucleus with a custom receptor.
Cell createValve<P>(
    bool Function(P pulse) gate, {
      required Cell source,
      Synapses synapses = Synapses.enabled,
    }) {
  final receptor = Receptor(
        (cell, pulse, {user}) {
      final payload = pulse.payload as P;
      final passes = gate(payload);

      // Log the valve decision
      if (passes) {
        print('   [Valve] ✅ PASS: ${payload.toString()}');
      } else {
        print('   [Valve] ❌ BLOCKED: ${payload.toString()}');
      }

      return passes ? pulse : null;
    },
  );

  final nucleus = Nucleus(
    bind: source,
    receptor: receptor,
    testRule: TestCell.allowAll,
    synapses: synapses,
    context: Context.system,
  );

  return Cell.fromNucleus(nucleus);
}

// ─────────────────────────────────────────────────────────────────────────
// Main Demo
// ─────────────────────────────────────────────────────────────────────────

/// ### Expected console output:
/// ```text
/// ── Cell.valve – Conditional Signal Propagation ──────────────────
///
/// 1. Basic Valve - Filtering by Priority
///    ── High Priority Events (>= 80) ──
///    [Valve] ✅ PASS: [CRITICAL] System failure detected (priority: 95)
///    [Obs] CRITICAL: System failure detected
///    [Valve] ✅ PASS: [WARNING] Memory usage high (priority: 80)
///    [Obs] WARNING: Memory usage high
///    [Valve] ❌ BLOCKED: [INFO] User logged in (priority: 30)
///    [Valve] ❌ BLOCKED: [DEBUG] Cache hit (priority: 10)
///    [Valve] ❌ BLOCKED: [INFO] Background task completed (priority: 40)
///
/// 2. Valve with Context-Aware Filtering
///    ── Admin-Only Events ──
///    [Valve] ✅ PASS: User admin_001 -> User role changed
///    [Obs] ADMIN: User role changed
///    [Valve] ❌ BLOCKED: User user_123 -> Profile updated
///    [Valve] ❌ BLOCKED: User guest_456 -> Page viewed
///    [Valve] ✅ PASS: User admin_002 -> System config updated
///    [Obs] ADMIN: System config updated
///
/// 3. Valve as Circuit Breaker - Rate Limiting
///    ── Rate Limited API Calls (max 3 per second) ──
///    [Valve] ✅ PASS: 1
///    [Obs] API call #1
///    [Valve] ✅ PASS: 2
///    [Obs] API call #2
///    [Valve] ✅ PASS: 3
///    [Obs] API call #3
///    [Valve] ❌ BLOCKED: 4
///    [Valve] ❌ BLOCKED: 5
///    [Valve] ❌ BLOCKED: 6
///    (Window reset after 1 second)
///    [Valve] ✅ PASS: 7
///    [Obs] API call #7
///    [Valve] ✅ PASS: 8
///    [Obs] API call #8
///    [Valve] ✅ PASS: 9
///    [Obs] API call #9
///
/// 4. Valve with Sensitivity Filtering
///    ── Filtering by Data Sensitivity ──
///    [Valve] ❌ BLOCKED: Packet PII-001 (confidential): johndoe@email.com
///    [Valve] ✅ PASS: Packet PUB-001 (public): Hello World
///    [Obs] PUB-001: Hello World
///    [Valve] ❌ BLOCKED: Packet SEC-001 (restricted): Secret API Key
///    [Valve] ✅ PASS: Packet PUB-002 (public): Public announcement
///    [Obs] PUB-002: Public announcement
///
/// 5. Dynamic Valve - Toggleable Gate
///    ── Toggleable Gate ──
///    [Valve] State: OPEN
///    [Valve] ✅ PASS: Message 1
///    [Obs] Message 1
///    [Valve] State: CLOSED
///    [Valve] ❌ BLOCKED: Message 2
///    [Valve] ❌ BLOCKED: Message 3
///    [Valve] State: OPEN
///    [Valve] ✅ PASS: Message 4
///    [Obs] Message 4
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.valve – Conditional Signal Propagation ──────────────────\n');

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Basic Valve - Filtering by Priority
  // ─────────────────────────────────────────────────────────────────────────

  print('1. Basic Valve - Filtering by Priority');
  print('   ── High Priority Events (>= 80) ──');

  final eventSource = Cell.ingress<SystemEvent>();

  final highPriorityValve = createValve<SystemEvent>(
        (event) => event.priority >= 80,
    source: eventSource.cell,
  );

  final highPriorityObs = Cell.observe(
    source: highPriorityValve,
    effect: (Pulse pulse) {
      final event = pulse.payload as SystemEvent;
      print('   [Obs] ${event.category.toUpperCase()}: ${event.message}');
    },
  );

  final events = [
    SystemEvent(id: '1', category: 'critical', priority: 95, message: 'System failure detected'),
    SystemEvent(id: '2', category: 'warning', priority: 80, message: 'Memory usage high'),
    SystemEvent(id: '3', category: 'info', priority: 30, message: 'User logged in'),
    SystemEvent(id: '4', category: 'debug', priority: 10, message: 'Cache hit'),
    SystemEvent(id: '5', category: 'info', priority: 40, message: 'Background task completed'),
  ];

  for (final event in events) {
    eventSource.emit(event);
    await Future.delayed(Duration(milliseconds: 30));
  }

  highPriorityObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Valve with Context-Aware Filtering
  // ─────────────────────────────────────────────────────────────────────────

  print('2. Valve with Context-Aware Filtering');
  print('   ── Admin-Only Events ──');

  final actionSource = Cell.ingress<UserAction>();

  final adminOnlyValve = createValve<UserAction>(
        (action) => action.userId.startsWith('admin'),
    source: actionSource.cell,
  );

  final adminOnlyObs = Cell.observe(
    source: adminOnlyValve,
    effect: (Pulse pulse) {
      final action = pulse.payload as UserAction;
      print('   [Obs] ADMIN: ${action.action}');
    },
  );

  final actions = [
    UserAction(userId: 'admin_001', action: 'User role changed'),
    UserAction(userId: 'user_123', action: 'Profile updated'),
    UserAction(userId: 'guest_456', action: 'Page viewed'),
    UserAction(userId: 'admin_002', action: 'System config updated'),
  ];

  for (final action in actions) {
    actionSource.emit(action);
    await Future.delayed(Duration(milliseconds: 30));
  }

  adminOnlyObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Valve as Circuit Breaker - Rate Limiting
  // ─────────────────────────────────────────────────────────────────────────

  print('3. Valve as Circuit Breaker - Rate Limiting');
  print('   ── Rate Limited API Calls (max 3 per second) ──');

  final rateState = RateLimiterState();

  final apiSource = Cell.ingress<String>();

  final rateLimitValve = createValve<String>(
        (call) {
      final now = DateTime.now();
      if (now.difference(rateState.windowStart) > Duration(seconds: 1)) {
        rateState.count = 0;
        rateState.windowStart = now;
      }

      if (rateState.count < 3) {
        rateState.count++;
        return true;
      }
      return false;
    },
    source: apiSource.cell,
  );

  final rateObs = Cell.observe(
    source: rateLimitValve,
    effect: (Pulse pulse) {
      print('   [Obs] API call #${pulse.payload}');
    },
  );

  for (int i = 1; i <= 9; i++) {
    apiSource.emit('$i');

    if (i == 6) {
      print('   (Window reset after 1 second)');
      await Future.delayed(Duration(seconds: 1));
    } else {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  rateObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Valve with Sensitivity Filtering
  // ─────────────────────────────────────────────────────────────────────────

  print('4. Valve with Sensitivity Filtering');
  print('   ── Filtering by Data Sensitivity ──');

  final dataSource = Cell.ingress<DataPacket>();

  final publicOnlyValve = createValve<DataPacket>(
        (packet) => packet.sensitivity == Sensitivity.public,
    source: dataSource.cell,
  );

  final publicOnlyObs = Cell.observe(
    source: publicOnlyValve,
    effect: (Pulse pulse) {
      final packet = pulse.payload as DataPacket;
      print('   [Obs] ${packet.id}: ${packet.payload}');
    },
  );

  final packets = [
    DataPacket(id: 'PII-001', payload: 'johndoe@email.com', sensitivity: Sensitivity.confidential),
    DataPacket(id: 'PUB-001', payload: 'Hello World', sensitivity: Sensitivity.public),
    DataPacket(id: 'SEC-001', payload: 'Secret API Key', sensitivity: Sensitivity.restricted),
    DataPacket(id: 'PUB-002', payload: 'Public announcement', sensitivity: Sensitivity.public),
  ];

  for (final packet in packets) {
    dataSource.emit(packet);
    await Future.delayed(Duration(milliseconds: 30));
  }

  publicOnlyObs.stop();
  print('');

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Dynamic Valve - Toggleable Gate
  // ─────────────────────────────────────────────────────────────────────────

  print('5. Dynamic Valve - Toggleable Gate');
  print('   ── Toggleable Gate ──');

  final gateState = GateState();

  final messageSource = Cell.ingress<String>();

  final gateValve = createValve<String>(
        (_) => gateState.isOpen,
    source: messageSource.cell,
  );

  final gateObs = Cell.observe(
    source: gateValve,
    effect: (Pulse pulse) {
      print('   [Obs] ${pulse.payload}');
    },
  );

  void toggleGate() {
    gateState.isOpen = !gateState.isOpen;
    print('   [Valve] State: ${gateState.isOpen ? 'OPEN' : 'CLOSED'}');
  }

  print('   [Valve] State: OPEN');

  messageSource.emit('Message 1');
  await Future.delayed(Duration(milliseconds: 50));

  toggleGate();

  messageSource.emit('Message 2');
  await Future.delayed(Duration(milliseconds: 50));

  messageSource.emit('Message 3');
  await Future.delayed(Duration(milliseconds: 50));

  toggleGate();

  messageSource.emit('Message 4');
  await Future.delayed(Duration(milliseconds: 50));

  gateObs.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}