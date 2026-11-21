# cell_flutter_devtools_extension — Documentation Index

The map to everything in `cell_flutter_devtools_extension` 0.1.0
(repository-internal; `publish_to: none` — this package is the *source*
of the web app shipped by `cell_flutter_devtools`).

## Start here

- Why this exists →
  [`cell_flutter_devtools/README.md`](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools/README.md)
- How to run it →
  [this package's README](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools_extension/README.md)

## The surface

| File | Contents |
|---|---|
| `lib/main.dart` | `CellDevToolsExtension` — the `DevToolsExtension` root widget |
| `lib/src/ledger_view.dart` | `LedgerView` — summary panel, filter bar, rows, live polling |
| `lib/src/ledger_model.dart` | `DevtoolsLedgerEntry` / `DevtoolsRejectionEntry` / `DevtoolsLedgerSnapshot` — the wire model |
| `lib/src/ledger_client.dart` | `ServiceLedgerClient` — the VM-service fetch path (web-only imports; kept out of the VM test path) |

The extension talks to a running app through `ext.cell.getLedger`, the
service extension registered by `cell_flutter_devtools`.

## How it is verified

- [TEST_VERIFICATION.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools_extension/TEST_VERIFICATION.md) —
  the generated test report (12 tests: loading/error/empty states, rows,
  filters, summary, live polling, and the wire-contract test). Regenerate
  with `python3 tool/generate_test_verification.py --run-tests`.
- `test/contract_test.dart` pins this UI's model to the provider
  package's serializer — the two sides change together.

## Related packages

- `cell_flutter_devtools` — the published provider package that embeds
  this app's compiled output.
- `cell` — the core graph.
- `cell_flutter_audit` — the same ledger as an in-app widget.
