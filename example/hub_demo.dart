// =============================================================================
// Practical executable walkthrough – Cell.hub
// Pattern matching · Priority ordering · Multicast routing
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.hub – Pattern matching, Priority & Multicast ─────────
///
/// 1. Exact / high-priority match – type "auth.login"
///    [Auth]     received: "user=alice"  (type=auth.login)
///
/// 2. Pattern match – type "user.profile.update"
///    [User]     received: "name=Bob"  (type=user.profile.update)
///
/// 3. Pattern match – type "admin.delete.account"
///    [Admin]    received: "id=42"  (type=admin.delete.account)
///
/// 4. No specific match → fallback
///    [Fallback] received: "ping"  (type=system.heartbeat)
///
/// 5. Multicast mode – all matching spokes receive the pulse
///    [Metrics]  received: "cpu=42%"  (type=metrics.cpu)
///    [Audit]    received: "cpu=42%"  (type=metrics.cpu)
///    [Log]      received: "user login"  (type=log.auth)
///    [Audit]    received: "user login"  (type=log.auth)
///
/// 6. Simple spokes map (exact routing)
///    [Save]     received: "document-1"
///    [Load]     received: "document-2"
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.hub – Pattern matching, Priority & Multicast ─────────\n');

  // -------------------------------------------------------------------------
  // 1. Spoke handlers (simple functions)
  // -------------------------------------------------------------------------
  Pulse? authHandler(Cell cell, Pulse pulse, {dynamic user}) {
    print('   [Auth]     received: "${pulse.payload}"  (type=${pulse.type})');
    return pulse;
  }

  Pulse? userHandler(Cell cell, Pulse pulse, {dynamic user}) {
    print('   [User]     received: "${pulse.payload}"  (type=${pulse.type})');
    return pulse;
  }

  Pulse? adminHandler(Cell cell, Pulse pulse, {dynamic user}) {
    print('   [Admin]    received: "${pulse.payload}"  (type=${pulse.type})');
    return pulse;
  }

  Pulse? auditHandler(Cell cell, Pulse pulse, {dynamic user}) {
    print('   [Audit]    received: "${pulse.payload}"  (type=${pulse.type})');
    return pulse;
  }

  Pulse? fallbackHandler(Cell cell, Pulse pulse, {dynamic user}) {
    print('   [Fallback] received: "${pulse.payload}"  (type=${pulse.type})');
    return pulse;
  }

  // -------------------------------------------------------------------------
  // 2. Hub with priority-ordered registrations + pattern routing
  // -------------------------------------------------------------------------
  //
  // Higher priority is preferred when multiple spokes match.
  // routing: HubRouting.pattern enables wildcard matching (* and ?).
  //
  final hub = Cell.hub(
    routing: HubRouting.pattern,
    fallback: 'fallback',
    registrations: [
      // Highest priority – exact key (still works under pattern mode)
      (
      key: 'auth.login',
      priority: 100,
      handler: authHandler,
      match: null,
      receptor: null,
      context: null,
      ),
      // Prefix-style pattern for any user event
      (
      key: 'user.*',
      priority: 80,
      handler: userHandler,
      match: null,
      receptor: null,
      context: null,
      ),
      // Broader admin pattern
      (
      key: 'admin.*',
      priority: 70,
      handler: adminHandler,
      match: null,
      receptor: null,
      context: null,
      ),
      // Low-priority catch-all used as fallback
      (
      key: 'fallback',
      priority: 0,
      handler: fallbackHandler,
      match: null,
      receptor: null,
      context: null,
      ),
    ],
  );

  // -------------------------------------------------------------------------
  // 3. Demonstrate priority + pattern matching
  // -------------------------------------------------------------------------
  print('1. Exact / high-priority match – type "auth.login"');
  hub.emit(Pulse('user=alice', type: 'auth.login'));
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n2. Pattern match – type "user.profile.update"');
  hub.emit(Pulse('name=Bob', type: 'user.profile.update'));
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n3. Pattern match – type "admin.delete.account"');
  hub.emit(Pulse('id=42', type: 'admin.delete.account'));
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n4. No specific match → fallback');
  hub.emit(Pulse('ping', type: 'system.heartbeat'));
  await Future.delayed(const Duration(milliseconds: 40));

  // -------------------------------------------------------------------------
  // 4. Multicast hub – every matching spoke receives the pulse
  // -------------------------------------------------------------------------
  print('\n5. Multicast mode – all matching spokes receive the pulse');

  final multicastHub = Cell.hub(
    routing: HubRouting.pattern,
    multicast: true, // deliver to every match
    registrations: [
      (
      key: 'metrics.*',
      priority: 50,
      handler: (cell, pulse, {user}) {
        print('   [Metrics]  received: "${pulse.payload}"  (type=${pulse.type})');
        return pulse;
      },
      match: null,
      receptor: null,
      context: null,
      ),
      (
      key: 'log.*',
      priority: 40,
      handler: (cell, pulse, {user}) {
        print('   [Log]      received: "${pulse.payload}"  (type=${pulse.type})');
        return pulse;
      },
      match: null,
      receptor: null,
      context: null,
      ),
      (
      key: '*', // matches everything
      priority: 10,
      handler: auditHandler,
      match: null,
      receptor: null,
      context: null,
      ),
    ],
  );

  multicastHub.emit(Pulse('cpu=42%', type: 'metrics.cpu'));
  await Future.delayed(const Duration(milliseconds: 40));

  multicastHub.emit(Pulse('user login', type: 'log.auth'));
  await Future.delayed(const Duration(milliseconds: 40));

  // -------------------------------------------------------------------------
  // 5. Simple spokes map (exact routing) – concise form
  // -------------------------------------------------------------------------
  print('\n6. Simple spokes map (exact routing)');

  final simpleHub = Cell.hub(
    routing: HubRouting.exact,
    spokes: {
      'save': (cell, pulse, {user}) {
        print('   [Save]     received: "${pulse.payload}"');
        return pulse;
      },
      'load': (cell, pulse, {user}) {
        print('   [Load]     received: "${pulse.payload}"');
        return pulse;
      },
    },
  );

  simpleHub.emit(Pulse('document-1', type: 'save'));
  simpleHub.emit(Pulse('document-2', type: 'load'));
  await Future.delayed(const Duration(milliseconds: 40));

  print('\n── finished ──────────────────────────────────────────────────');
}