# cell — Known issues

Developer-oriented list for **`packages/cell`** (the core graph). Status is
**RC** (Mitosis `1.0.0-rc.1`, Release Candidate, not published). Prefer
**source** over guides when they disagree.

Last reviewed against `lib/`, `test/`, and `pubspec.yaml` on 2026-09-01.
This is not a full audit.

---

## How to use this file

| Severity | Meaning |
|----------|---------|
| **Bug** | Behavior that will surprise you or leak resources |
| **Incomplete** | Documented or half-wired; do not rely on it |
| **Docs** | Comments/guides/examples that do not match the API |
| **Process** | Tests, versioning, publishing, review |

Workarounds are suggestions, not extra guarantees.

---

## Bugs and runtime gaps

### 1. Analyzer: unused `_pin` (Process)

`dart analyze lib` reports unused `_pin` on asyncMap / debounce /
throttle state (retain-cycle workaround that is never read). Harmless
but noisy.

---

## Incomplete vs advertised

### 2. `Cell.valve` is implemented; some docs still say otherwise (Docs)

`Cell.valve` exists, has examples (`example/valve_demo.dart`), and has
unit tests in `test/test_cell.dart`. Generated `doc/api/index.html` may
still describe it as missing until `dart doc` is regenerated. Trust the
factory and tests, not that HTML.

### 3. Public factories narrower than dartdoc

| Factory | Public parameters | Dartdoc still describes |
|---------|-------------------|-------------------------|
| `fromFuture` | `future` | synapses / flow-control as if they were parameters |
| `state` | `initial`, `evolve` | Guides pass `testRule` — **not** on this factory |

To validate state, wrap `evolve` (return `null`) or use `Cell.governed` /
`ValueCell` with `testRule`.

### 4. Transactions / txApply — tested, not independently audited (Process)

`Cell.transaction` and `Cell.txApply` are implemented and covered by
`test/test_transaction.dart` (54 tests) and `test/test_tx_apply.dart`
(46 tests). Isolation (`repeatableRead` / `serializable`), savepoints,
and compensation retry have **not** been independently reviewed
end-to-end. Treat as RC for money/inventory until you have your own
review.

### 5. Governance is metadata, not enforcement (Incomplete)

`Context`, `PulseContext`, `Sensitivity`, `compliances`,
`Context.describe` store strings/enums. Nothing here implements GDPR,
HIPAA, PCI-DSS, purpose limitation, or an audit log. `Cell.sanitized`
only runs your `redact` when sensitivity ≥ threshold.

Deputy **lineage** (`context.parent`) and `TestCell` can deny operations
**if you write the rule**. Defaults are `allowAll`. Isolation enums
(`sandboxed`, `total`) are labels unless a `TestCell`/receptor honors
them.

### 6. Core 16 numbering is a learning order (Docs)

Lists disagree: library table vs `HowTo-16` vs `valve`/`open` extras vs
`fromFuture`/`fromStream` as one slot. Do not treat numbers as a
stability contract.

---

## Documentation and examples

### 7. Guides that will not compile against current APIs

| Location | Problem | Actual API |
|----------|---------|------------|
| `guide/HowTo-Start.md` | `Cell.observe(..., bind: …)` and `observe<int>` | `source:`; `P extends Pulse` |
| `guide/HowTo-16_Essential_Operators.md` | `Cell.state(..., testRule: isPositive)` | No `testRule` on `state` |
| `lib/src/cell.dart` dartdoc | `guide/HowTo-17_Essential_Operators.md` | File is `HowTo-16_Essential_Operators.md` |
| `lib/src/cell.dart` dartdoc | `example/switch_map_demo.dart`, `from_future_demo`, `from_stream_demo`, `stream_bridge_demo` | Not in `example/`; some live under cell_flow |
| `ARCHITECTURE.md` intro / §7 | may lag README | Valve exists; package is RC `1.0.0-rc.1` |

Regenerate `doc/api/` after fixing comments; HTML may still mention
HowTo-17.

HowTo examples may still mention private APIs (`_nucleus`). Unit tests
use public APIs only.

### 8. Missing examples in this package

Present: state, ingress, observe, derive, distinct, throttle, hub,
sanitized, synthesis, valve, open, async_map, transaction, txApply
(`atomic_multi_update`), debounce via `stability_search_demo`,
receptor/instruction walkthroughs.

**Absent here:** dedicated `fromFuture`, `fromStream`, `switchMap`,
`debounce` demos (search demo covers debounce).

### 9. Repository / version strings

- `pubspec.yaml` `version:` `1.0.0-rc.1`
- `pubspec.yaml` `repository:` `https://github.com/cell/cell-framework`
- Monorepo README uses `simon-m-lee/Cell-Framework-Mitosis`
- Unpublished RC — easy to confuse with a stable pub `1.0.0`
- Dual license MIT/Apache; `FEATURES(Qwen).md` is a stale draft — ignore
  it

---

## Tests

**1115** tests in **20** files under `test/`. Last full run: **1115 passed /
0 failed / 0 skipped** (~7 s with coverage). Measured `lib/` line coverage:
**95.9%** (3397 / 3541). Inventory: [TEST_VERIFICATION.md](TEST_VERIFICATION.md).

Files are named `test_*.dart`, not `*_test.dart`. Therefore:

- `dart test` with no path finds **no tests**
- `dart test test` is a name filter, not a directory
- Pass explicit files (see `TEST_VERIFICATION.md`)

Covered: Cell (including deputy, `valve`, `OpenCell.perform`), Pulse
(including `PulseExtension.map` / `cast` via `PulseExtension(pulse)`),
Nucleus (`isInvalidated` follows a hosted `EphemeralPolicy`), Receptor,
Instruction, Synapses (including `FilterRule` parent/`fromRecord` and
`PropagationStrategy.sample`), TestCell, PropagationPolicy, SynthesisCell,
Context / DeputyContext / PulseContext, commons, `transaction`, `txApply`,
and operator phases 1–4 (`state`, `ingress`, `observe`, `derive`,
`debounce`, `throttle`, `distinct`, `synthesis`, `asyncMap`, `hub`,
`switchMap`, `fromFuture`, `fromStream`, `sanitized`, `open`).

Remaining test gaps:

- OpenCell `EphemeralPolicy.eventLimit` / `onEvent` are not fully
  exercised on `emit`
- Remaining lower line coverage: `context.dart` 90.3%,
  `internal/pulse.dart` 90.4%, `receptor.dart` 90.5%.
  `internal/test_cell.dart`, `internal/receptor.dart`,
  `operator_debounce.dart`, `test_cell.dart`, `value.dart`,
  `internal/cell.dart`, and `test_rule.dart` are 100%.
  `internal/synapses.dart` is 98.9%; leftover lines are
  `AsyncSynapses._rehydrate` (public `link` is identity-checked against
  the sync instance) and `Synapses.enabled.call` (`Never`). Leftover
  `receptor.dart` lines are InstructionChainMixin strategy /
  Function-token resume paths.

`CustomCell.sendPulse` in `test_cell.dart` still returns `null` (unused
fixture). `dart analyze lib` is clean except unused `_pin` (3 warnings).

---

## Workarounds (short)

| Need | Do this |
|------|---------|
| Fan-in | `Cell.synthesis` or **cell_flow** `Flow.merge` |
| Stream teardown | `fromStream` cancels on invalidation / GC; or pass `ephemeralPolicy` |
| Future errors | `fromFuture` emits a pulse with `type: 'error'` and the error as payload |
| Validated atom | `evolve` returns `null`, or `ValueCell`/`governed` + `TestCell` |
| Observe | `Cell.observe(source: cell, effect: …)` |
| Run tests | Explicit `test/test_*.dart` paths, not bare `dart test` |
| Rx merge/zip/scan | **cell_flow**, not this package |
| Compliance | Your rules + legal review; do not cite Cell as certified |

---

## Related docs

| File | Role |
|------|------|
| [README.md](README.md) | Status bullets (subset of this list) |
| [CHANGELOG.md](CHANGELOG.md) | Mitosis `1.0.0-rc.1` RC notes |
| [FEATURES.md](FEATURES.md) | Catalog (RC `1.0.0-rc.1`) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Intent; intro/§7 may lag README status |
| [TEST_VERIFICATION.md](TEST_VERIFICATION.md) | Test inventory, coverage, run commands |


