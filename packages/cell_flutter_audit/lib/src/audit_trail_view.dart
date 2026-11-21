// The primary widget: a scrollable, filterable receipt timeline.
library;

import 'package:cell_flutter_audit/src/audit_entry.dart';
import 'package:cell_flutter_audit/src/audit_rejection_event.dart';
import 'package:cell_flutter_audit/src/audit_trail_controller.dart';
import 'package:cell_flutter_audit/src/audit_trail_theme.dart';
import 'package:flutter/material.dart';

/// A scrollable timeline of [AuditEntry] cards, driven by an
/// [AuditTrailController].
///
/// Accepted receipts render with a green (vetted) or amber (unvetted)
/// left border; [RejectionEvent]s recorded by the controller render with a
/// red border when [showRejections] is enabled. Argument payloads are
/// collapsible, ids are monospace and truncated, and the newest entry can
/// auto-scroll into view.
class AuditTrailView extends StatefulWidget {
  /// Creates the timeline.
  const AuditTrailView({
    required this.controller,
    this.theme = const AuditTrailTheme(),
    this.autoScroll,
    this.showRejections = true,
    super.key,
  });

  /// The data controller. The view rebuilds on every controller change.
  final AuditTrailController controller;

  /// Styling knobs; defaults to a Material-3-friendly [AuditTrailTheme].
  final AuditTrailTheme theme;

  /// Overrides [AuditTrailTheme.autoScroll] when non-null.
  final bool? autoScroll;

  /// Whether [RejectionEvent]s recorded by the controller are interleaved
  /// into the timeline as red cards.
  final bool showRejections;

  @override
  State<AuditTrailView> createState() => _AuditTrailViewState();
}

class _AuditTrailViewState extends State<AuditTrailView> {
  final ScrollController _scroll = ScrollController();
  int _lastItemCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final entries = widget.controller.filteredEntries;
        final rejections =
            widget.showRejections ? widget.controller.rejections : const <RejectionEvent>[];
        final items = _merge(entries, rejections);

        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.theme.emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        final scrollToNewest =
            widget.autoScroll ?? widget.theme.autoScroll;
        if (scrollToNewest && items.length > _lastItemCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          });
        }
        _lastItemCount = items.length;

        return ListView.builder(
          controller: _scroll,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.rejection != null) {
              return _RejectionCard(
                event: item.rejection!,
                theme: widget.theme,
              );
            }
            return _AuditEntryCard(
              entry: item.entry!,
              theme: widget.theme,
            );
          },
        );
      },
    );
  }

  /// Merges entries and rejections into one timestamp-ordered display
  /// list. Direction follows the controller's sort when it sorts by
  /// timestamp; otherwise newest-first.
  List<_DisplayItem> _merge(
    List<AuditEntry> entries,
    List<RejectionEvent> rejections,
  ) {
    final ascending = widget.controller.sortField == SortField.timestamp &&
        widget.controller.isAscending;
    final items = [
      for (final e in entries) _DisplayItem(entry: e),
      for (final r in rejections) _DisplayItem(rejection: r),
    ];
    items.sort((a, b) {
      final result =
          a.timestamp.isBefore(b.timestamp) ? -1 : (a.timestamp == b.timestamp ? 0 : 1);
      return ascending ? result : -result;
    });
    return items;
  }
}

class _DisplayItem {
  _DisplayItem({this.entry, this.rejection});

  final AuditEntry? entry;
  final RejectionEvent? rejection;

  DateTime get timestamp =>
      entry?.timestamp ?? rejection!.timestamp;
}

/// One accepted-receipt card: colored left border, command/timestamp/
/// vetted header, truncated monospace id, transaction chip, and a
/// collapsible argument payload.
class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry, required this.theme});

  final AuditEntry entry;
  final AuditTrailTheme theme;

  @override
  Widget build(BuildContext context) {
    final borderColor = entry.isVetted ? theme.vettedColor : theme.unvettedColor;
    return Card(
      margin: theme.cardMargin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: theme.cardPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: borderColor, width: theme.borderWidth),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  entry.commandName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (theme.showTimestamp)
                  Text(
                    formatAuditTimestamp(entry.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (theme.showVettedIcon)
                  _VettedIcon(vetted: entry.isVetted, theme: theme),
              ],
            ),
            if (theme.showId)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tooltip(
                  message: entry.fullId,
                  triggerMode: TooltipTriggerMode.tap,
                  child: Text(
                    entry.displayId,
                    style: TextStyle(
                      fontFamily: theme.monospaceFont,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (entry.txSequence != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'tx #${entry.txSequence}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CollapsibleArgs(
                text: entry.formattedArgs,
                theme: theme,
                emptyLabel: 'No arguments',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rejected-command card: red border and the gate's reason.
class _RejectionCard extends StatelessWidget {
  const _RejectionCard({required this.event, required this.theme});

  final RejectionEvent event;
  final AuditTrailTheme theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: theme.cardMargin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: theme.cardPadding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: theme.rejectedColor, width: theme.borderWidth),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '✗ ${event.commandName}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.rejectedColor,
                      ),
                ),
                if (theme.showTimestamp)
                  Text(
                    formatAuditTimestamp(event.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Rejected by the integrity gate'
                '${event.reason == null ? '' : ': ${event.reason}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CollapsibleArgs(
                text: formatArguments(event.receipt.arguments),
                theme: theme,
                emptyLabel: 'No arguments',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The vetted ✓ / ✗ status icon with its status color.
class _VettedIcon extends StatelessWidget {
  const _VettedIcon({required this.vetted, required this.theme});

  final bool vetted;
  final AuditTrailTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = vetted ? theme.vettedColor : theme.unvettedColor;
    return Icon(
      vetted ? Icons.verified : Icons.remove_circle_outline,
      size: 16,
      color: color,
      semanticLabel: vetted ? 'Vetted' : 'Unvetted',
    );
  }
}

/// A tap-to-expand monospace payload. Shows [emptyLabel] when [text] is
/// null, and `[text]` otherwise; tapping toggles the expanded state.
class CollapsibleArgs extends StatefulWidget {
  /// Creates the collapsible payload.
  const CollapsibleArgs({
    required this.text,
    required this.theme,
    this.emptyLabel = 'No arguments',
    this.initiallyExpanded = false,
    super.key,
  });

  /// The pre-formatted payload, or `null` for the empty state.
  final String? text;

  /// Styling knobs (used for the monospace font).
  final AuditTrailTheme theme;

  /// Label shown when [text] is null.
  final String emptyLabel;

  /// Whether the payload starts expanded.
  final bool initiallyExpanded;

  @override
  State<CollapsibleArgs> createState() => _CollapsibleArgsState();
}

class _CollapsibleArgsState extends State<CollapsibleArgs> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final body = widget.text ?? widget.emptyLabel;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _expanded
                    ? body
                    : widget.text == null
                        ? widget.emptyLabel
                        : '${body.length > 48 ? '${body.substring(0, 48)}…' : body}  (tap to expand)',
                style: TextStyle(
                  fontFamily: widget.theme.monospaceFont,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
