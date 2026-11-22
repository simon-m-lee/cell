# Changelog

## 0.1.0

Initial release — the audit trail UI for `cell_flutter`. **Published to
pub.dev 2026-11-22.** The public API of `cell_flutter_audit.dart` and
`io.dart` is stable and additive-only going forward.

### Added

- `AuditTrailView` — the scrollable receipt timeline: green/amber left
  borders (vetted/unvetted), monospace truncated ids, `HH:mm:ss.SSS`
  timestamps, `tx #N` chips, collapsible payloads, red rejection cards,
  and the helpful empty-ledger message.
- `AuditTrailController` — `ChangeNotifier` over receipts: list / stream /
  `ApplyOutcome` ingestion, `filterBy` (command, vetted, time range),
  `search`, `sortBy`, `loadMore` pagination, and `RejectionEvent`
  recording.
- `AuditEntryTile` — the compact, embeddable row for sidebars and detail
  screens.
- `AuditTrailTheme` — colors, monospace fonts, spacing, and the
  show-id/timestamp/vetted toggles.
- `AuditTrailExporter` — JSON and CSV text export (RFC-4180 escaping);
  `AuditTrailFileExporter` in `cell_flutter_audit/io.dart` for dart:io
  platforms, keeping the main library web-safe.
- `AuditEntry` / `RejectionEvent` — display models that decouple the UI
  from the core receipt type.

### Verification and documentation

- 42 tests: controller, exporter, view, tile, and the
  `test/integration/audit_demo_ledger_test.dart` suite that replays the
  live audit demo's ledger mechanics.
- `tool/generate_test_verification.py` → `TEST_VERIFICATION.md` — the
  generated test report (mirrors the `cell` / `cell_flutter` tooling).
- `example/lib/cell_flutter_audit_example.dart` — the runnable
  quick-start (`example/lib/main.dart` is the thin pub.dev entry point).
- `doc/INDEX.md` and generated `doc/api/` — documentation index and API
  reference.
