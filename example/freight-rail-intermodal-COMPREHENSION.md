# COMPREHENSION — Rail Yard Flow Watch

## Name plate

| Field | Value |
|---|---|
| BRD | `example/BRD/freight-rail-intermodal-BRD.md` v0.1.0 |
| WalkThrough | `freight-rail-intermodal-WalkThrough.md` v0.1.0 |
| Ledger | none (not yet written) |
| Date | 2026-10-29 |
| Version | `0.1.0` |
| Supersedes | `none` |

## Comprehension checks

Session 1 — gate C1 (before WalkThrough acceptance):

| Scenario | Question | Prediction | BRD-derived result | Outcome | Follow-up |
|---|---|---|---|---|---|
| Three scenarios proposed: (1) ordinary — WARN at 61 s stop; (2) boundary — exactly 60 s stop (P-01); (3) interaction — hazardous container also at risk (BR-01 vs FR-03) | "Before you accept the WalkThrough, would you like to predict three scenarios?" | — | — | declined | none — recorded; not asked again this session |

## Counts

| Measure | Value |
|---|---|
| Asked | 0 |
| Matched | 0 |
| Mismatched | 0 |
| Skipped | 0 |
| Undetermined | 0 |
| Declined (offer) | 1 |

No score is computed. A decline says nothing about the reader.

## Change log

No protected changes on a first build.

| Date | Requirement ID | Old → new | Cause | Decided by | Status |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

## Decision log

| ID | Date | Context | Decision | Alternatives considered | Decided by | Revisit if |
|---|---|---|---|---|---|---|
| D-01 | 2026-10-29 | FR-08; CHG-nnn: none | Same-cause grouping lands in a `TissueMap` keyed by cause, not a Flow `groupBy` (WalkThrough §5.6) | Flow `groupBy` — not chosen because the open-incidents book is already a map and ACK closes a key | `[To be confirmed from BRD]` | F-06 resolves the grouping key |
| D-02 | 2026-10-29 | raise/close multi-book commit; CHG-nnn: none | `Cell.txApply` on Tissue **yes in v1** for raise/close; `Cell.transaction` deferred (WalkThrough §5.10) | Wave A deferral of the atomic commit — not chosen because raise/close moves four books together and must be all-or-nothing | `[To be confirmed from BRD]` | — |
| D-03 | 2026-10-29 | Entity graph (containers → trains → incidents); CHG-nnn: none | Entity-graph need deferred; `HowTo-Mitose-Organ.md` is absent and `cell_organ` is not assigned from memory (WalkThrough §5.10) | Assigning `cell_organ` from memory — not chosen, forbidden by the layer guide | `[To be confirmed from BRD]` | `HowTo-Mitose-Organ.md` becomes available |
| D-04 | 2026-10-29 | WalkThrough §5.12 Recommendations for Enhancement; CHG-nnn: none | Recommendations skipped — left in §5.12 for later | Applying in place — not chosen; applying as a CHANGE — not chosen | user (name not stated, `[To be confirmed from BRD]`) | A later change or in-place pass |
| D-05 | 2026-10-29 | Orphan scan; CHG-nnn: none | Illustrative reserve pool (baseline 6) + OVERDRAW scenario accepted as-is in the Demo | Removing it — not chosen; adding a BRD requirement — not chosen | user (name not stated, `[To be confirmed from BRD]`) | A BRD change formalises a pool |

Alternatives above are only those actually raised. No other decisions were made this session.

## Length record

| Document | Words | Status |
|---|---|---|
| `freight-rail-intermodal-WalkThrough.md` | 2854 | no cap — C4 removed in COMPREHENSION-AI-Generator §5 |
