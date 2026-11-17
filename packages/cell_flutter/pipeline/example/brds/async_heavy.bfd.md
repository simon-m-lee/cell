---
schema: flutter-pipeline/v1
title: Search
version: 1
---

## Requirements

| ID | Sentence | Screen | Trigger | Outcome | Type |
|---|---|---|---|---|---|
| REQ-001 | User sees the search field | Search | | Search field rendered | display |
| REQ-002 | Typing in the search field triggers a debounced search | Search | type in search field | Search results appear after 300ms | interaction |
| REQ-003 | While the search is in flight, the user sees a loading indicator | Search | type in search field | Loading indicator rendered | display |
| REQ-004 | A successful search shows the results | Search | type in search field | Results list rendered | display |
| REQ-005 | A failed search shows the error "Search failed" | Search | type in search field | Error text shown | recovery |
| REQ-006 | An empty result shows the text "No results" | Search | type in search field | No-results text rendered | display |
| REQ-007 | The user can retry a failed search | Search | tap Retry | Search retried | interaction |

## Screens

| Name | Route | Widgets |
|---|---|---|
| Search | / | CellTextField, CellAsyncBuilder, ElevatedButton, CellErrorBoundary |

## State

| Name | Type | Initial | Restorable | AppLevel |
|---|---|---|---|---|
| searchQuery | String | '' | no | no |
| searchResults | SearchResult | AsyncValue.loading | no | yes |

## Context

A search screen demonstrating debounced input, async fetching,
loading / success / error / empty states, and retry.
