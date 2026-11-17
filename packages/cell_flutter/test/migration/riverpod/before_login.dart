// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Riverpod login (before, riverpod 3.x) — a
// Notifier<LoginState> with derived validity.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginState {
  const LoginState({this.email = '', this.password = ''});

  final String email;
  final String password;

  LoginState copyWith({String? email, String? password}) => LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
      );
}

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void setEmail(String value) => state = state.copyWith(email: value);
  void setPassword(String value) => state = state.copyWith(password: value);
}

final loginProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);

final loginValidProvider = Provider<bool>((ref) {
  final s = ref.watch(loginProvider);
  return s.email.contains('@') && s.password.length >= 6;
});

Widget buildLoginApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: _LoginView()),
    ),
  );
}

class _LoginView extends ConsumerWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valid = ref.watch(loginValidProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Email'),
          onChanged: ref.read(loginProvider.notifier).setEmail,
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Password'),
          onChanged: ref.read(loginProvider.notifier).setPassword,
        ),
        Text(valid ? 'logged in' : 'not valid'),
      ],
    );
  }
}
