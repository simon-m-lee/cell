// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Settings screen — restorableState + CellTextField inside the
// CellRestorationScope, so the nickname survives process kill / restart,
// plus useCellRouter (route badge + back navigation).

import 'package:cell_flutter/hooks.dart';
import 'package:cell_flutter_router/hooks.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late final nickname = restorableState<String>(
    restorationId: 'settings.nickname',
    initial: 'simon',
  );
  late final notifications = restorableState<bool>(
    restorationId: 'settings.notifications',
    initial: true,
  );

  @override
  void initState() {
    super.initState();
    CellRestorationScope.maybeOf(context)?.register(nickname);
    CellRestorationScope.maybeOf(context)?.register(notifications);
    
  }

  @override
  void dispose() {
    CellFlutterDevTools.unregister('settings.nickname');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [_RouteBadge(), _BackButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CellTextField(
            cell: nickname,
            decoration: const InputDecoration(labelText: 'Nickname'),
          ),
          CellFormField<bool>(
            cell: notifications,
            builder: (state) => SwitchListTile(
              value: state.value ?? false,
              onChanged: (v) => state.didChange(v),
              title: const Text('Notifications'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the mirrored route location, rebuilt reactively.
class _RouteBadge extends HookWidget {
  const _RouteBadge();

  @override
  Widget build(BuildContext context) {
    final router = useCellRouter();
    return Center(child: Text(router.state.location));
  }
}

/// Navigates back to the login route through the router bridge.
class _BackButton extends HookWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final router = useCellRouter();
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => router.go('/'),
      tooltip: 'Back to login',
    );
  }
}
