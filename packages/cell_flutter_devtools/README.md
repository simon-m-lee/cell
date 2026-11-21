# cell_flutter_devtools

A [Flutter DevTools](https://docs.flutter.dev/tools/devtools) extension for
the Cell framework: the `ApplyReceipt` ledger of a running app, live inside
DevTools — a filterable timeline next to the widget inspector, not a widget
inside your app (for in-app display, use
[`cell_flutter_audit`](https://pub.dev/packages/cell_flutter_audit)).

[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_devtools/LICENSE)
[![Version](https://img.shields.io/badge/cell__flutter__devtools-0.1.0-blue.svg)](#status)

## Add it to your app (under 5 minutes)

1. Add the dev dependency:

   ```yaml
   dev_dependencies:
     cell_flutter_devtools: ^0.1.0
   ```

2. Register the ledger in `main()`:

   ```dart
   import 'package:cell_flutter_devtools/cell_flutter_devtools.dart';

   void main() {
     registerCellDevTools(receipts: () => myReceipts);
     runApp(const MyApp());
   }
   ```

3. Run the app, open DevTools, and enable the **cell_flutter_devtools**
   extension (DevTools prompts the first time).

**Where `myReceipts` comes from:** `ApplyLedger` mints receipts; it does
not store them. Keep the receipts your apply pipeline produces — the same
list you feed `cell_flutter_audit`:

```dart
final receipts = <ApplyReceipt>[];

final outcome = await myCell.apply(myCommand);
if (outcome is ApplyAccepted) receipts.add(outcome.receipt);
```

Rejections can be reported separately through the optional
`rejections:` callback (a `List<CellDevtoolsRejection>` — receipt + gate
reason); the extension shows their count in the summary panel.

The registration is wrapped in `assert`, so **release builds tree-shake
the entire DevTools surface** — no binary-size or security cost.

## What the extension shows

- **Timeline** — every receipt, newest first: `HH:mm:ss.SSS` timestamp,
  command name, truncated id, vetted ✓/✗, `tx #N`, formatted payload.
  Click a row for the full receipt JSON.
- **Filter bar** — command name (free text), vetted status
  (All / Vetted / Unvetted), time range (Last 1 / 5 / 30 min / All), and a
  Clear button.
- **Summary panel** — total receipts, receipts in the last minute, and
  rejected attempts.
- **Live indicator** — the extension polls `ext.cell.getLedger` every
  500ms; new receipts appear without a refresh.

## Architecture

```
cell_flutter_devtools/            # the package you depend on
  lib/                            # registerCellDevTools + serialization
  extension/devtools/
    config.yaml                   # DevTools metadata
    build/                        # pre-compiled extension web app
cell_flutter_devtools_extension/  # the extension UI source (web app)
```

The extension web app uses `package:devtools_extensions` and connects to
the running app through the VM service extension `ext.cell.getLedger`.

## The live demo

The [Audit Trail demo](https://simon-m-lee.github.io/cell/audit-trail/)
registers the extension (`demo/audit_trail/lib/main.dart`) — run it with
`flutter run`, open DevTools, and the demo's ledger appears. It is the
"try it live" experience for this package.

## Building the extension (maintainers)

```bash
cd packages/cell_flutter_devtools_extension
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../cell_flutter_devtools/extension/devtools
dart run devtools_extensions validate --package=../cell_flutter_devtools
```

## Status

0.1.0 — initial release. Dependencies: `cell` only (the extension web app
source lives in this repository as a sibling package, pre-compiled into
`extension/devtools/build/`).
