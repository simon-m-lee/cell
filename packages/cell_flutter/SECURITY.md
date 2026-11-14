# Security

## Reporting a vulnerability

Please report security issues privately to the maintainers via the
repository's security advisory process. Do not open a public issue for a
security vulnerability.

## Security posture (1.0 gate review)

The most recent review is `reports/SECURITY_REVIEW.md` (2026-11-13):
internal second-pass review of the binding layer with no findings above
"low". The review scope is the `cell_flutter` binding (widgets, hooks,
testing utilities); deputy/ledger security properties are the `cell`
core package's concern.

## Verified replay scope

The binding rests on `cell`'s verified replay round-trip (commit
`05b4895d`) for the pure state, debounce, throttle, `fromFuture`, and
`fromStream` probes (full suite 1371 tests, determinism gate 240/240).
Concurrent `asyncMap` effect attribution under `concurrency > 0` is
tracked separately (Gate G1.5) and is not claimed. Only
`Cell.fromFuture` emits error pulses today; `fromStream` and `asyncMap`
do not.

## Adopters

- **No external production adopters yet.** The S1 soft gate (an external
  app on `cell_flutter` for 30 days with no critical bugs) is documented
  as a gap in the 1.0 gate evaluation (`reports/GATE_1.0.md`). Opt-in
  adopter reports will be listed here as they arrive.
