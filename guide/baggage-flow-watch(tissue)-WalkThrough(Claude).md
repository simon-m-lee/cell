# Baggage Flow Watch — Design Walkthrough

**Companion to:** `baggage-flow-watch(tissue)-Demo.dart`
**Source requirement:** `airport_baggage_handling-BRD.md` — *Business Requirements — Airport Baggage Handling*, v1.0, 2026-09-16
**Framework:** [Mitosis / Cell Framework](https://github.com/simon-m-lee/cell) — `cell` + `cell_flow` + `cell_tissue`, `1.0.0-rc.5/6`

---

## 1. Why this framework fits this requirement

The BRD's problem statement is, structurally, a causal-integrity problem before it is a UI problem:

> *"The duty manager learns about a problem when the airline calls... By then, the bag is often already missing its flight."* (§3.2)
> *"Every alert must be acknowledged or dismissed within 15 minutes."* (BR-03)
> *"Every alert acknowledgement shall record who, when, and what action was taken."* (NFR-05)
> *"The system shall retain incident records for 24 months."* (DR-04)

That is exactly the class of system Mitosis is built for — its own README names *"safety-critical telemetry — alarm pipelines, sensor fusion, escalation logic"* as a target domain, and ships a worked example (`grid-demand-response(tissue)-Demo.dart`: shed interruptible load, protect hospital feeders, restore after a shift-lead ACK) that is structurally the same problem as *"stop a belt, alert a supervisor, restore after acknowledgement."* This design borrows that demo's shape deliberately rather than inventing a new one, because the requirements line up almost field-for-field:

| Grid demand-response | Baggage Flow Watch |
|---|---|
| Frequency sags below a threshold | Time-to-close-out falls below the minimum connection time |
| A feeder stalls (RTU stops responding) | A belt/sorter/carousel stops for >60s |
| Protect hospital feeders from shed | Protect diplomatic/hazardous bags from reroute (BR-01) |
| Shift-lead ACK restores reserve | Supervisor/duty-manager ACK closes an incident (FR-07) |
| Reliability-council append-only log | Airline/Safety & Compliance append-only audit log (AR-02) |

The core architectural promise Mitosis makes — *"you can always ask who, why, under which authority, and what happened downstream"* — is a direct answer to BR-03, NFR-05, and DR-04.

---

## 2. The three layers, mapped to this system

```
┌──────────────────────────────────────────────────────────────────────┐
│  TISSUE — the ops books                                              │
│  events (append-only log)   bags (current position/risk)             │
│  flights (AODB projection)  positionHistory (bounded ring buffer)    │
│  incidents (open/ack/escalated)   protectedBags   alertQ (dispatch)  │
├──────────────────────────────────────────────────────────────────────┤
│  FLOW — the decision                                                 │
│  riskOf: BagScan → RiskLevel        (FR-02, FR-03, BR-02)            │
│  MapValue + Filter(atRisk) → atRiskCell                              │
│  device-stall clock (harness-owned Timer, see §5)                    │
├──────────────────────────────────────────────────────────────────────┤
│  CELL — ingress & integrity                                          │
│  scanIn / deviceIn / flightIn — TestCell shape guards                │
│  (DR-06: reject a bag record with a missing tag or flight number)    │
└──────────────────────────────────────────────────────────────────────┘
        ▲                                                              ▲
        └───── Flow decides. Tissue records. Observers are the glue ───┘
```

**Flow decides:** `riskOf` is a pure function of a `BagScan` against the current `FlightRecord` — no Tissue in scope, unit-testable with a bare object, exactly as the upstream README's "Flow + Tissue seam" pattern requires.

**Tissue records:** every state change — a scan landing, a stall confirmed, an alert dispatched, an acknowledgement — is a governed mutation on a `TissueList`/`TissueMap`/`TissueQueue`/`TissueSet`, validated by a `TestTissue` rule before it commits.

**The observer is the only glue:** `Cell.observe(source: atRiskCell, effect: ...)` is the single wire between the policy and the books. Nothing inside `riskOf` writes to `bags` or `incidents`; nothing inside the Tissue write protocol re-evaluates risk.

---

## 3. Requirement traceability

### 3.1 Functional requirements (§7.1)

| ID | Requirement | Component |
|---|---|---|
| FR-01 | Real-time bag position, check-in → aircraft side | `BagScan` ingress → `ingestScan` → `bags` (current) + `positionHistory` (trail) |
| FR-02 | Time remaining until baggage close-out | `riskOf` reads `FlightRecord.closeOutTime` against `scan.at` |
| FR-03 | Flag "at risk" below minimum connection time | `riskOf`: `remaining < flight.minConnection` |
| FR-04 | Duty manager sees all at-risk bags, one screen | `dutyManagerView()` — read-only deputy of `incidents` |
| FR-05 | Alert when a device stops >60s | `ingestDeviceStatus` + harness `Timer(stallThreshold, _confirmStall)` |
| FR-06 | Alert shows device, bag count, flights at risk | `Incident.deviceId` / `.affectedBags` / `.affectedFlights`, built in `_confirmStall` |
| FR-07 | Supervisor acknowledges + records action | `acknowledge(incidentId, supervisor, note, at)` |
| FR-08 | Group bag alerts sharing a cause into one incident | `_openIncidentByDevice` — folds repeat stalls on the same device into the same open `Incident` |
| FR-09 | Duty manager sees all open incidents, all terminals | `dutyManagerView()` (unscoped deputy) |
| FR-10 | Daily performance report by airline | `dailyReport(day)` — pure projection over `events`/`bags` |
| FR-11 | Free-text note on an incident | `acknowledge(..., note, ...)` |
| FR-12 (Could) | Export day's incidents as spreadsheet | Not modelled — noted as an open extension point in §7 below |

### 3.2 Data requirements (§7.2)

| ID | Requirement | Component |
|---|---|---|
| DR-01 | Per-bag: tag, flight, terminal, position, scan times, status | `BagState` (current) + `positionHistory` (trail) |
| DR-02 | Per-flight: airline, flight no, scheduled departure, close-out, terminal | `FlightRecord`, held in `flights` |
| DR-03 | Per-incident: start/end, device, bags, flights, actions, who acknowledged | `Incident` |
| DR-04 | Retain incident records 24 months | `events` is append-only (`_eventAppendOnly` `TestTissue`); see §6 for the retention-window caveat |
| DR-05 | Retain bag position history 7 days | `positionHistory` — bounded `TissueQueue`; see §6 |
| DR-06 | Reject a bag record missing tag/flight number | `_bagScanShape` (`TestCell`, at ingress) **and** `_bagStateRule` (`TestTissue`, at the books) — defence in depth |

### 3.3 Rules and policy (§7.3)

| ID | Rule | Component |
|---|---|---|
| BR-01 | Diplomatic/hazardous bags never re-routed without Duty Manager authorisation | `protectedBags` (`TissueSet<String>`) — any reroute path must consult `protectedBags.contains(tag)` before writing; demonstrated as a write-time guard in the COMPLY scenario pattern (see the sibling `protected` set in the upstream grid demo for the same idiom applied to hospital feeders) |
| BR-02 | No alert for a bag on an already-closed flight | `riskOf`: `if (flight.isClosedAt(scan.at)) return RiskLevel.onTime;` — enforced in the *policy*, not filtered after the fact, so a closed-flight scan can never reach the Tissue write path as an alert |
| BR-03 | Every alert acknowledged or dismissed within 15 minutes | `_armEscalation` / `_escalate` — a harness-owned `Timer` per open incident, cancelled by `acknowledge` |
| BR-04 | Airline-shared data excludes passenger personal data | By construction: no type in the domain model (`BagScan`, `BagState`, `OpsEvent`, `DailyAirlineStat`) carries a passenger name, PNR, or contact field. `airlineLiaisonView()` returns only `DailyAirlineStat`, which is a pure aggregate |

### 3.4 Reporting and audit (§7.4)

| ID | Requirement | Component |
|---|---|---|
| AR-01 | Daily report: handled/delayed/missed/avg time per airline | `dailyReport()` → `DailyAirlineStat` |
| AR-02 | Incident log with timings and actions, on demand | `events` (append-only `TissueList<OpsEvent>`), readable by Duty Managers and Safety & Compliance via a read-only deputy |

### 3.5 Non-functional requirements (§8)

| ID | Requirement | How the design addresses it |
|---|---|---|
| NFR-01 | Screen updates within 5s of a bag moving | `Cell.observe` delivers synchronously in-process; the design's job ends at `bags`/`incidents` being current the instant `ingestScan`/`_confirmStall` return — the 5s budget is a UI-refresh concern downstream of this graph |
| NFR-02 | 99.9% availability, 04:00–24:00 | Deployment concern (§7 below), not a code-level property; noted for completeness |
| NFR-03 | 120,000 bag events/day | `alertQ` and `positionHistory` are explicitly bounded (`TissueQueue(capacity: ...)`) so the design degrades by dropping the *oldest* buffered item rather than growing unboundedly under load — see cell_tissue's documented circular-buffer behaviour |
| NFR-04 | Only "Baggage Ops" role sees bag-level data | `dutyManagerView()` / `supervisorView(terminal)` are `.deputy()` proxies — narrower authority than the harness's own `incidents`, never wider, per the framework's deputy contract (`deputy == principal` in identity, but rules can only narrow) |
| NFR-05 | Every acknowledgement records who/when/what | `OpsEvent(kind: 'ACK', refId: incidentId, detail: '$supervisor: "$note"', at: at)` |
| NFR-06 | "Is my terminal healthy?" in ≤10s | `supervisorView(terminal)` — a single filtered read, no cross-terminal scan required |
| NFR-07 | UK GDPR + CAA 2027 reporting | The domain model's PII-free-by-construction property (see BR-04) is the load-bearing part of this; `Context`/`Sensitivity` metadata (see §5) can attach classification for audit, but — per the upstream framework's own honest caveat — does not itself certify GDPR compliance |
| NFR-08 | Restore service within 30 minutes | Deployment/ops concern; the append-only `events` log is what makes a warm restart forensically reconstructable |

### 3.6 User journeys (§9) → scenarios in the demo

| Journey | Demo scenario |
|---|---|
| 9.1 Morning peak — spotting a jam | Scenario 2: `BELT-T2-03` stalls, confirms after 60s, Marco acknowledges 4 minutes later |
| 9.1 failure path — no ACK in 15 min | Scenario 4: `CAR-T4-01` stalls, escalation clock fires |
| 9.2 A bag at risk on a closing flight | Scenario 3: `BAG-0002` scanned 8 minutes before close-out (< 10-minute minimum) |
| 9.3 Morning airline report | `Report` section: `h.airlineLiaisonView(base)` |

### 3.7 Acceptance criteria (§10)

| ID | Criterion | Demonstrated by |
|---|---|---|
| AC-01 | Bag visible within 5s of each scan | `ingestScan` updates `bags` synchronously before returning |
| AC-02 | At-risk bags correctly identified | `riskOf` policy, exercised in Scenario 3 |
| AC-03 | Belt-stop alerts raised within 90s | `stallThreshold = 60s` timer, well inside the 90s target |
| AC-04 | Every alert acknowledgeable and recorded | `acknowledge()`, exercised in Scenarios 2 and 3 |
| AC-05 | Daily report matches a manual count | `dailyReport()` is a direct aggregation over `bags`/`flights` — no independent code path to drift from it |
| AC-06 | No personal data in airline reports | `DailyAirlineStat` has no passenger field — see BR-04 |
| AC-07 | 30-day 99.9% availability | Deployment concern, not exercised in the demo |

---

## 4. The write protocol (how a scan becomes a screen update)

1. `ingestScan(scan)` calls `scanIn.emitAsync(scan)` — the **Cell** ingress applies `_bagScanShape` (DR-06). A rejected scan returns `false` and touches no Tissue (Scenario 5).
2. The accepted scan flows through the **Flow** gate: `MapValue(riskOf) + Filter(atRisk)`. `riskOf` is pure and reads only `flights` (a lookup, not a Tissue write).
3. If the gate fires, `Cell.observe`'s effect checks the **per-bag latch** (`_lastRisk`) — a repeat at-risk scan for a bag already flagged does not re-open an incident. This is the harness-level equivalent of the upstream demo's `_lastShed`/`_lastWarn` Distinct latches, keyed per bag instead of a single scalar (see file header, "Documented design decisions").
4. `ingestScan` itself — independently of the gate firing — always updates `bags[tag]`, appends to `positionHistory`, and appends a `SCAN` row to `events`. The **books** are updated whether or not the bag is at risk; the **incident** is opened only when it is.
5. If an incident opens, `_dispatch` enqueues an `AlertDispatch` on `alertQ` (audit) and drives a plain-Dart pump (delivery) — see §6 for why these are split.
6. `_armEscalation` starts the 15-minute clock (BR-03).
7. `acknowledge(...)` cancels that clock, folds the incident to `acknowledged`, resets the affected bags' risk to `onTime`, and appends an `ACK` row carrying who/what/when (NFR-05).

The belt-stall path (`ingestDeviceStatus` → `_confirmStall`) follows the identical shape, with the 60-second confirmation clock in place of the at-risk gate.

---

## 5. Roles and authority (NFR-04)

Three read paths are exposed, each a `.deputy()` — a *proxy*, not a copy, over the same underlying `incidents` storage:

- **Duty Manager** (`dutyManagerView()`): unscoped, read-only. Matches FR-04/FR-09 — "one screen, one view," "all open incidents across all terminals."
- **Supervisor** (`supervisorView(terminal)`): read-only **and** terminal-scoped via a `TestTissue` that only accepts rows matching the caller's terminal. A deputy can only narrow what the principal allows, never widen it — so a Terminal 2 supervisor's deputy cannot be reconfigured client-side to see Terminal 4.
- **Airline Liaison** (`airlineLiaisonView(day)`): does not touch `incidents` at all. It calls `dailyReport()`, which reads only `bags` and `flights` and returns `DailyAirlineStat` — a type with no passenger-identifying field. This satisfies BR-04/AC-06 by construction rather than by a redaction step that could be forgotten.

A production deployment would attach `Context`/`DeputyContext` (role, actor, purpose) to each of these deputies for the audit trail NFR-05 and AR-02 require. The design stops short of modelling `Context` explicitly to keep the reference file readable; the extension point is the `context:` parameter every `.deputy(...)` call accepts.

---

## 6. Known limitations and deliberate simplifications

Following the upstream repository's own convention of documenting where a demo's real behaviour diverges from an idealised reading of the requirement:

1. **DR-05's "7 days" is approximated by a capacity bound, not a clock.** `positionHistory` is a `TissueQueue(capacity: 20000)` — a circular buffer that drops the oldest record once full. At 120,000 events/day (NFR-03), a 7-day window is roughly 840,000 records, far above a single in-process queue's practical capacity. A production system would pair this Tissue with a scheduled, time-keyed purge (or push `ElementAdded` pulses to a time-series store) rather than rely on capacity alone. This mirrors the upstream `TissueQueue` capacity pattern exactly, applied to a requirement it wasn't originally sized for — flagged here rather than silently mis-scoped.
2. **DR-04's "24 months" is structural (append-only), not a retention *policy*.** `events` never shrinks in this design; nothing deletes a row. Actual 24-month-then-purge behaviour is an operational job outside the reactive graph, the same way the upstream demo's `events` log never expires within the process lifetime of the demo.
3. **The 60-second stall confirmation and 15-minute escalation clock are harness-owned `Timer`s, not Flow pipeline nodes.** `cell_flow`'s `timeout`/`debounce` operators act on a single stream; this system needs one independent clock per device and one per open incident. Keeping them as keyed maps on the harness (`_stallTimers`, `_escalationTimers`) is the same pragmatic boundary the upstream demo draws around its RTU retry state — outside the graph, but owned by the same single writer that owns every Tissue.
4. **`alertQ` is the audit-side enqueue only.** Per the upstream `TissueQueue` drain caveat (`removeFirst`/`remove` may not drain the container in the current RC build), the actual dispatch pump runs on a plain `List<AlertDispatch>` (`_dispatchWork`); `alertQ`'s `ElementAdded` pulses remain the reconstructable trace of every attempted push.
5. **FR-12 (Could-priority spreadsheet export) is not modelled.** It is a pure export over `events`/`incidents`, no different in shape from `dailyReport()`; left as an extension point rather than implemented against a "Could" requirement.
6. **NFR-01, NFR-02, NFR-08 are deployment properties**, not properties this graph can provide alone (screen refresh latency, uptime, and recovery time depend on the hosting service and the UI layer, not the reactive graph's internal correctness). They're listed in §3.5 for completeness, not because the code demonstrates them.
7. **This file was not compiled or executed in this session.** The working sandbox used to produce this design has no network path to `pub.dev` or a Dart SDK. The code was written directly against the documented public API surface in the upstream repository's READMEs and `grid-demand-response(tissue)-Demo.dart` (same operator names, same constructor signatures, same `TestCell`/`TestTissue` shapes). Before relying on it, run:
   ```
   cd packages_root
   dart pub get
   dart run baggage-flow-watch(tissue)-Demo.dart
   ```
   and diff the console output against the scenario comments in the file header.

---

## 7. Suggested next steps

- **Terminal sharding.** BRD §4.4 caps scope at four terminals with no new hardware; one `BaggageFlowWatchHarness` per terminal, each with its own `events`/`bags`/`incidents`, would let Terminal 3's older sorters (open question Q-01) be onboarded independently without touching the other three.
- **`Cell.transaction` for the at-risk → incident → dispatch sequence.** The current design performs three sequential Tissue writes (`incidents[id] = ...`, `events.add(...)`, `alertQ.addLast(...)`) per alert. The upstream roadmap lists joint multi-Tissue commit as a post-1.0 migration target (`Cell.transaction`); adopting it once stable would remove the small window in which a process crash between those three writes could leave the books inconsistent.
- **`Context`/`Sensitivity` wiring for NFR-07.** Attach `Context.describe(...)` classification to each role deputy so the audit trail carries not just *who* acted but *under what authority* — the framework provides the primitive; this design leaves it as a follow-on rather than a decoration with no consumer yet.
- **FR-12 spreadsheet export**, implemented as a thin formatter over `dailyReport()` and a read-only `events` deputy, once a target spreadsheet library is chosen.

---

## 8. Reading order

1. `enum RiskLevel`, `enum DeviceState`, `enum IncidentCause` — the domain vocabulary.
2. `BagScan`, `DeviceStatus`, `FlightRecord` — the ingress payloads.
3. `BaggageFlowWatchHarness.riskOf` — the pure at-risk policy (start here to understand the risk model, same order the upstream demo recommends for `actionOf`).
4. `BaggageFlowWatchHarness.installGates` — the Flow pipeline.
5. `ingestScan` / `ingestDeviceStatus` / `raiseAlert`-equivalents (`_confirmStall`, `_openBagAtRiskIncident`) / `acknowledge` — the Tissue write protocol.
6. `main()` — the scenarios, in the order listed in §3.6–3.7 above.
