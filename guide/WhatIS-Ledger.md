## The one-sentence answer

The ledger is **the record of which BRD requirements have *executed evidence* that they conform — per requirement ID — and which do not.** It answers "what has actually been shown to work?" so that nobody has to answer that from memory, from reading code, or from a demo that looked fine.

## What it's for, concretely

1. **It separates three things that are easy to blur.** The **BRD** says what is *required*. The **Demo** says what the program *actually does*. The **ledger** says which requirements have been *shown to conform*, by execution, and which haven't. Without the ledger, "we built it" and "we proved it" collapse into the same sentence.

2. **It converts the BRD from a wish-list into a scorecard.** Every requirement ID gets a result: **Verified / Failed / Blocked**. So the question "are we done?" has a countable answer per ID, not a vibe.

3. **It makes Blocked a first-class, honest state.** In your run, all 13 rows are **Blocked** — not because the software is broken, but because the *expected values* are placeholders or missing (F-1/F-2/F-3, departure D-2). The ledger is what stops that from being quietly rounded up to "done." Blocked is a measured state, and the ledger says *why* each row is blocked and *what would unblock it*.

4. **It records provenance of the evidence.** Every row names where the run came from — "agent executed it" or, in your case, "user supplied the output." Mitose's rule: *reading code is never Verified; only executed evidence is.* The ledger is where that rule is enforced.

5. **It carries residual risk explicitly.** Rows that aren't Verified can be **Accepted** — but only by a *named person* with a *review date*. The ledger is where that acceptance lives, so "we know, and X accepted it until Y date" is auditable. The agent never fills that in for you.

6. **It scopes change mode.** When something changes later, the ledger tells you which rows to reset to Unverified and re-prove — impact traced by ID, not by guesswork.

## What it is *not*

- **Not a test log.** The test file *prints* `LEDGER` lines; the ledger *document* is the durable record built from them, with reasons, mitigation, provenance, and acceptance.
- **Not a bug list.** `Failed` means a check ran and didn't conform. `Blocked` means no defensible check could run. Very different, and the ledger keeps them apart.
- **Not a claim of correctness.** A ledger with zero Failed rows only says the *stated checks passed* against the BRD *as written*. It says nothing about whether the BRD itself is right.
- **Not a score of anyone's skill.** It measures conformance and records who accepted what — it doesn't grade people.
