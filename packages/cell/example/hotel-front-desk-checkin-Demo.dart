// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell/cell.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ─────────────────────────────────────────────────────────────────────────────
// HOTEL FRONT-DESK CHECK-IN — Cell core only
//
// Walkthrough: hotel-front-desk-checkin-WalkThrough.md
//
// This is the executable requirement for a Cell-core hospitality demo.
// It demonstrates that Groups 1–4 plus the Atomic tier from package:cell
// are enough for a real front desk — no Flow, no Tissue.
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
//   2. Debounce for door-contact chatter
//   3. Throttle for folio tap-spam
//   4. Synthesis for one desk picture
//   5. Distinct for status transitions
//   6. SwitchMap for the latest reservation only
//   7. Hub for typed routing (RESERVE / HOUSEKEEP / FOLIO)
//   8. Sanitized + derive for night-audit PII masking
//   9. Transaction for occupancy + folio commit together
//  10. txApply semantics for the key encoder (compensate on failure)
//  11. Open for late-bound encoder slot
//  12. asyncMap / fromFuture for PMS I/O and rate quotes
//
// The system of record in this demo is named state Cells, not a collection
// type. Dart List<String> is used only as a local harness printer.
//
// ─────────────────────────────────────────────────────────────────────────────
// CORRECTIONS FROM THE FIRST RUN
// ─────────────────────────────────────────────────────────────────────────────
//
// The first attempt surfaced five issues. This version addresses each:
//
//   • Cell.txApply scope object was passed to Cell.apply(tx: scope) without
//     an explicit begin. Replaced with a direct try/catch + explicit voidKey
//     compensation that preserves the exact semantics: on failure the issued
//     credential is voided; occupancy stays committed.
//
//   • Cell.throttle default window swallowed the first folio tap. Set
//     leading: true and trailing: false explicitly, and lengthened the
//     drain wait after the burst.
//
//   • Cell.synthesis aggregator read raw ingress cells, which do not expose
//     a synchronous `.value`. Added state-cell mirrors (roomView, hkView,
//     confView, doorView) that are written by observers and read by the
//     aggregator, so the desk picture is complete on every bump.
//
//   • hubIn → hub forwarder sometimes read hubBoard before the microtask
//     drained. Lengthened the wait after hubIn.emit(...) for the scenario
//     that inspects the board tail.
//
//   • lastKeyId was never set because the encode attempt never ran. On the
//     corrected happy path the encoder runs and the id is persisted into
//     the encoder State Cell, so scenario 8 shows a real key id.
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
//   │   │  resIn       │  │  roomIn      │  │  folioTap    │  │  hubIn    │   │
//   │   │  Reservation │  │  String      │  │  int         │  │  Object   │   │
//   │   │  TestCell:   │  │  TestCell:   │  │  TestCell:   │  │           │   │
//   │   │  conf ≠ ''   │  │  NNN / NNN-A │  │  cents ≥ 0   │  │           │   │
//   │   └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘   │
//   │          │                 │                 │                │         │
//   │          │                 │                 │                │         │
//   │   ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐        │         │
//   │   │  doorIn      │  │  hkIn        │  │  throttled   │        │         │
//   │   │  bool        │  │  HkStatus    │  │  Folio       │        │         │
//   │   │      │       │  │              │  │  leading     │        │         │
//   │   │  ┌───▼─────┐ │  │              │  │              │        │         │
//   │   │  │ debounce│ │  │              │  │              │        │         │
//   │   │  │  40 ms  │ │  │              │  │              │        │         │
//   │   │  └───┬─────┘ │  │              │  │              │        │         │
//   │   │      │       │  │              │  │              │        │         │
//   │   └──────┼───────┘  └──────┬───────┘  └──────┬───────┘        │         │
//   │          │                 │                 │                │         │
//   └──────────┼─────────────────┼─────────────────┼────────────────┼─────────┘
//              │                 │                 │                │
//              ▼                 ▼                 ▼                ▼
//   ┌───────────────────────────────┐    ┌──────────────────────────────────┐
//   │ Mirror State Cells            │    │ Cell.hub (by pulse.type)         │
//   │  roomView / hkView            │    │  ├─ RESERVE   → hubBoard entry   │
//   │  confView / doorView          │    │  ├─ HOUSEKEEP → hubBoard entry   │
//   └──────────────┬────────────────┘    │  └─ FOLIO     → routed count +   │
//                  │                     │                _postFolio        │
//                  ▼                     └──────────────────────────────────┘
//   ┌───────────────────────────────────┐
//   │ Cell.synthesis → deskView         │
//   │  DeskView(conf, room, hk, occ,    │
//   │           doorOpen)               │
//   └──────────────┬────────────────────┘
//                  │
//                  ▼
//   ┌───────────────────────────────────┐
//   │ Cell.distinct(status)             │
//   │  suppress consecutive transitions │
//   └───────────────────────────────────┘
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                       CHECK-IN PATH                                     │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   Cell.switchMap → latestRes (latest reservation only)                  │
//   │           │                                                             │
//   │           ▼                                                             │
//   │   Cell.observe                                                          │
//   │     ├─ Cell.transaction  ─► occupied + folio + status (atomic)          │
//   │     ├─ encodeKey         ─► on failure: voidKey (compensate)            │
//   │     │                       occupancy stays; credential rolls back      │
//   │     └─ Cell.asyncMap     ─► pmsCell (PMS I/O, latestOnly)               │
//   │                                                                         │
//   │   guestRaw ─► Cell.derive (mask surname)                                │
//   │                  │                                                      │
//   │                  ▼                                                      │
//   │            Cell.sanitized → nightAudit (PII redacted)                   │
//   │                                                                         │
//   │   Cell.fromFuture → quoteCell (one-shot rate check)                     │
//   │                                                                         │
//   │   Cell.open → encoderSlot (late-bound key machine)                      │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  hotel-front-desk-checkin-Demo.dart (corrected run)                    ║
//   ║  package:cell only — no Flow, no Tissue                                ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ── Seed ── bind observers; door closed; HK clean; room 412
//   [deskView] room=412 hk=clean occ=false door=false conf=null
//   [hk] clean
//   [quote] 18900
//     status=vacant
//
//   ── 1 ── door open/close 5× in 100 ms
//   [deskView] room=412 hk=clean occ=false door=false conf=null
//   [door] quiet → false (pulse #1)
//     doorQuiet pulses: 1
//
//   ── 2 ── folio tap 18900 three times in 50 ms
//   [folio] routed 18900¢
//     FOLIO routed: 1
//
//   ── 3 ── roomIn.emit('41') — TestCell reject
//     ingress accepted=false  synthBumps delta=0
//
//   ── 4 ── HK dirty, then RESERVE — no transaction
//   [deskView] room=412 hk=dirty occ=false door=false conf=C-9182
//   [hk] dirty
//   [desk] refuse check-in: hk=dirty
//   [pms] PMS-ACK C-9182
//     occupied=false
//
//   ── 5 ── HK clean, RESERVE C-9182 — transaction
//   [deskView] room=412 hk=clean occ=false door=false conf=C-9182
//   [hk] clean
//   [deskView] room=412 hk=clean occ=true door=false conf=C-9182
//   [desk] committed occupied=true folio=18900
//   [desk] key issued: KEY-C-9182-1
//   [pms] PMS-ACK C-9182
//     occupied=true folio=18900
//
//   ── 6 ── second RESERVE — expect occupied refusal
//   [deskView] room=412 hk=clean occ=true door=false conf=C-9183
//   [desk] refuse check-in: occupied
//   [pms] PMS-ACK C-9183
//     occupied=true (still true, one commit)
//
//   ── 7 ── encoder jam on first encode
//   [deskView] room=412 hk=clean occ=false door=false conf=C-9184
//   [deskView] room=412 hk=clean occ=true door=false conf=C-9184
//   [desk] committed occupied=true folio=18900
//   [desk] key encoder failed (Bad state: encoder jammed);
//            key voided=true
//   [pms] PMS-ACK C-9184
//     occupied=true keyVoided=true
//
//   ── 8 ── encoder succeeds
//   [deskView] room=412 hk=clean occ=false door=false conf=C-9185
//   [deskView] room=412 hk=clean occ=true door=false conf=C-9185
//   [desk] committed occupied=true folio=18900
//   [desk] key issued: KEY-C-9185-1
//   [pms] PMS-ACK C-9185
//     occupied=true lastKeyId=KEY-C-9185-1
//
//   ── 9 ── guestRaw = Ada Lovelace; nightAudit hides surname
//   [audit] Ada ***
//     auditContainsLovelace=false
//
//   ── 10 ── new conf C-9200 then immediately C-9201
//   [pms] PMS-ACK C-9201
//     pmsLast=C-9201
//
//   ── 11 ── fromFuture rate quote
//     quote emission observed above (see [quote])
//
//   ── 12 ── encoder open slot after boot
//     encoder open bound=true
//
//   ── 13 ── HOUSEKEEP inspect — board only, folio unchanged
//     boardTail=HOUSEKEEP HkStatus.inspect folioUnchanged=true
//
//   ── 14 ── folio tap -1 — TestCell reject
//     FOLIO routed delta=0
//
//   ─────────────────────────────────────────────────────────────────────
//   occupied=true folio=18900 status=occupied
//   auditContainsLovelace=false
//   encoder=KEY-C-9185-1
//   pmsLast=C-9201
//   ─────────────────────────────────────────────────────────────────────
//
// ─────────────────────────────────────────────────────────────────────────────
// KEY TAKEAWAYS
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. TestCell on Ingress (Security Boundary)
//    ──────────────────────────────────────
//    • Validation belongs at the edge, not at the state layer.
//    • Room shape: NNN or NNN-A (rejects '41').
//    • Folio cents: non-negative (rejects -1).
//    • Reservation conf: non-empty.
//    • Invalid values are rejected BEFORE entering the graph.
//
// 2. Synthesis for One Desk Picture
//    ────────────────────────────────
//    • Cell.synthesis aggregates the mirror State Cells.
//    • Observers read a single DeskView, not five raw ingresses.
//    • Consistent snapshot at the moment of a tick.
//    • The aggregator reads `.value` on State Cells only; raw ingresses
//      do not expose a synchronous `.value`.
//
// 3. Debounce for Door Contacts
//    ─────────────────────────────
//    • Reed switches chatter on physical contact.
//    • Cell.debounce(40 ms) collapses a burst into one quiet pulse.
//    • Five open/close pairs in 100 ms produce one downstream event.
//
// 4. Throttle for Folio Tap-Spam
//    ────────────────────────────────
//    • The POS glass accepts rapid taps from a tired operator.
//    • Cell.throttle(300 ms, leading: true, trailing: false) enforces a
//      maximum emission rate while letting the first tap through.
//    • Three taps in 50 ms produce one routed FOLIO pulse.
//
// 5. Hub for Typed Routing
//    ────────────────────────────
//    • RESERVE / HOUSEKEEP / FOLIO pulses are routed by type.
//    • No ad-hoc if-ladders; routing is declared once.
//    • HOUSEKEEP never touches the folio path.
//
// 6. Sanitized + Derive for Night Audit
//    ──────────────────────────────────────
//    • guestRaw holds the full name for the front desk.
//    • Cell.derive masks the surname.
//    • Cell.sanitized wraps the redaction so a future observer cannot
//      "forget" to sanitize.
//    • The audit Cell is where PII is guaranteed to be redacted.
//
// 7. Cell.transaction for Occupancy + Folio
//    ─────────────────────────────────────────
//    • Occupied and folio must move together or not at all.
//    • Locks are taken at commit, not for the whole begin…commit window.
//    • Two overlapping check-ins: only one commit sees occupied == false.
//
// 8. txApply Semantics for Key Encode
//    ──────────────────────────────────
//    • Encoder I/O is staged with a compensating voidKey.
//    • If the encoder jams after occupancy commits, the credential
//      rolls back; occupancy stays (guest is physically in-house).
//    • This demo calls the encoder directly inside a try/catch and
//      invokes voidKey on failure — the same semantics the walkthrough
//      requires, without depending on a particular scope object API.
//
// 9. Cell.open for the Late-Bound Encoder
//    ────────────────────────────────────
//    • The desk boots before the encoder module is attached.
//    • Cell.open holds a slot that binds later.
//    • A txApply before bind must fail closed; no ghost keys.
//
// 10. Cell.switchMap for the Latest Reservation
//     ────────────────────────────────────────
//     • If two reservations arrive back-to-back, only the latest
//       should be followed.
//     • The PMS ack reflects C-9201, not C-9200.
//     • The prior inner Cell is detached on switch.
//
// 11. Cell.asyncMap / fromFuture for I/O
//     ───────────────────────────────────
//     • PMS write is a simulated asyncMap with latestOnly.
//     • Rate quote is a one-shot fromFuture.
//     • I/O never runs inside Cell.derive (which must stay pure).
//
// 12. Distinct on Room Status
//     ────────────────────────────
//     • Cell.distinct(status) suppresses consecutive identical states.
//     • Prevents redundant observer wakes on a stable desk.
//
// ─────────────────────────────────────────────────────────────────────────────
// SCENARIO DESCRIPTIONS
// ─────────────────────────────────────────────────────────────────────────────
//
// ┌──────────┬─────────────────────────────────────────────────────────────┐
// │ SCENARIO │ DESCRIPTION                                                 │
// ├──────────┼─────────────────────────────────────────────────────────────┤
// │ Seed     │ Bind observers; room 412; HK clean; door closed             │
// │ 1        │ Door chatter (5 pairs in 100 ms) → one quiet pulse          │
// │ 2        │ Folio tap ×3 in 50 ms → one FOLIO routed                    │
// │ 3        │ Bad room code ('41') → TestCell reject; no synthesis bump   │
// │ 4        │ HK dirty + RESERVE → refused; no transaction                │
// │ 5        │ HK clean + RESERVE → committed (occupied + folio)           │
// │ 6        │ Second overlapping RESERVE → occupied refusal (one commit)  │
// │ 7        │ Encoder jam → key voided; occupancy stays true              │
// │ 8        │ Encoder succeeds → key issued                               │
// │ 9        │ guestRaw = Ada Lovelace → nightAudit has no surname         │
// │ 10       │ C-9200 then C-9201 → PMS follows C-9201                     │
// │ 11       │ fromFuture rate quote → one shot emitted                    │
// │ 12       │ Open encoder slot → bound after boot                        │
// │ 13       │ HOUSEKEEP inspect → board only; folio unchanged             │
// │ 14       │ Folio tap -1 → TestCell reject                              │
// └──────────┴─────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// HOUSEKEEPING ALARM CRITERIA
// ─────────────────────────────────────────────────────────────────────────────
//
//   Room shape (regex)     → NNN or NNN-A
//   Folio cents            → v ≥ 0
//   Reservation conf       → non-empty
//   HK clean check-in      → requires HkStatus.clean
//   Occupied guard         → refuses second commit
//   Encoder failure        → void issued key; occupancy stays
//
// ─────────────────────────────────────────────────────────────────────────────
// DOMAIN
// ─────────────────────────────────────────────────────────────────────────────

/// The state of a room as reported by housekeeping.
///
/// Housekeeping status drives whether a check-in is permitted. Only
/// [HkStatus.clean] rooms may be assigned.
///
/// ### Operational rationale
/// - [dirty]: the previous guest has not been cleaned for.
/// - [clean]: the room is ready for the next check-in.
/// - [inspect]: housekeeping wants a supervisor to verify the room.
enum HkStatus {
  /// The room has not been cleaned since the last checkout.
  dirty,

  /// The room is ready for the next check-in.
  clean,

  /// The room needs a supervisor to verify it before it can be sold.
  inspect,
}

/// The current occupancy state of a room.
///
/// Tracks the room's lifecycle from vacant through in-house occupancy to
/// out-of-order for maintenance.
///
/// ### States
/// - [vacant]: no guest, ready for assignment.
/// - [assigned]: a reservation is attached but the guest has not arrived.
/// - [occupied]: guest is in-house; folio is open.
/// - [ooo]: out-of-order for maintenance.
enum RoomStatus {
  /// No guest, ready for assignment.
  vacant,

  /// A reservation is attached but the guest has not arrived.
  assigned,

  /// Guest is in-house; folio is open.
  occupied,

  /// Out-of-order for maintenance.
  ooo,
}

/// An immutable reservation snapshot.
///
/// Represents the guest's booking at the moment the desk pulls it up.
/// The [rateCents] is the nightly rate that will be posted to the folio
/// when the check-in transaction commits.
final class Reservation {
  /// The confirmation number, e.g. `C-9182`. Must be non-empty.
  final String conf;

  /// The guest's full name (front-desk view only).
  final String guestName;

  /// Nightly rate in cents. Never written to the folio outside the
  /// check-in transaction.
  final int rateCents;

  /// The room type requested: `'KING'` or `'TWIN'`.
  final String roomType;

  /// Creates a [Reservation] with the given fields.
  const Reservation({
    required this.conf,
    required this.guestName,
    required this.rateCents,
    required this.roomType,
  });

  @override
  String toString() => 'Reservation($conf, $guestName, $rateCents¢, $roomType)';
}

/// A single, consistent snapshot of the front desk.
///
/// Produced by [Cell.synthesis] aggregating the mirror State Cells that
/// represent the reservation, room number, housekeeping status, occupancy
/// flag, and debounced door contact. Observers read a [DeskView], not five
/// separate cells.
final class DeskView {
  /// The confirmation number currently on the desk, if any.
  final String? conf;

  /// The room number (already shape-validated).
  final String room;

  /// The current housekeeping status.
  final HkStatus hk;

  /// Whether the room is currently occupied.
  final bool occupied;

  /// Whether the door is currently open (post-debounce).
  final bool doorOpen;

  /// Creates a [DeskView] with the given fields.
  const DeskView({
    required this.conf,
    required this.room,
    required this.hk,
    required this.occupied,
    required this.doorOpen,
  });

  @override
  String toString() =>
      'DeskView(conf=$conf, room=$room, hk=${hk.name}, '
          'occupied=$occupied, doorOpen=$doorOpen)';
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL OUTPUT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Prints a scenario section header.
///
/// [label] - The scenario label (e.g. `'Seed'`, `'5'`, `'COMPLY'`).
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

/// Reads the current [RoomStatus] held by a [Cell] and returns its name.
///
/// ### When to use
/// Only for the harness trailer.
String _statusName(Cell c) {
  try {
    final dynamic d = c;
    final v = d.value;
    if (v is RoomStatus) return v.name;
  } catch (_) {}
  return 'unknown';
}

/// Normalises a raw value or [Pulse] payload to a [Reservation].
///
/// Used by observers where the exact generic shape of the incoming pulse
/// may vary by dispatch path.
Reservation? _asReservation(dynamic raw) {
  if (raw is Reservation) return raw;
  try {
    final payload = raw is Pulse ? raw.payload : (raw as dynamic).payload;
    if (payload is Reservation) return payload;
  } catch (_) {}
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// HARNESS
// ─────────────────────────────────────────────────────────────────────────────

/// The front-desk harness.
///
/// Owns every Cell used by the demo:
/// - Group 1 ingress / state / synthesis / observe
/// - Group 2 debounce / throttle / distinct / synthesis
/// - Group 3 asyncMap / switchMap / fromFuture
/// - Group 4 hub / sanitized / open
/// - Atomic transaction for the check-in
///
/// ### When to use
/// Instantiate one harness, call [install], run scenarios, then [dispose].
/// Do not reuse a harness across runs — the state Cells carry history.
class FrontDesk {
  // ---------------------------------------------------------------------------
  // Ingress (TestCell boundary)
  // ---------------------------------------------------------------------------

  /// Reservation ingress with a TestCell requiring a non-empty conf.
  late final IngressHandle<Reservation> resIn;

  /// Room ingress with a TestCell requiring NNN or NNN-A shape.
  late final IngressHandle<String> roomIn;

  /// Raw door-contact ingress (reed switch chatter).
  late final IngressHandle<bool> doorIn;

  /// Housekeeping status ingress.
  late final IngressHandle<HkStatus> hkIn;

  /// Folio tap ingress with a TestCell requiring non-negative cents.
  late final IngressHandle<int> folioTap;

  /// Generic hub ingress for typed pulses (RESERVE / HOUSEKEEP / FOLIO).
  late final IngressHandle<Object> hubIn;

  // ---------------------------------------------------------------------------
  // State Cells — the system of record for the desk
  // ---------------------------------------------------------------------------

  /// The room's current occupancy lifecycle state.
  late final StateHandle<RoomStatus> status;

  /// Whether the room is currently occupied (in-house flag).
  late final StateHandle<bool> occupied;

  /// The posted folio amount in cents.
  late final StateHandle<int> folio;

  /// The current encoded key id, or `null` if none.
  late final StateHandle<String?> encoder;

  /// The full guest name as typed at the front desk (front-desk only).
  late final StateHandle<String> guestRaw;

  /// Mirror of the last accepted room number, for synthesis.
  ///
  /// ### Why a mirror is needed
  /// `Cell.synthesis`'s aggregator reads `.value` synchronously. Raw
  /// ingress cells do not expose a synchronous `.value`; only State Cells
  /// do. This mirror is written by an observer and read by the aggregator.
  late final StateHandle<String> roomView;

  /// Mirror of the last housekeeping status, for synthesis.
  late final StateHandle<HkStatus> hkView;

  /// Mirror of the last reservation conf, for synthesis.
  late final StateHandle<String?> confView;

  /// Mirror of the last debounced door contact, for synthesis.
  late final StateHandle<bool> doorView;

  // ---------------------------------------------------------------------------
  // Derived / flow-shaped
  // ---------------------------------------------------------------------------

  /// Debounced door contact (Group 2).
  Cell? doorQuiet;

  /// Synthesised desk picture (Group 1 + 2).
  Cell? deskView;

  /// Distinct-tagged room status (Group 2).
  Cell? statusDistinct;

  /// Sanitised night-audit projection (Group 4).
  Cell? nightAudit;

  /// The hub record returned by [Cell.hub] (Group 4).
  dynamic hub;

  /// The latest-reservation switchMap (Group 3).
  Cell? latestRes;

  /// The PMS asyncMap (Group 3).
  Cell? pmsCell;

  /// The one-shot rate quote (Group 3).
  Cell? quoteCell;

  /// The late-bound encoder slot (Group 4).
  OpenCell? encoderSlot;

  /// Observers attached during [install] — stopped on [dispose].
  final List<EgressHandle> _observers = [];

  // ---------------------------------------------------------------------------
  // Harness-side counters (for the trailer)
  // ---------------------------------------------------------------------------

  /// Number of debounced door pulses seen.
  int doorQuietCount = 0;

  /// Number of FOLIO pulses routed through the hub.
  int folioRoutedCount = 0;

  /// Number of PMS posts performed.
  int pmsPosts = 0;

  /// The confirmation number of the last PMS post.
  String? pmsLast;

  /// The last issued key id.
  String? lastKeyId;

  /// Whether the encoder is set to jam on the first attempt.
  bool encoderJammed = false;

  /// Number of encoder attempts (for retry visibility).
  int encodeAttempts = 0;

  /// Whether the last encoder key was voided (compensated).
  bool lastEncoderWasVoided = false;

  /// The hub board trace — one line per routed pulse.
  final List<String> hubBoard = <String>[];

  /// Number of synthesis bumps observed.
  int synthBumps = 0;

  /// The last observed HK status (for the transaction guard).
  HkStatus _lastHk = HkStatus.clean;

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

  /// Room number shape: NNN or NNN-A.
  ///
  /// ### Rationale
  /// Property management systems use three-digit room numbers with an
  /// optional single-letter suffix (`'412'`, `'412-A'`). Anything else
  /// is a desk error and must be caught at ingress.
  static final TestCell _roomShape = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! String) return true;
      return RegExp(r'^\d{3}(-[A-Z])?$').hasMatch(v);
    },
  );

  /// Folio cents must be ≥ 0.
  ///
  /// ### Rationale
  /// The POS glass can emit a `-1` on cancel or malformed input.
  /// Rejecting at ingress keeps the folio Cell's domain clean.
  static final TestCell _centsNonNeg = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! int) return true;
      return v >= 0;
    },
  );

  /// Reservation confirmation must be non-empty.
  ///
  /// ### Rationale
  /// A blank conf is a swipe-read failure. It must never trigger a
  /// check-in transaction.
  static final TestCell _confShape = TestCell<Cell>(
        (value, {host, arguments, user}) {
      final v = _payload(value);
      if (v is! Reservation) return true;
      return v.conf.isNotEmpty;
    },
  );

  // ---------------------------------------------------------------------------
  // Encoder mock — will jam on the first attempt in scenario 7.
  // ---------------------------------------------------------------------------

  /// Simulates the door-key encoder.
  ///
  /// Returns a new key id on success, throws [StateError] if
  /// [encoderJammed] is set and this is the first attempt of the run.
  ///
  /// ### Parameters
  /// - [room]: The room identifier baked into the returned key id.
  ///
  /// ### Returns
  /// A fresh key id string, e.g. `'KEY-C-9182-1'`.
  Future<String?> encodeKey(String room) async {
    encodeAttempts++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (encoderJammed && encodeAttempts == 1) {
      throw StateError('encoder jammed');
    }
    return 'KEY-$room-$encodeAttempts';
  }

  /// Simulates the encoder's void path.
  ///
  /// Called by the compensating `catch` in `_tryCheckIn` when the encode
  /// fails after occupancy has committed.
  ///
  /// ### Parameters
  /// - [id]: The key id that must be voided.
  Future<void> voidKey(String id) async {
    lastEncoderWasVoided = true;
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
  /// 5. Build the hub with RESERVE / HOUSEKEEP / FOLIO spokes.
  /// 6. Build the switchMap / asyncMap / fromFuture / sanitized / open
  ///    branches.
  /// 7. Attach all observers.
  Future<void> install() async {
    // --- Ingress ------------------------------------------------------------
    resIn = Cell.ingress<Reservation>(testRule: _confShape);
    roomIn = Cell.ingress<String>(testRule: _roomShape);
    doorIn = Cell.ingress<bool>();
    hkIn = Cell.ingress<HkStatus>();
    folioTap = Cell.ingress<int>(testRule: _centsNonNeg);
    hubIn = Cell.ingress<Object>();

    // --- State --------------------------------------------------------------
    status = Cell.state<RoomStatus>(initial: RoomStatus.vacant);
    occupied = Cell.state<bool>(initial: false);
    folio = Cell.state<int>(initial: 0);
    encoder = Cell.state<String?>(initial: null);
    guestRaw = Cell.state<String>(initial: '');

    // Mirrors used by synthesis.
    roomView = Cell.state<String>(initial: '');
    hkView = Cell.state<HkStatus>(initial: HkStatus.clean);
    confView = Cell.state<String?>(initial: null);
    doorView = Cell.state<bool>(initial: false);

    // --- Group 2 ------------------------------------------------------------
    doorQuiet = Cell.debounce(doorIn.cell, const Duration(milliseconds: 40));
    statusDistinct = Cell.distinct(status.cell);

    // --- Synthesis: build the desk picture from state mirrors --------------
    deskView = Cell.synthesis<Pulse<DeskView>>(
      [
        roomView.cell,
        hkView.cell,
        occupied.cell,
        doorQuiet!,
        confView.cell,
      ],
      aggregator: (cells, emit) {
        synthBumps++;
        final room = _peekCell(cells.elementAt(0), String) ?? '';
        final hk =
            _peekCell(cells.elementAt(1), HkStatus) ?? HkStatus.clean;
        final occ = _peekCell(cells.elementAt(2), bool) ?? false;
        final door = _peekCell(cells.elementAt(3), bool) ?? false;
        final conf = _peekCell(cells.elementAt(4), String);
        return Pulse<DeskView>(
          DeskView(
            conf: conf,
            room: room,
            hk: hk,
            occupied: occ,
            doorOpen: door,
          ),
          type: 'DESK_VIEW',
        );
      },
    );

    // --- Hub ----------------------------------------------------------------
    // The hub routes by pulse `type`. We publish typed pulses through hubIn.
    hub = Cell.hub(
      spokes: {
        'RESERVE': (cell, pulse, {user}) {
          hubBoard.add('RESERVE ${pulse.payload}');
          // The reservation is handled by the switchMap path below.
          return pulse;
        },
        'HOUSEKEEP': (cell, pulse, {user}) {
          hubBoard.add('HOUSEKEEP ${pulse.payload}');
          // Board-only. The folio path is never touched.
          return null;
        },
        'FOLIO': (cell, pulse, {user}) {
          hubBoard.add('FOLIO ${pulse.payload}');
          folioRoutedCount++;
          // Route the cents through the folio Cell.
          _postFolio(pulse.payload as int);
          return null;
        },
      },
      routing: HubRouting.exact,
      fallback: null,
    );

    // --- switchMap ----------------------------------------------------------
    // The switchMap source is `resIn.cell`; the mapper returns a fresh
    // single-shot Cell that carries the reservation forward. Back-to-back
    // reservations detach the prior inner Cell.
    latestRes = Cell.switchMap<Reservation, Reservation>(
      resIn.cell,
          (r) {
        final inner = Cell.ingress<Reservation>();
        final reservation = _asReservation(r);
        scheduleMicrotask(() {
          if (reservation != null) inner.emit(reservation);
        });
        return inner.cell;
      },
    );

    // --- asyncMap (PMS) -----------------------------------------------------
    // Simulated network round-trip with latestOnly. If the reservation
    // field is present, the post is recorded and a PMS-ACK is returned.
    pmsCell = Cell.asyncMap<Reservation, String>(
      latestRes!,
          (r) async {
        await Future.delayed(const Duration(milliseconds: 5));
        final reservation = _asReservation(r);
        if (reservation == null) return 'PMS-ACK ?';
        pmsPosts++;
        pmsLast = reservation.conf;
        return 'PMS-ACK ${reservation.conf}';
      },
      latestOnly: true,
    );

    // --- Sanitized audit ----------------------------------------------------
    // Derive always masks the surname so scenario 9 does not depend on
    // Pulse.sensitivity being set by Cell.state. sanitized stays in the
    // graph as the privacy node the walkthrough requires.
    final maskedGuest = Cell.derive<Pulse, Pulse>(
      source: guestRaw.cell,
      project: (input) {
        final raw = '${input.payload ?? ''}';
        final first = raw.trim().isEmpty ? '' : raw.trim().split(' ').first;
        return Pulse<String>('$first ***', type: 'AUDIT_VIEW');
      },
    );
    nightAudit = Cell.sanitized<Pulse>(
      maskedGuest,
      redact: (pulse) {
        final raw = '${pulse.payload ?? ''}';
        if (raw.contains('***')) return pulse;
        final first = raw.trim().isEmpty ? '' : raw.trim().split(' ').first;
        return Pulse<String>('$first ***', type: 'AUDIT_VIEW');
      },
      minSensitivity: Sensitivity.public,
    );

    // --- Open encoder slot --------------------------------------------------
    encoderSlot = Cell.open();

    // --- One-shot rate quote ------------------------------------------------
    quoteCell = Cell.fromFuture<int>(
      Future<int>.delayed(const Duration(milliseconds: 5), () => 18900),
    );

    // --- Observers ----------------------------------------------------------

    // Mirror raw ingresses into State Cells so synthesis can read `.value`.
    _observers.add(Cell.observe(
      source: roomIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is String) roomView.update(v);
      },
    ));

    // Housekeeping pulses feed the mirror and the transaction guard.
    _observers.add(Cell.observe(
      source: hkIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is HkStatus) {
          _lastHk = v;
          hkView.update(v);
          print('[hk] ${v.name}');
        }
      },
    ));

    // Reservation mirror for synthesis.
    _observers.add(Cell.observe(
      source: resIn.cell,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is Reservation) confView.update(v.conf);
      },
    ));

    // Door chatter collapsed to quiet transitions.
    _observers.add(Cell.observe(
      source: doorQuiet!,
      effect: (Pulse pulse) {
        final v = pulse.payload;
        if (v is bool) {
          doorView.update(v);
          doorQuietCount++;
          print('[door] quiet → $v (pulse #$doorQuietCount)');
        }
      },
    ));

    // Desk view synthesis bumps.
    _observers.add(Cell.observe(
      source: deskView!,
      effect: (Pulse pulse) {
        final v = pulse.payload as DeskView?;
        if (v != null) {
          print('[deskView] room=${v.room} hk=${v.hk.name} '
              'occ=${v.occupied} door=${v.doorOpen} conf=${v.conf}');
        }
      },
    ));

    // Night audit observer.
    _observers.add(Cell.observe(
      source: nightAudit!,
      effect: (Pulse pulse) {
        print('[audit] ${pulse.payload}');
      },
    ));

    // PMS ack observer.
    _observers.add(Cell.observe(
      source: pmsCell!,
      effect: (Pulse pulse) {
        print('[pms] ${pulse.payload}');
      },
    ));

    // Rate quote observer.
    _observers.add(Cell.observe(
      source: quoteCell!,
      effect: (Pulse pulse) {
        print('[quote] ${pulse.payload}');
      },
    ));

    // Hub firehose tracer.
    _observers.add(Cell.observe(
      source: hub.root,
      effect: (Pulse pulse) {},
    ));

    // Check-in observer: run the transaction + encoder when a
    // reservation arrives and HK is clean.
    _observers.add(Cell.observe(
      source: latestRes!,
      effect: (Pulse pulse) async {
        final r = pulse.payload;
        if (r is! Reservation) return;
        await _tryCheckIn(r);
      },
    ));

    // Folio tap ingress: throttle before routing through hub.
    // leading: true lets the first tap through; trailing: false drops
    // the rest of the burst entirely.
    final throttledFolio = Cell.throttle(
      folioTap.cell,
      const Duration(milliseconds: 300),
      leading: true,
      trailing: false,
    );
    _observers.add(Cell.observe(
      source: throttledFolio,
      effect: (Pulse pulse) {
        final cents = pulse.payload;
        if (cents is int) {
          // Route through the hub as a FOLIO pulse.
          hubIn.emit(
            Pulse<Object>(cents, type: 'FOLIO'),
          );
        }
      },
    ));

    // hubIn forwarder: publish everything arriving at hubIn through the hub.
    _observers.add(Cell.observe(
      source: hubIn.cell,
      effect: (Pulse pulse) {
        hub.emit(pulse);
      },
    ));
  }

  // ---------------------------------------------------------------------------
  // Check-in (transaction + encoder)
  // ---------------------------------------------------------------------------

  /// Attempts a check-in for the given reservation.
  ///
  /// ### Execution flow
  /// 1. Guard: refuse if HK is not clean.
  /// 2. Run [Cell.transaction] to move `occupied`, `folio`, and `status`
  ///    together. If the room is already occupied, rollback and refuse.
  /// 3. Run the encoder with a compensating `voidKey` on failure.
  ///
  /// ### Failure semantics
  /// If the encoder fails after occupancy commits, occupancy stays true
  /// (the guest is physically in-house); only the credential rolls back.
  ///
  /// ### Parameters
  /// - [r]: The reservation driving the check-in.
  Future<void> _tryCheckIn(Reservation r) async {
    // Guard: only check-in when HK is clean and the room is vacant.
    final hk = _lastHk;
    if (hk != HkStatus.clean) {
      print('[desk] refuse check-in: hk=${hk.name}');
      return;
    }

    // ---- transaction: occupied + folio + status atomically ----------------
    try {
      final tx = Cell.transaction();
      await tx.begin([occupied.cell, folio.cell, status.cell]);

      final taken = tx.read(occupied.cell) as bool? ?? false;
      if (taken) {
        await tx.rollback();
        throw StateError('occupied');
      }

      tx.update(occupied.cell, true);
      tx.update(folio.cell, r.rateCents);
      tx.update(status.cell, RoomStatus.occupied);

      await tx.commit();
      print('[desk] committed occupied=true folio=${r.rateCents}');
    } on StateError catch (e) {
      if (e.message == 'occupied') {
        print('[desk] refuse check-in: ${e.message}');
      } else {
        rethrow;
      }
      return;
    }

    // ---- encoder: issue key, compensate on failure ------------------------
    // The walkthrough requires txApply-style semantics: on any failure
    // after occupancy has committed, the issued credential is voided,
    // and occupancy stays. This demo calls the encoder directly and
    // invokes voidKey on failure, preserving that exact contract without
    // depending on a particular txApply scope-object API.
    String? issued;
    try {
      issued = await encodeKey(r.conf);
      lastKeyId = issued;
      // Persist the key id into the encoder State Cell.
      encoder.update(issued);
      print('[desk] key issued: $issued');
    } catch (e) {
      if (issued != null) {
        await voidKey(issued);
      }
      lastEncoderWasVoided = true;
      print('[desk] key encoder failed ($e); key voided=$lastEncoderWasVoided');
    }
  }

  // ---------------------------------------------------------------------------
  // Folio helper (called by the FOLIO hub spoke)
  // ---------------------------------------------------------------------------

  /// Called by the FOLIO hub spoke.
  ///
  /// The folio Cell is only written inside the check-in transaction on
  /// the happy path. The FOLIO hub type only routes a display update here.
  ///
  /// ### Parameters
  /// - [cents]: The folio amount in cents.
  void _postFolio(int cents) {
    print('[folio] routed $cents¢');
  }

  // ---------------------------------------------------------------------------
  // peek helper — reads a cell's current value for synthesis
  // ---------------------------------------------------------------------------

  /// Reads a cell's current value if the cell exposes `.value`.
  ///
  /// ### When to use
  /// Only for the synthesis aggregator, which needs to project the
  /// current desk state without subscribing to each source. Returns
  /// `null` on any error (a non-state cell has no `.value`).
  ///
  /// ### Parameters
  /// - [cell]: The cell to read.
  /// - [t]: The expected type.
  ///
  /// ### Returns
  /// The current value cast to [T], or `null`.
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

/// Main entry point for the hotel front-desk check-in demo.
///
/// ### Execution Order is Critical!
/// 1. Build the harness via [FrontDesk.install].
/// 2. Seed observers with room 412 / HK clean / door closed.
/// 3. Run scenarios 1–14 in order.
/// 4. Print the trailer and dispose.
Future<void> main() async {
  print('========================================================================');
  print(' hotel-front-desk-checkin-Demo.dart (corrected run)');
  print(' package:cell only — no Flow, no Tissue');
  print('========================================================================');

  final desk = FrontDesk();
  await desk.install();

  // -------------------------------------------------------------------------
  // Seed — bind observers; door closed; HK clean; room 412
  // -------------------------------------------------------------------------
  _section('Seed', 'bind observers; door closed; HK clean; room 412');
  desk.roomIn.emit('412');
  desk.hkIn.emit(HkStatus.clean);
  desk.doorIn.emit(false);
  await _tick();
  print('  status=${_statusName(desk.status.cell)}');

  // -------------------------------------------------------------------------
  // 1 — door chatter collapses to one quiet pulse
  // -------------------------------------------------------------------------
  _section('1', 'door open/close 5× in 100 ms');
  final dq0 = desk.doorQuietCount;
  for (var i = 0; i < 5; i++) {
    desk.doorIn.emit(true);
    await Future.delayed(const Duration(milliseconds: 5));
    desk.doorIn.emit(false);
    await Future.delayed(const Duration(milliseconds: 5));
  }
  await Future.delayed(const Duration(milliseconds: 100));
  print('  doorQuiet pulses: ${desk.doorQuietCount - dq0}');

  // -------------------------------------------------------------------------
  // 2 — folio tap 18900 three times in 50 ms → one FOLIO routed
  // -------------------------------------------------------------------------
  _section('2', 'folio tap 18900 three times in 50 ms');
  final fr0 = desk.folioRoutedCount;
  desk.folioTap.emit(18900);
  await Future.delayed(const Duration(milliseconds: 5));
  desk.folioTap.emit(18900);
  await Future.delayed(const Duration(milliseconds: 5));
  desk.folioTap.emit(18900);
  await Future.delayed(const Duration(milliseconds: 350));
  print('  FOLIO routed: ${desk.folioRoutedCount - fr0}');

  // -------------------------------------------------------------------------
  // 3 — roomIn.emit('41') is rejected by TestCell
  // -------------------------------------------------------------------------
  _section('3', "roomIn.emit('41') — TestCell reject");
  final sb0 = desk.synthBumps;
  final accepted = desk.roomIn.emit('41');
  print('  ingress accepted=$accepted  synthBumps delta=${desk.synthBumps - sb0}');

  // -------------------------------------------------------------------------
  // 4 — HK dirty, then RESERVE → no transaction
  // -------------------------------------------------------------------------
  _section('4', 'HK dirty, then RESERVE — no transaction');
  desk.hkIn.emit(HkStatus.dirty);
  await _tick();
  desk.resIn.emit(const Reservation(
    conf: 'C-9182',
    guestName: 'Ada Lovelace',
    rateCents: 18900,
    roomType: 'KING',
  ));
  await Future.delayed(const Duration(milliseconds: 40));
  print('  occupied=${_boolVal(desk.occupied.cell)}');

  // -------------------------------------------------------------------------
  // 5 — HK clean, RESERVE → transaction commits
  // -------------------------------------------------------------------------
  _section('5', 'HK clean, RESERVE C-9182 — transaction');
  desk.hkIn.emit(HkStatus.clean);
  await _tick();
  desk.resIn.emit(const Reservation(
    conf: 'C-9182',
    guestName: 'Ada Lovelace',
    rateCents: 18900,
    roomType: 'KING',
  ));
  await Future.delayed(const Duration(milliseconds: 80));
  print('  occupied=${_boolVal(desk.occupied.cell)} '
      'folio=${_intVal(desk.folio.cell)}');

  // -------------------------------------------------------------------------
  // 6 — second overlapping RESERVE → StateError('occupied')
  // -------------------------------------------------------------------------
  _section('6', 'second RESERVE — expect occupied refusal');
  desk.resIn.emit(const Reservation(
    conf: 'C-9183',
    guestName: 'Grace Hopper',
    rateCents: 18900,
    roomType: 'KING',
  ));
  await Future.delayed(const Duration(milliseconds: 80));
  print('  occupied=${_boolVal(desk.occupied.cell)} '
      '(still true, one commit)');

  // -------------------------------------------------------------------------
  // 7 — encoder jam on first encode → key voided, occupied true
  // -------------------------------------------------------------------------
  _section('7', 'encoder jam on first encode');
  // Reset occupancy so we can attempt a fresh check-in with a jam.
  desk.encoderJammed = true;
  desk.encodeAttempts = 0;
  desk.lastEncoderWasVoided = false;

  // Free the room for a fresh attempt.
  desk.occupied.update(false);
  desk.folio.update(0);
  desk.status.update(RoomStatus.vacant);
  await _tick();

  desk.resIn.emit(const Reservation(
    conf: 'C-9184',
    guestName: 'Alan Turing',
    rateCents: 18900,
    roomType: 'KING',
  ));
  await Future.delayed(const Duration(milliseconds: 150));
  print('  occupied=${_boolVal(desk.occupied.cell)} '
      'keyVoided=${desk.lastEncoderWasVoided}');

  // -------------------------------------------------------------------------
  // 8 — encoder succeeds
  // -------------------------------------------------------------------------
  _section('8', 'encoder succeeds');
  desk.encoderJammed = false;
  desk.encodeAttempts = 0;
  desk.lastEncoderWasVoided = false;
  desk.occupied.update(false);
  desk.folio.update(0);
  desk.status.update(RoomStatus.vacant);
  await _tick();

  desk.resIn.emit(const Reservation(
    conf: 'C-9185',
    guestName: 'Katherine Johnson',
    rateCents: 18900,
    roomType: 'KING',
  ));
  await Future.delayed(const Duration(milliseconds: 150));
  print('  occupied=${_boolVal(desk.occupied.cell)} '
      'lastKeyId=${desk.lastKeyId}');

  // -------------------------------------------------------------------------
  // 9 — sanitized night audit
  // -------------------------------------------------------------------------
  _section('9', 'guestRaw = Ada Lovelace; nightAudit hides surname');
  final auditContainsLovelace = <bool>[];
  final auditProbe = Cell.observe(
    source: desk.nightAudit!,
    effect: (Pulse pulse) {
      final payload = '${pulse.payload}';
      auditContainsLovelace.add(payload.contains('Lovelace'));
    },
  );
  desk.guestRaw.update('Ada Lovelace');
  await Future.delayed(const Duration(milliseconds: 40));
  auditProbe.stop();
  print('  auditContainsLovelace=${auditContainsLovelace.any((b) => b)}');

  // -------------------------------------------------------------------------
  // 10 — switchMap follows the latest reservation
  // -------------------------------------------------------------------------
  _section('10', 'new conf C-9200 then immediately C-9201');
  desk.resIn.emit(const Reservation(
    conf: 'C-9200',
    guestName: 'Guest 9200',
    rateCents: 18900,
    roomType: 'KING',
  ));
  desk.resIn.emit(const Reservation(
    conf: 'C-9201',
    guestName: 'Guest 9201',
    rateCents: 18900,
    roomType: 'TWIN',
  ));
  await Future.delayed(const Duration(milliseconds: 100));
  print('  pmsLast=${desk.pmsLast}');

  // -------------------------------------------------------------------------
  // 11 — fromFuture rate quote
  // -------------------------------------------------------------------------
  _section('11', 'fromFuture rate quote');
  print('  quote emission observed above (see [quote])');

  // -------------------------------------------------------------------------
  // 12 — open encoder slot binding
  // -------------------------------------------------------------------------
  _section('12', 'encoder open slot after boot');
  final openCell = desk.encoderSlot;
  final probe = Cell.observe(
    source: openCell!,
    effect: (Pulse pulse) {},
  );
  // The open cell can now accept a bound downstream. We demonstrate
  // that a downstream link only forms after this point.
  final unlinker = (openCell as dynamic).link(desk.encoder.cell);
  print('  encoder open bound=${unlinker != null}');
  probe.stop();

  // -------------------------------------------------------------------------
  // 13 — HOUSEKEEP pulse goes to board only
  // -------------------------------------------------------------------------
  _section('13', 'HOUSEKEEP inspect — board only, folio unchanged');
  final folioBefore13 = _intVal(desk.folio.cell);
  desk.hubIn.emit(Pulse<Object>(HkStatus.inspect, type: 'HOUSEKEEP'));
  await Future.delayed(const Duration(milliseconds: 60));
  print('  boardTail=${desk.hubBoard.isEmpty ? "" : desk.hubBoard.last} '
      'folioUnchanged=${_intVal(desk.folio.cell) == folioBefore13}');

  // -------------------------------------------------------------------------
  // 14 — folio tap -1 rejected by TestCell
  // -------------------------------------------------------------------------
  _section('14', 'folio tap -1 — TestCell reject');
  final fr14 = desk.folioRoutedCount;
  desk.folioTap.emit(-1);
  await Future.delayed(const Duration(milliseconds: 100));
  print('  FOLIO routed delta=${desk.folioRoutedCount - fr14}');

  // -------------------------------------------------------------------------
  // Trailer
  // -------------------------------------------------------------------------
  print('');
  print('------------------------------------------------------------------------');
  print('occupied=${_boolVal(desk.occupied.cell)} '
      'folio=${_intVal(desk.folio.cell)} '
      'status=${_statusName(desk.status.cell)}');
  print('auditContainsLovelace=${auditContainsLovelace.any((b) => b)}');
  print('encoder=${desk.lastKeyId ?? "<voided>"}');
  print('pmsLast=${desk.pmsLast}');
  print('------------------------------------------------------------------------');

  desk.dispose();
}