// A compact, embeddable audit row for sidebars and detail screens.
//
// `package:flutter/material.dart` is deprecated from Flutter 3.47 onwards
// (material_ui migration). This package supports Flutter >= 3.24, where
// material.dart is the correct import, so the analyzer hints raised by
// pub.dev's newest-SDK analysis are intentionally ignored here.
// ignore_for_file: deprecated_member_use, deprecated_import
library;

import 'package:cell_flutter_audit/src/audit_entry.dart';
import 'package:cell_flutter_audit/src/audit_trail_theme.dart';
import 'package:cell_flutter_audit/src/audit_trail_view.dart';
import 'package:flutter/material.dart';

/// A single-row summary of one [AuditEntry]: short timestamp, command
/// name, vetted status. Tapping expands the argument payload (or invokes
/// [onTap] when supplied).
class AuditEntryTile extends StatefulWidget {
  /// Creates the tile.
  const AuditEntryTile({
    required this.entry,
    this.theme = const AuditTrailTheme(),
    this.onTap,
    super.key,
  });

  /// The receipt to summarize.
  final AuditEntry entry;

  /// Styling knobs.
  final AuditTrailTheme theme;

  /// Optional tap callback. When `null`, tapping toggles the expanded
  /// argument payload.
  final VoidCallback? onTap;

  @override
  State<AuditEntryTile> createState() => _AuditEntryTileState();
}

class _AuditEntryTileState extends State<AuditEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = widget.theme;
    final borderColor =
        entry.isVetted ? theme.vettedColor : theme.unvettedColor;
    return Container(
      margin: theme.cardMargin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: borderColor, width: theme.borderWidth),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: theme.showVettedIcon
                ? Icon(
                    entry.isVetted
                        ? Icons.verified
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: borderColor,
                  )
                : null,
            title: Text(
              entry.commandName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: theme.showTimestamp
                ? Text(formatAuditTimestamp(entry.timestamp))
                : null,
            trailing: entry.txSequence == null
                ? null
                : Text(
                    '#${entry.txSequence}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
            onTap: widget.onTap ?? () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, bottom: 6),
              child: CollapsibleArgs(
                text: entry.formattedArgs,
                theme: theme,
                initiallyExpanded: true,
              ),
            ),
        ],
      ),
    );
  }
}
