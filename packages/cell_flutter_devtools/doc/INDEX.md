# cell_flutter_devtools — Documentation Index

The map to everything in `cell_flutter_devtools` 0.1.0.

## Start here

- Deciding whether Cell is right for your app? →
  [`doc/comparison.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/doc/comparison.md)
- Want the extension in your app? → this package's
  [README](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools/README.md)
- Want the extension UI source? →
  [`cell_flutter_devtools_extension`](https://github.com/simon-m-lee/cell/tree/master/packages/cell_flutter_devtools_extension)

## Decision table

| I want to... | Use |
|---|---|
| Expose my app's receipts to DevTools | `registerCellDevTools(receipts: …)` |
| Report gate rejections too | the optional `rejections:` callback |
| Serialize one receipt by hand | `serializeReceipt` / `buildCellLedgerResponse` |
| Run the package's example | `example/` (audited counter + registration) |
| Rebuild the extension UI | `build_and_copy` + `validate` (see README) |

## The API surface

| Entry point | Contents |
|---|---|
| `package:cell_flutter_devtools/cell_flutter_devtools.dart` | `registerCellDevTools`, `buildCellLedgerResponse`, `serializeReceipt`, `serializeRejection`, `CellDevtoolsRejection`, `cellGetLedgerExtension` |

API docs: [`doc/api/`](api/index.html) — generate with `dart doc --output doc/api`.

The service extension itself is `ext.cell.getLedger`; the registration is
`assert`-guarded so release builds tree-shake the entire DevTools surface.

## How it is verified

- [TEST_VERIFICATION.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools/TEST_VERIFICATION.md) —
  the generated test report (serialization contract, empty ledger, error
  payloads, registration smoke). Regenerate with
  `python3 tool/generate_test_verification.py --run-tests`.
- The companion package `cell_flutter_devtools_extension` carries the UI
  tests and a cross-package wire-contract test that parses this package's
  real serializer output.
- The pre-compiled extension web app ships in
  `extension/devtools/build/`; `dart run devtools_extensions validate
  --package=.` checks the layout before publishing.

## Related packages

- `cell` — the core graph; mints the receipts the extension reads.
- `cell_flutter` — the widget bindings.
- `cell_flutter_audit` — the same ledger as an in-app widget.
