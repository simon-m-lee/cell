// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import 'package:cell_flutter/cell_flutter.dart';
import 'package:flutter/material.dart';

sealed class AuthState {
  const AuthState();
}

class SignedOut extends AuthState {
  const SignedOut();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final String user;
}

void main() => runApp(const AuthApp());

class AuthApp extends StatefulWidget {
  const AuthApp({super.key});
  @override
  State<AuthApp> createState() => _AuthAppState();
}

class _AuthAppState extends State<AuthApp> {
  late final StateHandle<AuthState> _auth =
      Cell.state<AuthState>(initial: const SignedOut());

  @override
  Widget build(BuildContext context) {
    return CellScope(
      cells: {#auth: _auth.cell},
      child: MaterialApp(
        home: CellListener<AuthState>(
          cell: _auth.cell,
          onPulse: (context, pulse) {
            // Effects only — no navigation here. Navigation is driven
            // by the CellBuilder below.
            if (pulse.payload is SignedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed in')),
              );
            }
          },
          child: CellBuilder<AuthState>(
            cell: _auth.cell,
            builder: (_, state) => switch (state) {
              SignedIn() => const HomeScreen(),
              _ => LoginScreen(auth: _auth),
            },
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.auth, super.key});
  final StateHandle<AuthState> auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: Semantics(
          label: 'Sign in',
          button: true,
          child: ElevatedButton(
            onPressed: () => auth.update(const SignedIn('demo_user')),
            child: const Text('Sign in as demo_user'),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = CellScope.valueOf<AuthState>(context, #auth);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: CellBuilder<AuthState>(
          cell: auth.unmodifiable,
          builder: (_, state) => Text(switch (state) {
            SignedIn(user: final u) => 'Signed in as $u',
            _ => 'Not signed in',
          }),
        ),
      ),
    );
  }
}
