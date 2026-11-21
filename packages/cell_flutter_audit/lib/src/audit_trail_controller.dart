// The data controller behind the audit widgets.
//
// `ApplyLedger` mints receipts; it does not store them. Your code owns the
// history — collect it however you like, then hand it to this controller
// as a list, a stream, or one [ApplyOutcome] at a time:
//
// ```dart
// final controller = AuditTrailController();
// final outcome = await cell.apply(command);
// controller.addOutcome(outcome);          // accepted/staged/rejected
// ```
library;

import 'dart:async';

import 'package:cell/cell.dart';
import 'package:flutter/foundation.dart';

import 'audit_entry.dart';
import 'audit_rejection_event.dart';

/// The fields [AuditTrailController.sortBy] can order by.
enum SortField { timestamp, commandName, vetted }

/// Holds the audit history, applies filters/search/sort, and pages the
/// visible window for large ledgers.
///
/// The controller accepts receipts through three equally valid paths:
///
/// * a `List<ApplyReceipt>` passed to the constructor,
/// * a `Stream<ApplyReceipt>` of live receipts,
/// * [addReceipt] / [addOutcome] calls from your apply pipeline.
///
/// Rejections are **not** in the ledger. [ApplyRejected] outcomes passed
/// to [addOutcome] are stored separately as [RejectionEvent]s, which
/// [AuditTrailView] optionally interleaves into the timeline.
class AuditTrailController extends ChangeNotifier {
  /// Creates the controller from an optional initial [receipts] list and
  /// an optional live [stream] of receipts.
  AuditTrailController({
    List<ApplyReceipt> receipts = const [],
    Stream<ApplyReceipt>? stream,
  }) : _receipts = List.of(receipts) {
    if (stream != null) {
      _subscription = stream.listen(addReceipt);
    }
  }

  final List<ApplyReceipt> _receipts;
  final List<RejectionEvent> _rejections = [];
  StreamSubscription<ApplyReceipt>? _subscription;

  String? _commandNameFilter;
  bool _commandNameExact = false;
  bool? _vettedFilter;
  DateTime? _afterFilter;
  DateTime? _beforeFilter;
  String? _searchQuery;

  SortField _sortField = SortField.timestamp;
  bool _ascending = false;

  /// The number of matching entries currently visible. [loadMore] grows it.
  int _visibleLimit = 50;

  /// Every receipt currently held by the controller, in append order.
  List<ApplyReceipt> get receipts => List.unmodifiable(_receipts);

  /// Every receipt as a display entry, in append order (unfiltered).
  List<AuditEntry> get entries =>
      _receipts.map(AuditEntry.fromReceipt).toList();

  /// The denial events recorded so far, oldest first.
  List<RejectionEvent> get rejections => List.unmodifiable(_rejections);

  /// The current filter/search/sort applied to [entries], truncated to the
  /// current [visibleLimit].
  List<AuditEntry> get filteredEntries {
    final result = entries.where(_matches).toList();
    result.sort(_compare);
    if (result.length <= _visibleLimit) return result;
    return result.sublist(0, _visibleLimit);
  }

  /// The total number of entries matching the current filter and search,
  /// before pagination.
  int get totalMatches => entries.where(_matches).length;

  /// Whether more matching entries exist beyond [filteredEntries].
  bool get hasMore => totalMatches > _visibleLimit;

  /// The number of entries [filteredEntries] may show.
  int get visibleLimit => _visibleLimit;

  /// The active sort field.
  SortField get sortField => _sortField;

  /// Whether the active sort is ascending.
  bool get isAscending => _ascending;

  /// Appends one receipt and notifies listeners.
  void addReceipt(ApplyReceipt receipt) {
    _receipts.add(receipt);
    notifyListeners();
  }

  /// Appends a receipt and notifies listeners, in one synchronous step.
  void addReceipts(Iterable<ApplyReceipt> receipts) {
    _receipts.addAll(receipts);
    notifyListeners();
  }

  /// Records a denial event and notifies listeners. Use this when the gate
  /// itself supplied no reason and your UI wants to show one.
  void addRejection(RejectionEvent event) {
    _rejections.add(event);
    notifyListeners();
  }

  /// Records an apply outcome:
  ///
  /// * [ApplyAccepted] and [ApplyStaged] → the receipt joins the timeline.
  /// * [ApplyRejected] → a [RejectionEvent] is recorded instead; the
  ///   command never ran, so it is not part of the receipt timeline.
  void addOutcome(ApplyOutcome<Object?> outcome) {
    switch (outcome) {
      case ApplyAccepted<Object?>():
        _receipts.add(outcome.receipt);
      case ApplyStaged():
        _receipts.add(outcome.receipt);
      case ApplyRejected<Object?>():
        _rejections.add(RejectionEvent.fromOutcome(outcome));
    }
    notifyListeners();
  }

  /// Filters by command name (substring by default; [exact] for equality),
  /// vetted status, and/or an inclusive time range.
  void filterBy({
    String? commandName,
    bool? vetted,
    DateTime? after,
    DateTime? before,
    bool exact = false,
  }) {
    _commandNameFilter = commandName;
    _commandNameExact = exact;
    _vettedFilter = vetted;
    _afterFilter = after;
    _beforeFilter = before;
    notifyListeners();
  }

  /// Removes all filters (keeps the search query — use [search] with an
  /// empty string to clear that too).
  void clearFilters() {
    _commandNameFilter = null;
    _commandNameExact = false;
    _vettedFilter = null;
    _afterFilter = null;
    _beforeFilter = null;
    notifyListeners();
  }

  /// Sets the full-text search query, matched case-insensitively against
  /// the command name and the formatted arguments. An empty query clears
  /// the search.
  void search(String query) {
    _searchQuery = query.trim().isEmpty ? null : query.trim().toLowerCase();
    notifyListeners();
  }

  /// Sorts by [field]; [ascending] defaults to `false` (newest/largest
  /// first).
  void sortBy(SortField field, {bool ascending = false}) {
    _sortField = field;
    _ascending = ascending;
    notifyListeners();
  }

  /// Grows the visible window by [pageSize] entries. Returns `true` when
  /// more entries became visible.
  Future<void> loadMore({int pageSize = 50}) async {
    _visibleLimit += pageSize;
    notifyListeners();
  }

  /// Drops every receipt, rejection, and filter.
  void clear() {
    _receipts.clear();
    _rejections.clear();
    clearFilters();
    search('');
    _visibleLimit = 50;
    notifyListeners();
  }

  bool _matches(AuditEntry entry) {
    if (_commandNameFilter != null) {
      final name = entry.commandName;
      final filter = _commandNameFilter!;
      final hit = _commandNameExact ? name == filter : name.contains(filter);
      if (!hit) return false;
    }
    if (_vettedFilter != null && entry.isVetted != _vettedFilter) {
      return false;
    }
    if (_afterFilter != null && entry.timestamp.isBefore(_afterFilter!)) {
      return false;
    }
    if (_beforeFilter != null && entry.timestamp.isAfter(_beforeFilter!)) {
      return false;
    }
    if (_searchQuery != null) {
      final haystack =
          '${entry.commandName} ${entry.formattedArgs ?? ''}'.toLowerCase();
      if (!haystack.contains(_searchQuery!)) return false;
    }
    return true;
  }

  int _compare(AuditEntry a, AuditEntry b) {
    final int result = switch (_sortField) {
      SortField.timestamp => a.timestamp.compareTo(b.timestamp),
      SortField.commandName => a.commandName.toLowerCase().compareTo(
            b.commandName.toLowerCase(),
          ),
      SortField.vetted => (a.isVetted ? 1 : 0).compareTo(b.isVetted ? 1 : 0),
    };
    return _ascending ? result : -result;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
