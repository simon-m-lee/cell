// BLoC reference screen for the Cell migration guide.
//
// A todo feature with a full `Bloc` — events (`LoadTodos`, `AddTodo`,
// `ToggleTodo`) and states (`TodoLoading`, `TodoLoaded`, `TodoError`) —
// plus `BlocBuilder` / `BlocListener` in the widget tree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── Model ───────────────────────────────────────────────────────────────────

class Todo {
  Todo({required this.id, required this.description, this.completed = false});

  final String id;
  final String description;
  final bool completed;

  Todo copyWith({bool? completed}) => Todo(
      id: id,
      description: description,
      completed: completed ?? this.completed);
}

// ── Events and states ───────────────────────────────────────────────────────

sealed class TodoEvent {
  const TodoEvent();
}

class LoadTodos extends TodoEvent {
  const LoadTodos();
}

class AddTodo extends TodoEvent {
  const AddTodo(this.description);

  final String description;
}

class ToggleTodo extends TodoEvent {
  const ToggleTodo(this.id);

  final String id;
}

sealed class TodoState {
  const TodoState();
}

class TodoLoading extends TodoState {
  const TodoLoading();
}

class TodoLoaded extends TodoState {
  const TodoLoaded(this.todos);

  final List<Todo> todos;
}

class TodoError extends TodoState {
  const TodoError(this.message);

  final String message;
}

// ── The Bloc ────────────────────────────────────────────────────────────────

class TodoBloc extends Bloc<TodoEvent, TodoState> {
  TodoBloc() : super(const TodoLoading()) {
    on<LoadTodos>(_onLoad);
    on<AddTodo>(_onAdd);
    on<ToggleTodo>(_onToggle);
  }

  Future<void> _onLoad(LoadTodos event, Emitter<TodoState> emit) async {
    // Simulate a repository read.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    emit(TodoLoaded([
      Todo(id: '1', description: 'Seed todo'),
    ]));
  }

  Future<void> _onAdd(AddTodo event, Emitter<TodoState> emit) async {
    final current = state;
    if (current is! TodoLoaded) return;
    final trimmed = event.description.trim();
    if (trimmed.isEmpty) {
      // Emit the error for BlocListener to surface, then recover so the
      // list stays visible for the next attempt.
      emit(const TodoError('Description must not be empty.'));
      emit(TodoLoaded(current.todos));
      return;
    }
    // Simulate a network write, then append.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    emit(TodoLoaded([
      ...current.todos,
      Todo(id: '${current.todos.length + 1}', description: trimmed),
    ]));
  }

  void _onToggle(ToggleTodo event, Emitter<TodoState> emit) {
    final current = state;
    if (current is! TodoLoaded) return;
    emit(TodoLoaded([
      for (final t in current.todos)
        t.id == event.id ? t.copyWith(completed: !t.completed) : t,
    ]));
  }
}

// ── UI ──────────────────────────────────────────────────────────────────────

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => TodoBloc()..add(const LoadTodos()),
        child: const MaterialApp(home: TodoListScreen()),
      );
}

class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLoC todos')),
      body: BlocListener<TodoBloc, TodoState>(
        listener: (context, state) {
          if (state is TodoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: BlocBuilder<TodoBloc, TodoState>(
          builder: (context, state) => switch (state) {
            TodoLoading() =>
              const Center(child: CircularProgressIndicator()),
            TodoLoaded(todos: final todos) => ListView.builder(
                itemCount: todos.length,
                itemBuilder: (_, i) {
                  final todo = todos[i];
                  return CheckboxListTile(
                    key: Key('todo-${todo.id}'),
                    title: Text(todo.description),
                    value: todo.completed,
                    onChanged: (_) =>
                        context.read<TodoBloc>().add(ToggleTodo(todo.id)),
                  );
                },
              ),
            TodoError(message: final message) => Center(
                child: Text(message),
              ),
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('open-form'),
        onPressed: () => _showTodoForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showTodoForm(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add todo'),
        content: TextField(
          key: const Key('description-field'),
          controller: controller,
          decoration: const InputDecoration(hintText: 'Description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('submit-button'),
            onPressed: () {
              context.read<TodoBloc>().add(AddTodo(controller.text));
              Navigator.pop(dialogContext);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
