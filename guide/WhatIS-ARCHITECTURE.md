The **ARCHITECTURE document** describes the **structure of the running Demo** — its parts and how they connect — so a reader can navigate the code that ships. It is written **from the Demo**, not from the WalkThrough, and it reads the ledger so it never presents a Blocked or Failed requirement as if it were handled.

## The one-sentence answer

ARCHITECTURE answers *"how is the program built, as it actually runs?"* — the ingress points, the FlowInstruction(s) and chain assembly, the observer glue, the Tissue books and their types, the deputies and boundaries, the gates — traced to the Demo's real symbols and cited to decision IDs, with any unproven or accepted-residual items listed as limitations.

## What it's for, concretely

1. **It maps the code, using the code's own names.** It names the actual classes and functions the Demo exports — e.g. `RiskInstruction.riskOf`, `Books.inJourney`, `Books.atRisk`, `assembleChain`, `installGates` — not an aspirational design. The Demo is the source of truth; if the document describes a lock or feature the Demo doesn't contain, that's a defect in the document, not a plan.

2. **It shows the seam in practice.** Where the instruction decides, where the chain assembles (`MapValue` → `+` → `toHandle`), where `Cell.observe` glues and writes the books — expressed against the real symbols, so the seam rule is visible in the structure, not just asserted.

3. **It records boundaries and provenance.** The ingress points and their `TestCell`, the deputies (`.unmodifiable` views) and who may read/write what, and whether `Cell.transaction` / `Cell.txApply` are present or deferred (with the Real-desk row). This is the structural counterpart of the fail-closed provenance and boundary registers.

4. **It cites decisions rather than re-arguing them.** Where a design choice appears, it cites the decision ID from the log (gate C3) instead of restating the reasoning. That keeps the *why* in one place and the *what* in another.

5. **It respects the ledger.** If the ledger marks a requirement Blocked, Failed, or Unverified, ARCHITECTURE must **not** describe it as handled — it lists accepted residual items under limitations and says plainly what is unproven. Documentation must not outrun the evidence.

6. **It is a navigation aid, not a proof.** It helps someone find their way around the running system and understand its boundaries; it does not claim the system is correct or conformant — that's the ledger's job.

## What it is *not*

- **Not design fiction** — it describes the Demo that exists, not the one you intend to write.
- **Not a substitute for the ledger** — it can't turn Blocked into Verified by describing it nicely.
- **Not written from the WalkThrough alone** — the hard stop is a missing Demo or WalkThrough; and if a ledger exists, it must be read first.
- **Not a second decision log** — it links to decision IDs; it doesn't restate the reasoning.
- **Not required** — it's offered, not assumed; you can take ARCHITECTURE, FEATURES, both, or neither.

## How it differs from its neighbours

| Document | Answers |
|---|---|
| BRD | *What is required?* |
| WalkThrough | *How must it behave?* |
| Demo | *What does it actually do?* |
| Ledger | *What is proven?* |
| **ARCHITECTURE** | ***How is it built, as it runs?*** |
| FEATURES | *What can a user do with it?* (also read from the Demo) |
