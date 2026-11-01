# LEDGER — Rail Yard Flow Watch

## Name plate

| Field | Value |
|---|---|
| BRD | `example/BRD/freight-rail-intermodal-BRD.md` v0.1.0 |
| WalkThrough | `freight-rail-intermodal-WalkThrough.md` v0.1.0 (Demo Assessment filled) |
| Demo | `freight-rail-intermodal-Demo.dart` v0.1.0 |
| Test file | `freight-rail-intermodal-test.dart` v0.1.0 |
| Ledger version | `0.1.0` |
| Supersedes | `none` |
| Build / commit | workspace copy (no commit recorded) |
| Last run | 2026-10-29 |
| Last change | `none` (first build) |
| Dart SDK | 3.11.5 |
| Mitosis packages | cell 1.0.0-rc.6 · cell_flow 1.0.0-rc.7 · cell_tissue 1.0.0-rc.7 |

## Result values

| Result | Meaning |
|---|---|
| Verified | A recorded run printed `LEDGER <ID> PASS` for this row |
| Failed | A recorded run printed `LEDGER <ID> FAIL` for this row |
| Unverified | No executed evidence yet |
| Blocked | `LEDGER <ID> BLOCKED`, or the row depends on an open parameter / finding |
| Accepted | A named person accepted the residual, with a review date |
| Retired | Removed on purpose; the ID is never reused |

## Parameter register

| ID | Parameter | Used by | Value | Unit | Owner | Status | Open Q |
|---|---|---|---|---|---|---|---|
| P-01 | Crane/block stop alert | FR-05 | 60 | seconds | Terminal Ops | set | — |
| P-02 | Acknowledge window | BR-03 | 15 | minutes | Network Ops | set | Q-03 |
| P-03 | Incident retention | DR-04 | 24 | months | Customer service | set | — |
| P-04 | Position-history retention | DR-05 | 7 | days | Terminal Ops | set | — |
| P-05 `[AI SUGGESTED]` | Screen update target | NFR-01 | 5 | s | `[To be confirmed from BRD]` | set (§8) | — |
| P-06 `[AI SUGGESTED]` | Availability window/target | NFR-02 | 99.9% (04:00–24:00) | % | `[To be confirmed from BRD]` | set (§8) | — |
| P-07 `[AI SUGGESTED]` | Capacity | NFR-03 | 30,000 | events/day | `[To be confirmed from BRD]` | set (§8) | — |
| P-08 `[AI SUGGESTED]` | Usability answer time | NFR-06 | ≤10 | s | `[To be confirmed from BRD]` | set (§8) | — |
| P-09 `[AI SUGGESTED]` | Recovery time | NFR-08 | ≤30 | min | `[To be confirmed from BRD]` | set (§8) | — |
| P-10 `[AI SUGGESTED]` | Minimum connection time | FR-03 | `[To be confirmed from BRD]` | min | `[To be confirmed from BRD]` | TBD | journey §9.2 implies 10 |
| P-11 `[AI SUGGESTED]` | Commercial-sensitive field list | BR-04 | `[To be confirmed from BRD]` | list | `[To be confirmed from BRD]` | TBD | — |
| P-12 `[AI SUGGESTED]` | Protected container tags | BR-01 | hazardous, temperature-controlled | list | Company policy | set | — |
| P-13 `[AI SUGGESTED]` | Stop-alert asset types | FR-05 | crane, sorter, block | list | Terminal Ops | set | — |
| P-14 `[AI SUGGESTED]` | Authorized role | NFR-04 | Yard Ops | role | `[To be confirmed from BRD]` | set | — |
| P-15 `[AI SUGGESTED]` | Incident grouping key | FR-08 | `[To be confirmed from BRD]` | key | `[To be confirmed from BRD]` | TBD | — |
| P-16 `[AI SUGGESTED]` | Spreadsheet export format | FR-12 | `[To be confirmed from BRD]` | format | `[To be confirmed from BRD]` | TBD | — |

## Findings

| # | Type | Severity | IDs | Finding | Question for owner |
|---|---|---|---|---|---|
| F-01 | Missing value | **Blocking** | FR-03 | "Minimum connection time" not in the parameter register; §9.2 implies 10 minutes | What is the minimum connection time, and who owns it? |
| F-02 | Missing value | **Blocking** | BR-04 | "Commercial-sensitive data" has no field list | Which fields must never appear in customer reports? |
| F-03 | Missing behavior | Clarify | BR-03 | Escalation policy after the 15-minute window is open (Q-03) | What is the approved escalation policy? |
| F-04 | Orphan rule | Clarify | BR-01 | No FR implements re-route authorization; re-routing is out of scope | Is BR-01 enforced only as the protected-tag clause in v1? |
| F-05 | Journey mismatch | Clarify | FR-05/06/07 | §9.1 names Diego as Yard 2 supervisor; §6.2 says Yard 4 | Which yard does Diego run? |
| F-06 | Missing value | Clarify | FR-08 | "Same cause" grouping key undefined | What defines the same cause? |
| F-07 | Measure basis | Clarify | NFR-06, NFR-08, §12 | Sample size / failure scenario / measurement window missing | What are the measurement conditions? |
| F-08 | Criterion trace | Clarify | AC-01…07 | Acceptance criteria cite no requirement IDs | Do the ACs need to be rewritten to cite IDs? |
| F-09 | Missing value | Clarify | FR-12 | Export format unspecified | What spreadsheet format is required? |
| F-10 | Precedence gap | Clarify | BR-01, BR-02 | §7.6 does not order BR-01 vs BR-02 when both match | Which wins for a hazardous container on a departed train? |

## Ledger

### Functional (FR)

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| FR-01 | Must | T | T scan sequence | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Real-time feed not driven; Q-01 Yard 3 feed. Owner: Terminal Ops |
| FR-02 | Must | T | T boundary | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | `remainingMinutes(600,592)==8`. Owner: — |
| FR-03 | Must | T | T boundary | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | F-01: minimum connection time missing; placeholder 10 not BRD-sourced. Owner: `[To be confirmed from BRD]` |
| FR-04 | Must | H | H trial | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class H: single-screen trial not run. Owner: Yard Masters |
| FR-05 | Must | T | T boundary 59/60/61 | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | 61 s → warn, 60 s → none (P-01). Owner: — |
| FR-06 | Must | T | T fixture | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | `alertSummary` carries asset, count, train. Owner: — |
| FR-07 | Must | T | T transition | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Graph drive: ACK closes and restores. Owner: — |
| FR-08 | Should | T | T fixture | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | F-06: grouping key TBD; v1 keys by container ID. Owner: `[To be confirmed from BRD]` |
| FR-09 | Should | T | T fixture | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Cross-yard open-incident query not driven. Owner: Yard Masters |
| FR-10 | Must | T | T aggregation | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Daily report not driven; Q-02 recipients. Owner: Commercial |
| FR-11 | Should | T | T | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Free-text note not driven. Owner: Yard Masters |
| FR-12 | Could | T | T export | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | F-09: export format TBD. Owner: `[To be confirmed from BRD]` |

### Data (DR)

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| DR-01 | Must | T | T fixture | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Container record fields not driven as a unit check. Owner: Terminal Ops |
| DR-02 | Must | T | T fixture | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Train record fields not driven as a unit check. Owner: Terminal Ops |
| DR-03 | Must | T | T fixture | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Incident record fields not driven as a unit check. Owner: Terminal Ops |
| DR-04 | Must | T | T boundary (simulated clock) | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | 24-month retention is Wave B on a copy. Owner: Customer service |
| DR-05 | Must | T | T boundary (simulated clock) | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | 7-day history is Wave B on a copy. Owner: Terminal Ops |
| DR-06 | Must | T | T ingress | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Empty container/train ID rejected by TestCell. Owner: — |

### Rules (BR)

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| BR-01 | Must | T | T policy | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Hazardous → `none` (protected clause first). Owner: — |
| BR-02 | Must | T | T policy | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Departed train → `none`. Owner: — |
| BR-03 | Must | T | T boundary 14/15/16 | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Q-03: escalation policy open; no wall clock in v1. Owner: Network Ops Programme Office |
| BR-04 | Must | I | I inspection | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | F-02: sensitive-field list TBD; no exclusion check. Owner: `[To be confirmed from BRD]` |

### Reporting (AR)

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| AR-01 | none | T | T aggregation | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Daily per-customer report not driven. Owner: Commercial |
| AR-02 | none | T | T query | **Verified** | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Append-only `events` log driven in the FR-07 graph test. Owner: — |

### Non-functional (NFR)

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| NFR-01 | none | M | M measurement | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class M: 5 s update needs a measured run. Owner: `[To be confirmed from BRD]` |
| NFR-02 | none | M | M measurement | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class M: 99.9% availability needs a measured run. Owner: `[To be confirmed from BRD]` |
| NFR-03 | none | M | M capacity run | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class M: 30k events/day needs a capacity run. Owner: `[To be confirmed from BRD]` |
| NFR-04 | none | T | T role check | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Deferred: SSO / role isolation is Wave A. Owner: `[To be confirmed from BRD]` |
| NFR-05 | none | T | T | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | ACK who/when/action not driven as a unit check. Owner: `[To be confirmed from BRD]` |
| NFR-06 | none | H | H trial | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class H: ≤10 s answer needs a human trial (F-07 basis). Owner: Yard Masters |
| NFR-07 | none | J | J acceptance | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class J: GDPR + ORR 2027 acceptance only. Owner: Safety & Compliance |
| NFR-08 | none | M | M recovery run | Blocked | 2026-10-29 · agent · `dart test example/freight-rail-intermodal-test.dart` | Class M: ≤30 min recovery needs a measured run (F-07 scenario). Owner: `[To be confirmed from BRD]` |

## Summary block

| Measure | Value |
|---|---|
| Requirements | 32 |
| By priority | Must 18 · Should 3 · Could 1 · none 10 |
| Verified / Failed / Blocked / Unverified / Accepted | 8 / 0 / 24 / 0 / 0 |
| **Evidence coverage** | (8 + 0) ÷ 32 = **25%** |
| **Pass rate among covered** | 8 ÷ (8 + 0) = **100%** |
| **Release gap** | 11 Must rows neither Verified nor Accepted: FR-01, FR-03, FR-04, FR-10, DR-01, DR-02, DR-03, DR-04, DR-05, BR-03, BR-04 |
| Open Blocking findings | 2 (F-01, F-02) |
| Class J rows awaiting acceptance | 1 (NFR-07) |
| Orphan behaviors without a disposition | 0 (illustrative reserve pool accepted by the user) |

This block is not collapsed into one score; the rows above are the score.

## Blocked-row mitigation

One recommendation per currently Blocked ID:

| ID | Recommendation |
|---|---|
| FR-01 | Drive a scan-sequence T test once Q-01 (Yard 3 feed) is answered |
| FR-03 | Resolve F-01: owner supplies the minimum connection time into P-10; then write the 9/10/11-minute boundary test |
| FR-04 | Run the class-H single-screen trial with named yard masters |
| FR-08 | Resolve F-06: define the cause key, then re-key `incidentMap` and write the grouping fixture |
| FR-09 | Drive the cross-yard open-incident query over `incidentMap` |
| FR-10 | Add a harness roll-up read of `events` per customer (after Q-02) |
| FR-11 | Drive a free-text note round-trip on an incident |
| FR-12 | Resolve F-09: agree the export format, then drive the export fixture |
| DR-01 | Drive a container-record fixture asserting every DR-01 field |
| DR-02 | Drive a train-record fixture asserting every DR-02 field |
| DR-03 | Drive an incident-record fixture asserting timings, actions, ack supervisor |
| DR-04 | Wave B: retention rule on a copy of `events` (24 months) |
| DR-05 | Wave B: retention rule on position history (7 days) |
| BR-03 | Resolve Q-03: approve escalation, then add a timer ingress and the 14/15/16-minute boundary test |
| BR-04 | Resolve F-02: DPO supplies the field list, then record the exclusion inspection |
| AR-01 | Same roll-up as FR-10, asserted per customer metric |
| NFR-01 | Measured run: 5 s screen update under load |
| NFR-02 | Measured run: 99.9% availability 04:00–24:00 over the AC-07 window |
| NFR-03 | Capacity run: 30k container events/day |
| NFR-04 | Wave A: SSO + Yard Ops role check |
| NFR-05 | Drive ACK who/when/action assertion (piggyback on FR-07) |
| NFR-06 | Human trial: "is my yard healthy?" ≤10 s with stated participants |
| NFR-07 | Named acceptance by Safety & Compliance with a review date |
| NFR-08 | Measured recovery run: restore ≤30 min with a stated failure scenario |

Sequenced mitigation plan:

| Step | IDs | Action | Evidence that moves the row | Owner | Depends on | Target |
|---|---|---|---|---|---|---|
| 1 | FR-03 | Supply P-10 | `LEDGER FR-03 PASS` | `[To be confirmed from BRD]` | F-01 | — |
| 2 | BR-04 | Supply P-11 field list | Recorded class-I inspection | `[To be confirmed from BRD]` | F-02 | — |
| 3 | BR-03 | Approve escalation policy | `LEDGER BR-03 PASS` | Network Ops Programme Office | Q-03 | — |
| 4 | FR-08 | Define cause key | `LEDGER FR-08 PASS` | `[To be confirmed from BRD]` | F-06 | — |
| 5 | DR-01, DR-02, DR-03, FR-09, NFR-05 | Extend BRD-group tests over the real graph | `LEDGER … PASS` | Terminal Ops | — | — |
| 6 | FR-10, AR-01, FR-11, FR-12 | Harness roll-up + export format | `LEDGER … PASS` | Commercial | Q-02, F-09 | — |
| 7 | DR-04, DR-05 | Wave B retention on a copy | class-I / T | Customer service, Terminal Ops | — | — |
| 8 | FR-04, NFR-06, NFR-01, NFR-02, NFR-03, NFR-08 | Named trials and measured runs | Recorded M/H runs | Yard Masters, `[To be confirmed from BRD]` | F-07 | — |
| 9 | FR-01, NFR-04 | Real feed + SSO (Wave A) | T role check, scan-sequence test | Terminal Ops | Q-01 | — |
| 10 | NFR-07 | Named acceptance with review date | Accepted row | Safety & Compliance | — | — |

## Orphan behavior register

| Where | What | Decision |
|---|---|---|
| Demo `reserve` (illustration baseline 6) + scenario 9 OVERDRAW | The BRD names no countable pool; the reserve/attention pool exists to demonstrate raise/close and overdraw | **Accepted** — keep the illustration in the Demo. Decided by: user (name not stated, `[To be confirmed from BRD]`) on 2026-10-29 |

## Residual acceptance

| ID | Accepted by | Date | Review by | Reason |
|---|---|---|---|---|
| — | — | — | — | — |

Gate L4 (2026-10-29): user accepted **none** of the 24 non-Verified rows. All remain Blocked; the release gap stays 11 Must rows.

## Run log

| Date | Command | Output | Produced by |
|---|---|---|---|
| 2026-10-29 | `dart pub get` | Got dependencies | agent |
| 2026-10-29 | `dart analyze example/freight-rail-intermodal-Demo.dart example/freight-rail-intermodal-test.dart` | No issues found | agent |
| 2026-10-29 | `dart run example/freight-rail-intermodal-Demo.dart` | 12/12 banners PASS, exit 0 | agent |
| 2026-10-29 | `dart test example/freight-rail-intermodal-test.dart` | 17/17 tests passed; 32 `LEDGER` lines (8 PASS, 24 BLOCKED) | agent |
