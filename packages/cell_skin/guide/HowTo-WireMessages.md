# HowTo-WireMessages

`WireMessage` is the whole wire vocabulary — a sealed hierarchy with
one variant per intent. Every transport is a `Pulse<WireMessage>`
whose `type` (see `SkinPulseTypes`) discriminates the variant.

## The variants

| Variant | Intent | Correlation |
| :--- | :--- | :--- |
| `WireRequest` | A command at `(cellId, function)`. | `correlationId` is server-assigned; `clientCorrelationId` is echo-only. |
| `WireResponse` | The target's real `ApplyOutcome` (or a `pendingReceipt` marker). | Echoes the request's ids. |
| `WireStateChange` | A state observation (`cellId`, payload, optional receipt). | **None** — egress is not a reply. |
| `WireError` | A pre-apply rejection: `unknown_tool`, `bad_arguments`, `cursor_required`, `conflict`, `transport_error`. | Echoes the request's ids. |
| `WireNotification` | Fire-and-forget. | None. |
| `WireManifestRequest` / `WireManifestResponse` | Tool catalogue. | None. |
| `WireLedgerEntry` | One audit entry (`LedgerEntry.toJson`). | None. |

## Argument envelope

`WireRequest` carries arguments as JSON-decoded maps:

- **positional** — an index-keyed map with contiguous keys `'0'..'n-1'`
  (never JSON insertion order). The REST adapter also accepts a plain
  JSON array.
- **named** — keys must be Dart identifiers (`[a-zA-Z_$][a-zA-Z0-9_$]*`).

Malformed envelopes — gaps, duplicates, bad names — are rejected with
`WireError{code: 'bad_arguments'}` **before** `target.apply` runs.

## Building and decoding

```dart
final request = WireRequest(
  cellId: 'home.living.thermostat',
  function: 'setTarget',
  positional: {'0': 21},
  correlationId: 'srv-1',
  clientCorrelationId: 'client-1',
);

final json = request.toJson();
final decoded = WireMessage.fromJson(json) as WireRequest;
```

`WireMessage.fromJson` throws `FormatException` on unknown kinds and
malformed fields — never a raw `TypeError`.

## Response semantics

```dart
final response = WireResponse(
  correlationId: 'srv-1',
  outcome: ApplyAccepted<Object?>(true, receipt),
);

final decoded = WireMessage.fromJson(response.toJson()) as WireResponse;
decoded.outcome;     // null — a live ApplyOutcome needs the live cell
decoded.outcomeJson; // WireOutcome(kind: 'accepted', result: true)
```

A decoded response carries the wire form under `outcomeJson`; the
constructor asserts `pendingReceipt || outcome != null ||
outcomeJson != null`.

## Errors have no receipts

`WireError` exists because an error produced *before* the target's
`apply` has no receipt and must not masquerade as a `WireResponse`.
Domain denials are different: `ApplyRejected` travels inside a
`WireResponse` with the domain's real receipt.

## Sanitisation

`WireOutcome` / `wireReceiptJson` sanitise everything before encoding:
unencodable results, reasons, and arguments become labelled
placeholders with `resultOmitted` / `reasonOmitted` /
`argumentsOmitted` flags. The wire is always JSON-encodable — a
non-JSON result is reported honestly, never as a post-apply 500.

## See also

- `HowTo-Egress.md` — the state-change variant in depth.
- `HowTo-Idempotency.md` — correlation and retries.
- `FEATURES-Skin.md` §3.
