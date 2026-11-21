// Cell DevTools extension provider.
//
// Adds the VM-service extension `ext.cell.getLedger` that exposes a Cell
// app's `ApplyReceipt` history as JSON, and ships the pre-compiled
// DevTools extension web app in `extension/devtools/build/`.
//
// `ApplyLedger` mints receipts; it does not store them. Your app owns the
// history (for example the list you feed `cell_flutter_audit`), and hands
// it to [registerCellDevTools] as a callback:
//
// ```dart
// void main() {
//   registerCellDevTools(receipts: () => myReceipts);
//   runApp(const MyApp());
// }
// ```
//
// The registration is wrapped in `assert`, so release builds tree-shake
// the entire DevTools surface.
library;

export 'src/cell_devtools.dart'
    show
        registerCellDevTools,
        buildCellLedgerResponse,
        serializeReceipt,
        serializeRejection,
        CellDevtoolsRejection,
        cellGetLedgerExtension;
