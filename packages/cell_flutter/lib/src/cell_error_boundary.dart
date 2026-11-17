// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Renders a fallback instead of Flutter's error screen when a cell-driven
/// error is thrown while building the subtree below it.
///
/// [CellErrorBoundary] is the binding's **Error Boundary**. It protects a
/// subtree against the synchronous widget-lifecycle failures cells can
/// cause:
///
/// - a `CellNotifier` bound to an **invalidated cell** (thrown from
///   `CellBuilder` / `CellSelector` / `useCell*` during `initState`);
/// - a `setState`-during-build error triggered by a pulse arriving while a
///   cell-driven widget is building.
///
/// When such an error is reported, the boundary renders [onError] instead
/// of [child]; calling [CellErrorBoundaryState.reset] re-renders the child.
///
/// ### What the boundary does NOT intercept
/// Errors reported through the binding's **report channel** —
/// `FlutterError.reportError` with `library: 'cell_flutter'` (type
/// mismatches, `emitErrors: true` error pulses, `CellListener` handler
/// failures) — are **not** captured: the reporting widget already handles
/// them, and no exception was thrown. Those reports are forwarded to the
/// previously installed `FlutterError.onError`. This boundary does not
/// replace `ErrorWidget.builder`.
///
/// ### Nested boundaries
/// A captured error is consumed by the **nearest** boundary: the inner
/// boundary shows its fallback and the outer one never sees the error.
/// Reports on the `cell_flutter` channel pass through every boundary
/// unchanged.
///
/// ### Known limitation
/// The interception is global (`FlutterError.onError`) while the boundary
/// is mounted: a non-cell error thrown elsewhere in the app is attributed
/// to the boundary if it arrives first. Use the boundary as a **root**
/// safety net, not as fine-grained per-screen instrumentation.
///
/// ### Example
/// ```dart
/// CellErrorBoundary(
///   onError: (error, stack) => ErrorCard(error: error),
///   child: CellBuilder<int>(
///     cell: counter.cell,
///     builder: (_, v) => Text('$v'),
///   ),
/// );
/// ```
///
/// ### See Also:
/// - [CellErrorBoundaryState.reset] — the recovery entry point.
/// - `ErrorWidget.builder` — the Flutter mechanism this complements.
class CellErrorBoundary extends StatefulWidget {
  /// Creates a boundary around [child].
  const CellErrorBoundary({
    required this.onError,
    required this.child,
    this.onReset,
    super.key,
  });

  /// Renders the fallback when an error is caught.
  final Widget Function(Object error, StackTrace? stack) onError;

  /// The subtree to protect.
  final Widget child;

  /// Called when the boundary is reset (e.g. a "Retry" button in the
  /// fallback).
  final void Function()? onReset;

  @override
  State<CellErrorBoundary> createState() => CellErrorBoundaryState();
}

/// The state behind [CellErrorBoundary].
///
/// Obtain it through a `GlobalKey<CellErrorBoundaryState>` to call
/// [reset] — for example from a retry button inside the fallback.
class CellErrorBoundaryState extends State<CellErrorBoundary> {
  Object? _error;
  StackTrace? _stack;
  FlutterExceptionHandler? _previousOnError;

  // The exact tear-off installed on FlutterError.onError — instance-method
  // tear-offs are not `identical` across evaluations, so the dispose guard
  // must compare against this stored reference.
  late final FlutterExceptionHandler _installedHandler = _handleError;

  @override
  void initState() {
    super.initState();
    _previousOnError = FlutterError.onError;
    FlutterError.onError = _installedHandler;
  }

  /// Clears the captured error and re-renders [CellErrorBoundary.child].
  ///
  /// Also invokes [CellErrorBoundary.onReset] when provided.
  ///
  /// The restoration is deferred to a post-frame callback: the retry
  /// button inside the fallback is focused when tapped, and unmounting a
  /// focused subtree synchronously inside the pointer event leaks its
  /// `_FocusInheritedScope` dependency (asserted by the framework when
  /// the enclosing route later unmounts). Deferring removes the fallback
  /// in a clean frame. Callers that need the child back synchronously
  /// should pump one frame after calling [reset].
  void reset() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
        _stack = null;
      });
      widget.onReset?.call();
    });
    // Guarantee a frame so the post-frame callback actually runs even
    // when reset() is called between frames.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Libraries whose errors are thrown by the widget/scheduler framework
  /// while building — the only errors this boundary captures. Everything
  /// else (the binding's report channel, the test framework's own failure
  /// reports, app-level reports) is forwarded to the previous handler.
  static const Set<String> _capturedLibraries = {
    'widgets library',
    'scheduler library',
    'rendering library',
  };

  void _handleError(FlutterErrorDetails details) {
    // Forward everything that is not a framework-thrown build error: the
    // binding's report channel (type mismatches, emitErrors pulses,
    // listener-handler failures) and the test framework's own failure
    // reports must reach the previously installed handler.
    if (!_capturedLibraries.contains(details.library)) {
      _previousOnError?.call(details);
      return;
    }
    // A second error after the fallback is showing is forwarded so it is
    // not silently swallowed.
    if (_error != null || !mounted) {
      _previousOnError?.call(details);
      return;
    }
    void capture() {
      if (!mounted || _error != null) return;
      setState(() {
        _error = details.exception;
        _stack = details.stack;
      });
    }

    if (isCellBuildPhaseNow()) {
      // A build-phase error cannot setState synchronously; capture after
      // the frame. The failed element shows Flutter's ErrorWidget for one
      // frame, then the fallback replaces the whole subtree.
      SchedulerBinding.instance.addPostFrameCallback((_) => capture());
    } else {
      capture();
    }
  }

  /// The phase check for this file (kept local to avoid coupling the
  /// boundary to the widget-layer deferral helpers).
  bool isCellBuildPhaseNow() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
  }

  @override
  void dispose() {
    if (identical(FlutterError.onError, _installedHandler)) {
      FlutterError.onError = _previousOnError!;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.onError(error, _stack);
    }
    return widget.child;
  }
}
