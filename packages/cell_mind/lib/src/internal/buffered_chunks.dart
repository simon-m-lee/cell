// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

part of '../../cell_mind.dart';

/// Coalesces chunks arriving within [window] into joined emissions.
///
/// ### Non-obvious
/// - **Not lossy** — every chunk lands in exactly one emission.
/// - The pending buffer flushes on `onDone` and on error.
/// - Cancelling the output stream cancels the source subscription and
///   the pending timer.
Stream<String> _bufferedChunks(Stream<String> source, Duration window) {
  final controller = StreamController<String>();
  final buffer = <String>[];
  Timer? timer;

  void flush() {
    if (buffer.isEmpty) return;
    controller.add(buffer.join());
    buffer.clear();
  }

  final sub = source.listen(
    (chunk) {
      buffer.add(chunk);
      timer?.cancel();
      timer = Timer(window, flush);
    },
    onDone: () {
      timer?.cancel();
      flush();
      controller.close();
    },
    onError: (Object e, StackTrace st) {
      timer?.cancel();
      flush();
      controller.addError(e, st);
    },
  );

  controller.onCancel = () {
    timer?.cancel();
    return sub.cancel();
  };

  return controller.stream;
}
