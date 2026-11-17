# Changelog

## 0.1.0

- First internal release (`publish_to: none`).
- Structured BRD parsing (`flutter-pipeline/v1`) with the full
  18-mode failure contract.
- 15 executable placement rules + 8 patterns + 5 anti-pattern checks.
- Walkthrough (Gate 1) and design (Gate 2) artifacts.
- Deterministic code + test generation targeting the living
  cell_flutter API; the three canonical BRDs compile, analyze clean,
  and pass their generated tests.
- Five-category verification rubric + LEDGER emitter.
- CLI: `generate`, `verify`, `assess` with the documented flags and
  exit codes; non-interactive sessions auto-approve the gates.
- Committed reference apps under `example/generated/` verified
  byte-for-byte by `verify`.
- CI: unit job + opt-in compile gate.
