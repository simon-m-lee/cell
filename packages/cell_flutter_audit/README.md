# cell_flutter_audit

Audit trail widgets for [`cell_flutter`](https://pub.dev/packages/cell_flutter):
render the Cell framework's `ApplyReceipt` forensic ledger as a ready-made,
filterable, exportable timeline. The framework mints the receipts — this
package gives you the UI.

[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_audit/LICENSE)
[![Version](https://img.shields.io/badge/cell__flutter__audit-0.1.0-blue.svg)](#status)

## What it provides

- `AuditTrailView` — the scrollable receipt timeline (vetted/unvetted
  borders, collapsible payloads, rejection cards, auto-scroll).
- `AuditTrailController` — a `ChangeNotifier` over receipts: filter,
  search, sort, pagination, and `ApplyOutcome` ingestion.
- `AuditEntryTile` — a compact, embeddable audit row for sidebars and
  detail screens.
- `AuditTrailTheme` — colors, monospace fonts, spacing, and the
  show-id/timestamp/vetted toggles.
- `AuditTrailExporter` — JSON and CSV text export; file export in
  `package:cell_flutter_audit/io.dart` (keeps the main library
  web-safe).
- `AuditEntry` / `RejectionEvent` — the display models that decouple the
  widgets from the core receipt type.

## Install

```yaml
dependencies:
  cell: ^2.0.0
  cell_flutter: ^1.0.0
  cell_flutter_audit: ^0.1.0
```

## Quick start

```dart
import 'package:cell_flutter_audit/cell_flutter_audit.dart';

final controller = AuditTrailController();          // 1. the data
final outcome = await myCell.apply(myCommand);      // 2. an apply outcome
controller.addOutcome(outcome);                     // 3. record it
// ...
AuditTrailView(controller: controller)              // 4. the widget
```

**Important:** the view shows receipts minted by `Cell.apply`. A cell
mutated with `value = …` produces no receipts — if the timeline is empty,
the view itself says so ("No receipts yet. Mutations must go through
`cell.apply` to appear here."). That message is the package teaching the
requirement, not a bug.

The runnable quick-start lives in
[`example/lib/cell_flutter_audit_example.dart`](example/lib/cell_flutter_audit_example.dart)
(`example/lib/main.dart` is the thin pub.dev entry point).

## The widgets

### `AuditTrailView` — the timeline

A scrollable list of receipt cards: green left border for vetted receipts,
amber for unvetted (trusted internal) receipts, monospace truncated ids
(full id on tap), `HH:mm:ss.SSS` timestamps, `tx #N` chips for staged
transactions, and collapsible argument payloads. Auto-scrolls to the
newest receipt (configurable).

```dart
AuditTrailView(
  controller: controller,
  autoScroll: true,            // or per-theme
  showRejections: true,        // interleave RejectionEvents as red cards
)
```

### `AuditTrailController` — the data

A `ChangeNotifier` that holds the history, applies filters/search/sort,
and pages large ledgers:

```dart
final controller = AuditTrailController(
  receipts: initialReceipts,   // optional
  stream: receiptStream,       // optional live stream
);
controller.filterBy(commandName: 'add', vetted: true, after: since);
controller.clearFilters();
controller.search('payload');
controller.sortBy(SortField.timestamp);          // or .commandName / .vetted
await controller.loadMore(pageSize: 50);          // pagination
```

- `addReceipt` / `addReceipts` — push receipts directly.
- `addOutcome(ApplyOutcome)` — routes `ApplyAccepted`/`ApplyStaged`
  receipts into the timeline and `ApplyRejected` into `rejections`.
- `addRejection(RejectionEvent)` — attach your own denial copy when the
  gate supplies no reason.

### `AuditEntryTile` — the compact row

Timestamp, command name, and vetted status in one embeddable row; tapping
expands the payload:

```dart
AuditEntryTile(entry: AuditEntry.fromReceipt(receipt))
```

### `AuditTrailTheme` — the styling

`vettedColor`, `unvettedColor`, `rejectedColor`, `monospaceFont`,
`cardPadding`/`cardMargin`, and the `showId` / `showTimestamp` /
`showVettedIcon` toggles.

## The exporter

```dart
final json = AuditTrailExporter.toJson(receipts);   // indented array
final csv = AuditTrailExporter.toCsv(receipts);     // RFC-4180 escaping
```

File export (dart:io platforms; keeps the main library web-compatible):

```dart
import 'package:cell_flutter_audit/io.dart';

await AuditTrailFileExporter.exportToFile(
  receipts,
  path: '/tmp/audit.json',
  format: ExportFormat.json,       // or ExportFormat.csv
);
```

The JSON shape is one object per receipt:
`id`, `function`, `arguments` (`positional` / `named`), `timestamp`,
`vetted`, `txSequence`. Exports are intended for ledgers under ~10,000
entries; larger ledgers should page with `loadMore`.

## Rejections

`ApplyLedger` records only accepted commands — a denied command is an
`ApplyRejected` outcome, not a ledger entry. Feed it through
`addOutcome` (or wrap it in a `RejectionEvent` yourself) and
`AuditTrailView` renders it as a red-bordered card with the gate's reason,
interleaved by timestamp.

## Integration with the live demo

The [Audit Trail demo](https://simon-m-lee.github.io/cell/audit-trail/)
renders the same ledger this package is designed for.
`test/integration/audit_demo_ledger_test.dart` replays the demo's exact
mechanics — the governed counter, the gate-rejected mutation, and the
`Cell.txApply` undo — and asserts the view renders the same receipts,
including the demo's rejection copy.

## Documentation

- [Documentation index](doc/INDEX.md) — the API map and decision table.
- [API reference](doc/api/index.html) — generated with
  `dart doc --output doc/api`.
- [Test verification report](TEST_VERIFICATION.md) — generated by
  `python3 tool/generate_test_verification.py --run-tests` (42 tests).
- [Fair comparison page](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter/doc/comparison.md) —
  whether Cell is right for your app.
- [CHANGELOG.md](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_audit/CHANGELOG.md) —
  release history.

## Status

0.1.0 — initial release. The public API covers `AuditTrailView`,
`AuditTrailController`, `AuditTrailExporter` (+ `io.dart` file export),
`AuditEntryTile`, `AuditTrailTheme`, `AuditEntry`, and `RejectionEvent`.
Dependencies: `cell`, `cell_flutter`, and Flutter — nothing else.
