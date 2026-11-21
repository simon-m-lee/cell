# cell_flutter_audit

Audit trail widgets for [cell_flutter](https://pub.dev/packages/cell_flutter):
render the Cell framework's `ApplyReceipt` forensic ledger as a ready-made,
filterable, exportable timeline. The framework mints the receipts — this
package gives you the UI.

[![License](https://img.shields.io/badge/License-MIT%20%2F%20Apache--2.0-blue.svg)](https://github.com/simon-m-lee/cell/blob/master/packages/cell_flutter_audit/LICENSE)
[![Version](https://img.shields.io/badge/cell__flutter__audit-0.1.0-blue.svg)](#status)

## Quick start

```dart
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

See [`example/`](example/) for the full runnable quick-start.

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

## Status

0.1.0 — initial release. The public API covers `AuditTrailView`,
`AuditTrailController`, `AuditTrailExporter` (+ `io.dart` file export),
`AuditEntryTile`, `AuditTrailTheme`, `AuditEntry`, and `RejectionEvent`.
Dependencies: `cell`, `cell_flutter`, and Flutter — nothing else.
