// Audit trail UI for cell_flutter.
//
// Renders the Cell framework's `ApplyReceipt` forensic data as ready-made
// widgets: a scrollable timeline ([AuditTrailView]), a compact row
// ([AuditEntryTile]), a controller that filters/sorts/paginates
// ([AuditTrailController]), and exporters ([AuditTrailExporter]).
//
// The ledger itself stays where it belongs — your code. `Cell.apply`
// returns an [ApplyOutcome] for every mutation; feed those outcomes into
// [AuditTrailController.addOutcome] (or pass the receipts as a list or
// stream) and wrap an [AuditTrailView] around the controller.
library;

export 'src/audit_entry.dart'
    show AuditEntry, formatAuditTimestamp, functionDisplayName, formatArguments;
export 'src/audit_entry_tile.dart' show AuditEntryTile;
export 'src/audit_rejection_event.dart' show RejectionEvent;
export 'src/audit_trail_controller.dart'
    show AuditTrailController, SortField;
export 'src/audit_trail_exporter.dart'
    show AuditTrailExporter, ExportFormat;
export 'src/audit_trail_theme.dart' show AuditTrailTheme;
export 'src/audit_trail_view.dart' show AuditTrailView, CollapsibleArgs;
