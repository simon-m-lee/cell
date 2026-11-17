// Copyright (c) 2025-Present Lee Man Hoi Simon. See the AUTHORS file
// for details. Use of this source code is governed by a MIT or
// Apache-2.0 license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

// Migration fixture: Bloc counter (before) — a Cubit.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

Widget buildCounterApp() {
  return BlocProvider(
    create: (_) => CounterCubit(),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: BlocBuilder<CounterCubit, int>(
            builder: (context, count) => TextButton(
              onPressed: () => context.read<CounterCubit>().increment(),
              child: Text('count: $count'),
            ),
          ),
        ),
      ),
    ),
  );
}
