---
schema: flutter-pipeline/v1
title: Todo List
version: 1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the list of todos | Todos | | Todo list rendered | display |
| REQ-002 | User can add a new todo | Todos | tap Add | New todo rendered | interaction |
| REQ-003 | User can delete a todo | Todos | swipe left on a todo | Todo removed | interaction |
| REQ-004 | User can reorder todos | Todos | drag a todo | Todo list reordered | interaction |
| REQ-005 | Todos persist across app restart | Todos | | Todo list restored | atomic |

## Screens

| Name | Route | Widgets |
|---|---|---|
| Todos | / | CellListView, CellTextField, ElevatedButton, CellListener |

## State

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|
| todos | List<Todo> | [] | yes | yes |
| newTodoTitle | String | '' | no | no |

## Context

A todo list demonstrating list rendering, item add / delete / reorder,
and persistence.
