// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell/cell.dart';
import 'package:flutter/scheduler.dart';

/// True while Flutter is building or flushing the microtasks it queued
/// mid-frame. `setState` from a cell pulse in either phase throws.
bool get isCellBuildPhase {
  final phase = SchedulerBinding.instance.schedulerPhase;
  return phase == SchedulerPhase.midFrameMicrotasks ||
      phase == SchedulerPhase.persistentCallbacks;
}

/// Runs [action] now, or after the current frame if called during build.
void runAfterBuild(void Function() action) {
  if (!isCellBuildPhase) {
    action();
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => action());
}

/// Last value this binding can see without a private cell API.
///
/// [ValueCell] stores that value on [ValueCell.value]. Plain cells
/// (`fromFuture`, `fromStream`, `asyncMap`, `derive`) do not expose a
/// retained pulse on the `Cell` type this package resolves, so this
/// returns null and the widget waits for the next pulse.
Pulse<Object?>? retainedPulseOf(Cell cell) {
  if (cell is ValueCell<dynamic>) {
    return Pulse<Object?>(cell.value);
  }
  return null;
}
