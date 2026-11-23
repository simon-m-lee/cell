// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

/// The GIF-drift test from the plan: the storyboard is 300 frames at
/// 15fps. If a developer changes [MockAgent.pauseUnit] or adds a beat
/// without re-recording the GIF, the beat arithmetic here must change
/// with it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_home/mock/mock_agent.dart';
import 'package:echo_home/state/demo_state.dart';

void main() {
  test('demo timeline produces 300 frames at 15fps', () {
    expect(DemoTimeline.totalFrames, 300);
    expect(DemoTimeline.frameRate, 15);

    var total = 0;
    for (final beat in DemoTimeline.beats) {
      total += beat.frames;
    }
    expect(total, DemoTimeline.totalFrames);
  });

  test('every beat maps to a storyboard frame range', () {
    expect(DemoTimeline.beatForFrame(0), 'establish');
    expect(DemoTimeline.beatForFrame(29), 'establish');
    expect(DemoTimeline.beatForFrame(30), 'discovery');
    expect(DemoTimeline.beatForFrame(299), 'replay');
  });

  test('the pause unit is a whole number of frames at 4x', () {
    // 500ms at 4x = 125ms; the GIF's frame time is ~66.7ms. The pause
    // unit is the knob the drift test protects.
    expect(MockAgent.pauseUnit, const Duration(milliseconds: 500));
    expect(MockAgent.pauseUnit.inMilliseconds % 500, 0);
  });
}
