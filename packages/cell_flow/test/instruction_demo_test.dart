// Copyright (c) 2025-Present Lee Man Hoi Simon. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT or Apache-2.0 license that can be found in the LICENSE file.

/// Runs each instruction file's demo `main()` so those bodies count toward
/// `lib/` line coverage. Demos print to stdout; that is expected.
library;


import 'package:cell_flow/src/instruction/async_expand.dart'
    as async_expand;
import 'package:cell_flow/src/instruction/async_fold.dart' as async_fold;
import 'package:cell_flow/src/instruction/async_map.dart' as async_map;
import 'package:cell_flow/src/instruction/buffer.dart' as buffer;
import 'package:cell_flow/src/instruction/combine_latest.dart'
    as combine_latest;
import 'package:cell_flow/src/instruction/concat.dart' as concat;
import 'package:cell_flow/src/instruction/concat_map.dart' as concat_map;
import 'package:cell_flow/src/instruction/debounce.dart' as debounce;
import 'package:cell_flow/src/instruction/delay.dart' as delay;
import 'package:cell_flow/src/instruction/distinct.dart' as distinct;
import 'package:cell_flow/src/instruction/exhaust_map.dart'
    as exhaust_map;
import 'package:cell_flow/src/instruction/filter.dart' as filter;
import 'package:cell_flow/src/instruction/from_future.dart'
    as from_future;
import 'package:cell_flow/src/instruction/from_stream.dart'
    as from_stream;
import 'package:cell_flow/src/instruction/group_by.dart' as group_by;
import 'package:cell_flow/src/instruction/interval.dart' as interval;
import 'package:cell_flow/src/instruction/map.dart' as map_ops;
import 'package:cell_flow/src/instruction/merge.dart' as merge;
import 'package:cell_flow/src/instruction/merge_map.dart' as merge_map;
import 'package:cell_flow/src/instruction/of.dart' as of_ops;
import 'package:cell_flow/src/instruction/pairwise.dart' as pairwise;
import 'package:cell_flow/src/instruction/partition.dart' as partition;
import 'package:cell_flow/src/instruction/pluck.dart' as pluck;
import 'package:cell_flow/src/instruction/race.dart' as race;
import 'package:cell_flow/src/instruction/reduce.dart' as reduce;
import 'package:cell_flow/src/instruction/retry.dart' as retry;
import 'package:cell_flow/src/instruction/routing.dart' as routing;
import 'package:cell_flow/src/instruction/sample.dart' as sample;
import 'package:cell_flow/src/instruction/scan.dart' as scan;
import 'package:cell_flow/src/instruction/share.dart' as share;
import 'package:cell_flow/src/instruction/skip.dart' as skip;
import 'package:cell_flow/src/instruction/start_with.dart' as start_with;
import 'package:cell_flow/src/instruction/switch_map.dart' as switch_map;
import 'package:cell_flow/src/instruction/take.dart' as take;
import 'package:cell_flow/src/instruction/tap.dart' as tap;
import 'package:cell_flow/src/instruction/throttle.dart' as throttle;
import 'package:cell_flow/src/instruction/timeout.dart' as timeout;
import 'package:cell_flow/src/instruction/window.dart' as window;
import 'package:cell_flow/src/instruction/zip.dart' as zip;
import 'package:test/test.dart';

void main() {
  Timeout? demoTimeout() => Timeout(const Duration(seconds: 20));

  group('instruction demo mains emit through bodies', () {
    test('tap', tap.main, timeout: demoTimeout());
    test('routing', routing.main, timeout: demoTimeout());
    test('of', of_ops.main, timeout: demoTimeout());
    test('delay', delay.main, timeout: demoTimeout());
    test('partition', partition.main, timeout: demoTimeout());
    test('map', map_ops.main, timeout: demoTimeout());
    test('merge', merge.main, timeout: demoTimeout());
    test('skip', skip.main, timeout: demoTimeout());
    test('start_with', start_with.main, timeout: demoTimeout());
    test('reduce', reduce.main, timeout: demoTimeout());
    test('take', take.main, timeout: demoTimeout());
    test('retry', retry.main, timeout: demoTimeout());
    test('timeout', timeout.main, timeout: demoTimeout());
    test('sample', sample.main, timeout: demoTimeout());
    test('throttle', throttle.main, timeout: demoTimeout());
    test('share', share.main, timeout: demoTimeout());
    test('pluck', pluck.main, timeout: demoTimeout());
    test('group_by', group_by.main, timeout: demoTimeout());
    test('scan', scan.main, timeout: demoTimeout());
    test('filter', filter.main, timeout: demoTimeout());
    test('distinct', distinct.main, timeout: demoTimeout());
    test('buffer', buffer.main, timeout: demoTimeout());
    test('window', window.main, timeout: demoTimeout());
    test('zip', zip.main, timeout: demoTimeout());
    test('pairwise', pairwise.main, timeout: demoTimeout());
    test('concat', concat.main, timeout: demoTimeout());
    test('concat_map', concat_map.main, timeout: demoTimeout());
    test('merge_map', merge_map.main, timeout: demoTimeout());
    test('switch_map', switch_map.main, timeout: demoTimeout());
    test('exhaust_map', exhaust_map.main, timeout: demoTimeout());
    test('async_map', async_map.main, timeout: demoTimeout());
    test('async_expand', async_expand.main, timeout: demoTimeout());
    test('async_fold', async_fold.main, timeout: demoTimeout());
    test('combine_latest', combine_latest.main, timeout: demoTimeout());
    test('debounce', debounce.main, timeout: demoTimeout());
    test('interval', interval.main, timeout: demoTimeout());
    test('from_stream', from_stream.main, timeout: demoTimeout());
    test('race', race.main, timeout: demoTimeout());
    test(
      'from_future',
      from_future.main,
      timeout: Timeout(const Duration(seconds: 90)),
    );
  });
}
