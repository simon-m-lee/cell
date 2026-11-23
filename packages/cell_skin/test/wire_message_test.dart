// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'dart:convert';

import 'package:cell/cell.dart';
import 'package:cell_skin/cell_skin.dart';
import 'package:test/test.dart';

void main() {
  test('WireRequest round-trips through JSON', () {
    final request = WireRequest(
      cellId: 'home.living.thermostat',
      function: 'setTarget',
      positional: {'0': 19},
      named: {'mode': 'eco'},
      correlationId: 'c-1',
      lastSeenSeq: 3,
    );
    final decoded = WireMessage.fromJson(
            jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>)
        as WireRequest;
    expect(decoded.cellId, 'home.living.thermostat');
    expect(decoded.function, 'setTarget');
    expect(decoded.positional, {'0': 19});
    expect(decoded.named, {'mode': 'eco'});
    expect(decoded.correlationId, 'c-1');
    expect(decoded.lastSeenSeq, 3);
  });

  test('WireNotification and WireError round-trip', () {
    final notification =
        WireNotification(method: 'initialized', params: {'a': 1});
    final decodedNotification = WireMessage.fromJson(
        jsonDecode(jsonEncode(notification.toJson()))
            as Map<String, dynamic>) as WireNotification;
    expect(decodedNotification.method, 'initialized');

    final error = WireError(correlationId: 'c', code: 'conflict', message: 'x');
    final decodedError = WireMessage.fromJson(
            jsonDecode(jsonEncode(error.toJson())) as Map<String, dynamic>)
        as WireError;
    expect(decodedError.code, 'conflict');
    expect(decodedError.correlationId, 'c');
  });

  test('manifest messages round-trip', () {
    final manifest = SkinManifest(cells: [
      const SkinCellDescriptor(
        cellId: 'a',
        description: 'A',
        functions: [SkinFunctionDescriptor(name: 'f')],
      ),
    ]);
    final response = WireManifestResponse(manifest: manifest);
    final decoded = WireMessage.fromJson(
            jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>)
        as WireManifestResponse;
    expect(decoded.manifest.toolCount, 1);
    expect(decoded.manifest.cells.single.cellId, 'a');
  });

  test('ledger entry message round-trips through the canonical JSON', () {
    final entry = LedgerEntry.fromJson({
      'seq': 0,
      'prevHash': 'g',
      'hash': 'h',
      'pulseDigest': 'p',
      'receipt': {
        'id': 'r',
        'cell': 'a',
        'function': 'f',
        'arguments': {'positional': null, 'named': null},
        'timestamp': '2026-11-22T00:00:00.000Z',
        'vetted': true,
      },
      'effects': <Object?>[],
      'deltas': <Object?>[],
      'at': '2026-11-22T00:00:00.000Z',
    });
    final message = WireLedgerEntry(entry: entry);
    final decoded = WireMessage.fromJson(
            jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>)
        as WireLedgerEntry;
    expect(decoded.entry.seq, 0);
    expect(wireLedgerEntryCellId(decoded.entry), 'a');
  });

  test('unknown kind throws FormatException', () {
    expect(() => WireMessage.fromJson({'kind': 'nope'}), throwsFormatException);
  });

  test('result pulse types follow the taxonomy', () async {
    final handle = Cell.state<int>(initial: 1);
    final command = (
      function: handle.update,
      arguments: (positionalArguments: [2], namedArguments: null),
      compensation: null,
    );
    final outcome = await handle.cell.apply<Object?>(command);
    expect(outcome, isA<ApplyAccepted<Object?>>());
    expect(SkinPulseTypes.resultType(outcome), 'mcp.tools.result.accepted');
    expect(SkinPulseTypes.restResponseType(outcome),
        'rest.apply.response.accepted');
  });
}
