The **WalkThrough** is the bridge document: it turns the *what* of the BRD into the *how the executable must behave*, in enough detail that a Demo can be written against it and checked against it. It is the source of truth for behaviour **until the Demo exists** — and after that it becomes the reference the Demo is assessed against.

## The one-sentence answer

The WalkThrough says, in plain and then mechanical terms, **how the program must behave to satisfy the BRD** — the ingress, the policy and chain, the pulse path, the books, the scenarios and their expected prints, and a coverage matrix tying each scenario back to a BRD ID — so that the Demo has a contract to meet and the ledger has expected values to verify.

## What it's for, concretely

1. **It is the contract between the BRD and the code.** The BRD says "warn the duty manager early enough to act." The WalkThrough says "flag appears while ≥10 min of the 35-min budget remain; clause order normal → at risk → warn → latch; banner prints `verdict=warn remaining=<n>`." The Demo is then written *to the WalkThrough*, not to someone's idea of it.

2. **It places each part in the right layer.** The **layer map** decides which Cell / Flow / Tissue construct answers which requirement — ingress, instruction, chain assembly, observer glue, books. The seam sentence is load-bearing here: *the instruction decides, the chain assembles, the observer glues*, with no Tissue writes in the instruction.

3. **It fixes the expected prints the ledger will verify.** The **coverage matrix** (scenario → BRD ID → expected print) is where "Verified" will ultimately come from. If those expected prints are real, the ledger can carry Verified rows; if they're placeholders, the ledger correctly reports Blocked — which is exactly what happened in your run.

4. **It defines the scenarios that must be exercised** — happy, at-risk/warn, protected (stale never shown as current), latch, ACK, reject, multi-cause, COMPLY — each with a must-print banner that compares actual to expected and exits non-zero on failure.

5. **It records what is deferred or unproven.** Real-desk deferrals (`transaction`/`txApply`), unproven clauses, and behaviours `main()` doesn't drive all get written down here and carried into the ledger — so they can't silently disappear.

6. **It gets revisited against the Demo.** Once the Dart exists, §5.12 (Demo Assessment) is filled *from the file* — what was implemented, what `main()` doesn't drive, trailer integers, recommendations. The Demo wins on symbols and what actually runs; the WalkThrough is corrected where the code disproves it.

## What it is *not*

- **Not the BRD** — it doesn't invent business numbers, actors, or clauses; expected values come from the BRD and its parameter register.
- **Not the Demo** — it's the behaviour contract *before* the code; after the code exists, the Demo is the source of truth for what the program actually does.
- **Not the ledger** — it states what *must* be printed; the ledger records what *was* proven by execution.
- **Not a wish-list** — FEATURES must not be written from a WalkThrough alone; they read the running Demo (and the ledger).
