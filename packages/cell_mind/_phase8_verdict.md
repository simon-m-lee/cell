# Phase 8 Verdict — `prompt` (1.1.0)

Pre-flight and findings recorded per `research/Mind/Phase-8.md` §3.2.

## Pre-flight (all green)

| Check | Result |
|---|---|
| Phase 0–7 suite | 402/402 pass before any Phase 8 change |
| `1.0.0` tagged | yes (`a5abd185`) |
| `crypto` sha256 | `crypto 3.0.7` resolved in the workspace lockfile (transitive via `cell`); promoted to a direct dependency of `cell_mind` |
| Receptor fix (Phase 6) | verified by `test/runtime/receptor_fix_test.dart` |
| `TestCell.chain` short-circuit | verified by `test/policy/composition_test.dart` |
| `Decision` records `traceId` | yes (via `Decision.pulse.context.traceId`) |
| `Defer` → `onDeferred` | verified by `test/approval/defer_routing_test.dart` |
| `jsonEncode`/`jsonDecode` | `dart:convert`, stable |

## Plan-vs-live deviations (recorded, deliberate)

### F8.1 — `VerdictPolicy.call` widened to `FutureOr<Verdict>` (enabling change)

The live `VerdictPolicy.call` returned `Verdict` synchronously; a
prompted policy must await an LLM before it can decide. The plan
(§7.1) requires both factories to return `VerdictPolicy` composed via
`cognitive(verdictPolicy: ...)` — impossible without async support in
the recording runtime. Resolution:

- `VerdictPolicy.call` return type widened `Verdict` →
  `FutureOr<Verdict>`; `_RecordingTestCell` awaits `Future<Verdict>`
  results. **Source-compatible**: every 1.0 rule returning `Verdict`
  compiles unchanged.
- `verdictPolicy(...)` now accepts `FutureOr<Verdict>` rules.
- This is the only non-additive line in the `FROZEN_API.md` diff.
  Documented in CHANGELOG §1.1.0.

### F8.2 — `promptedPolicyWith` accepts renderer/parser overrides

D5 says the inline mode passes renderers/parsers as parameters and
delegates to config mode, but the frozen §7.1 signature of
`promptedPolicyWith` has no such parameters. Added optional
`contextRenderer:`, `decisionRenderer:`, `verdictParser:` parameters
(additive; defaults are `renderContext` / `renderDecision` /
`parseVerdict`, which are public so users can compose rather than
replace).

### F8.3 — Validation relaxes the "verdict key" rule

D14 requires `outputSchema` to have a `verdict` key, but the
`classifier` / `extractor` presets (D13) must validate with
`label` / `fields` shapes. `validate()` accepts any one of
`verdict` / `label` / `fields`.

### F8.4 — Cache is static, keyed by config id + version

D2 requires config-mode instances to share verdicts while inline
instances stay isolated. The process-wide `_PromptCache` keyed by
`sha256(config.id | version | contextHash | decisionHash |
systemPromptHash)` delivers both: inline ids are per-instance UUIDs,
config ids are shared by construction. Cache hits **still journal** a
`PromptEffect` — otherwise a recorded session with duplicate decisions
could not replay.

### F8.5 — Argument-level evaluations short-circuit

The substrate validates each command argument through the rule; the
recorder's verdict slot historically ran for those frames too (that is
how `defer-in-argument-validation` works). A prompted policy
short-circuits argument evaluations (`arguments is Function`) with
`Accept` — the LLM decides about the command *with* its arguments at
the command decision. Cost: one adapter call per decision, not per
argument. Sync verdict policies keep their 1.0 semantics.

### F8.6 — Pulse timestamps are not rendered

§8.2's decision block lists provenance but no timestamp. Rendering the
pulse timestamp would change every prompt byte between recording and
replay (each emission stamps a new time) and break both the cache and
the replay input digest. Deliberately omitted; documented in the guide
§5.4.

### F8.7 — Replay divergences and validation errors propagate

`ReplayDivergenceException` (implements `Exception`) was previously
swallowed by the recorder's fail-closed catch; the prompt journal
would have silently recorded `composite-rejected` on divergence.
Rethrown now. Non-`Exception` errors from async verdicts (e.g.
`ArgumentError` from `config.validate()`) also propagate — validation
failures are programmer errors, not decisions.

### F8.8 — Adapter timeout handling

The frozen factory signatures have no timeout parameter (the plan's
D9 lists `prompt-timeout` but D4 keeps transport in user code).
Resolution: a `TimeoutException` thrown *by the adapter* is captured
as `Reject('prompt-timeout')`; any other adapter error as
`Reject('prompt-error')`. Framework-side timeouts remain user code.

### F8.9 — Conformance compares type/reason/resolver, not annotations

The default parser adds `reason`/`confidence` to a verdict's
annotations; comparing annotations would fail every hand-built
`ConformanceCase.expected` against a parsed verdict. Annotations are
excluded from the comparison (documented).

### F8.10 — Freeze-tool header is deterministic

The Phase 7 generator emitted `Frozen on: <now>` — every CI run would
diff against a fresh timestamp. `tool/freeze_api.dart` now emits fixed
constants (`1.1.0`, `2026-11-15`); CI can diff a fresh generation
against the committed manifest with zero noise.

## Verification (all green)

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos --fatal-warnings` | 0 issues |
| Phase 8 tests (`test/prompt/`) | 155/155 |
| Full suite (Phase 1–8) | 555+ pass |
| `example/10_prompted_policy.dart` | all hard checks pass |
| `benchmark/micro/prompted_policy_cost.dart` | renders 22.5k/s, parses 247k/s, cache-miss 2.0k decisions/s, cache-hit 5.3k decisions/s |
| `FROZEN_API.md` vs `1.0.0` | additive prompt module; one documented widening (F8.1) |
| Doc audit | every new public declaration carries the seven required sections |
| `guide/12-Prompted-Policy.md` | 781 lines |
