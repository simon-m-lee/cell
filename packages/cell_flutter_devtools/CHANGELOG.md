# Changelog

## 0.1.0

Initial release — the DevTools extension provider for the Cell
framework. **Published to pub.dev 2026-11-22.** The public API of
`cell_flutter_devtools.dart` is stable and additive-only going forward.

### Added

- `registerCellDevTools(receipts: …, {rejections})` — registers the
  `ext.cell.getLedger` VM-service extension; `assert`-guarded so release
  builds tree-shake the entire DevTools surface.
- `serializeReceipt` / `serializeRejection` / `buildCellLedgerResponse` —
  the JSON wire contract, with empty-ledger and error-payload handling.
- `CellDevtoolsRejection` — the denial wrapper the extension's summary
  panel counts.
- The pre-compiled extension web app in `extension/devtools/build/`
  (timeline, filter bar, summary panel, 500ms live polling), with
  `extension/devtools/config.yaml` metadata.

### Verification and documentation

- 7 tests: serialization contract, named arguments, empty ledger,
  rejection payloads, error conversion, and registration smoke.
- `tool/generate_test_verification.py` → `TEST_VERIFICATION.md` — the
  generated test report (dart runner variant of the repo tooling).
- `example/lib/cell_flutter_devtools_example.dart` — a runnable audited
  counter that registers the extension (`example/lib/main.dart` is the
  thin pub.dev entry point).
- `doc/INDEX.md` and generated `doc/api/` — documentation index and API
  reference.
- The companion source package `cell_flutter_devtools_extension`
  (publish_to: none) carries the UI tests and the cross-package
  wire-contract test.
