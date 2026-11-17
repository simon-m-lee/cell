// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Bloc login (before) — events and states.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginState {
  const LoginState({this.email = '', this.password = ''});

  final String email;
  final String password;

  LoginState copyWith({String? email, String? password}) => LoginState(
        email: email ?? this.email,
        password: password ?? this.password,
      );

  bool get valid => email.contains('@') && password.length >= 6;
}

sealed class LoginEvent {}

class EmailChanged extends LoginEvent {
  EmailChanged(this.value);

  final String value;
}

class PasswordChanged extends LoginEvent {
  PasswordChanged(this.value);

  final String value;
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<EmailChanged>((event, emit) => emit(state.copyWith(email: event.value)));
    on<PasswordChanged>(
        (event, emit) => emit(state.copyWith(password: event.value)));
  }
}

Widget buildLoginApp() {
  return BlocProvider(
    create: (_) => LoginBloc(),
    child: MaterialApp(
      home: Scaffold(
        body: BlocBuilder<LoginBloc, LoginState>(
          builder: (context, state) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (v) =>
                    context.read<LoginBloc>().add(EmailChanged(v)),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: (v) =>
                    context.read<LoginBloc>().add(PasswordChanged(v)),
              ),
              Text(state.valid ? 'logged in' : 'not valid'),
            ],
          ),
        ),
      ),
    ),
  );
}
