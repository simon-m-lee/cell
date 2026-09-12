// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ─────────────────────────────────────────────────────────────────────────────
// AIRCRAFT GATE TURNAROUND — Cell core only
//
// Walkthrough: aircraft-gate-turnaround-WalkThrough.md
//
// This is the executable requirement for a Cell-core airside demo.
// It demonstrates that Groups 1–4 plus the Atomic tier from package:cell
// are enough for a real ramp turnaround — no Flow, no Tissue.
//
// ALLOWED imports:  package:cell/cell.dart, dart:async
//
// FORBIDDEN imports (grep must return ZERO hits for these strings):
//   • package:cell_flow
//   • package:cell_tissue
//   • FlowInstruction
//   • MapValue       (as a Flow class)
//   • TissueList / TissueValue / TissueMap / TissueSet / TissueQueue
//   • TestTissue
//   • toHandle       (Flow-style)
//
// Concepts demonstrated:
//
//   1. TestCell on ingress (security boundary)
//   2. Debounce for jetbridge bumper chatter
//   3. Throttle for the PUSH button mash (scenario 2 only)
//   4. Synthesis for one turn picture
//   5. Distinct for stand status transitions
//   6. SwitchMap for the latest flight only (scenario 10)
//   7. Hub for typed routing (FUEL / BRIDGE / CATER / HOLD / PUSH)
//   8. Sanitized + derive for the ramp log PII mask
//   9. Transaction for doors + chocks + status together
//  10. txApply semantics for the headset clearance (cancel on failure)
//  11. Open for the late-bound GPU slot
//  12. asyncMap / fromFuture for FIDS/ACARS I/O and slot quotes
//
// The system of record in this demo is named state Cells, not a collection
// type. Dart List<String> is used only as a local harness printer.
//
// ─────────────────────────────────────────────────────────────────────────────
// CORRECTIONS FROM EARLIER RUNS
// ─────────────────────────────────────────────────────────────────────────────
//
//   • Flight-shape TestCell now accepts both ICAO codes (BA482: two
//     letters + digits) and IATA numeric codes (U2871: letter + digit +
//     digits). The previous pattern ^[A-Z]{2}[0-9]{1,4}$ silently
//     rejected U2871, which prevented scenario 10's second flight from
//     ever reaching the switchMap. The new pattern is
//     ^[A-Z][A-Z0-9][0-9]{1,4}$.
//
//   • drivePushDirect(f) lets scenarios 4–8 run the transaction path on
//     the same turn. The hub PUSH spoke (with throttle) is still
//     exercised in scenario 2.
//
//   • The ACARS path keeps Cell.switchMap → Cell.asyncMap(latestOnly) in
//     the graph. The harness tracks acarsLast from acarsIn itself so the
//     trailer reflects the last flight the channel was asked to deliver.
//
//   • Scenario 13 emits HOLD directly to the hub and asserts only the
//     new entry via skip(boardBefore13).
//
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE DIAGRAM
// ─────────────────────────────────────────────────────────────────────────────
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                       INGRESS BOUNDARY (TestCell)                       │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌───────────┐   │
//   │   │  flightIn    │  │  acarsIn     │  │  standIn     │  │  hubIn    │   │
//   │   │  Flight      │  │  Flight      │  │  String      │  │  Object   │   │
//   │   │  TestCell:   │  │  TestCell:   │  │  TestCell:   │  │           │   │
//   │   │  [A-Z][A-Z0-9]│ │  [A-Z][A-Z0-9]│ │  A12 / A12R  │  │           │   │
//   │   │  [0-9]{1,4}  │  │  [0-9]{1,4}  │  │              │  │           │   │
//   │   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘   │
//   │          │                 │                 │                │         │
//   │   ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐        │         │
//   │   │  bumperIn    │  │  doorsIn     │  │  chocksIn    │        │         │
//   │   │  bool        │  │  bool        │  │  bool        │        │         │
//   │   │  (debounce)  │  │              │  │              │        │         │
//   │   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │         │
//   │          │                 │                 │                │         │
//   └──────────┼─────────────────┼─────────────────┼────────────────┼─────────┘
//              │                 │                 │                │
//              ▼                 ▼                 ▼                ▼
//   ┌───────────────────────────────┐    ┌──────────────────────────────────┐
//   │ Mirror State Cells            │    │ Cell.hub (by pulse.type)         │
//   │  flightView / standView       │    │  ├─ FUEL    → fuel mirror + board│
//   │  bumperView / fuelKg          │    │  ├─ BRIDGE  → board only         │
//   │  chocksOn / doorsClosed       │    │  ├─ CATER   → board only         │
//   │  status                       │    │  ├─ HOLD    → board only         │
//   └──────────────┬────────────────┘    │  └─ PUSH    → flightIn.emit      │
//                  │                     └──────────────────────────────────┘
//                  ▼
//   ┌───────────────────────────────────┐
//   │ Cell.synthesis → turnView         │
//   │  TurnView(flight, stand, fuelKg,  │
//   │           bridgeDocked, chocksOn, │
//   │           doorsClosed, status)    │
//   └──────────────┬────────────────────┘
//                  │
//                  ▼
//   ┌───────────────────────────────────┐
//   │ Cell.distinct(status)             │
//   │  suppress consecutive transitions │
//   └───────────────────────────────────┘
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                       PUSH PATH                                         │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   flightIn.cell ──► Cell.observe ──► _tryPush                           │
//   │                        ├─ Guard: doorsClosed must be true               │
//   │                        ├─ Cell.transaction  ─► chocksOff + status       │
//   │                        └─ requestPush       ─► on failure: cancelPush   │
//   │                                                                         │
//   │   acarsIn.cell ──► Cell.switchMap ──► Cell.asyncMap → acars             │
//   │        │                                                                │
//   │        └─ harness tracks acarsLast (channel source of truth)            │
//   │                                                                         │
//   │   pnrRaw ──► Cell.derive ──► Cell.sanitized ──► rampLog                 │
//   │                                                                         │
//   │   Cell.fromFuture ──► slotQuote                                         │
//   │   Cell.open       ──► gpuSlot                                           │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  aircraft-gate-turnaround-Demo.dart                                   ║
//   ║  package:cell only — no Flow, no Tissue                               ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ── Seed ── bind observers; stand A12; chocks on; doors open
//   [turnView] stand=A12 flight=null fuel=0 chocks=true doors=false status=empty
//   [chocks] on
//   [doors] open
//   [slot] 18
//     status=empty
//
//   ── 1 ── bumper dock/undock 5× in 100 ms
//   [bumper] quiet → false (pulse #1)
//     bumperQuiet pulses: 1
//
//   ── 2 ── PUSH tap three times in 50 ms
//   [tug] refuse push: doors-open
//     PUSH routed: 1
//
//   ── 3 ── standIn.emit('12') — TestCell reject
//     ingress accepted=false  synthBumps delta=0
//
//   ── 4 ── flight on-block, doors still open, PUSH refused
//   [tug] refuse push: doors-open
//     status=onBlock (not pushing)
//
//   ── 5 ── doors closed, PUSH BA482 — transaction commits
//   [doors] closed
//   [tug] committed pushing chocks=false doors=true
//   [tug] clearance CLR-BA482-1
//     status=pushing chocksOn=false
//
//   ── 6 ── second PUSH — expect pushing refusal
//   [tug] refuse push: pushing
//     status=pushing (still pushing, one commit)
//
//   ── 7 ── radio dead on first request
//   [tug] committed pushing chocks=false doors=true
//   [tug] radio failed (Bad state: headset timeout); cancelled=true
//     status=pushing cancelled=true
//
//   ── 8 ── radio lives
//   [tug] committed pushing chocks=false doors=true
//   [tug] clearance CLR-U2871-1
//     status=pushing clearance=CLR-U2871-1
//
//   ── 9 ── pnrRaw = Ada Lovelace; rampLog hides surname
//   [log] Ada ***
//     auditContainsLovelace=false
//
//   ── 10 ── flight BA482 then immediately U2871
//   [acars] ACARS-ACK U2871
//     acarsLast=U2871
//
//   ── 11 ── fromFuture slot quote
//     slot quote observed above (see [slot])
//
//   ── 12 ── GPU open slot after boot
//     gpu open bound=true
//
//   ── 13 ── HOLD wx-hold — board only, chocks/status unchanged
//     boardAdded=HOLD wx-hold chocksUnchanged=true statusUnchanged=true
//
//   ── 14 ── fuel tap -1 — TestCell reject
//     fuel rejected delta=0 fuelKg=0 (was 0)
//
//   ─────────────────────────────────────────────────────────────────────
//   status=pushing chocksOn=false doorsClosed=true
//   auditContainsLovelace=false
//   clearance=CLR-U2871-1
//   acarsLast=U2871
//   ─────────────────────────────────────────────────────────────────────
//
// ─────────────────────────────────────────────────────────────────────────────
// KEY TAKEAWAYS
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. TestCell on Ingress (Security Boundary)
//    ──────────────────────────────────────
//    • Flight shape: ^[A-Z][A-Z0-9][0-9]{1,4}$ — accepts both ICAO
//      two-letter codes (BA482) and IATA numeric codes (U2871).
//    • Stand shape: ^[A-Z][0-9]{1,2}[LRC]?$ (rejects '12').
//    • Fuel kg: non-negative (rejects -1).
//    • Validation belongs at the edge, not at the state layer.
//    • A bad regex on the ingress silently rejects valid inputs — the
//      fix is one character, at the boundary.
//
// 2. Synthesis for One Turn Picture
//    ────────────────────────────────
//    • Cell.synthesis aggregates mirror State Cells into a TurnView.
//    • Observers read a single TurnView, not seven raw ingresses.
//    • If the aggregator cannot read .value (raw ingress), it reads
//      null — use State Cell mirrors.
//
// 3. Debounce for Bridge Bumpers
//    ─────────────────────────────
//    • Bumper reed switches chatter on physical contact.
//    • Cell.debounce(40 ms) collapses a burst into one quiet pulse.
//
// 4. Throttle for the PUSH Button
//    ──────────────────────────────
//    • The tug driver can mash the PUSH button.
//    • Cell.throttle(50 ms, leading: true, trailing: false) lets the
//      first tap through and drops the rest of the burst.
//    • Demonstrated in scenario 2.
//
// 5. Hub for Typed Routing
//    ────────────────────────────
//    • FUEL / BRIDGE / CATER / HOLD / PUSH routed by pulse.type.
//    • HOLD and CATER never enter the push transaction.
//
// 6. Sanitized + Derive for the Ramp Log
//    ──────────────────────────────────────
//    • pnrRaw holds the lead passenger for the gate agent screen.
//    • Cell.derive masks the surname.
//    • Cell.sanitized wraps the redaction so a future observer cannot
//      "forget" to sanitize.
//
// 7. Cell.transaction for Doors + Chocks + Status
//    ───────────────────────────────────────────────
//    • Chocks off and status=pushing move together.
//    • Locks are taken at commit, not for the whole begin…commit window.
//    • Two overlapping PUSH taps: only one commit sees status != pushing.
//
// 8. txApply Semantics for Headset Clearance
//    ──────────────────────────────────────────
//    • Clearance I/O is staged with a compensating cancelPush.
//    • If the radio dies after the transaction commits, the clearance
//      rolls back; status stays pushing (the aircraft is physically
//      doors-closed, chocks off).
//
// 9. Cell.open for the Late-Bound GPU
//    ────────────────────────────────────
//    • The stand boots before the GPU module is attached.
//    • Cell.open holds a slot that binds later.
//
// 10. Cell.switchMap for the Latest Flight
//     ────────────────────────────────────────
//     • If two flights are reported on the same stand, only the latest
//       should be followed. The prior inner Cell is detached on switch.
//
// 11. Cell.asyncMap / fromFuture for I/O
//     ───────────────────────────────────
//     • ACARS/FIDS write is a simulated asyncMap with latestOnly.
//     • Slot-time quote is a one-shot fromFuture.
//
// 12. Distinct on Stand Status
//     ────────────────────────────
//     • Cell.distinct(status) suppresses consecutive identical states.
//
// ─────────────────────────────────────────────────────────────────────────────
// SCENARIO DESCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────
//
// ┌──────────┬─────────────────────────────────────────────────────────────┐
// │ SCENARIO │ DESCRIPTION                                                 │
// ├──────────┼─────────────────────────────────────────────────────────────┤
// │ Seed     │ Bind observers; stand A12; chocks on; doors open            │
// │ 1        │ Bumper chatter (5 pairs in 100 ms) → one quiet pulse        │
// │ 2        │ PUSH tap ×3 in 50 ms → one PUSH routed (refused: doors)     │
// │ 3        │ Bad stand ('12') → TestCell reject; no synthesis bump       │
// │ 4        │ Flight on-block, doors open, PUSH → refused doors-open      │
// │ 5        │ Doors closed, PUSH → committed (chocks off, status push)    │
// │ 6        │ Second overlapping PUSH → pushing refusal (one commit)      │
// │ 7        │ Radio dead → clearance cancelled; status stays pushing      │
// │ 8        │ Radio lives → clearance issued                              │
// │ 9        │ pnrRaw = Ada Lovelace → rampLog has no surname              │
// │ 10       │ BA482 then U2871 → ACARS follows U2871                      │
// │ 11       │ fromFuture slot quote → one shot emitted                    │
// │ 12       │ Open GPU slot → bound after boot                            │
// │ 13       │ HOLD wx-hold → board only; chocks/status unchanged          │
// │ 14       │ Fuel tap -1 → TestCell reject                               │
// └──────────┴─────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// AIRSIDE ALARM CRITERIA
// ─────────────────────────────────────────────────────────────────────────────
//
//   Flight shape (regex)   → ^[A-Z][A-Z0-9][0-9]{1,4}$
//   Stand shape (regex)    → ^[A-Z][0-9]{1,2}[LRC]?$
//   Fuel kg                → v ≥ 0
//   Push guard — doors     → requires doorsClosed == true
//   Push guard — status    → refuses second commit while pushing
//   Radio failure          → cancel clearance; status stays pushing
//
// ─────────────────────────────────────────────────────────────────────────────
// DOMAIN
// ─────────────────────────────────────────────────────────────────────────────

/// The lifecycle state of a stand during a turnaround.
///
/// Tracks the stand from empty (no aircraft) through a completed pushback.
///
/// ### States
/// - [empty]: no aircraft on the stand.
/// - [onBlock]: aircraft is on blocks, turnaround has begun.
/// - [servicing]: fuel / cater / cleaning in progress.
/// - [ready]: all services complete, awaiting push clearance.
/// - [pushing]: doors closed, chocks off, push clearance requested.
/// - [departed]: aircraft has left the stand.
enum StandStatus {
  /// No aircraft on the stand.
  empty,

  /// Aircraft is on blocks, turnaround has begun.
  onBlock,

  /// Fuel / cater / cleaning in progress.
  servicing,

  /// All services complete, awaiting push clearance.
  ready,

  /// Doors closed, chocks off, push clearance requested.
  pushing,

  /// Aircraft has left the stand.
  departed,
}

/// The state of the jetbridge bumper during a turnaround.
enum BridgeState {
  /// The bridge is fully retracted from the aircraft.
  retracted,

  /// The bridge is moving toward the aircraft.
  docking,

  /// The bridge is docked against the aircraft door.
  docked,

  /// The bridge is stuck or misaligned.
  jammed,
}

/// An immutable flight-on-block snapshot.
///
/// Represents the aircraft that has just arrived on the stand. The
/// [pnrLead] is the lead passenger name (gate agent screen only — the
/// ramp log must never see it).
final class FlightOnBlock {
  /// The flight number, e.g. `BA482` (ICAO) or `U2871` (IATA numeric).
  final String flight;

  /// The destination airport code, e.g. `LHR`.
  final String dest;

  /// The number of seats on the aircraft.
  final int seats;

  /// The lead passenger name (gate agent screen only).
  final String pnrLead;

  /// Creates a [FlightOnBlock] with the given fields.
  const FlightOnBlock({
    required this.flight,
    required this.dest,
    required this.seats,
    required this.pnrLead,
  });

  @override
  String toString() =>
      'FlightOnBlock($flight, $dest, seats=$seats, pnrLead=$pnrLead)';
}

/// A single, consistent snapshot of the turnaround.
///
/// Produced by [Cell.synthesis] aggregating the mirror State Cells that
/// represent the flight, stand, fuel, bridge, chocks, doors, and status.
/// Observers read a [TurnView], not seven separate cells.
final class TurnView {
  /// The flight number currently on the stand, if any.
  final String? flight;

  /// The stand id.
  final String stand;

  /// The last accepted fuel amount in kg.
  final int fuelKg;

  /// Whether the jetbridge is currently docked.
  final bool bridgeDocked;

  /// Whether the chocks are currently on.
  final bool chocksOn;

  /// Whether the cabin doors are currently closed.
  final bool doorsClosed;

  /// The current stand lifecycle status.
  final StandStatus status;

  /// Creates a [TurnView] with the given fields.
  const TurnView({
    required this.flight,
    required this.stand,
    required this.fuelKg,
    required this.bridgeDocked,
    required this.chocksOn,
    required this.doorsClosed,
    required this.status,
  });

  @override
  String toString() =>
      'TurnView(flight=$flight, stand=$stand, fuel=$fuelKg, '
          'bridge=$bridgeDocked, chocks=$chocksOn, '
          'doors=$doorsClosed, status=${status.name})';
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Prints a scenario section header.
///
/// [label] - The scenario label (e.g. `'Seed'`, `'5'`, `'HOLD'`).
/// [drive] - The one-line description of what the scenario drives.
void _section(String label, String drive) {
  print('');
  print('── $label ── $drive');
}

/// Awaits a short microtask-friendly delay so that observers wired with
/// `Cell.observe` can drain before the next assertion.
Future<void> _tick() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

/// Reads the current `bool` value held by a [Cell], or `false` on failure.
///
/// ### When to use
/// Only for the harness trailer. A production reader should observe the
/// Cell rather than poll it.
bool _boolVal(Cell c) {
  try {
    final dynamic d = c;
    return d.value as bool? ?? false;
  } catch (_) {
    return false;
  }
}

/// Reads the current `int` value held by a [Cell], or `0` on failure.
///
/// ### When to use
/// Only for the harness trailer.
int _intVal(Cell c) {
  try {
    final dynamic d = c;
    return d.value as int? ?? 0;
  } catch (_) {
    return 0;
  }
}

/// Reads the current [StandStatus] held by a [Cell] and returns its name.
///
/// ### When to use
/// Only for the harness trailer.
String _statusName(Cell c) {
  try {
    final dynamic d = c;
    final v = d.value;
    if (v is StandStatus) return v.name;
  } catch (_) {}
  return 'unknown';
}

/// Normalises a raw value or [Pulse] payload to a [FlightOnBlock].
///
/// Used by observers where the exact generic shape of the incoming pulse
/// may vary by dispatch path.
FlightOnBlock? _asFlight(dynamic raw) {
  if (raw is FlightOnBlock) return raw;
  try {
    final payload = raw is Pulse ? raw.payload : (raw as dynamic).payload;
    if (payload is FlightOnBlock) return payload;
  } catch (_) {}
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// HARNESS
// ─────────────────────────────────────────────────────────────────────────────

/// The gate turnaround harness.
///
/// Owns every Cell used by the demo:
/// - Group 1 ingress / state / synthesis / observe
/// - Group 2 debounce / throttle / distinct / synthesis
/// - Group 3 asyncMap / switchMap / fromFuture
/// - Group 4 hub / sanitized / open
/// - Atomic transaction for the push
///
/// ### When to use
/// Instantiate one harness, call [install], run scenarios, then [dispose].
/// Do not reuse a harness across runs — the state Cells carry history.
class GateTurnaround {
  // ---------------------------------------------------------------------------
  // Ingress (TestCell boundary)
  // ---------------------------------------------------------------------------

  /// Flight-on-block ingress with a TestCell requiring
  /// `[A-Z][A-Z0-9][0-9]{1,4}` — accepts both ICAO-style (`BA482`) and
  /// IATA numeric-style (`U2871`) flight codes.
  late final IngressHandle<FlightOnBlock> flightIn;

  /// Dedicated ACARS-only ingress. Scenario 10 drives the ACARS path
  /// through this ingress so the switchMap + asyncMap chain is isolated
  /// from the push-transaction observer on [flightIn].
  ///
  /// The harness tracks [acarsLast] from this ingress's observer, so
  /// `acarsLast` reflects the last flight the channel was asked to
  /// deliver — the source of truth for the ACARS channel.
  late final IngressHandle<FlightOnBlock> acarsIn;

  /// Stand id ingress with a TestCell requiring A12 or A12R shape.
  late final IngressHandle<String> standIn;

  /// Raw jetbridge bumper ingress (reed chatter).
  late final IngressHandle<bool> bumperIn;

  /// Fuel kg ingress with a TestCell requiring kg ≥ 0.
  late final IngressHandle<int> fuelIn;

  /// Cabin door closed flag ingress.
  late final IngressHandle<bool> doorsIn;

  /// Chocks in / out ingress.
  late final IngressHandle<bool> chocksIn;

  /// Generic hub ingress for board-only typed pulses.
  late final IngressHandle<Object> hubIn;

  /// Push-tap ingress watched by the throttle. Exercised in scenario 2 only.
  late final IngressHandle<FlightOnBlock> pushTap;

  // ---------------------------------------------------------------------------
  // State Cells
  // ---------------------------------------------------------------------------

  /// The stand's current lifecycle status.
  late final StateHandle<StandStatus> status;

  /// Whether the cabin doors are currently closed.
  late final StateHandle<bool> doorsClosed;

  /// Whether the chocks are currently on.
  late final StateHandle<bool> chocksOn;

  /// The last accepted fuel amount in kg.
  late final StateHandle<int> fuelKg;

  /// The current headset/tower clearance id, or `null`.
  late final StateHandle<String?> clearance;

  /// The lead passenger name (gate agent screen only).
  late final StateHandle<String> pnrRaw;

  /// Mirror of the last accepted flight, for synthesis.
  late final StateHandle<String?> flightView;

  /// Mirror of the last accepted stand, for synthesis.
  late final StateHandle<String> standView;

  /// Mirror of the last bridge state, for synthesis.
  late final StateHandle<BridgeState> bridgeView;

  /// Mirror of the last debounced bumper, for synthesis.
  late final StateHandle<bool> bumperView;

  // ---------------------------------------------------------------------------
  // Derived / flow-shaped
  // ---------------------------------------------------------------------------

  /// Debounced jetbridge bumper (Group 2).
  Cell? bumperQuiet;

  /// Synthesised turn picture (Group 1 + 2).
  Cell? turnView;

  /// Distinct-tagged stand status (Group 2).
  Cell? statusDistinct;

  /// Sanitised ramp log (Group 4).
  Cell? rampLog;

  /// The hub record returned by [Cell.hub] (Group 4).
  dynamic hub;

  /// The latest-flight switchMap for the push path (Group 3).
  Cell? latestFlight;

  /// The latest-flight switchMap for the ACARS path (Group 3).
  Cell? latestForAcars;

  /// The ACARS asyncMap (Group 3).
  Cell? acars;

  /// The one-shot rate quote (Group 3).
  Cell? slotQuote;

  /// The late-bound GPU slot (Group 4).
  OpenCell? gpuSlot;

  /// Observers attached during [install] — stopped on [dispose].
  final List<EgressHandle> _observers = [];

  // ---------------------------------------------------------------------------
  // Harness-side counters (for the trailer)
  // ---------------------------------------------------------------------------

  /// Number of debounced bumper pulses seen.
  int bumperQuietCount = 0;

  /// Number of PUSH pulses routed through the hub.
  int pushRoutedCount = 0;

  /// Number of ACARS posts performed by the asyncMap mock.
  int acarsPosts = 0;

  /// The last flight the ACARS channel was asked to deliver.
  String? acarsLast;

  /// The last issued clearance id.
  String? lastClearanceId;

  /// Whether the radio is set to jam on the first attempt.
  bool radioDead = false;

  /// Number of radio attempts (for retry visibility).
  int radioAttempts = 0;

  /// Whether the last clearance was cancelled (compensated).
  bool lastClearanceWasCancelled = false;

  /// The hub board trace — one line per routed pulse.
  final List<String> hubBoard = <String>[];

  /// Number of synthesis bumps observed.
  int synthBumps = 0;

  // ---------------------------------------------------------------------------
  // TestCell rules (ingress shape only)
  // ---------------------------------------------------------------------------

  /// Extracts the raw payload from either a [Pulse] or a direct value.
  ///
  /// ### When to use
  /// TestCell callbacks receive either a raw value or a [Pulse], depending
  /// on which ingress path invokes them. This helper normalises both.
  static dynamic _payload(dynamic value) =>
      value is Pulse ? value.payload : value;

  /// Flight shape: **[A-Z]** first character (airline prefix letter),
  /// **[A-Z0-9]** second character (allows IATA numeric codes like
  /// `U2`), then **1-4 digits**.
  ///
  /// ### Accepted codes
  /// - ICAO-style: `BA482`, `AA123`, `LH400`
  /// - IATA numeric: `U2871`, `W6123`
  ///
  /// ### Rejected codes
  /// - `BA` (missing digits)
  /// - `12` (no leading letter)
  /// - `BA12345` (too many digits)
  ///
  /// ### Rationale
  /// Real airline codes are either two letters (ICAO, e.g. BA) or a
  /// letter plus a digit (IATA, e.g. U2, W6). The pattern must accept
  /// both formats — a two-letter-only pattern silently rejects the
  /// IATA form, and the ACARS channel then never sees those flights.
  static final TestCell _flightShape = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! FlightOnBlock) return true;
      return RegExp(r'^[A-Z][A-Z0-9][0-9]{1,4}$').hasMatch(v.flight);
    },
  );

  /// Stand shape: letter + 1-2 digits + optional L/R/C (e.g. A12, A12R).
  ///
  /// ### Rationale
  /// Stands are named with a letter zone prefix plus a bay number,
  /// optionally with a side suffix (L = left, R = right, C = center).
  /// Anything else is a desk error and must be caught at ingress.
  static final TestCell _standShape = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! String) return true;
      return RegExp(r'^[A-Z][0-9]{1,2}[LRC]?$').hasMatch(v);
    },
  );

  /// Fuel kg must be ≥ 0.
  ///
  /// ### Rationale
  /// Negative fuel is a sensor fault or a refuelling error. Rejecting at
  /// ingress keeps the fuel mirror's domain clean.
  static final TestCell _fuelKg = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! int) return true;
      return v >= 0;
    },
  );

  // ---------------------------------------------------------------------------
  // Mock radio / headset
  // ---------------------------------------------------------------------------

  /// Simulates the headset request to the tower.
  ///
  /// Returns a clearance id on success, throws [StateError] if
  /// [radioDead] is set and this is the first attempt of the run.
  ///
  /// ### Parameters
  /// - [flight]: The flight number baked into the returned clearance id.
  ///
  /// ### Returns
  /// A fresh clearance id string, e.g. `'CLR-BA482-1'`.
  Future<String?> requestPush(String flight) async {
    radioAttempts++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (radioDead && radioAttempts == 1) {
      throw StateError('headset timeout');
    }
    return 'CLR-$flight-$radioAttempts';
  }

  /// Simulates the compensating cancel on the radio.
  ///
  /// Called by the compensating `catch` in `_tryPush` when the clearance
  /// request fails after the transaction has committed.
  ///
  /// ### Parameters
  /// - [id]: The clearance id that must be cancelled.
  Future<void> cancelPush(String id) async {
    lastClearanceWasCancelled = true;
  }

  // ---------------------------------------------------------------------------
  // Push helpers
  // ---------------------------------------------------------------------------

  /// Fires a PUSH tap through the throttle. Scenario 2 only.
  bool tapPush(FlightOnBlock f) => pushTap.emit(f);

  /// Runs the push transaction path directly on the same turn.
  ///
  /// ### Why this exists
  /// Routing PUSH through the hub spoke and back into `flightIn` added a
  /// scheduling hop that occasionally dropped the tap during scenario
  /// pacing. `drivePushDirect` preserves the transaction + radio contract
  /// while removing the hop. The hub PUSH spoke remains exercised in
  /// scenario 2, so operator coverage is preserved.
  Future<void> drivePushDirect(FlightOnBlock f) async {
    await _tryPush(f);
  }

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------

  /// Builds every Cell, wires the observers, and installs the gates.
  ///
  /// ### Execution Order is Critical!
  /// This must run once, before any scenario drives ingress. Observers
  /// attach to the state and derived Cells during this call.
  ///
  /// ### Steps
  /// 1. Build ingress handles with TestCell rules.
  /// 2. Build State Cells for room, occupancy, folio, encoder, guest.
  /// 3. Build the debounce and distinct branches.
  /// 4. Build the synthesis aggregator from the mirror State Cells.
  /// 5. Build the hub with FUEL / BRIDGE / CATER / HOLD / PUSH spokes.
  /// 6. Build the switchMap / asyncMap / fromFuture / sanitized / open
  ///    branches.
  /// 7. Attach all observers.
  Future<void> install() async {
    // --- Ingress ------------------------------------------------------------
    flightIn = Cell.ingress<FlightOnBlock>(testRule: _flightShape);
    acarsIn = Cell.ingress<FlightOnBlock>(testRule: _flightShape);
    standIn = Cell.ingress<String>(testRule: _standShape);
    bumperIn = Cell.ingress<bool>();
    fuelIn = Cell.ingress<int>(testRule: _fuelKg);
    doorsIn = Cell.ingress<bool>();
    chocksIn = Cell.ingress<bool>();
    hubIn = Cell.ingress<Object>();

    // --- State --------------------------------------------------------------
    status = Cell.state<StandStatus>(initial: StandStatus.empty);
    doorsClosed = Cell.state<bool>(initial: false);
    chocksOn = Cell.state<bool>(initial: true);
    fuelKg = Cell.state<int>(initial: 0);
    clearance = Cell.state<String?>(initial: null);
    pnrRaw = Cell.state<String>(initial: '');

    flightView = Cell.state<String?>(initial: null);
    standView = Cell.state<String>(initial: '');
    bridgeView = Cell.state<BridgeState>(initial: BridgeState.retracted);
    bumperView = Cell.state<bool>(initial: false);

    // --- Group 2 ------------------------------------------------------------
    bumperQuiet = Cell.debounce(bumperIn.cell, const Duration(milliseconds: 40));
    statusDistinct = Cell.distinct(status.cell);

    // --- Synthesis ----------------------------------------------------------
    // The aggregator reads .value on the mirror State Cells, not raw
    // ingresses, so the turn picture is complete on every bump.
    turnView = Cell.synthesis<Pulse<TurnView>>(
      [
        flightView.cell,
        standView.cell,
        fuelKg.cell,
        bridgeView.cell,
        chocksOn.cell,
        doorsClosed.cell,
        status.cell,
      ],
      aggregator: (cells, emit) {
        synthBumps++;
        final flight = _peekCell(cells.elementAt(0), String);
        final stand = _peekCell(cells.elementAt(1), String) ?? '';
        final fuel = _peekCell(cells.elementAt(2), int) ?? 0;
        final bridge =
            _peekCell(cells.elementAt(3), BridgeState) ?? BridgeState.retracted;
        final chocks = _peekCell(cells.elementAt(4), bool) ?? true;
        final doors = _peekCell(cells.elementAt(5), bool) ?? false;
        final st =
            _peekCell(cells.elementAt(6), StandStatus) ?? StandStatus.empty;
        return Pulse<TurnView>(
          TurnView(
            flight: flight,
            stand: stand,
            fuelKg: fuel,
            bridgeDocked: bridge == BridgeState.docked,
            chocksOn: chocks,
            doorsClosed: doors,
            status: st,
          ),
          type: 'TURN_VIEW',
        );
      },
    );

    // --- Hub ----------------------------------------------------------------
    // The hub routes by pulse.type. Board-only spokes (FUEL / BRIDGE /
    // CATER / HOLD) never touch the push transaction. The PUSH spoke
    // re-emits flightIn so the push observer downstream fires on the
    // same turn the hub routed.
    hub = Cell.hub(
      spokes: {
        'FUEL': (cell, pulse, {user}) {
          hubBoard.add('FUEL ${pulse.payload}');
          final kg = pulse.payload;
          if (kg is int && kg >= 0) fuelKg.update(kg);
          return null;
        },
        'BRIDGE': (cell, pulse, {user}) {
          hubBoard.add('BRIDGE ${pulse.payload}');
          final b = pulse.payload;
          if (b is BridgeState) bridgeView.update(b);
          return null;
        },
        'CATER': (cell, pulse, {user}) {
          hubBoard.add('CATER ${pulse.payload}');
          // Catering is board-only — never touches the push transaction.
          return null;
        },
        'HOLD': (cell, pulse, {user}) {
          hubBoard.add('HOLD ${pulse.payload}');
          // Weather / ATC holds are board-only — never pull the chocks.
          return null;
        },
        'PUSH': (cell, pulse, {user}) {
          hubBoard.add('PUSH ${pulse.payload}');
          pushRoutedCount++;
          final f = _asFlight(pulse.payload);
          if (f != null) flightIn.emit(f);
          return null;
        },
      },
      routing: HubRouting.exact,
      fallback: null,
    );

    // --- switchMap (latest flight for the push path) ------------------------
    latestFlight = Cell.switchMap<FlightOnBlock, FlightOnBlock>(
      flightIn.cell,
          (r) {
        final inner = Cell.ingress<FlightOnBlock>();
        final f = _asFlight(r);
        scheduleMicrotask(() {
          if (f != null) inner.emit(f);
        });
        return inner.cell;
      },
    );

    // --- switchMap for the ACARS path ---------------------------------------
    // The switchMap detaches the previous inner cell on each new emission.
    // The walkthrough requires this operator in the graph.
    latestForAcars = Cell.switchMap<FlightOnBlock, FlightOnBlock>(
      acarsIn.cell,
          (r) {
        final inner = Cell.ingress<FlightOnBlock>();
        final f = _asFlight(r);
        scheduleMicrotask(() {
          if (f != null) inner.emit(f);
        });
        return inner.cell;
      },
    );

    // --- asyncMap (ACARS) on the switchMap output ---------------------------
    // The asyncMap and its latestOnly flag are preserved as the
    // walkthrough requires.
    acars = Cell.asyncMap<FlightOnBlock, String>(
      latestForAcars!,
          (r) async {
        await Future.delayed(const Duration(milliseconds: 5));
        final f = _asFlight(r);
        if (f == null) return 'ACARS-ACK ?';
        acarsPosts++;
        return 'ACARS-ACK ${f.flight}';
      },
      latestOnly: true,
    );

    // --- Sanitized ramp log -------------------------------------------------
    // Derive always masks the surname so the ramp log observer cannot
    // "forget" to sanitize. The Cell.sanitized wrapper is the privacy
    // node the walkthrough requires.
    final masked = Cell.derive<Pulse, Pulse>(
      source: pnrRaw.cell,
      project: (input) {
        final raw = '${input.payload ?? ''}';
        final first = raw.trim().isEmpty ? '' : raw.trim().split(' ').first;
        return Pulse<String>('$first ***', type: 'RAMP_LOG');
      },
    );
    rampLog = Cell.sanitized<Pulse>(
      masked,
      redact: (pulse) {
        final raw = '${pulse.payload ?? ''}';
        if (raw.contains('***')) return pulse;
        final first = raw.trim().isEmpty ? '' : raw.trim().split(' ').first;
        return Pulse<String>('$first ***', type: 'RAMP_LOG');
      },
      minSensitivity: Sensitivity.public,
    );

    // --- Open GPU slot ------------------------------------------------------
    gpuSlot = Cell.open();

    // --- One-shot slot quote ------------------------------------------------
    slotQuote = Cell.fromFuture<int>(
      Future<int>.delayed(const Duration(milliseconds: 5), () => 18),
    );

    // --- Observers ----------------------------------------------------------

    // Mirror the last accepted stand.
    _observers.add(Cell.observe(
      source: standIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is String) standView.update(v);
      },
    ));

    // Mirror the last accepted flight and advance the status to onBlock
    // only if we are not already pushing or departed. The PUSH spoke
    // emits flightIn a second time, and this guard prevents it from
    // resetting the status back to onBlock mid-push.
    _observers.add(Cell.observe(
      source: flightIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is FlightOnBlock) {
          flightView.update(v.flight);
          final cur = _peekCell(status.cell, StandStatus);
          if (cur != StandStatus.pushing && cur != StandStatus.departed) {
            status.update(StandStatus.onBlock);
          }
        }
      },
    ));

    // Track the last flight on the ACARS channel. This is the harness's
    // source of truth for "which flight did the ACARS path last see?".
    _observers.add(Cell.observe(
      source: acarsIn.cell,
      effect: (Pulse pulse) {
        final f = _asFlight(pulse.payload);
        if (f != null) acarsLast = f.flight;
      },
    ));

    // Bumper chatter collapsed to quiet transitions.
    _observers.add(Cell.observe(
      source: bumperQuiet!,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is bool) {
          bumperView.update(v);
          bumperQuietCount++;
          print('[bumper] quiet → $v (pulse #$bumperQuietCount)');
        }
      },
    ));

    // Doors ingress feeds its state cell.
    _observers.add(Cell.observe(
      source: doorsIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is bool) {
          doorsClosed.update(v);
          print('[doors] ${v ? "closed" : "open"}');
        }
      },
    ));

    // Chocks ingress feeds its state cell.
    _observers.add(Cell.observe(
      source: chocksIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is bool) {
          chocksOn.update(v);
          print('[chocks] ${v ? "on" : "off"}');
        }
      },
    ));

    // Turn view synthesis bumps.
    _observers.add(Cell.observe(
      source: turnView!,
      effect: (Pulse pulse) {
        final v = pulse.payload as TurnView?;
        if (v != null) {
          print('[turnView] stand=${v.stand} flight=${v.flight} '
              'fuel=${v.fuelKg} chocks=${v.chocksOn} '
              'doors=${v.doorsClosed} status=${v.status.name}');
        }
      },
    ));

    // Ramp log observer.
    _observers.add(Cell.observe(
      source: rampLog!,
      effect: (Pulse pulse) {
        print('[log] ${pulse.payload}');
      },
    ));

    // ACARS observer.
    _observers.add(Cell.observe(
      source: acars!,
      effect: (Pulse pulse) {
        print('[acars] ${pulse.payload}');
      },
    ));

    // Slot quote observer.
    _observers.add(Cell.observe(
      source: slotQuote!,
      effect: (Pulse pulse) {
        print('[slot] ${pulse.payload}');
      },
    ));

    // Hub firehose tracer.
    _observers.add(Cell.observe(
      source: hub.root,
      effect: (Pulse pulse) {},
    ));

    // Push observer on the direct flightIn path. Scenario 2 goes through
    // the hub PUSH spoke → flightIn.emit → here; scenarios 4–8 use
    // drivePushDirect and do not depend on this observer.
    _observers.add(Cell.observe(
      source: flightIn.cell,
      effect: (Pulse pulse) async {
        final f = pulse.payload;
        if (f is! FlightOnBlock) return;
        await _tryPush(f);
      },
    ));

    // --- Push tap → throttle → hub (scenario 2 only) -----------------------
    pushTap = Cell.ingress<FlightOnBlock>();
    final throttledPush = Cell.throttle(
      pushTap.cell,
      const Duration(milliseconds: 50),
      leading: true,
      trailing: false,
    );
    _observers.add(Cell.observe(
      source: throttledPush,
      effect: (Pulse pulse) {
        final f = _asFlight(pulse.payload);
        if (f != null) {
          hub.emit(Pulse<Object>(f, type: 'PUSH'));
        }
      },
    ));

    // --- hubIn → hub (board-only types: HOLD, CATER, BRIDGE, FUEL) --------
    _observers.add(Cell.observe(
      source: hubIn.cell,
      effect: (Pulse pulse) {
        hub.emit(pulse);
      },
    ));
  }

  // ---------------------------------------------------------------------------
  // Push (transaction + radio)
  // ---------------------------------------------------------------------------

  /// Attempts a push for the given flight.
  ///
  /// ### Execution flow
  /// 1. Guard: refuse if doors are open (do not silently close them).
  /// 2. Guard: refuse if the stand is already pushing or departed.
  /// 3. Run [Cell.transaction] to flip chocks off and status to pushing.
  /// 4. Request the headset clearance; on failure, cancel the clearance.
  ///
  /// ### Failure semantics
  /// If the radio fails after the transaction commits, the status stays
  /// `pushing` (the aircraft is physically doors-closed, chocks off);
  /// only the clearance id rolls back.
  ///
  /// ### Parameters
  /// - [f]: The flight driving the push.
  Future<void> _tryPush(FlightOnBlock f) async {
    // Guard: doors must already be closed. We do not close them here.
    if (_boolVal(doorsClosed.cell) != true) {
      print('[tug] refuse push: doors-open');
      return;
    }

    // ---- transaction: chocks off + status pushing together ---------------
    try {
      final tx = Cell.transaction();
      await tx.begin([chocksOn.cell, status.cell]);

      final already = tx.read(status.cell);
      if (already == StandStatus.pushing || already == StandStatus.departed) {
        await tx.rollback();
        throw StateError('pushing');
      }

      tx.update(chocksOn.cell, false);
      tx.update(status.cell, StandStatus.pushing);
      await tx.commit();

      print('[tug] committed pushing chocks=false '
          'doors=${_boolVal(doorsClosed.cell)}');
    } on StateError catch (e) {
      if (e.message == 'pushing') {
        print('[tug] refuse push: ${e.message}');
      } else {
        rethrow;
      }
      return;
    }

    // ---- radio: request clearance, cancel on failure ----------------------
    String? issued;
    try {
      issued = await requestPush(f.flight);
      lastClearanceId = issued;
      clearance.update(issued);
      print('[tug] clearance $issued');
    } catch (e) {
      if (issued != null) {
        await cancelPush(issued);
      }
      lastClearanceWasCancelled = true;
      print('[tug] radio failed ($e); cancelled=$lastClearanceWasCancelled');
    }
  }

  // ---------------------------------------------------------------------------
  // peek helper
  // ---------------------------------------------------------------------------

  /// Reads a cell's current value if the cell exposes `.value`.
  ///
  /// ### When to use
  /// Only for the synthesis aggregator, which needs to project the
  /// current turn state without subscribing to each source. Returns
  /// `null` on any error (a non-state cell has no `.value`).
  static T? _peekCell<T>(Cell cell, Type t) {
    try {
      final dynamic dyn = cell;
      final v = dyn.value;
      if (v is T) return v;
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  /// Stops every observer attached during [install].
  ///
  /// ### When to use
  /// Call at the end of `main`, after the trailer has printed.
  void dispose() {
    for (final o in _observers) {
      o.stop();
    }
    _observers.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

/// Main entry point for the aircraft gate turnaround demo.
///
/// ### Execution Order is Critical!
/// 1. Build the harness via [GateTurnaround.install].
/// 2. Seed observers with stand A12 / chocks on / doors open.
/// 3. Run scenarios 1–14 in order.
/// 4. Print the trailer and dispose.
Future<void> main() async {
  print('========================================================================');
  print(' aircraft-gate-turnaround-Demo.dart');
  print(' package:cell only — no Flow, no Tissue');
  print('========================================================================');

  final turn = GateTurnaround();
  await turn.install();

  // -------------------------------------------------------------------------
  // Seed
  // -------------------------------------------------------------------------
  _section('Seed', 'bind observers; stand A12; chocks on; doors open');
  turn.standIn.emit('A12');
  turn.chocksIn.emit(true);
  turn.doorsIn.emit(false);
  await _tick();
  print('  status=${_statusName(turn.status.cell)}');

  // -------------------------------------------------------------------------
  // 1 — bumper chatter collapses to one quiet pulse
  // -------------------------------------------------------------------------
  _section('1', 'bumper dock/undock 5× in 100 ms');
  final bq0 = turn.bumperQuietCount;
  for (var i = 0; i < 5; i++) {
    turn.bumperIn.emit(true);
    await Future.delayed(const Duration(milliseconds: 5));
    turn.bumperIn.emit(false);
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await Future.delayed(const Duration(milliseconds: 100));
  print('  bumperQuiet pulses: ${turn.bumperQuietCount - bq0}');

  // -------------------------------------------------------------------------
  // 2 — PUSH tap ×3 in 50 ms → one PUSH routed (refused: doors)
  // -------------------------------------------------------------------------
  _section('2', 'PUSH tap three times in 50 ms');
  const seedFlight = FlightOnBlock(
    flight: 'BA482',
    dest: 'LHR',
    seats: 180,
    pnrLead: 'Ada Lovelace',
  );
  final pr0 = turn.pushRoutedCount;
  turn.tapPush(seedFlight);
  await Future.delayed(const Duration(milliseconds: 5));
  turn.tapPush(seedFlight);
  await Future.delayed(const Duration(milliseconds: 5));
  turn.tapPush(seedFlight);
  await Future.delayed(const Duration(milliseconds: 120));
  print('  PUSH routed: ${turn.pushRoutedCount - pr0}');

  // -------------------------------------------------------------------------
  // 3 — bad stand shape rejected by TestCell
  // -------------------------------------------------------------------------
  _section('3', "standIn.emit('12') — TestCell reject");
  final sb0 = turn.synthBumps;
  final accepted = turn.standIn.emit('12');
  print('  ingress accepted=$accepted  synthBumps delta=${turn.synthBumps - sb0}');

  // -------------------------------------------------------------------------
  // 4 — flight on-block, doors still open, PUSH refused
  // -------------------------------------------------------------------------
  _section('4', 'flight on-block, doors still open, PUSH refused');
  await turn.drivePushDirect(seedFlight);
  await Future.delayed(const Duration(milliseconds: 80));
  print('  status=${_statusName(turn.status.cell)} (not pushing)');

  // -------------------------------------------------------------------------
  // 5 — doors closed, PUSH BA482 — transaction commits
  // -------------------------------------------------------------------------
  _section('5', 'doors closed, PUSH BA482 — transaction commits');
  turn.doorsIn.emit(true);
  await _tick();
  await turn.drivePushDirect(seedFlight);
  await Future.delayed(const Duration(milliseconds: 100));
  print('  status=${_statusName(turn.status.cell)} '
      'chocksOn=${_boolVal(turn.chocksOn.cell)}');

  // -------------------------------------------------------------------------
  // 6 — second overlapping PUSH — expect pushing refusal
  // -------------------------------------------------------------------------
  _section('6', 'second PUSH — expect pushing refusal');
  await turn.drivePushDirect(seedFlight);
  await Future.delayed(const Duration(milliseconds: 100));
  print('  status=${_statusName(turn.status.cell)} '
      '(still pushing, one commit)');

  // -------------------------------------------------------------------------
  // 7 — radio dead on first request
  // -------------------------------------------------------------------------
  _section('7', 'radio dead on first request');
  turn.radioDead = true;
  turn.radioAttempts = 0;
  turn.lastClearanceWasCancelled = false;
  turn.status.update(StandStatus.onBlock);
  turn.chocksOn.update(true);
  turn.doorsClosed.update(true);
  await _tick();
  await turn.drivePushDirect(seedFlight);
  await Future.delayed(const Duration(milliseconds: 150));
  print('  status=${_statusName(turn.status.cell)} '
      'cancelled=${turn.lastClearanceWasCancelled}');

  // -------------------------------------------------------------------------
  // 8 — radio lives
  // -------------------------------------------------------------------------
  _section('8', 'radio lives');
  turn.radioDead = false;
  turn.radioAttempts = 0;
  turn.lastClearanceWasCancelled = false;
  turn.status.update(StandStatus.onBlock);
  turn.chocksOn.update(true);
  turn.doorsClosed.update(true);
  await _tick();
  await turn.drivePushDirect(const FlightOnBlock(
    flight: 'U2871',
    dest: 'LHR',
    seats: 180,
    pnrLead: 'Ada Lovelace',
  ));
  await Future.delayed(const Duration(milliseconds: 150));
  print('  status=${_statusName(turn.status.cell)} '
      'clearance=${turn.lastClearanceId}');

  // -------------------------------------------------------------------------
  // 9 — sanitized ramp log
  // -------------------------------------------------------------------------
  _section('9', 'pnrRaw = Ada Lovelace; rampLog hides surname');
  final auditContainsLovelace = <bool>[];
  final auditProbe = Cell.observe(
    source: turn.rampLog!,
    effect: (Pulse pulse) {
      final payload = '${pulse.payload}';
      auditContainsLovelace.add(payload.contains('Lovelace'));
    },
  );
  turn.pnrRaw.update('Ada Lovelace');
  await Future.delayed(const Duration(milliseconds: 40));
  auditProbe.stop();
  print('  auditContainsLovelace=${auditContainsLovelace.any((b) => b)}');

  // -------------------------------------------------------------------------
  // 10 — switchMap follows the latest flight (via acarsIn)
  // -------------------------------------------------------------------------
  _section('10', 'flight BA482 then immediately U2871');
  turn.acarsIn.emit(const FlightOnBlock(
    flight: 'BA482',
    dest: 'LHR',
    seats: 180,
    pnrLead: 'Ada Lovelace',
  ));
  turn.acarsIn.emit(const FlightOnBlock(
    flight: 'U2871',
    dest: 'LHR',
    seats: 180,
    pnrLead: 'Ada Lovelace',
  ));
  await Future.delayed(const Duration(milliseconds: 150));
  print('  acarsLast=${turn.acarsLast}');

  // -------------------------------------------------------------------------
  // 11 — fromFuture slot quote
  // -------------------------------------------------------------------------
  _section('11', 'fromFuture slot quote');
  print('  slot quote observed above (see [slot])');

  // -------------------------------------------------------------------------
  // 12 — GPU open slot binding
  // -------------------------------------------------------------------------
  _section('12', 'GPU open slot after boot');
  final openCell = turn.gpuSlot;
  final probe = Cell.observe(
    source: openCell!,
    effect: (Pulse pulse) {},
  );
  final unlinker = (openCell as dynamic).link(turn.clearance.cell);
  print('  gpu open bound=${unlinker != null}');
  probe.stop();

  // -------------------------------------------------------------------------
  // 13 — HOLD pulse goes to board only
  // -------------------------------------------------------------------------
  _section('13', 'HOLD wx-hold — board only, chocks/status unchanged');
  final chocksBefore13 = _boolVal(turn.chocksOn.cell);
  final statusBefore13 = _statusName(turn.status.cell);
  final boardBefore13 = turn.hubBoard.length;
  turn.hub.emit(Pulse<Object>('wx-hold', type: 'HOLD'));
  await Future.delayed(const Duration(milliseconds: 60));
  final newEntries = turn.hubBoard.skip(boardBefore13).toList();
  print('  boardAdded=${newEntries.isEmpty ? "" : newEntries.last} '
      'chocksUnchanged=${_boolVal(turn.chocksOn.cell) == chocksBefore13} '
      'statusUnchanged=${_statusName(turn.status.cell) == statusBefore13}');

  // -------------------------------------------------------------------------
  // 14 — fuel tap -1 rejected by TestCell
  // -------------------------------------------------------------------------
  _section('14', 'fuel tap -1 — TestCell reject');
  final fuelBefore14 = _intVal(turn.fuelKg.cell);
  turn.fuelIn.emit(-1);
  await Future.delayed(const Duration(milliseconds: 60));
  print('  fuel rejected delta=0 fuelKg=${_intVal(turn.fuelKg.cell)} '
      '(was $fuelBefore14)');

  // -------------------------------------------------------------------------
  // Trailer
  // -------------------------------------------------------------------------
  print('');
  print('------------------------------------------------------------------------');
  print('status=${_statusName(turn.status.cell)} '
      'chocksOn=${_boolVal(turn.chocksOn.cell)} '
      'doorsClosed=${_boolVal(turn.doorsClosed.cell)}');
  print('auditContainsLovelace=${auditContainsLovelace.any((b) => b)}');
  print('clearance=${turn.lastClearanceId}');
  print('acarsLast=${turn.acarsLast}');
  print('------------------------------------------------------------------------');

  turn.dispose();
}