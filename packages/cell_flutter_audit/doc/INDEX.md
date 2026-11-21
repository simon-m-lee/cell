# cell_flutter_audit — Documentation Index

The map to everything in `cell_flutter_audit` 0.1.0.

## Start here

- New to Cell? → `cell_flutter`'s
  [`guide/HowTo-CellBuilder.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/guide/HowTo-CellBuilder.md)
- Deciding whether Cell is right for your app? →
  [`doc/comparison.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/doc/comparison.md)
- Want the receipt widgets? → this package's
  [README](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_audit/README.md)

## Decision table

| I want to... | Use |
|---|---|
| Render a receipt timeline in-app | `AuditTrailView` |
| Filter / search / sort / page receipts | `AuditTrailController` |
| Embed a compact audit row | `AuditEntryTile` |
| Export receipts as JSON / CSV text | `AuditTrailExporter` |
| Export receipts to a file (dart:io) | `package:cell_flutter_audit/io.dart` |
| Show gate rejections next to the ledger | `RejectionEvent` + `showRejections` |
| Customize colors, fonts, spacing | `AuditTrailTheme` |
| Decouple the UI from `ApplyReceipt` | `AuditEntry.fromReceipt` |

## The API surface

| Entry point | Contents |
|---|---|
| `package:cell_flutter_audit/cell_flutter_audit.dart` | The main barrel: `AuditTrailView`, `AuditTrailController`, `AuditTrailExporter`, `AuditEntryTile`, `AuditTrailTheme`, `AuditEntry`, `RejectionEvent`, `SortField`, `ExportFormat` |
| `package:cell_flutter_audit/io.dart` | `AuditTrailFileExporter` — file export for dart:io platforms only (keeps the main library web-safe) |

API docs: [`doc/api/`](api/index.html) — generate with `dart doc --output doc/api`.

## How it is verified

- [TEST_VERIFICATION.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_audit/TEST_VERIFICATION.md) —
  the generated test report (42 tests: controller, exporter, view, tile,
  and the demo-ledger integration suite). Regenerate with
  `python3 tool/generate_test_verification.py --run-tests`.
- `test/integration/audit_demo_ledger_test.dart` — replays the live audit
  demo's ledger mechanics and asserts the view renders the same receipts.

## Related packages

- `cell` — the core graph; mints the `ApplyReceipt`s this package renders.
- `cell_flutter` — the widget bindings.
- `cell_flutter_devtools` — the same ledger inside Flutter DevTools
  (debugging surface, not the in-app widget).
- The [live Audit Trail demo](https://simon-m-lee.github.io/cell/audit-trail/) —
  the hand-rolled version of what this package ships as a widget.
