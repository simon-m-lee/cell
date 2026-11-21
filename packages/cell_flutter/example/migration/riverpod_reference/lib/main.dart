// Riverpod reference screen for the Cell migration guide.
//
// A realistic todo list: a notifier-backed list, a filter state, a
// derived filtered list, and an async submission path with validation.
// Uses `@riverpod` + `build_runner` (modern Riverpod codegen).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

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

enum TodoFilter { all, active, completed }

// ── State: the todo list ────────────────────────────────────────────────────

@riverpod
class TodoList extends _$TodoList {
  @override
  List<Todo> build() => [];

  void addTodo(String description) {
    state = [
      ...state,
      Todo(id: '${state.length + 1}', description: description),
    ];
  }

  void toggleTodo(String id) {
    state = [
      for (final t in state)
        t.id == id ? t.copyWith(completed: !t.completed) : t,
    ];
  }

  void deleteTodo(String id) =>
      state = [for (final t in state) if (t.id != id) t];

  /// Async submission with validation. Lives on the notifier so the
  /// provider is not auto-disposed while the network call is in flight.
  Future<String> submitTodo(String description) async {
    await Future<void>.delayed(const Duration(milliseconds: 10)); // network
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      throw Exception('Description must not be empty.');
    }
    if (trimmed.length > 60) {
      throw Exception('Description must be 60 characters or fewer.');
    }
    addTodo(trimmed);
    return 'saved';
  }
}

// ── State: the active filter ────────────────────────────────────────────────

@riverpod
class Filter extends _$Filter {
  @override
  TodoFilter build() => TodoFilter.all;

  void set(TodoFilter filter) => state = filter;
}

// ── Derived: the filtered list ──────────────────────────────────────────────

@riverpod
List<Todo> filteredTodos(Ref ref) {
  final todos = ref.watch(todoListProvider);
  final filter = ref.watch(filterProvider);
  return switch (filter) {
    TodoFilter.all => todos,
    TodoFilter.active => [for (final t in todos) if (!t.completed) t],
    TodoFilter.completed => [for (final t in todos) if (t.completed) t],
  };
}

// ── UI ──────────────────────────────────────────────────────────────────────

void main() => runApp(const ProviderScope(child: TodoApp()));

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: TodoListScreen());
}

class TodoListScreen extends ConsumerWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(filteredTodosProvider);
    final filter = ref.watch(filterProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod todos')),
      body: Column(
        children: [
          SegmentedButton<TodoFilter>(
            segments: const [
              ButtonSegment(value: TodoFilter.all, label: Text('All')),
              ButtonSegment(value: TodoFilter.active, label: Text('Active')),
              ButtonSegment(value: TodoFilter.completed, label: Text('Done')),
            ],
            selected: {filter},
            onSelectionChanged: (s) =>
                ref.read(filterProvider.notifier).set(s.first),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: todos.length,
              itemBuilder: (_, i) {
                final todo = todos[i];
                return CheckboxListTile(
                  key: Key('todo-${todo.id}'),
                  title: Text(todo.description),
                  value: todo.completed,
                  onChanged: (_) =>
                      ref.read(todoListProvider.notifier).toggleTodo(todo.id),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('open-form'),
        onPressed: () => _showTodoForm(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showTodoForm(BuildContext context, WidgetRef ref) {
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
            onPressed: () async {
              try {
                await ref
                    .read(todoListProvider.notifier)
                    .submitTodo(controller.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
