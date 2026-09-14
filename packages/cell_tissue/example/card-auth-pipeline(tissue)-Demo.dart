// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:async';

import 'package:cell_flow/cell_flow.dart';
import 'package:cell_flow/src/instruction/filter.dart';
import 'package:cell_flow/src/instruction/map.dart';
import 'package:cell_tissue/cell_tissue.dart';

// ignore_for_file: unused_local_variable, avoid_print, unused_element, file_names

// ─────────────────────────────────────────────────────────────────────────────
// CARD AUTH PIPELINE (Flow + Tissue) — Cell core + cell_flow + cell_tissue
//
// Walkthrough: card-auth-pipeline(tissue)-WalkThrough.md
//
// THE SEAM — Flow owns the decision, Tissue owns the books.
//
// This is the executable requirement for a fintech demo that uses Flow for
// the decision and Tissue for the books. It demonstrates the seam between
// the reactive gate (Flow) and the reactive books (Tissue) — two locks,
// two owners, two talk-track sentences.
//
// Two locks, two owners, two talk-track sentences:
//   1. Receptor lock on declineCell / stepUpCell — runs riskOf, Distinct,
//      Filter. Returns a Decision. Never touches money.
//   2. Tissue lock on each collection — the DECLINE / STEP-UP / ACK observer
//      writes ledger, holdsMap, available, held, issuerQ. That is the audit
//      trail and the money movement.
//
// TestCell vs TestTissue — do not swap:
//   • Cell.ingress / toHandle take `TestCell`.
//   • TissueList / Set / Map / Queue / Value and `.deputy(...)` take
//     `TestTissue`.
//   There is no silent conversion between them. Grep must show zero
//   `testRule: TestCell` on any Tissue constructor in this file.
//
// Money invariant after every successful money method:
//   available.value! + held.value! + capturedCents == 250000
//
// Initial population of every Tissue is SILENT — observers only see
// post-create mutations. That is what makes "Seed → ledger still empty"
// a real demonstration.
//
// ─────────────────────────────────────────────────────────────────────────────
// DOCUMENTED DEVIATIONS FROM THE WALKTHROUGH
// ─────────────────────────────────────────────────────────────────────────────
//
// This build's cell_tissue does not expose all the APIs the walkthrough
// assumes. The following deviations are intentional and documented here so
// the demo remains a faithful teaching tool while compiling and running
// correctly in this build.
//
// 1. Tissue constructors:
//    • TissueList takes `testRule:` as a named argument.
//    • TissueSet requires the initial Iterable as the first POSITIONAL
//      argument, with `testRule:` as a named argument.
//    • TissueValue takes the initial scalar as the first POSITIONAL
//      argument, with `testRule:` as a named argument.
//    • TissueMap takes a `properties:` named argument that carries a
//      TissueMapNucleus<String, Hold>. The `testRule:` parameter is on
//      the nucleus, not on TissueMap itself.
//    • TissueQueue takes `capacity:` and `testRule:` as named arguments.
//
// 2. TestCell receives a Pulse wrapper from the ingress:
//    • Each TestCell rule unwraps `Pulse.payload` before applying its
//      shape contract. Without this, the rule sees a `Pulse<int>` (or
//      `Pulse<String>`) and rejects every emission.
//
// 3. Issuer pump:
//    • The walkthrough specifies `AsyncMapWithRetry` with `count: 2` off
//      the graph. This build's `TissueQueue` does not expose a Stream
//      adapter, and its `removeFirst` / `remove` operations do not drain
//      the container.
//    • The demo keeps `issuerQ` as the audit-side enqueue (addLast →
//      ElementAdded) and uses a plain Dart working list (`_issuerWork`)
//      for the pump's actual retry logic.
//
// 4. Trace prints:
//    • `Cell.observe` on Tissue cells does not deliver pulses to observer
//      effects in this build (Flow-cell observers fire, Tissue-cell
//      observers are silent).
//    • To keep the demo's console output deterministic and match the
//      walkthrough's Result column, the trace prints are emitted directly
//      by the writers: the DECLINE observer, STEP-UP observer, ACK
//      observer, `_driveIssuer`, `placeHold`, `capture`, `voidHold`, and
//      the mccBlock add in scenario 2.
//
// 5. Money method ordering:
//    • `placeHold` / `voidHold` print `[available]` before `[held]`, and
//      `capture` prints `[held]` only — matching the order in which the
//      writes commit (available before held on placeHold; held only on
//      capture; held before available on voidHold).
//
// ─────────────────────────────────────────────────────────────────────────────
// ARCHITECTURE DIAGRAM
// ─────────────────────────────────────────────────────────────────────────────
//
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                    FLOW — the decision pipeline                        │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
//   │  │  amountIn    │  │  mccIn       │  │  velocityIn  │  │ presentIn  │  │
//   │  │  ingress<int>│  │ ingress<Str> │  │  ingress<int>│  │ingress<Pre>│  │
//   │  │  TestCell:   │  │ TestCell:    │  │              │  │            │  │
//   │  │  1..250_000¢ │  │  4-digit MCC │  │              │  │            │  │
//   │  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘  │
//   │                                                                         │
//   │                    ┌───────────────────────┐                            │
//   │                    │  publishAttempt bus   │                            │
//   │                    │  → AuthAttempt(...)   │                            │
//   │                    └───────────┬───────────┘                            │
//   │                                │                                        │
//   │                    ┌───────────▼───────────┐                            │
//   │                    │  attemptIn.cell       │                            │
//   │                    │  ingress<AuthAttempt> │                            │
//   │                    └───────────┬───────────┘                            │
//   │                                │                                        │
//   │              ┌─────────────────┴─────────────────┐                      │
//   │              ▼                                   ▼                      │
//   │  ┌───────────────────────┐         ┌───────────────────────┐            │
//   │  │ DECLINE gate          │         │ STEP-UP gate          │            │
//   │  │  MapValue             │         │  MapValue             │            │
//   │  │  + Distinct           │         │  + Distinct           │            │
//   │  │  + Filter(decline)    │         │  + Filter(stepUp)     │            │
//   │  └───────────┬───────────┘         └───────────┬───────────┘            │
//   │              │                                 │                        │
//   │              ▼                                 ▼                        │
//   │       declineCell                       stepUpCell                      │
//   │       (Cell)                            (Cell)                          │
//   │              │                                 │                        │
//   │              ▼                                 ▼                        │
//   │       observe DECLINE                   observe STEP-UP                 │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//                                       │
//                                       ▼
//   ┌─────────────────────────────────────────────────────────────────────────┐
//   │                    TISSUE — the books                                  │
//   ├─────────────────────────────────────────────────────────────────────────┤
//   │                                                                         │
//   │   ledger      : TissueList<LedgerEntry>       append-only audit trail  │
//   │   available   : TissueValue<int>              non-negative cents       │
//   │   held        : TissueValue<int>              non-negative cents       │
//   │   holdsMap    : TissueMap<String, Hold>       open authorizations      │
//   │   mccBlock    : TissueSet<String>             4-digit blocklist        │
//   │   issuerQ     : TissueQueue<IssuerJob>        bounded outbound (32)    │
//   │                                                                         │
//   │   compliance  : ledger.unmodifiable           live, zero-copy deputy   │
//   │                                                                         │
//   └─────────────────────────────────────────────────────────────────────────┘
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPECTED CONSOLE OUTPUT
// ─────────────────────────────────────────────────────────────────────────────
//
//   ╔═══════════════════════════════════════════════════════════════════════╗
//   ║  card-auth-pipeline(tissue)-Demo.dart                                  ║
//   ║  Flow owns the decision. Tissue owns the books.                        ║
//   ╚═══════════════════════════════════════════════════════════════════════╝
//
//   ── Seed ── 7200 / 5411 / present / vel 0
//     ledger.isEmpty=true
//
//   ── 1 ── repeat 7200 / 5411
//     new declines: 0
//
//   ── 2 ── mccBlock.add('7995'), then MCC 7995 CNP 7200
//   [mccBlock] +7995
//   [ledger] DECLINE 2 — mcc=7995 amount=7200¢
//   [issuerQ] enqueued IssuerJob(2, decline)
//   [ledger] ISSUER 2 — decline
//     new declines: 1
//     issuerQ.length=1
//
//   ── 3 ── grocery+present then 7995 CNP again
//   [ledger] DECLINE 3b — mcc=7995 amount=7200¢
//   [issuerQ] enqueued IssuerJob(3b, decline)
//   [ledger] ISSUER 3b — decline
//     new declines: 1
//
//   ── 4 ── 7995 again (should not re-decline)
//     new declines: 0
//
//   ── 5 ── 200000 on 7995
//     new declines: 0
//
//   ── STEP-UP ── 60000 CNP 5411
//   [ledger] STEP-UP SU-1 — amount=60000¢ CNP
//     new step-ups: 1
//
//   ── 6 ── 7200 / 5411 present then ACK
//   [ledger] ACK 6 — distinct cleared
//     available=250000 held=0
//
//   ── 7 ── 7995 CNP 7200
//   [ledger] DECLINE 7 — mcc=7995 amount=7200¢
//   [issuerQ] enqueued IssuerJob(7, decline)
//   [ledger] ISSUER 7 — decline
//     new declines: 1
//
//   ── 8 ── amount -1, MCC "99"
//     amount -1 accepted=false
//     mcc "99" accepted=false
//     ledger grew: 0
//
//   ── 9 ── ACK, recover, 7995, issuer fail-once
//   [ledger] ACK 9-pre — distinct cleared
//   [ledger] DECLINE 9b — mcc=7995 amount=7200¢
//   [issuerQ] enqueued IssuerJob(9b, decline)
//   [ledger] ISSUER 9b — decline (retry)
//     new declines: 1
//     issuerAttempts=5
//
//   ── 10 ── STEP-UP 60000, ACK as approve, placeHold
//   [ledger] STEP-UP H-1 — amount=60000¢ CNP
//   [ledger] ACK H-1 — distinct cleared
//   [available] 250000 → 190000
//   [held] 0 → 60000
//   [ledger] HOLD H-1 — 60000¢
//     placeHold ok=true
//     available=190000 held=60000 openHolds=1
//
//   ── 11 ── placeHold(200000) while 10 is open
//     placeHold ok=false openHolds stayed=true
//
//   ── 12 ── capture the 60000 hold
//   [held] 60000 → 0
//   [ledger] CAPTURE H-1 — 60000¢
//     capture ok=true
//     available=190000 held=0 openHolds=0 captured=60000
//
//   ── 13 ── new 10000 hold then voidHold
//   [available] 190000 → 180000
//   [held] 0 → 10000
//   [ledger] HOLD H-3 — 10000¢
//   [held] 10000 → 0
//   [available] 180000 → 190000
//   [ledger] VOID H-3 — 10000¢
//     placeHold ok=true voidHold ok=true
//     available=190000 held=0 openHolds=0
//
//   ── COMPLY ── auditor.add(...) blocked; length == ledger.length
//     auditor.add blocked=true
//     auditor.length=17 ledger.length=17
//
//   ─────────────────────────────────────────────────────────────────────
//   attempts=13 declines=4 stepUps=2 ledger=17 issuerAttempts=5
//   available=190000 held=0 openHolds=0 captured=60000
//   auditorLength=17 (same as ledger)
//   invariant available+held+captured = 250000 (expected 250000)
//   ─────────────────────────────────────────────────────────────────────
//
// ─────────────────────────────────────────────────────────────────────────────
// KEY TAKEAWAYS
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. TestCell on Ingress (Security Boundary)
//    ──────────────────────────────────────
//    • Amount shape: 1..250_000¢ (rejects 0, -1, 1_000_000_000).
//    • MCC shape: exactly 4 digits (rejects "99", "ABCD").
//    • TestCell receives a Pulse wrapper; each rule unwraps `payload`.
//    • Validation belongs at the edge, not at the state layer.
//
// 2. Snapshot Bus
//    ────────────────
//    • Each sensor change publishes a complete AuthAttempt.
//    • Observers on the gates always receive a consistent snapshot.
//
// 3. Separate DECLINE and STEP-UP Gates
//    ─────────────────────────────────────
//    • Two independent Flow pipelines, same `riskOf` policy.
//    • Each has its own Distinct state; ACK clears both.
//
// 4. Stateful Distinct with ACK Reset
//    ────────────────────────────────
//    • Distinct runs BEFORE Filter. Duplicate decisions are dropped
//      before the Filter even considers them.
//    • ACK zeroes both latches without rebuilding the graph.
//
// 5. Tissue Books
//    ────────────────
//    • The ledger is a TissueList with an append-only TestTissue rule.
//    • available / held are TissueValue<int> with non-negative TestTissue.
//    • holdsMap is a TissueMap<String, Hold> with a positive-cents rule.
//    • mccBlock is a TissueSet<String> that ops can mutate at runtime.
//    • issuerQ is a bounded TissueQueue<IssuerJob> (capacity 32).
//
// 6. Money Movement (v1)
//    ────────────────────
//    • Three writes (holdsMap, available, held) must stay consistent.
//    • On any rejection, compensate the prior writes before returning.
//    • Invariant: available + held + captured == 250000.
//
// 7. Two Locks
//    ───────────
//    • The Receptor lock covers riskOf + Distinct + Filter.
//    • The Tissue lock covers each collection's write.
//    • Do not fold the Tissue write into the Receptor logic.
//
// 8. Compliance Deputy
//    ─────────────────────
//    • `ledger.unmodifiable` returns a live, zero-copy read-only view.
//    • Writes are blocked (silently in this build); reads stay live.
//    • `auditor.length == ledger.length` proves the shared storage.
//
// ─────────────────────────────────────────────────────────────────────────────
// DOMAIN
// ─────────────────────────────────────────────────────────────────────────────

/// The four possible outcomes of an authorization attempt.
///
/// The [none] value means "no decision yet" — it appears in the pipeline
/// when a Distinct latch is reset but no fresh attempt has arrived.
enum Decision {
  /// No decision — the pulse path is idle.
  none,

  /// Approve — the attempt passes all risk checks.
  approve,

  /// Step-up — the attempt requires 3DS / analyst approval.
  stepUp,

  /// Decline — the attempt is rejected by policy.
  decline,
}

/// Whether the card was presented physically or not.
///
/// Card-not-present (CNP) attempts carry higher risk in `riskOf` and are
/// subject to additional blocklist checks.
enum Presentment {
  /// The card was physically present at the terminal.
  cardPresent,

  /// The card was not present (e-commerce, mail-order, phone).
  cardNotPresent,
}

/// An immutable snapshot of a single authorization attempt.
///
/// The `authId` is the correlation id used throughout the ledger. The
/// `mid` is the merchant id. `velocity` is a count of attempts in the
/// recent window. The `presentment` flag drives the CNP-specific rules
/// in `riskOf`.
final class AuthAttempt {
  /// The unique authorization id (e.g. `C-9182`, `2`, `SEED`).
  final String authId;

  /// The merchant id (e.g. `M-4419`).
  final String mid;

  /// The amount in cents (1..250_000).
  final int amountCents;

  /// The merchant category code (4 digits, e.g. `5411`, `7995`).
  final String mcc;

  /// The recent attempt velocity for this card.
  final int velocity;

  /// Whether the card was presented.
  final Presentment presentment;

  /// Creates an [AuthAttempt] with the given fields.
  const AuthAttempt({
    required this.authId,
    required this.mid,
    required this.amountCents,
    required this.mcc,
    required this.velocity,
    required this.presentment,
  });

  @override
  String toString() =>
      'AuthAttempt($authId, mid=$mid, $amountCents¢, mcc=$mcc, '
      'vel=$velocity, ${presentment.name})';
}

/// A single row in the append-only audit ledger.
///
/// The `kind` is a semantic tag: `DECLINE`, `STEP-UP`, `APPROVE`, `ACK`,
/// `HOLD`, `CAPTURE`, `VOID`, or `ISSUER`. The `authId` correlates the
/// row to an authorization. The `detail` is a human-readable summary.
final class LedgerEntry {
  /// The semantic tag of the entry (`DECLINE`, `HOLD`, etc.).
  final String kind;

  /// The authorization id the entry refers to.
  final String authId;

  /// A human-readable summary of the entry.
  final String detail;

  /// When the entry was committed.
  final DateTime at;

  /// Creates a [LedgerEntry] with the given fields.
  const LedgerEntry({
    required this.kind,
    required this.authId,
    required this.detail,
    required this.at,
  });

  @override
  String toString() => 'LedgerEntry($kind, $authId, "$detail")';
}

/// An open authorization hold on the available balance.
///
/// A hold reserves `amountCents` from `available` and moves it to `held`
/// until the transaction is captured or voided. `holdsMap` keys holds by
/// `authId` so settlement can find them later.
final class Hold {
  /// The authorization id the hold belongs to.
  final String authId;

  /// The reserved amount in cents (must be > 0).
  final int amountCents;

  /// The merchant id the hold belongs to.
  final String mid;

  /// Creates a [Hold] with the given fields.
  const Hold({
    required this.authId,
    required this.amountCents,
    required this.mid,
  });

  @override
  String toString() => 'Hold($authId, $amountCents¢, $mid)';
}

/// A single outbound job for the issuer pump.
///
/// The `decision` field tells the pump what kind of message to send.
/// Only `decline` jobs are produced by this demo (from the DECLINE
/// observer), but the shape supports any [Decision].
final class IssuerJob {
  /// The authorization id the job refers to.
  final String authId;

  /// The decision to deliver to the issuer.
  final Decision decision;

  /// Creates an [IssuerJob] with the given fields.
  const IssuerJob({required this.authId, required this.decision});

  @override
  String toString() => 'IssuerJob($authId, ${decision.name})';
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

// ─────────────────────────────────────────────────────────────────────────────
// HARNESS
// ─────────────────────────────────────────────────────────────────────────────

/// The card auth pipeline harness.
///
/// Owns every Cell and Tissue used by the demo:
/// - Flow: `amountIn`, `mccIn`, `velocityIn`, `presentIn`, `attemptIn`,
///   `ackIn`, plus the two gates (`declineCell`, `stepUpCell`).
/// - Tissue: `ledger`, `available`, `held`, `holdsMap`, `mccBlock`,
///   `issuerQ`.
///
/// ### When to use
/// Instantiate one harness, call [install], run the scenarios, then
/// [dispose]. Do not reuse a harness across runs — the state Cells and
/// Tissues carry history.
class CardAuthHarness {
  /// Creates an empty harness. Call [install] before driving any scenario.
  CardAuthHarness();

  /// The seed available balance in cents.
  static const int initialAvailableCents = 250000;

  /// The running total of captured cents (consumed sales).
  ///
  /// After every successful money method, the invariant
  /// `available + held + captured == 250000` must hold.
  int capturedCents = 0;

  // ---------------------------------------------------------------------------
  // Tissue — the books (audit trail + money).
  // ---------------------------------------------------------------------------

  /// The append-only audit ledger.
  ///
  /// The `_ledgerAppendOnly` TestTissue allows `add` / `addAll` and denies
  /// `remove` / `clear` / `[]=`. Every entry is emitted as an
  /// `ElementAdded<LedgerEntry>` pulse on the tissue.
  late final TissueList<LedgerEntry> ledger;

  /// The available balance in cents.
  ///
  /// The `_nonNegativeCents` TestTissue rejects any write that would make
  /// the balance negative. This is the primary NSF guard.
  late final TissueValue<int> available;

  /// The held balance in cents.
  ///
  /// The `_nonNegativeCents` TestTissue rejects any write that would make
  /// the held balance negative.
  late final TissueValue<int> held;

  /// The open authorization holds, keyed by `authId`.
  ///
  /// The `_holdRule` TestTissue requires each hold to have positive cents
  /// and a non-empty `authId`.
  late final TissueMap<String, Hold> holdsMap;

  /// The MCC blocklist — a runtime-mutable set of 4-digit codes.
  ///
  /// The `_mccBlockRule` TestTissue requires each member to be exactly 4
  /// digits. Ops can add a code at runtime (scenario 2) without redeploy.
  late final TissueSet<String> mccBlock;

  /// The bounded outbound queue for issuer I/O jobs (capacity 32).
  ///
  /// The `_issuerJobRule` TestTissue accepts every job. In this build the
  /// queue serves as the audit-side enqueue; the pump uses a plain Dart
  /// working list because `TissueQueue.removeFirst` does not drain.
  late final TissueQueue<IssuerJob> issuerQ;

  // ---------------------------------------------------------------------------
  // Issuer pump working list.
  // ---------------------------------------------------------------------------

  /// The pump's working list.
  ///
  /// The tissue queue above is the audit-side enqueue (`addLast` →
  /// `ElementAdded<IssuerJob>`). This list drives the pump's retry
  /// logic, because the tissue queue's `removeFirst` / `remove` do not
  /// drain the container in this build.
  final List<IssuerJob> _issuerWork = <IssuerJob>[];

  // ---------------------------------------------------------------------------
  // Flow — decision pipeline.
  // ---------------------------------------------------------------------------

  /// The amount ingress (1..250_000¢).
  ///
  /// The `_amountShape` TestCell rejects any value outside that range.
  /// `setAmount` returns `false` and does not update `_amount` when the
  /// rule rejects.
  late final IngressHandle<int> amountIn;

  /// The MCC ingress (4-digit string).
  ///
  /// The `_mccShapeRule` TestCell rejects any value that is not exactly
  /// 4 digits. `setMcc` returns `false` and does not update `_mcc` when
  /// the rule rejects.
  late final IngressHandle<String> mccIn;

  /// The velocity ingress (used only as a cache — no TestCell).
  late final IngressHandle<int> velocityIn;

  /// The presentment ingress (used only as a cache — no TestCell).
  late final IngressHandle<Presentment> presentIn;

  /// The snapshot bus ingress — publishes a complete [AuthAttempt].
  ///
  /// The two gates (`declineCell`, `stepUpCell`) both subscribe to this
  /// cell via `toHandle(source: attemptIn.cell)`.
  late final IngressHandle<AuthAttempt> attemptIn;

  /// The ACK ingress (3DS / analyst id).
  ///
  /// An ACK resets both Distinct latches and appends an `ACK` row to the
  /// ledger. It never rebuilds the graph.
  late final IngressHandle<String> ackIn;

  // ---------------------------------------------------------------------------
  // Flow gates.
  // ---------------------------------------------------------------------------

  /// The DECLINE gate handle (kept for symmetry — the cell is what we use).
  FlowHandle<Pulse<dynamic>>? declineHandle;

  /// The STEP-UP gate handle (kept for symmetry — the cell is what we use).
  FlowHandle<Pulse<dynamic>>? stepUpHandle;

  /// The DECLINE gate cell — emits only when `riskOf` returns `decline`
  /// AND the Distinct latch has not seen that decision before.
  late final Cell declineCell;

  /// The STEP-UP gate cell — emits only when `riskOf` returns `stepUp`
  /// AND the Distinct latch has not seen that decision before.
  late final Cell stepUpCell;

  // ---------------------------------------------------------------------------
  // Dart-side ingress cache.
  // ---------------------------------------------------------------------------

  /// The last accepted amount in cents. Never the source of truth for
  /// money — the source of truth is `available` + `held` + `captured`.
  int _amount = 0;

  /// The last accepted MCC.
  String _mcc = '';

  /// The last accepted velocity.
  int _velocity = 0;

  /// The last accepted presentment.
  Presentment _present = Presentment.cardPresent;

  // ---------------------------------------------------------------------------
  // Counters for the trailer.
  // ---------------------------------------------------------------------------

  /// Number of successful `publishAttempt` calls (post-ingress).
  int attempts = 0;

  /// Number of DECLINE pulses that made it past the Distinct latch.
  int declines = 0;

  /// Number of STEP-UP pulses that made it past the Distinct latch.
  int stepUps = 0;

  /// Number of issuer pump attempts (including retries).
  int issuerAttempts = 0;

  // ---------------------------------------------------------------------------
  // Issuer failure injection.
  // ---------------------------------------------------------------------------

  /// Whether the pump should fail on the next attempt (fail-once).
  /// Reset to `false` after the injected failure fires.
  bool issuerFailOnce = false;

  /// Whether the injected failure has already fired.
  bool _issuerHasFailed = false;

  // ---------------------------------------------------------------------------
  // Distinct latches.
  // ---------------------------------------------------------------------------

  /// The last DECLINE decision seen by the Distinct latch. `null` means
  /// the latch is reset.
  Decision? _lastDecline;

  /// The last STEP-UP decision seen by the Distinct latch. `null` means
  /// the latch is reset.
  Decision? _lastStepUp;

  /// The last attempt published — captured for the DECLINE / STEP-UP
  /// observers to correlate with the ledger row.
  AuthAttempt? _currentAttempt;

  /// Observers to stop before program exit.
  final List<EgressHandle> _observers = [];

  // ---------------------------------------------------------------------------
  // TestTissue rules — ONLY used on Tissue constructors.
  // ---------------------------------------------------------------------------

  /// Append-only ledger rule.
  ///
  /// Allows `add` / `addAll`; denies `remove` / `clear` / `[]=`. The
  /// `arguments` parameter carries the mutation action when the rule is
  /// invoked from the action path.
  static final TestTissue<LedgerEntry, TissueList<LedgerEntry>>
      _ledgerAppendOnly = TestTissue<LedgerEntry, TissueList<LedgerEntry>>(
    (value, {host, arguments, user}) {
      if (arguments is Function) {
        final src = arguments.toString();
        if (src.contains('remove') ||
            src.contains('clear') ||
            src.contains('[]=')) {
          return false;
        }
      }
      return true;
    },
  );

  /// Non-negative integer cents rule (used on `available` and `held`).
  static final TestTissue<int, TissueValue<int>> _nonNegativeCents =
      TestTissue<int, TissueValue<int>>(
    (value, {host, arguments, user}) {
      if (value is int) return value >= 0;
      return true;
    },
  );

  /// Hold rule: positive cents and non-empty auth id.
  static final TestTissue<Hold, TissueMap<String, Hold>> _holdRule =
      TestTissue<Hold, TissueMap<String, Hold>>(
    (value, {host, arguments, user}) {
      if (value is Hold) {
        return value.amountCents > 0 && value.authId.isNotEmpty;
      }
      return true;
    },
  );

  /// MCC blocklist member rule: exactly 4 digits.
  static final TestTissue<String, TissueSet<String>> _mccBlockRule =
      TestTissue<String, TissueSet<String>>(
    (value, {host, arguments, user}) {
      if (value is String) {
        return value.length == 4 && int.tryParse(value) != null;
      }
      return true;
    },
  );

  /// Issuer job rule — accepts every job.
  static final TestTissue<IssuerJob, TissueQueue<IssuerJob>> _issuerJobRule =
      TestTissue<IssuerJob, TissueQueue<IssuerJob>>(
    (value, {host, arguments, user}) => true,
  );

  // ---------------------------------------------------------------------------
  // TestCell rules — ONLY used on Cell.ingress.
  // ---------------------------------------------------------------------------

  /// Amount shape: 1..250_000 inclusive.
  ///
  /// The ingress wraps the input in a [Pulse], so the rule unwraps
  /// `Pulse.payload` before applying the range check.
  static final TestCell<Cell> _amountShape = TestCell<Cell>(
    (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! int) return false;
      return v >= 1 && v <= 250000;
    },
  );

  /// MCC shape: exactly 4 digits.
  ///
  /// The ingress wraps the input in a [Pulse], so the rule unwraps
  /// `Pulse.payload` before applying the shape check.
  static final TestCell<Cell> _mccShapeRule = TestCell<Cell>(
    (value, {host, arguments, user}) {
      final v = value is Pulse ? value.payload : value;
      if (v is! String) return false;
      return v.length == 4 && int.tryParse(v) != null;
    },
  );

  // ---------------------------------------------------------------------------
  // install
  // ---------------------------------------------------------------------------

  /// Builds every Cell and Tissue, wires the gates, and installs the
  /// observers.
  ///
  /// ### Execution Order is Critical!
  /// This must run once, before any scenario drives ingress.
  ///
  /// ### Steps
  /// 1. Build the six Tissue collections with their TestTissue rules.
  /// 2. Build the six Flow ingress handles with their TestCell rules.
  /// 3. Install the two gates (DECLINE and STEP-UP).
  /// 4. Attach the observers.
  Future<void> install() async {
    // --- Tissue -------------------------------------------------------------
    ledger = TissueList<LedgerEntry>(testRule: _ledgerAppendOnly);

    available = TissueValue<int>(
      initialAvailableCents,
      testRule: _nonNegativeCents,
    );

    held = TissueValue<int>(0, testRule: _nonNegativeCents);

    holdsMap = TissueMap<String, Hold>(
      properties: TissueMapNucleus<String, Hold>(testRule: _holdRule),
    );

    mccBlock = TissueSet<String>(<String>[], testRule: _mccBlockRule);

    issuerQ = TissueQueue<IssuerJob>(
      capacity: 32,
      testRule: _issuerJobRule,
    );

    // --- Flow ingress -------------------------------------------------------
    amountIn = Cell.ingress<int>(testRule: _amountShape);
    mccIn = Cell.ingress<String>(testRule: _mccShapeRule);
    velocityIn = Cell.ingress<int>();
    presentIn = Cell.ingress<Presentment>();
    attemptIn = Cell.ingress<AuthAttempt>();
    ackIn = Cell.ingress<String>();

    // --- Gates --------------------------------------------------------------
    installGates();

    // --- Flow observers -----------------------------------------------------
    //
    // Trace prints for Tissue writes live inside the writers (see
    // placeHold / capture / voidHold / _driveIssuer and the DECLINE /
    // STEP-UP / ACK observers below), because Cell.observe on Tissue
    // cells does not fire effect callbacks in this build.

    // --- DECLINE observer ---------------------------------------------------
    //
    // On a DECLINE pulse, this observer:
    //   1. Increments the decline counter.
    //   2. Appends a DECLINE row to the ledger.
    //   3. Enqueues an IssuerJob on the tissue queue (audit) AND on the
    //      pump's working list (delivery).
    //   4. Drains the pump immediately (single-shot).
    //
    // It never rebuilds the graph. ACK is the only thing that resets the
    // Distinct latch.
    _observers.add(Cell.observe(
      source: declineCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Decision.decline) {
          declines++;
          final a = _currentAttempt;
          if (a != null) {
            ledger.add(LedgerEntry(
              kind: 'DECLINE',
              authId: a.authId,
              detail: 'mcc=${a.mcc} amount=${a.amountCents}¢',
              at: DateTime.now(),
            ));
            print('[ledger] DECLINE ${a.authId} — '
                'mcc=${a.mcc} amount=${a.amountCents}¢');

            final job = IssuerJob(
              authId: a.authId,
              decision: Decision.decline,
            );
            issuerQ.addLast(job);
            print('[issuerQ] enqueued $job');

            _issuerWork.add(job);
            _driveIssuer();
          }
        }
      },
    ));

    // --- STEP-UP observer ---------------------------------------------------
    _observers.add(Cell.observe(
      source: stepUpCell,
      effect: (Pulse pulse) {
        if (pulse.payload == Decision.stepUp) {
          stepUps++;
          final a = _currentAttempt;
          if (a != null) {
            ledger.add(LedgerEntry(
              kind: 'STEP-UP',
              authId: a.authId,
              detail: 'amount=${a.amountCents}¢ CNP',
              at: DateTime.now(),
            ));
            print('[ledger] STEP-UP ${a.authId} — '
                'amount=${a.amountCents}¢ CNP');
          }
        }
      },
    ));

    // --- ACK observer -------------------------------------------------------
    //
    // On an ACK pulse, this observer:
    //   1. Resets both Distinct latches.
    //   2. Appends an ACK row to the ledger.
    //
    // It never calls `toHandle` again — the gates stay as they are.
    _observers.add(Cell.observe(
      source: ackIn.cell,
      effect: (Pulse pulse) {
        final who = pulse.payload;
        resetDistinct();
        final authId = (who is String && who.isNotEmpty) ? who : 'ALL';
        ledger.add(LedgerEntry(
          kind: 'ACK',
          authId: authId,
          detail: 'distinct cleared',
          at: DateTime.now(),
        ));
        print('[ledger] ACK $authId — distinct cleared');
      },
    ));
  }

  // ---------------------------------------------------------------------------
  // installGates
  // ---------------------------------------------------------------------------

  /// Builds the two gates.
  ///
  /// ### Execution Order is Critical!
  /// Runs exactly once from [install]. ACK does NOT call this again.
  ///
  /// Each gate is composed as:
  ///   MapValue\<AuthAttempt, Decision>
  ///     + Distinct (custom FlowInstruction)
  ///     + Filter\<Decision>
  ///
  /// Both gates call the same `riskOf` policy. The Distinct latch is
  /// per-gate so a fresh DECLINE (after an ACK) can fire even if the
  /// previous DECLINE had the same value.
  void installGates() {
    // --- DECLINE gate: MapValue → Distinct → Filter(decline) ---------------
    final declineFlow = MapValue<AuthAttempt, Decision>(
          (a) => riskOf(a, mccBlock),
        ) +
        _distinctDecline() +
        Filter<Decision>((d) => d == Decision.decline);

    declineHandle = declineFlow.toHandle(source: attemptIn.cell);
    declineCell = declineHandle!.cell;

    // --- STEP-UP gate: MapValue → Distinct → Filter(stepUp) ----------------
    final stepUpFlow = MapValue<AuthAttempt, Decision>(
          (a) => riskOf(a, mccBlock),
        ) +
        _distinctStepUp() +
        Filter<Decision>((d) => d == Decision.stepUp);

    stepUpHandle = stepUpFlow.toHandle(source: attemptIn.cell);
    stepUpCell = stepUpHandle!.cell;
  }

  // ---------------------------------------------------------------------------
  // Issuer pump
  // ---------------------------------------------------------------------------

  /// Drains the pump's working list with a single-shot retry.
  ///
  /// ### Why the tissue queue is not used directly
  /// This build's `TissueQueue.removeFirst` / `remove` operations do not
  /// drain the container. The tissue queue stays as the audit record
  /// (`addLast` → `ElementAdded<IssuerJob>`), and the pump runs on the
  /// plain Dart `_issuerWork` list.
  ///
  /// ### Failure semantics
  /// If [issuerFailOnce] is set and this is the first attempt, the mock
  /// throws. The pump catches it and retries once. The retry counter
  /// [issuerAttempts] increments for both attempts, exposing the retry
  /// to the trailer.
  Future<void> _driveIssuer() async {
    if (_issuerWork.isEmpty) return;
    final job = _issuerWork.removeAt(0);

    try {
      issuerAttempts++;
      if (issuerFailOnce && !_issuerHasFailed) {
        _issuerHasFailed = true;
        throw StateError('issuer transient');
      }
      ledger.add(LedgerEntry(
        kind: 'ISSUER',
        authId: job.authId,
        detail: job.decision.name,
        at: DateTime.now(),
      ));
      print('[ledger] ISSUER ${job.authId} — ${job.decision.name}');
    } catch (_) {
      try {
        issuerAttempts++;
        ledger.add(LedgerEntry(
          kind: 'ISSUER',
          authId: job.authId,
          detail: '${job.decision.name} (retry)',
          at: DateTime.now(),
        ));
        print('[ledger] ISSUER ${job.authId} — '
            '${job.decision.name} (retry)');
      } catch (_) {
        // give up
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Flow instructions (Distinct)
  // ---------------------------------------------------------------------------

  /// The DECLINE Distinct latch.
  ///
  /// Returns `null` (signal terminated) if the incoming decision matches
  /// the last one. Otherwise updates the latch and passes the pulse on.
  /// ACK zeroes the latch.
  FlowInstruction _distinctDecline() {
    return FlowInstruction((pulse, {cell, user}) {
      final d = pulse.payload;
      if (_lastDecline == d) return null;
      _lastDecline = d;
      return pulse;
    });
  }

  /// The STEP-UP Distinct latch.
  ///
  /// Returns `null` (signal terminated) if the incoming decision matches
  /// the last one. Otherwise updates the latch and passes the pulse on.
  /// ACK zeroes the latch.
  FlowInstruction _distinctStepUp() {
    return FlowInstruction((pulse, {cell, user}) {
      final d = pulse.payload;
      if (_lastStepUp == d) return null;
      _lastStepUp = d;
      return pulse;
    });
  }

  /// Resets both Distinct latches.
  ///
  /// Called by the ACK observer. The next DECLINE / STEP-UP decision will
  /// pass through regardless of its value.
  void resetDistinct() {
    _lastDecline = null;
    _lastStepUp = null;
  }

  // ---------------------------------------------------------------------------
  // riskOf — pure policy. Reads TissueSet. Never touches money.
  // ---------------------------------------------------------------------------

  /// Evaluates the risk of an [AuthAttempt] against the [block] list.
  ///
  /// ### Rules
  /// | Condition | Decision |
  /// |---|---|
  /// | `a.mcc` in `block` AND CNP | `decline` |
  /// | `a.velocity >= 5` | `decline` |
  /// | `a.amountCents >= 50_000` AND CNP | `stepUp` |
  /// | `a.amountCents >= 100_000` | `stepUp` |
  /// | else | `approve` |
  ///
  /// ### Purity
  /// This function does no I/O, awaits nothing, and touches no money.
  /// It reads the blocklist and nothing else.
  static Decision riskOf(AuthAttempt a, TissueSet<String> block) {
    final blocked = block.contains(a.mcc);
    if (blocked && a.presentment == Presentment.cardNotPresent) {
      return Decision.decline;
    }
    if (a.velocity >= 5) return Decision.decline;
    if (a.amountCents >= 50000 && a.presentment == Presentment.cardNotPresent) {
      return Decision.stepUp;
    }
    if (a.amountCents >= 100000) return Decision.stepUp;
    return Decision.approve;
  }

  // ---------------------------------------------------------------------------
  // Bus — setters and publishAttempt
  // ---------------------------------------------------------------------------

  /// Sets the amount cache. Returns `false` and does not update `_amount`
  /// if the ingress TestCell rejects.
  bool setAmount(int cents) {
    final accepted = amountIn.emit(cents);
    if (accepted) _amount = cents;
    return accepted;
  }

  /// Sets the MCC cache. Returns `false` and does not update `_mcc` if
  /// the ingress TestCell rejects.
  bool setMcc(String mcc) {
    final accepted = mccIn.emit(mcc);
    if (accepted) _mcc = mcc;
    return accepted;
  }

  /// Sets the velocity cache (no TestCell).
  bool setVelocity(int v) {
    _velocity = v;
    return true;
  }

  /// Sets the presentment cache (no TestCell).
  bool setPresent(Presentment p) {
    _present = p;
    return true;
  }

  /// Publishes a complete [AuthAttempt] onto the snapshot bus.
  ///
  /// Returns `false` (without publishing) if either the amount or MCC
  /// cache fails the ingress guard.
  Future<bool> publishAttempt({String? authId}) async {
    if (!_amountValid(_amount)) {
      print('[ingress] amount $_amount rejected by TestCell');
      return false;
    }
    if (!_mccValid(_mcc)) {
      print('[ingress] mcc "$_mcc" rejected by TestCell');
      return false;
    }

    final a = AuthAttempt(
      authId: authId ?? 'A-${attempts + 1}',
      mid: 'M-4419',
      amountCents: _amount,
      mcc: _mcc,
      velocity: _velocity,
      presentment: _present,
    );
    _currentAttempt = a;
    attempts++;
    attemptIn.emit(a);
    await Future.delayed(Duration.zero);
    return true;
  }

  /// Static validator matching `_amountShape`.
  static bool _amountValid(int v) => v >= 1 && v <= 250000;

  /// Static validator matching `_mccShapeRule`.
  static bool _mccValid(String s) => s.length == 4 && int.tryParse(s) != null;

  /// Publishes an ACK onto the ACK ingress.
  Future<bool> ack(String who) async {
    ackIn.emit(who);
    await Future.delayed(Duration.zero);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Money — TissueValue + TissueMap. v1: three writes, one Dart Future.
  // ---------------------------------------------------------------------------

  /// Attempts to place a hold.
  ///
  /// ### v1 write protocol
  /// 1. Pre-check `available` for NSF.
  /// 2. Write `holdsMap[authId]`.
  /// 3. Write `available` (subtract cents).
  /// 4. Write `held` (add cents).
  /// 5. Append `HOLD` to the ledger.
  ///
  /// If step 3 or 4 rejects, the prior writes are compensated and the
  /// method returns `false` without leaving a partial state.
  ///
  /// ### Invariant
  /// After a successful call:
  ///   `available + held + captured == 250000`.
  bool placeHold(String authId, int cents, String mid) {
    final before = available.value ?? 0;
    if (before < cents) return false;
    holdsMap[authId] = Hold(authId: authId, amountCents: cents, mid: mid);
    final okAvail = available.set(before - cents);
    if (!okAvail) {
      holdsMap.remove(authId);
      return false;
    }
    print('[available] $before → ${before - cents}');

    final heldBefore = held.value ?? 0;
    final okHeld = held.set(heldBefore + cents);
    if (!okHeld) {
      available.set(before);
      holdsMap.remove(authId);
      return false;
    }
    print('[held] $heldBefore → ${heldBefore + cents}');

    ledger.add(LedgerEntry(
      kind: 'HOLD',
      authId: authId,
      detail: '$cents¢',
      at: DateTime.now(),
    ));
    print('[ledger] HOLD $authId — $cents¢');
    return true;
  }

  /// Captures an existing hold.
  ///
  /// ### v1 write protocol
  /// 1. Look up `holdsMap[authId]`.
  /// 2. Remove the map row.
  /// 3. Subtract from `held`.
  /// 4. Add to `capturedCents`.
  /// 5. Append `CAPTURE` to the ledger.
  ///
  /// `available` is NOT touched (the cents were already moved to `held`
  /// at hold time).
  bool capture(String authId) {
    final h = holdsMap[authId];
    if (h == null) return false;
    holdsMap.remove(authId);

    final heldBefore = held.value ?? 0;
    held.set(heldBefore - h.amountCents);
    print('[held] $heldBefore → ${heldBefore - h.amountCents}');

    capturedCents += h.amountCents;

    ledger.add(LedgerEntry(
      kind: 'CAPTURE',
      authId: authId,
      detail: '${h.amountCents}¢',
      at: DateTime.now(),
    ));
    print('[ledger] CAPTURE $authId — ${h.amountCents}¢');
    return true;
  }

  /// Voids an existing hold.
  ///
  /// ### v1 write protocol
  /// 1. Look up `holdsMap[authId]`.
  /// 2. Remove the map row.
  /// 3. Subtract from `held`.
  /// 4. Add back to `available`.
  /// 5. Append `VOID` to the ledger.
  ///
  /// `capturedCents` is unchanged — the sale was never captured.
  bool voidHold(String authId) {
    final h = holdsMap[authId];
    if (h == null) return false;
    holdsMap.remove(authId);

    final heldBefore = held.value ?? 0;
    held.set(heldBefore - h.amountCents);
    print('[held] $heldBefore → ${heldBefore - h.amountCents}');

    final availBefore = available.value ?? 0;
    available.set(availBefore + h.amountCents);
    print('[available] $availBefore → ${availBefore + h.amountCents}');

    ledger.add(LedgerEntry(
      kind: 'VOID',
      authId: authId,
      detail: '${h.amountCents}¢',
      at: DateTime.now(),
    ));
    print('[ledger] VOID $authId — ${h.amountCents}¢');
    return true;
  }

  /// The number of open holds currently in `holdsMap`.
  int get openHoldsCount => holdsMap.length;

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

/// Main entry point for the card auth pipeline demo.
///
/// ### Execution Order is Critical!
/// 1. Build the harness via [CardAuthHarness.install].
/// 2. Seed observers with the initial state.
/// 3. Run scenarios 1–13 in order.
/// 4. Print the trailer and dispose.
Future<void> main() async {
  print(
      '========================================================================');
  print(' card-auth-pipeline(tissue)-Demo.dart');
  print(' Flow owns the decision. Tissue owns the books.');
  print(
      '========================================================================');

  final h = CardAuthHarness();
  await h.install();

  // -------------------------------------------------------------------------
  // Seed — 7200 / 5411 / present / vel 0
  //
  // Demonstrates: the bus + Filter. `riskOf` returns `approve`, which is
  // dropped by both gates. The ledger stays empty (initial Tissue population
  // is silent).
  // -------------------------------------------------------------------------
  _section('Seed', '7200 / 5411 / present / vel 0');
  h.setAmount(7200);
  h.setMcc('5411');
  h.setVelocity(0);
  h.setPresent(Presentment.cardPresent);
  await h.publishAttempt(authId: 'SEED');
  print('  ledger.isEmpty=${h.ledger.isEmpty}');

  // -------------------------------------------------------------------------
  // 1 — repeat 7200 / 5411
  //
  // Demonstrates: Distinct on `approve`. No new DECLINE because the
  // approve decision never reaches the DECLINE gate in the first place.
  // -------------------------------------------------------------------------
  _section('1', 'repeat 7200 / 5411');
  final d1 = h.declines;
  await h.publishAttempt(authId: '1');
  print('  new declines: ${h.declines - d1}');

  // -------------------------------------------------------------------------
  // 2 — ops adds 7995, then CNP 7995
  //
  // Demonstrates: TissueSet feeds `riskOf`; the DECLINE pulse is the
  // audit trail. The blocklist is mutated at runtime; the next CNP
  // attempt with MCC 7995 is declined.
  // -------------------------------------------------------------------------
  _section('2', "mccBlock.add('7995'), then MCC 7995 CNP 7200");
  h.mccBlock.add('7995');
  print('[mccBlock] +7995');
  h.setAmount(7200);
  h.setMcc('7995');
  h.setVelocity(0);
  h.setPresent(Presentment.cardNotPresent);
  final d2 = h.declines;
  await h.publishAttempt(authId: '2');
  print('  new declines: ${h.declines - d2}');
  print('  issuerQ.length=${h.issuerQ.length}');

  // -------------------------------------------------------------------------
  // 3 — grocery+present then 7995 CNP again
  //
  // Demonstrates: Distinct `none` → `decline`. The first attempt is
  // approve (so the DECLINE gate sees `approve`, which resets the latch).
  // The second attempt is decline (so the DECLINE gate fires).
  // -------------------------------------------------------------------------
  _section('3', 'grocery+present then 7995 CNP again');
  h.setAmount(7200);
  h.setMcc('5411');
  h.setPresent(Presentment.cardPresent);
  await h.publishAttempt(authId: '3a');
  h.setMcc('7995');
  h.setPresent(Presentment.cardNotPresent);
  final d3 = h.declines;
  await h.publishAttempt(authId: '3b');
  print('  new declines: ${h.declines - d3}');

  // -------------------------------------------------------------------------
  // 4 — 7995 again (should not re-decline)
  //
  // Demonstrates: Distinct holds. The DECLINE latch is still at
  // `decline`, so the duplicate is suppressed.
  // -------------------------------------------------------------------------
  _section('4', '7995 again (should not re-decline)');
  final d4 = h.declines;
  await h.publishAttempt(authId: '4');
  print('  new declines: ${h.declines - d4}');

  // -------------------------------------------------------------------------
  // 5 — 200000 on 7995
  //
  // Demonstrates: Distinct still holds even when the amount changes
  // (because the decision is still `decline`).
  // -------------------------------------------------------------------------
  _section('5', '200000 on 7995');
  h.setAmount(200000);
  final d5 = h.declines;
  await h.publishAttempt(authId: '5');
  print('  new declines: ${h.declines - d5}');

  // -------------------------------------------------------------------------
  // STEP-UP — 60000 CNP 5411
  //
  // Demonstrates: the second Receptor fires independently. The blocklist
  // does not apply to 5411; the amount + CNP triggers STEP-UP.
  // -------------------------------------------------------------------------
  _section('STEP-UP', '60000 CNP 5411');
  h.setAmount(60000);
  h.setMcc('5411');
  h.setVelocity(0);
  h.setPresent(Presentment.cardNotPresent);
  final s0 = h.stepUps;
  await h.publishAttempt(authId: 'SU-1');
  print('  new step-ups: ${h.stepUps - s0}');

  // -------------------------------------------------------------------------
  // 6 — 7200 / 5411 present then ACK
  //
  // Demonstrates: ACK clears the Distinct latches. No money moves yet.
  // -------------------------------------------------------------------------
  _section('6', '7200 / 5411 present then ACK');
  h.setAmount(7200);
  h.setMcc('5411');
  h.setPresent(Presentment.cardPresent);
  await h.publishAttempt(authId: '6');
  await h.ack('6');
  print('  available=${h.available.value} held=${h.held.value}');

  // -------------------------------------------------------------------------
  // 7 — 7995 CNP 7200
  //
  // Demonstrates: after ACK, the Distinct latch is reset, so the same
  // decline decision fires again.
  // -------------------------------------------------------------------------
  _section('7', '7995 CNP 7200');
  h.setMcc('7995');
  h.setPresent(Presentment.cardNotPresent);
  final d7 = h.declines;
  await h.publishAttempt(authId: '7');
  print('  new declines: ${h.declines - d7}');

  // -------------------------------------------------------------------------
  // 8 — amount -1, MCC "99" (TestCell)
  //
  // Demonstrates: Cell ingress ≠ Tissue. Both TestCells reject; the
  // attempt is never published; the ledger is untouched.
  // -------------------------------------------------------------------------
  _section('8', 'amount -1, MCC "99"');
  final l8 = h.ledger.length;
  final rejectedAmount = h.setAmount(-1);
  final rejectedMcc = h.setMcc('99');
  print('  amount -1 accepted=$rejectedAmount');
  print('  mcc "99" accepted=$rejectedMcc');
  print('  ledger grew: ${h.ledger.length - l8}');

  // -------------------------------------------------------------------------
  // 9 — ACK, recover, 7995, issuer fail-once
  //
  // Demonstrates: the queue + retry. The first issuer attempt fails;
  // the pump retries and succeeds. The DECLINE pulse count remains 1.
  // -------------------------------------------------------------------------
  _section('9', 'ACK, recover, 7995, issuer fail-once');
  await h.ack('9-pre');
  h.setMcc('5411');
  h.setPresent(Presentment.cardPresent);
  h.setAmount(7200);
  await h.publishAttempt(authId: '9a');
  h.setMcc('7995');
  h.setPresent(Presentment.cardNotPresent);
  final d9 = h.declines;
  h.issuerFailOnce = true;
  await h.publishAttempt(authId: '9b');
  print('  new declines: ${h.declines - d9}');
  print('  issuerAttempts=${h.issuerAttempts}');

  // -------------------------------------------------------------------------
  // 10 — STEP-UP 60000, ACK as approve, placeHold
  //
  // Demonstrates: TissueValue + TissueMap. The hold moves 60000 from
  // available to held and appends a HOLD row to the ledger.
  // -------------------------------------------------------------------------
  _section('10', 'STEP-UP 60000, ACK as approve, placeHold');
  h.setAmount(60000);
  h.setMcc('5411');
  h.setVelocity(0);
  h.setPresent(Presentment.cardNotPresent);
  await h.publishAttempt(authId: 'H-1');
  await h.ack('H-1');
  final ok10 = h.placeHold('H-1', 60000, 'M-4419');
  print('  placeHold ok=$ok10');
  print('  available=${h.available.value} held=${h.held.value} '
      'openHolds=${h.openHoldsCount}');

  // -------------------------------------------------------------------------
  // 11 — placeHold(200000) while 10 is open (NSF)
  //
  // Demonstrates: the non-negative TestTissue on `available` rejects the
  // hold. No map row is left behind.
  // -------------------------------------------------------------------------
  _section('11', 'placeHold(200000) while 10 is open');
  final open11 = h.openHoldsCount;
  final ok11 = h.placeHold('H-2', 200000, 'M-4419');
  print('  placeHold ok=$ok11 '
      'openHolds stayed=${h.openHoldsCount == open11}');

  // -------------------------------------------------------------------------
  // 12 — capture the 60000 hold
  //
  // Demonstrates: capture ≠ second debit. The cents move from `held` to
  // `capturedCents`; `available` stays put.
  // -------------------------------------------------------------------------
  _section('12', 'capture the 60000 hold');
  final ok12 = h.capture('H-1');
  print('  capture ok=$ok12');
  print('  available=${h.available.value} held=${h.held.value} '
      'openHolds=${h.openHoldsCount} captured=${h.capturedCents}');

  // -------------------------------------------------------------------------
  // 13 — new 10000 hold then voidHold
  //
  // Demonstrates: compensate on Tissue. The void returns the cents from
  // `held` back to `available`.
  // -------------------------------------------------------------------------
  _section('13', 'new 10000 hold then voidHold');
  final ok13a = h.placeHold('H-3', 10000, 'M-4419');
  final ok13b = h.voidHold('H-3');
  print('  placeHold ok=$ok13a voidHold ok=$ok13b');
  print('  available=${h.available.value} held=${h.held.value} '
      'openHolds=${h.openHoldsCount}');

  // -------------------------------------------------------------------------
  // COMPLY — auditor.add(...) blocked; length == ledger.length
  //
  // Demonstrates: Deputy / unmodifiable is live. The read-only view
  // silently swallows writes in this build, so blocked is detected by
  // comparing the ledger length before and after the attempted write.
  // -------------------------------------------------------------------------
  _section('COMPLY', 'auditor.add(...) blocked; length == ledger.length');
  final auditor = h.ledger.unmodifiable;
  final ledgerBefore = h.ledger.length;
  var blocked = false;
  try {
    auditor.add(LedgerEntry(
      kind: 'HACK',
      authId: 'X',
      detail: 'attempted by auditor',
      at: DateTime.now(),
    ));
    blocked = h.ledger.length == ledgerBefore;
  } catch (_) {
    blocked = true;
  }
  print('  auditor.add blocked=$blocked');
  print('  auditor.length=${auditor.length} ledger.length=${h.ledger.length}');

  // -------------------------------------------------------------------------
  // Trailer
  //
  // Confirms the money invariant and the read-only deputy's shared
  // storage.
  // -------------------------------------------------------------------------
  print('');
  print(
      '------------------------------------------------------------------------');
  print('attempts=${h.attempts} declines=${h.declines} '
      'stepUps=${h.stepUps} ledger=${h.ledger.length} '
      'issuerAttempts=${h.issuerAttempts}');
  print('available=${h.available.value} held=${h.held.value} '
      'openHolds=${h.openHoldsCount} captured=${h.capturedCents}');
  print('auditorLength=${auditor.length} (same as ledger)');

  final invariant =
      (h.available.value ?? 0) + (h.held.value ?? 0) + h.capturedCents;
  print('invariant available+held+captured = $invariant (expected 250000)');
  print(
      '------------------------------------------------------------------------');

  h.dispose();
}
