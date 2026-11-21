// The ledger timeline: summary panel, filter bar, receipt rows, and the
// live indicator. Polls `ext.cell.getLedger` every 500ms by default.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'ledger_model.dart';

/// Time-range filter buckets.
enum TimeRange {
  lastMinute('Last 1 min'),
  last5Minutes('Last 5 min'),
  last30Minutes('Last 30 min'),
  all('All');

  const TimeRange(this.label);

  final String label;
}

/// The extension's main view.
class LedgerView extends StatefulWidget {
  const LedgerView({
    required this.fetch,
    super.key,
    this.pollInterval = const Duration(milliseconds: 500),
  });

  /// The fetch path. `main.dart` passes `ServiceLedgerClient.fetch` (the
  /// real VM-service call); tests inject fakes.
  final Future<DevtoolsLedgerSnapshot?> Function() fetch;

  /// How often the view polls for new receipts.
  final Duration pollInterval;

  @override
  State<LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends State<LedgerView> {
  static const _emptyMessage =
      "No receipts yet. Make a change to your app's cells to see it here.";
  static const _errorMessage = 'Could not connect to the Cell ledger. '
      'Make sure your app calls `registerCellDevTools` in `main()`.';

  List<DevtoolsLedgerEntry> _entries = [];
  List<DevtoolsRejectionEntry> _rejections = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _commandFilter = TextEditingController();
  bool? _vettedFilter;
  TimeRange _timeRange = TimeRange.all;

  Timer? _pollTimer;
  Timer? _flashTimer;
  bool _liveFlash = false;
  int _lastCount = 0;
  bool _firstFetch = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _flashTimer?.cancel();
    _commandFilter.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final snapshot = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        if (snapshot != null) {
          final grew = snapshot.entries.length > _lastCount;
          _entries = List.of(snapshot.entries);
          _rejections = List.of(snapshot.rejections);
          if (grew && !_firstFetch) _flash();
          _lastCount = snapshot.entries.length;
        }
        _firstFetch = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
        _firstFetch = false;
      });
    }
  }

  void _flash() {
    _flashTimer?.cancel();
    setState(() => _liveFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _liveFlash = false);
    });
  }

  List<DevtoolsLedgerEntry> get _filtered {
    final query = _commandFilter.text.trim().toLowerCase();
    final now = DateTime.now();
    final cutoff = switch (_timeRange) {
      TimeRange.lastMinute => now.subtract(const Duration(minutes: 1)),
      TimeRange.last5Minutes => now.subtract(const Duration(minutes: 5)),
      TimeRange.last30Minutes => now.subtract(const Duration(minutes: 30)),
      TimeRange.all => null,
    };
    final result = _entries.where((entry) {
      if (query.isNotEmpty &&
          !entry.functionName.toLowerCase().contains(query)) {
        return false;
      }
      if (_vettedFilter != null && entry.vetted != _vettedFilter) {
        return false;
      }
      if (cutoff != null && entry.timestamp.isBefore(cutoff)) return false;
      return true;
    }).toList();
    // Newest first.
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  int get _lastMinuteCount {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    return _entries.where((e) => !e.timestamp.isBefore(cutoff)).length;
  }

  void _clearFilters() {
    setState(() {
      _commandFilter.clear();
      _vettedFilter = null;
      _timeRange = TimeRange.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty && _error != null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(_errorMessage, textAlign: TextAlign.center),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(_emptyMessage, textAlign: TextAlign.center),
        ),
      );
    }

    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryPanel(
          total: _entries.length,
          lastMinute: _lastMinuteCount,
          rejected: _rejections.length,
          liveFlash: _liveFlash,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        _FilterBar(
          commandFilter: _commandFilter,
          vettedFilter: _vettedFilter,
          timeRange: _timeRange,
          onCommandChanged: () => setState(() {}),
          onVettedChanged: (value) => setState(() => _vettedFilter = value),
          onTimeRangeChanged: (value) => setState(() => _timeRange = value),
          onClear: _clearFilters,
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No receipts match the filters.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _LedgerRow(entry: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.total,
    required this.lastMinute,
    required this.rejected,
    required this.liveFlash,
  });

  final int total;
  final int lastMinute;
  final int rejected;
  final bool liveFlash;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Total: $total', style: labelStyle),
          ),
          Expanded(
            child: Text('Last 1 min: $lastMinute', style: labelStyle),
          ),
          Expanded(
            child: Text('Rejected: $rejected', style: labelStyle),
          ),
          AnimatedOpacity(
            opacity: liveFlash ? 1 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.green),
                const SizedBox(width: 4),
                Text('live', style: labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.commandFilter,
    required this.vettedFilter,
    required this.timeRange,
    required this.onCommandChanged,
    required this.onVettedChanged,
    required this.onTimeRangeChanged,
    required this.onClear,
  });

  final TextEditingController commandFilter;
  final bool? vettedFilter;
  final TimeRange timeRange;
  final VoidCallback onCommandChanged;
  final ValueChanged<bool?> onVettedChanged;
  final ValueChanged<TimeRange> onTimeRangeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              key: const Key('command-filter'),
              controller: commandFilter,
              onChanged: (_) => onCommandChanged(),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Command',
                hintText: 'e.g. add',
              ),
            ),
          ),
          DropdownButton<bool?>(
            key: const Key('vetted-filter'),
            value: vettedFilter,
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: true, child: Text('Vetted')),
              DropdownMenuItem(value: false, child: Text('Unvetted')),
            ],
            onChanged: onVettedChanged,
          ),
          DropdownButton<TimeRange>(
            key: const Key('time-filter'),
            value: timeRange,
            items: [
              for (final range in TimeRange.values)
                DropdownMenuItem(value: range, child: Text(range.label)),
            ],
            onChanged: (value) {
              if (value != null) onTimeRangeChanged(value);
            },
          ),
          TextButton(
            key: const Key('clear-filters'),
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatefulWidget {
  const _LedgerRow({required this.entry});

  final DevtoolsLedgerEntry entry;

  @override
  State<_LedgerRow> createState() => _LedgerRowState();
}

class _LedgerRowState extends State<_LedgerRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final vettedColor =
        entry.vetted ? const Color(0xFF2E7D32) : const Color(0xFFF9A825);
    return InkWell(
      key: ValueKey('ledger-row-${entry.id}'),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatTimestamp(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  entry.functionName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  entry.displayId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                Icon(
                  entry.vetted ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: vettedColor,
                  semanticLabel: entry.vetted ? 'Vetted' : 'Unvetted',
                ),
                if (entry.txSequence != null)
                  Text(
                    '#${entry.txSequence}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                if (formatArguments(entry.arguments).isNotEmpty)
                  Text(
                    formatArguments(entry.arguments),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(entry.raw),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
