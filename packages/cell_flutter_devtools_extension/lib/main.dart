// The cell_flutter_devtools extension UI.
//
// A Flutter web app embedded in DevTools as an iframe. `DevToolsExtension`
// initializes the connection to DevTools and the VM service; `LedgerView`
// then polls `ext.cell.getLedger` on the connected app.
library;

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/ledger_client.dart';
import 'src/ledger_view.dart';

void main() => runApp(const CellDevToolsExtension());

/// The DevTools extension root.
class CellDevToolsExtension extends StatelessWidget {
  const CellDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) =>
      DevToolsExtension(child: LedgerView(fetch: ServiceLedgerClient().fetch));
}
