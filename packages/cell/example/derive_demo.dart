// =============================================================================
// Practical executable walkthrough – Cell.derive
// Functional projections · Causal tracing  (type-safe)
// =============================================================================

import 'dart:async';
import 'package:cell/cell.dart';

/// ### Expected console output:
/// ```text
/// ── Cell.derive – Projections & Causal Tracing ────────────────
///
/// 1. Functional projection (extract display name)
///    [Name]   "ADA LOVELACE"  (type=user.displayName)
///
/// 2. Chained projections (email → domain → label)
///    [Name]   "GRACE HOPPER"  (type=user.displayName)
///    [Label]  "mail@navy.mil"  (type=user.label)
///
/// 3. Causal tracing (lineage of a derived pulse)
///    [Name]   "ALAN"  (type=user.displayName)
///    [Label]  "mail@lab.org"  (type=user.label)
///    [Age]    payload=adult  type=user.ageGroup
///            parent.payload={name: Alan, email: alan@lab.org, age: 42}
///            root.payload={name: Alan, email: alan@lab.org, age: 42}
///            trace=[]
///    [Name]   "KID"  (type=user.displayName)
///    [Label]  "mail@school.edu"  (type=user.label)
///    [Age]    payload=minor  type=user.ageGroup
///            parent.payload={name: Kid, email: kid@school.edu, age: 12}
///            root.payload={name: Kid, email: kid@school.edu, age: 12}
///            trace=[]
///
/// 4. Empty name projects to placeholder
///    [Name]   "(anonymous)"  (type=user.displayName)
///    [Label]  "mail@y.z"  (type=user.label)
///    [Age]    payload=adult  type=user.ageGroup
///            parent.payload={name:    , email: x@y.z, age: 20}
///            root.payload={name:    , email: x@y.z, age: 20}
///            trace=[]
///
/// ── finished ──────────────────────────────────────────────────
/// ```
Future<void> main() async {
  print('── Cell.derive – Projections & Causal Tracing ────────────────\n');

  // -------------------------------------------------------------------------
  // Source: user profile
  // -------------------------------------------------------------------------
  final profile = Cell.state<Map<String, dynamic>>(
    initial: {'name': '', 'email': '', 'age': 0},
    evolve: (host, pulse) {
      final v = pulse.payload;
      return v is Map<String, dynamic> ? Pulse(v) : null;
    },
  );

  // -------------------------------------------------------------------------
  // 1. Functional projection – extract display name
  // -------------------------------------------------------------------------
  print('1. Functional projection (extract display name)');

  final displayName = Cell.derive<Pulse, Pulse>(
    source: profile.cell,
    project: (Pulse input) {
      final map = input.payload as Map<String, dynamic>? ?? {};
      final name = (map['name'] as String? ?? '').trim();
      // Always return a Pulse (non-null) to satisfy O extends Pulse
      final label = name.isEmpty ? '(anonymous)' : name.toUpperCase();
      return Pulse(label, type: 'user.displayName');
    },
  );

  final nameObserver = Cell.observe(
    source: displayName,
    effect: (Pulse pulse) {
      print('   [Name]   "${pulse.payload}"  (type=${pulse.type})');
    },
  );

  profile.update({'name': 'ada lovelace', 'email': 'ada@example.com', 'age': 36});
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // 2. Chained projections – email → domain → label
  // -------------------------------------------------------------------------
  print('\n2. Chained projections (email → domain → label)');

  final emailCell = Cell.derive<Pulse, Pulse>(
    source: profile.cell,
    project: (Pulse input) {
      final map = input.payload as Map<String, dynamic>? ?? {};
      final email = map['email'] as String? ?? '';
      return Pulse(email, type: 'user.email');
    },
  );

  final domainCell = Cell.derive<Pulse, Pulse>(
    source: emailCell,
    project: (Pulse input) {
      final email = '${input.payload}';
      final domain = email.contains('@') ? email.split('@').last : '';
      return Pulse(domain, type: 'user.domain');
    },
  );

  final labelCell = Cell.derive<Pulse, Pulse>(
    source: domainCell,
    project: (Pulse input) {
      final domain = '${input.payload}';
      final label = domain.isEmpty ? '(no-domain)' : 'mail@$domain';
      return Pulse(label, type: 'user.label');
    },
  );

  final labelObserver = Cell.observe(
    source: labelCell,
    effect: (Pulse pulse) {
      print('   [Label]  "${pulse.payload}"  (type=${pulse.type})');
    },
  );

  profile.update({'name': 'Grace Hopper', 'email': 'grace@navy.mil', 'age': 85});
  await Future.delayed(const Duration(milliseconds: 40));

  // -------------------------------------------------------------------------
  // 3. Causal tracing – parent / root / trace
  // -------------------------------------------------------------------------
  print('\n3. Causal tracing (lineage of a derived pulse)');

  final traced = Cell.derive<Pulse, Pulse>(
    source: profile.cell,
    project: (Pulse input) {
      final map = input.payload as Map<String, dynamic>? ?? {};
      final age = map['age'] as int? ?? 0;
      return Pulse(age >= 18 ? 'adult' : 'minor', type: 'user.ageGroup');
    },
  );

  final traceObserver = Cell.observe(
    source: traced,
    effect: (Pulse pulse) {
      print('   [Age]    payload=${pulse.payload}  type=${pulse.type}');

      try {
        final parent = (pulse as dynamic).parent;
        print('           parent.payload=${parent?.payload}');
      } catch (_) {
        print('           parent: (unavailable)');
      }

      try {
        final root = (pulse as dynamic).root;
        print('           root.payload=${root?.payload}');
      } catch (_) {
        print('           root: (unavailable)');
      }

      try {
        final trace = (pulse as dynamic).trace;
        print('           trace=$trace');
      } catch (_) {
        print('           trace: (unavailable)');
      }
    },
  );

  profile.update({'name': 'Alan', 'email': 'alan@lab.org', 'age': 42});
  await Future.delayed(const Duration(milliseconds: 40));

  profile.update({'name': 'Kid', 'email': 'kid@school.edu', 'age': 12});
  await Future.delayed(const Duration(milliseconds: 40));

  // -------------------------------------------------------------------------
  // 4. Empty name still projects (no null return)
  // -------------------------------------------------------------------------
  print('\n4. Empty name projects to placeholder');

  profile.update({'name': '   ', 'email': 'x@y.z', 'age': 20});
  await Future.delayed(const Duration(milliseconds: 30));

  // -------------------------------------------------------------------------
  // Clean-up
  // -------------------------------------------------------------------------
  nameObserver.stop();
  labelObserver.stop();
  traceObserver.stop();

  print('\n── finished ──────────────────────────────────────────────────');
}