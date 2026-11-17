// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Login screen — CellTextField + CellFormField + Form.validate(),
// plus the persisted nickname (cell_flutter_persistence) as the
// email prefill.

import 'package:cell_flutter/cell_flutter.dart';
import 'package:cell_flutter_router/cell_flutter_router.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final email = Cell.state<String>(initial: '');
  late final password = Cell.state<String>(initial: '');
  late final rememberMe = Cell.state<bool>(initial: false);
  EgressHandle<Pulse<Object?>>? _nicknameLink;
  bool _linked = false;

  @override
  void initState() {
    super.initState();
    CellFlutterDevTools.register('login.email', email.cell);
    CellFlutterDevTools.register('login.password', password.cell);
    CellFlutterDevTools.register('login.rememberMe', rememberMe.cell);
  }

  @override
  void dispose() {
    _nicknameLink?.stop();
    CellFlutterDevTools.unregister('login.email');
    CellFlutterDevTools.unregister('login.password');
    CellFlutterDevTools.unregister('login.rememberMe');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill the email from the persisted nickname (the app-level
    // PersistedCell) — including its async load completing later.
    if (_linked) {
      return;
    }
    final persisted = NicknameProvider.maybeOf(context);
    if (persisted == null) {
      return;
    }
    _linked = true;
    _nicknameLink = Cell.observe<Pulse<Object?>>(
      source: persisted.cell,
      effect: (_) {
        final value = persisted.cell.value;
        if (value != null &&
            value.isNotEmpty &&
            (email.cell.value?.isEmpty ?? true)) {
          email.cell.value = value;
        }
      },
      initiallyStarted: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CellTextField(
              cell: email.cell,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            CellTextField(
              cell: password.cell,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (v) => v == null || v.length < 6 ? 'Too short' : null,
            ),
            CellFormField<bool>(
              cell: rememberMe.cell,
              builder: (state) => CheckboxListTile(
                value: state.value ?? false,
                onChanged: (v) => state.didChange(v),
                title: const Text('Remember me'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  CellRouterScope.of(context).router.go(
                        '/list',
                        extra: email.cell.value ?? '',
                      );
                }
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
