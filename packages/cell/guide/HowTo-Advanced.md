# Advanced

Optional machinery. You can ship with `Cell.state`, `Cell.observe`, and the Core operators and never open these pages.

Use this group when a write must be *justified*, *isolated*, or *short-lived* — not for counters and forms.

## What “advanced” means here

| Topic | When you actually need it |
| --- | --- |
| [Context](HowTo-Context.md) | Domain / constraint metadata on a cell |
| [Deputy Context](HowTo-DeputyContext.md) | A narrower proxy of the same cell |
| [Nucleus](HowTo-Nucleus.md) | Shared immutable blueprints |
| [Pulse Context](HowTo-PulseContext.md) | Actor / reason / purpose on a pulse |
| [Pulse Ephemeral Policy](HowTo-PulseEphemeralPolicy.md) | TTL and hop limits on a signal |
| [Ephemeral Policy](HowTo-EphemeralPolicy.md) | TTL and event budgets on a cell |
| [Propagation Policy](HowTo-PropagationPolicy.md) | Debounce / throttle / batch at the synapse |
| [Transactions](HowTo-Transaction.md) | Multi-cell buffered writes and isolation |
| [txApply](HowTo-TransactionOnApply.md) | Staged `apply()` plus compensation |

None of this runs unless you pass the type in. `Context.describe('…')` stores text; it is not a compliance program.

## Tagging APIs

On an advanced type or factory:

```dart
/// {@category Advanced}
/// {@category Transactions}
static Transaction transaction([TransactionOptions? options]) { ... }
```

The first tag lists the member on the Advanced topic page. The second keeps the dedicated HowTo page.
