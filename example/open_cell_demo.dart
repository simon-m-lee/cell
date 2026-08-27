// =============================================================================
// Practical executable walkthrough – Cell.open
// Manual signal injection · Dynamic topology (link / unlink)
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// Expected console output:
/// ```text
/// ── Cell.open – Manual Injection & Dynamic Topology ───────────
///
/// 1. Manual signal injection via emit
///    linked logger → gate
///    [Gate]    received payload=PING type=system.ping
///    [Logger]  {cmd: PING, handled: true}
///    [Gate]    received payload=STATUS type=system.status
///    [Logger]  {cmd: STATUS, handled: true}
///
/// 2. Dynamic topology (link / unlink)
///    linked metrics
///    [Gate]    received payload=SAVE type=system.save
///    [Logger]  {cmd: SAVE, handled: true}
///    [Metrics] count+1 payload={cmd: SAVE, handled: true}
///    unlinked logger
///    [Gate]    received payload=SAVE type=system.save
///    [Metrics] count+1 payload={cmd: SAVE, handled: true}
///    unlinked metrics
///    [Gate]    received payload=NOOP type=system.noop
///
/// 3. UI panel attach / detach
///    attached A
///    attached B
///    [Panel:A] {view: dashboard}
///    [Panel:B] {view: dashboard}
///    detached A
///    [Panel:B] {view: settings}
///
/// 4. Hybrid mode (bind + manual emit)
///    [Hybrid]  payload=42 type=sensor.reading
///    [HybridOut] 42
///    [Hybrid]  payload=99 type=sensor.override
///    [HybridOut] 99
///
/// 5. OpenCell.perform (command target)
///    [Perform] {op: credit, amount: 25} → balance 100 → 125
///    [Perform] {op: debit, amount: 10} → balance 125 → 115
///    final balance: 115
///
/// 6. Scripted injection (test harness)
///    results: [4, 9, 16]
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.open – Manual Injection & Dynamic Topology ───────────\n');

  // -------------------------------------------------------------------------
  // 1. Create an open gateway and inject signals manually
  // -------------------------------------------------------------------------
  print('1. Manual signal injection via emit');

  final gate = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        // Transform / tag manual commands
        final cmd = pulse.payload;
        print('   [Gate]    received payload=$cmd type=${pulse.type}');
        return Pulse(
          {'cmd': cmd, 'handled': true},
          type: pulse.type ?? 'command',
        );
      },
    ),
  );

  // Downstream logger linked at runtime
  final logger = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        print('   [Logger]  ${pulse.payload}');
        return pulse;
      },
    ),
  );

  final unlinkLogger = await gate.link(logger);
  print('   linked logger → gate');

  gate.emit(Pulse('PING', type: 'system.ping'));
  await Future.delayed(const Duration(milliseconds: 30));

  await gate.ingest(
    Pulse('STATUS', type: 'system.status'),
  );
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // 2. Dynamic topology – link a second observer, then unlink the first
  // -------------------------------------------------------------------------
  print('\n2. Dynamic topology (link / unlink)');

  final metrics = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        print('   [Metrics] count+1 payload=${pulse.payload}');
        return pulse;
      },
    ),
  );

  final unlinkMetrics = await gate.link(metrics);
  print('   linked metrics');

  gate.emit(Pulse('SAVE', type: 'system.save'));
  await Future.delayed(const Duration(milliseconds: 30));

  // Detach logger – further pulses should not reach it
  unlinkLogger?.call();
  print('   unlinked logger');

  gate.emit(Pulse('SAVE', type: 'system.save'));
  await Future.delayed(const Duration(milliseconds: 30));
  // Expect Metrics only (no Logger)

  unlinkMetrics?.call();
  print('   unlinked metrics');

  gate.emit(Pulse('NOOP', type: 'system.noop'));
  await Future.delayed(const Duration(milliseconds: 20));
  // Expect Gate only (no downstream)

  // -------------------------------------------------------------------------
  // 3. UI panel attach / detach pattern
  // -------------------------------------------------------------------------
  print('\n3. UI panel attach / detach');

  final bus = Cell.open(
    receptor: Receptor.passThrough,
  );

  final panels = <String, Cell>{};

  Future<void Function()?> attachPanel(String name) async {
    final panel = Cell.open(
      receptor: Receptor(
            (cell, pulse, {user}) {
          print('   [Panel:$name] ${pulse.payload}');
          return pulse;
        },
      ),
    );
    panels[name] = panel;
    final unlink = await bus.link(panel);
    print('   attached $name');
    return unlink;
  }

  final unlinkA = await attachPanel('A');
  final unlinkB = await attachPanel('B');

  bus.emit(Pulse({'view': 'dashboard'}, type: 'ui.nav'));
  await Future.delayed(const Duration(milliseconds: 30));

  unlinkA?.call();
  print('   detached A');

  bus.emit(Pulse({'view': 'settings'}, type: 'ui.nav'));
  await Future.delayed(const Duration(milliseconds: 30));
  // Only Panel:B

  unlinkB?.call();

  // -------------------------------------------------------------------------
  // 4. Hybrid mode – bind upstream + still accept manual emit
  // -------------------------------------------------------------------------
  print('\n4. Hybrid mode (bind + manual emit)');

  final sensor = Cell.ingress<int>();

  final hybrid = Cell.open(
    source: sensor.cell,
    receptor: Receptor(
          (cell, pulse, {user}) {
        print('   [Hybrid]  payload=${pulse.payload} type=${pulse.type}');
        return pulse;
      },
    ),
  );

  final hybridOut = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        print('   [HybridOut] ${pulse.payload}');
        return pulse;
      },
    ),
  );
  await hybrid.link(hybridOut);

  // Automatic path from bound source
  await sensor.ingest(
    Pulse(42, type: 'sensor.reading', source: sensor.cell),
  );
  await Future.delayed(const Duration(milliseconds: 30));

  // Manual injection on the same open cell
  hybrid.emit(Pulse(99, type: 'sensor.override'));
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // 5. OpenCell.perform – action-oriented node
  // -------------------------------------------------------------------------
  print('\n5. OpenCell.perform (command target)');

  final account = Cell.state<int>(
    initial: 100,
    evolve: (host, pulse) {
      final v = pulse.payload;
      return v is int ? Pulse(v) : null;
    },
  );

  final commands = OpenCell.perform(
    account.cell,
        (on, pulse, {user}) {
      final op = pulse.payload as Map<String, dynamic>? ?? {};
      final current = account.cell.value ?? 0;
      final next = switch (op['op']) {
        'credit' => current + (op['amount'] as int? ?? 0),
        'debit' => current - (op['amount'] as int? ?? 0),
        _ => current,
      };
      print('   [Perform] $op → balance $current → $next');
      account.update(next);
      return Pulse(next, type: 'account.updated');
    },
  );

  commands.emit(Pulse({'op': 'credit', 'amount': 25}, type: 'account.cmd'));
  await Future.delayed(const Duration(milliseconds: 20));
  commands.emit(Pulse({'op': 'debit', 'amount': 10}, type: 'account.cmd'));
  await Future.delayed(const Duration(milliseconds: 20));
  print('   final balance: ${account.cell.value}');

  // -------------------------------------------------------------------------
  // 6. Testing – inject scripted pulses
  // -------------------------------------------------------------------------
  print('\n6. Scripted injection (test harness)');

  final underTest = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        final n = pulse.payload as int? ?? 0;
        return Pulse(n * n, type: 'squared');
      },
    ),
  );

  final results = <int>[];
  final probe = Cell.open(
    receptor: Receptor(
          (cell, pulse, {user}) {
        results.add(pulse.payload as int);
        return pulse;
      },
    ),
  );
  await underTest.link(probe);

  for (final n in [2, 3, 4]) {
    underTest.emit(Pulse(n));
  }
  await Future.delayed(const Duration(milliseconds: 30));
  print('   results: $results'); // [4, 9, 16]

  print('\n── finished ──────────────────────────────────────────────────');
}