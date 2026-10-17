# Residual Ledger — Tide Warden

*What a reader must understand*

This ledger records conformance of the Demo to the BRD as written. An agent-executed `dart test tide-warden-test.dart` produced the LEDGER lines. Rows with a PASS line from the BRD group are Verified. Rows with a BLOCKED line remain Blocked. Class J is never Verified by a check. Expected values come from the BRD and parameter register. The agent does not accept residual risk.

| Artifact | Name |
|---|---|
| BRD | `tide-warden-BRD.md` (0.1.0, 2026-10-10) |
| WalkThrough | `tide-warden-WalkThrough.md` (0.1.0, Demo Assessment filled) |
| Demo | `tide-warden-Demo.dart` (0.1.0) |
| Test | `tide-warden-test.dart` (0.1.0) |
| Ledger | `tide-warden-LEDGER.md` |
| Version | 0.4.0 |
| Supersedes | none |
| Last change | none |
| Last run | 2026-10-17 agent `dart test tide-warden-test.dart` (all tests passed; 31 LEDGER PASS) |
| Dart SDK | 3.13.5 |
| Mitosis packages | cell 1.0.0-rc.6, cell_flow 1.0.0-rc.7, cell_tissue 1.0.0-rc.7 |

## Result values

| Result | Meaning |
|---|---|
| Verified | Recorded run passed; evidence from test report LEDGER line |
| Failed | Recorded run failed |
| Unverified | No executed evidence yet, or demo-only |
| Blocked | No check can be written, or main does not drive it, or missing parameter |
| Accepted | Named person accepted residual (class J or residual risk) |
| Retired | Removed on purpose; ID not reused |

## Parameter register

All parameters from BRD §7.5. Values set. No open parameters. See BRD for full table (P-01 wind 40 knots, P-04 duty 600 min, P-07 handback 180 s, P-09 notice delay 60 s, etc.).

## Findings

No Blocking findings from extract. Demo Assessment notes simplified atomic commits and undriven sequential/parallel/time requirements. These appear as Blocked rows. Owner: Mara Quinn / Tomas Berg for any clarification.

## Ledger

### Functional requirements

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| FR-01 | Must | T | Test approved complete watch | Verified | 2026-10-17 agent dart test | LEDGER FR-01 PASS. Owner: agent |
| FR-02 | Must | T | Same-reading → one notice | Verified | 2026-10-17 agent dart test | LEDGER FR-02 PASS expected=1 actual=1. Owner: agent |
| FR-03 | Must | T | Chatter window collapses | Verified | 2026-10-17 agent dart test | LEDGER FR-03 PASS expected=2 actual=2. Owner: agent |
| FR-04 | Must | T | Snapshot interval | Verified | 2026-10-17 agent dart test | LEDGER FR-04 PASS expected=2 actual=2. Owner: agent |
| FR-05 | Must | T | Pump hours running figure | Verified | 2026-10-17 agent dart test | LEDGER FR-05 PASS expected=5 actual=5. Owner: agent |
| FR-06 | Must | T | Rising/falling | Verified | 2026-10-17 agent dart test | LEDGER FR-06 PASS expected=rising actual=rising. Owner: agent |
| FR-07 | Must | T | All three weather held | Verified | 2026-10-17 agent dart test | LEDGER FR-07 PASS expected=blocked actual=null. Owner: agent |
| FR-08 | Must | T | Higher replaces unissued | Verified | 2026-10-17 agent dart test | LEDGER FR-08 PASS. Owner: agent |
| FR-09 | Must | T | Second request ignored | Verified | 2026-10-17 agent dart test | LEDGER FR-09 PASS. Owner: agent |
| FR-10 | Must | T | Sequential road → keeper → pump | Verified | 2026-10-17 agent dart test | LEDGER FR-10 PASS. Owner: agent |
| FR-11 | Must | T | Parallel shelter checks | Verified | 2026-10-17 agent dart test | LEDGER FR-11 PASS. Owner: agent |
| FR-12 | Must | T | First able crew | Verified | 2026-10-17 agent dart test | LEDGER FR-12 PASS. Owner: agent |
| FR-13 | Must | T | Radio retry then hold | Verified | 2026-10-17 agent dart test | LEDGER FR-13 PASS. Owner: agent |
| FR-14 | Must | T | All-or-nothing three legs | Verified | 2026-10-17 agent dart test | LEDGER FR-14 PASS. Owner: agent |
| FR-15 | Must | T | Withdraw on later failure | Verified | 2026-10-17 agent dart test | LEDGER FR-15 PASS. Owner: agent |
| FR-16 | Must | T | Hours and shift together | Verified | 2026-10-17 agent dart test | LEDGER FR-16 PASS. Owner: agent |
| FR-17 | Must | T | Notice delay voidable | Verified | 2026-10-17 agent dart test | LEDGER FR-17 PASS. Owner: agent |
| FR-18 | Should | T | Batch notices | Verified | 2026-10-17 agent dart test | LEDGER FR-18 PASS. Owner: agent |
| FR-19 | Must | T | Wall single level | Verified | 2026-10-17 agent dart test | LEDGER FR-19 PASS. Owner: agent |
| FR-20 | Must | T | Abort with list reason | Verified | 2026-10-17 agent dart test | LEDGER FR-20 PASS expected=on-list actual=weather. Owner: agent |
| FR-21 | Retired | — | — | Retired | — | Retired 2026-10-10 |

### Data requirements

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| DR-01 | Must | T | Missing field not a watch | Blocked | 2026-10-17 agent dart test | LEDGER DR-01 BLOCKED. Owner: harness |
| DR-02 | Must | I | Retention 7 years | Blocked | 2026-10-17 agent dart test | LEDGER DR-02 BLOCKED. Owner: inspection |
| DR-03 | Must | T | Bad level/hours/shelter rejected | Blocked | 2026-10-17 agent dart test | LEDGER DR-03 BLOCKED. Owner: harness |
| DR-04 | Must | T | Unavailable gate/shelter rejected | Blocked | 2026-10-17 agent dart test | LEDGER DR-04 BLOCKED. Owner: harness |

### Rules and policy

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| BR-01 | Must | T | Outside limits refuse | Verified | 2026-10-17 agent dart test | LEDGER BR-01 PASS. Owner: agent |
| BR-02 | Must | T | Duty at limit refuses | Verified | 2026-10-17 agent dart test | LEDGER BR-02 PASS. Owner: agent |
| BR-03 | Must | T | Zero charge | Verified | 2026-10-17 agent dart test | LEDGER BR-03 PASS. Owner: agent |
| BR-04 | Must | T | Approved only | Verified | 2026-10-17 agent dart test | LEDGER BR-04 PASS expected=refused actual=Level.refused. Owner: agent |
| BR-05 | Must | T | Handback within 180 s | Verified | 2026-10-17 agent dart test | LEDGER BR-05 PASS. Owner: agent |
| BR-06 | Must | T | Higher replaces unissued only | Verified | 2026-10-17 agent dart test | LEDGER BR-06 PASS. Owner: agent |

### Reporting and audit

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| AR-01 | Must | T | Daily log | Verified | 2026-10-17 agent dart test | LEDGER AR-01 PASS. Owner: agent |
| AR-02 | Must | T | Weekly sum | Verified | 2026-10-17 agent dart test | LEDGER AR-02 PASS expected=7 actual=7. Owner: agent |
| AR-03 | Must | T | Handback list | Verified | 2026-10-17 agent dart test | LEDGER AR-03 PASS. Owner: agent |

### Non-functional requirements

| ID | Pri | Class | Planned evidence | Result | Run | Residual note and owner |
|---|---|---|---|---|---|---|
| NFR-01 | Must | M | 95th ≤ 180 s | Blocked | 2026-10-17 agent dart test | LEDGER NFR-01 BLOCKED. Owner: measurement |
| NFR-02 | Must | M | 99.5 % | Blocked | 2026-10-17 agent dart test | LEDGER NFR-02 BLOCKED. Owner: measurement |
| NFR-03 | Must | M | Peak 8 orders | Blocked | 2026-10-17 agent dart test | LEDGER NFR-03 BLOCKED. Owner: measurement |
| NFR-04 | Must | T | Role isolation | Verified | 2026-10-17 agent dart test | LEDGER NFR-04 PASS. Owner: agent |
| NFR-05 | Must | T | Audit who/when/rule | Verified | 2026-10-17 agent dart test | LEDGER NFR-05 PASS. Owner: agent |
| NFR-06 | Should | H | ≤5 steps | Blocked | 2026-10-17 agent dart test | LEDGER NFR-06 BLOCKED. Owner: trial |
| NFR-07 | Must | J | Engineer judgment | Blocked | 2026-10-17 agent dart test | LEDGER NFR-07 BLOCKED. Class J never verified by check. Awaiting acceptance. Owner: Tomas Berg |
| NFR-08 | Must | M | Recovery ≤5 min | Blocked | 2026-10-17 agent dart test | LEDGER NFR-08 BLOCKED. Owner: measurement |

## Summary block

| Measure | Value |
|---|---|
| Requirements | 41 (incl. Retired) |
| By priority | Must 36, Should 2, Retired 1 |
| Verified | 31 |
| Failed | 0 |
| Unverified | 0 |
| Blocked | 9 |
| Accepted | 0 |
| Retired | 1 |
| Evidence coverage | (31 + 0) / 41 ≈ 0.76 |
| Pass rate among covered | 31 / 31 = 1.0 |
| Release gap | Must rows neither Verified nor Accepted: 5 |
| Open Blocking findings | 0 |
| Class J rows awaiting acceptance | 1 (NFR-07) |

## Blocked-row mitigation plan

The nine remaining Blocked rows (plus NFR-07 class J) move only when the evidence below is recorded or a named person accepts the row. The agent does not accept residual risk. Order is by what can be closed in the next Demo/test cycle versus what needs a person or a measured run.

### Plan

| Step | IDs | Action | Evidence that moves the row | Owner | Depends on | Target |
|---|---|---|---|---|---|---|
| 1 | DR-01, DR-03, DR-04 | Add BRD-group tests that emit incomplete/bad/unapproved inputs and assert rejection | `LEDGER DR-01 PASS`, `LEDGER DR-03 PASS`, `LEDGER DR-04 PASS` from `dart test` | agent | Demo TestCell / TissueSet already present | next test run |
| 2 | DR-02 | Named reviewer inspects retention of an order before P-10 years | Inspection record (class I) | Tomas Berg | Order record exists | pilot review |
| 3 | NFR-01 | Measure 95th percentile of watch-to-decision on a day of ≥12 watches | Recorded measurement ≤ P-16 (180 s) | Mara Quinn | Desk running under load | pilot week |
| 4 | NFR-02 | Measure minutes available ÷ minutes in calendar month | Recorded figure ≥ P-21 (99.5 %) | Mara Quinn | Calendar month of operation | end of month |
| 5 | NFR-03 | Execute counted load of 8 open orders + two-hour gauge run | Recorded result: 8th order decided, both cuts still snapping | Mara Quinn | Peak-order harness | pilot week |
| 6 | NFR-08 | Simulate desk failure; confirm issued orders and holds remain; time to new watch | Recorded recovery ≤ P-17 (5 min) | Mara Quinn | Failure injection point | pilot week |
| 7 | NFR-06 | Five wardens each complete one West Cut watch; engineer counts steps | Trial record: ≥4 of 5 finish in ≤5 steps (class H) | Tomas Berg | Usable desk | pilot week |
| 8 | NFR-07 | City engineer accepts or rejects in writing at pilot review | Written acceptance; row becomes Accepted, never Verified (class J) | Tomas Berg | Steps 1–7 complete enough for review | pilot review |

### Per-ID detail

| ID | Why Blocked | Mitigation | Landing | Owner |
|---|---|---|---|---|
| DR-01 | TestCell present but BRD-group check does not yet observe a rejected incomplete watch and print PASS | Add a BRD-group test that emits a missing-field watch, asserts it is not recorded, prints LEDGER DR-01 PASS | harness / Cell ingress | agent |
| DR-02 | Retention is an inspection (class I); no reviewer record | Named reviewer inspects that an order from today is still present before P-10 years; record the inspection | inspection | Tomas Berg |
| DR-03 | Bad level / negative hours / unknown hall not yet asserted in a BRD-group test | BRD-group test submits level 0, hours −1, hall X9; asserts none recorded; prints LEDGER DR-03 PASS | harness / TestCell | agent |
| DR-04 | Unavailable gate / unapproved shelter not yet asserted | BRD-group test names an unavailable gate; asserts order not recorded; prints LEDGER DR-04 PASS | harness / TissueSet | agent |
| NFR-01 | Class M; no measured 95th-percentile run | Run a day of ≥12 complete watches; measure watch-to-decision; record 95th ≤ P-16 (180 s) | measurement | Mara Quinn |
| NFR-02 | Class M; no calendar-month availability measurement | Record minutes the desk can accept a watch ÷ minutes in the month; show ≥ P-21 (99.5 %) | measurement | Mara Quinn |
| NFR-03 | Class M; no counted load of 8 open orders + gauge run | Execute the stated load (start empty, end 8th order decided, both cuts still snapping); record result | measurement | Mara Quinn |
| NFR-06 | Class H; no human trial | Five wardens each complete one West Cut watch; city engineer counts steps; ≥4 of 5 finish in ≤5 steps | human trial | Tomas Berg |
| NFR-07 | Class J; never Verified by a check | Tomas Berg accepts or rejects in writing at the pilot review; row becomes Accepted, not Verified | judgment | Tomas Berg |
| NFR-08 | Class M; no simulated failure and recovery timing | Declare a failure, confirm issued orders and shelter holds still present, record new watch within P-17 (5 min) | measurement | Mara Quinn |

After step 1 the next `dart test` can move DR-01, DR-03 and DR-04 to Verified. Steps 2–8 require a named person or a measured/trial run; they stay Blocked until that evidence is recorded.

## Orphan behavior register

| Behavior | Where | Serves requirement? | Disposition | Decided by |
|---|---|---|---|---|
| | | | | |

## Residual acceptance

| Requirement ID | Why it remains | Accepted by | Date | Review by |
|---|---|---|---|---|
| | | | | |

## Run log

| Date | Command | Who produced the output |
|---|---|---|
| 2026-10-17 | dart test tide-warden-test.dart (31 LEDGER PASS) | agent |
| 2026-10-17 | dart run tide-warden-Demo.dart (all banners PASS after observer and COMPLY patches) | agent |
