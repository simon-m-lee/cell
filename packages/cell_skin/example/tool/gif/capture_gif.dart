// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Captures the animated GIF embedded in the cell_skin README.
//
// This is a capture tool, not a unit test. Run it explicitly:
//
//   flutter test tool/gif/capture_gif.dart --dart-define=DEMO_RECORDING=true
//
// It boots the REAL Echo Home scenario (graph, membrane, REST adapter,
// scripted agent) inside the flutter_test rasterizer, captures the
// rendered screen at ~8 fps while the timeline plays, triggers the
// real "Verify & Replay" overlay, and encodes the frames as
// ../doc/demo/echo_home.gif — the file the package README embeds.
//
// The GIF is 640x400, loops forever, and never drops below the beats
// the README promises: discovery, accepted, rejected, batched,
// verified.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cell/cell.dart' show CellGraphRegistry;
import 'package:echo_home/mock/mock_scenario.dart';
import 'package:echo_home/screens/demo_screen.dart';
import 'package:echo_home/state/demo_state.dart';
import 'package:echo_home/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const int _tickMs = 125; // ~8 fps wall-clock capture.
const int _maxTicks = 160; // ~20 seconds, a generous ceiling.
const int _gifWidth = 640;
const int _gifHeight = 400;

Future<void> main() async {
  testWidgets('capture the Echo Home demo as an animated GIF',
      (tester) async {
    await _loadRealFonts();
    // ignore: invalid_use_of_visible_for_testing_member
    CellGraphRegistry.forceReset();

    final scenario = MockScenario();
    await tester.runAsync(scenario.start);
    addTearDown(() async {
      await tester.runAsync(scenario.dispose);
    });

    // Capture at a comfortable logical size (aspect 1.6) and downscale
    // during encoding. Both setters fire before the first pump so the
    // test surface matches exactly.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    // ignore: avoid_print
    print('capture surface: ${tester.view.physicalSize} @ '
        '${tester.view.devicePixelRatio}x');

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: RepaintBoundary(
        key: boundaryKey,
        child: DemoScreen(scenario: scenario, onRestart: () {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: _tickMs));

    final frames = <img.Image>[];
    var storyFrame = 0;
    var replayStarted = false;
    var replayTail = 0;

    for (var tick = 0; tick < _maxTicks; tick++) {
      // Let the real scenario advance on the wall clock, then advance
      // the test clock so UI animations (AnimatedSwitcher card rolls,
      // flash pulses) run to completion — a plain pump() would freeze
      // the outgoing value on top of the new one.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: _tickMs)));
      await tester.pump(const Duration(milliseconds: _tickMs));

      // The recording-mode frame marker: 15fps storyboard time at 4x
      // playback is ~60 storyboard frames per second, ~7.5 per tick.
      storyFrame = (storyFrame + 8) % DemoTimeline.totalFrames;
      scenario.state.frameLabel
          .update(MockScenario.frameLabel(storyFrame));

      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final width = image.width;
        final height = image.height;
        final data =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        final frame = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: data!.buffer,
          order: img.ChannelOrder.rgba,
          numChannels: 4,
        );
        frames.add(img.copyResize(
          frame,
          width: _gifWidth,
          height: _gifHeight,
          interpolation: img.Interpolation.average,
        ));
      });
      await tester.pump();

      // Once the scripted timeline finishes, run the real replay so the
      // GIF ends on the "Verified" beat with the overlay visible.
      if (!replayStarted &&
          !scenario.isRunning &&
          (scenario.state.ledgerSeq.cell.value ?? -1) >= 2) {
        replayStarted = true;
        await tester.runAsync(scenario.verifyAndReplay);
      }
      if (replayStarted) {
        if (scenario.state.replayDivergences.cell.value != null) {
          replayTail++;
        }
        // ~1.2s of the completed overlay, then stop.
        if (replayTail >= 10) break;
      }
    }

    expect(frames, isNotEmpty, reason: 'the capture must produce frames');
    expect(scenario.state.replayDivergences.cell.value, 0,
        reason: 'the GIF must end on a zero-divergence replay');
    expect(scenario.state.doorDenials.cell.value, 1,
        reason: 'the GIF must show the real door rejection');
    // ignore: avoid_print
    print('debug cells: thermostat=${scenario.home.thermostat.cell.value} '
        'light=${scenario.home.light.cell.value} '
        'lightColor=${scenario.home.lightColor.cell.value} '
        'transcript=${scenario.state.transcript.cell.value?.length} '
        'ledgerRows=${scenario.state.ledgerRows.cell.value?.length} '
        'ledgerSeq=${scenario.state.ledgerSeq.cell.value} '
        'replayEntries=${scenario.state.replayEntries.cell.value}');

    // Preview frames at a few points in the capture for sanity checks.
    final outputDir = Directory('../doc/demo');
    outputDir.createSync(recursive: true);
    for (final (label, index) in [
      ('early', frames.length ~/ 8),
      ('mid', frames.length ~/ 2),
      ('late', frames.length - 2),
    ]) {
      final preview = img.copyResize(frames[index],
          width: _gifWidth, height: _gifHeight);
      File('${outputDir.path}/echo_home_preview_$label.png')
          .writeAsBytesSync(img.encodePng(preview));
    }

    final encoder = img.GifEncoder(
      delay: _tickMs,
      repeat: 0,
      samplingFactor: 10,
    );
    for (final frame in frames) {
      encoder.addFrame(frame);
    }
    final gif = encoder.finish();
    expect(gif, isNotNull);

    final output = File('../doc/demo/echo_home.gif');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(gif!);
    // ignore: avoid_print
    print('Wrote ${output.path} (${gif.length} bytes, '
        '${frames.length} frames).');
  });
}

/// The test rasterizer normally renders every glyph as a solid block
/// (the FlutterTest font). Loading the real UI font and the Material
/// icon font under their expected family names makes the captured
/// frames legible.
Future<void> _loadRealFonts() async {
  final candidates = <(String, String)>[
    if (Platform.isWindows) ('Roboto', r'C:\Windows\Fonts\segoeui.ttf'),
  ];
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    candidates.add((
      'MaterialIcons',
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
          'MaterialIcons-Regular.otf',
    ));
  }
  for (final (family, path) in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(
          ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }
}
