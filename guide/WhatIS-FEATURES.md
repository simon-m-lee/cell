The **FEATURES document** describes **what a user can actually do with the running Demo** — the observable capabilities as they exist in the code, not as they were wished for in the BRD or sketched in the WalkThrough. It is written **from the Demo**, and it reads the ledger so it never advertises a capability whose requirement is Blocked, Failed, or Unverified as if it were working.

## The one-sentence answer

FEATURES answers *"what can someone do with this thing, as it runs?"* — it inventories the user-facing capabilities, each traced to the Demo behaviour and to the BRD requirement it serves, with anything unproven or accepted-residual called out as a limitation rather than dressed up as a feature.

## What it's for, concretely

1. **It is the user-facing inventory of the Demo.** Not the requirement list (that's the BRD) and not the code structure (that's ARCHITECTURE) — but the capabilities a user can exercise: e.g. "see all in-journey bags in one view," "see at-risk bags flagged with remaining time," "have stale status visibly marked," "receive an ACK/reject for ingress," "see a CAA-style compliance row (format pending)."

2. **It is written from what runs.** The hard stop is a missing Demo. It must not be written from the WalkThrough's wish-list — the rule is explicit: *"Not permission to … write FEATURES from a WalkThrough wish-list."* If `main()` doesn't drive it, it isn't a feature yet.

3. **It ties each feature to a requirement ID.** So a reader can see *why* a capability exists and which BRD row it serves — and, conversely, which requirements have no user-facing capability yet.

4. **It respects the ledger.** If a requirement is Blocked (as all 13 are in your run), FEATURES must not present that capability as delivered. It lists the honest limitations alongside the feature inventory. Documentation must not outrun evidence.

5. **It names the landing layer where useful.** Like the WalkThrough's recommendations, a feature can note which layer carries it (Cell / Flow / Tissue / harness) so the inventory doubles as a map of where capability lives.

6. **It cites decision IDs** rather than re-arguing design choices — same discipline as ARCHITECTURE.

## What it is *not*

- **Not a marketing brochure** — it doesn't overstate; Blocked stays Blocked.
- **Not the BRD** — requirements are *what's asked*; features are *what's usable*.
- **Not the ARCHITECTURE** — structure vs capability; ARCHITECTURE maps parts, FEATURES maps what a user can do.
- **Not the ledger** — it doesn't prove conformance; it inventories capability and defers to the ledger for evidence.
- **Not required** — offered, not assumed; you may take ARCHITECTURE, FEATURES, both, or neither.

## How it differs from its neighbours

| Document | Answers |
|---|---|
| BRD | *What is required?* |
| WalkThrough | *How must it behave?* |
| Demo | *What does it actually do?* |
| Ledger | *What is proven?* |
| ARCHITECTURE | *How is it built, as it runs?* |
| **FEATURES** | ***What can a user do with it?*** |

## In your specific run

FEATURES has not been written, and if written now it would be an **honest inventory with heavy limitations**: the user can exercise the S1–S8 scenarios through `main()` (single view, at-risk flag, stale marking, ACK/reject, multi-cause, a compliance row whose format is BLOCKED), but there is no real `cell`/`cell_flow`/`cell_tissue` wiring (D-3), the fail-closed checks are placeholders, and the ledger shows **0 Verified / 13 Blocked**. So each listed capability would carry "structure present; not Verified — see ledger." That is exactly the kind of honesty the document is meant to enforce.

## Where it sits in the pipeline

BRD → WalkThrough → Comprehension → Demo → Ledger → decision log (C3) → **ARCHITECTURE / FEATURES** (offered, not assumed; both read the ledger).

**Next in your run:** §8 — the **decision log (gate C3)** must be shown before either document is written. Shall I continue to §8 now — draft `baggage-flow-COMPREHENSION.md` from the decisions actually raised, then ask whether you want ARCHITECTURE, FEATURES, both, or neither?