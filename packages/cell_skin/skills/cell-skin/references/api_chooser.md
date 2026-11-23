<!-- GENERATED FILE — do not edit by hand. -->
<!-- Regenerate with: dart run tool/generate_api_chooser.dart -->

# API Chooser — `cell_skin`

**Layer:** Skin — the membrane between a Cell graph and remote consumers
(MCP hosts, REST clients, Dart clients). Does **not** own: graph nodes
(cell), the decision (cell_flow), the books (cell_tissue).

**Read this file when:** a BRD sentence says "expose the graph over REST",
"stream ledger entries", "bind a tool for MCP", "authenticate remote
callers", or "observe cell state over the wire".

The full decision procedure lives in the layer docs; this matrix
is generated from the `### AI Agent Guide` doc blocks and cannot
drift.

| Symbol | When to use | When NOT to use | Live signature | Guide | Example |
|---|---|---|---|---|---|
| `SkinBinding` | ** a requirement says "expose X on cell Y", "tools/list should show Z", or "this command must be serialisable". | ** declaring graph behaviour — gates belong to the cell's `TestCell`, not the binding. | ** `const SkinBinding({required String cellId, required String functionName, required Cell target, required Function function, String? description, JsonSchema? argumentSchema, bool strictCursor = false, Function? compensation})` — pinned at `cell_skin: 0.1.0` | ** `FEATURES-Skin.md` §4 (binding table and whitelist). | ** `example/lib/mock/mock_home.dart` (every Echo Home tool is one binding). |
| `SkinClient` | ** a script, test, or agent drives the membrane from Dart; the demo pattern is this client, never a fake. | ** cross-process calls — use `RestAdapter`; cell-shaped remote views — use [RemoteCellClient]. | ** `SkinClient({required SkinMembrane membrane})` with `Future<ApplyOutcome<Object?>?> apply(String cellId, String function, {List<Object?>? positional, Map<String, Object?>? named, int? lastSeenSeq, PulseContext? context})` — pinned at `cell_skin: 0.1.0` | ** `FEATURES-Skin.md` §12 (clients). | ** `example/lib/mock/mock_agent.dart` (every scripted beat). |
| `WireRequest` | ** sending a command at a bound `(cellId, function)` over any transport. | ** fire-and-forget signals — use [WireNotification]; state observations — use [WireStateChange]. | ** `const WireRequest({required String cellId, required String function, Map<String, Object?>? positional, Map<String, Object?>? named, required String correlationId, String? clientCorrelationId, int? lastSeenSeq})` — pinned at `cell_skin: 0.1.0` | ** `ARCHITECTURE-Skin.md` §3 (wire taxonomy) and §6 (correlation). | ** `example/lib/mock/mock_agent.dart` (every scripted beat is one request). |
| `WireStateChange` | ** streaming target state changes to observers (SSE, MCP notifications, Dart clients). | ** completing a request — it has no correlation id; replies are [WireResponse] or [WireError]. | ** `const WireStateChange({required String cellId, Object? payload, WireReceipt? receipt, bool pendingReceipt = false})` — pinned at `cell_skin: 0.1.0` | ** `ARCHITECTURE-Skin.md` §4 (receipt provenance). | ** `example/lib/widgets/home_pane.dart` (the thermostat readout observes this variant). |
| `authenticate` | ** a requirement says "authenticate REST callers", "per-principal context", or "bearer tokens". | ** authorisation decisions — return the principal and let the graph's gates decide. | ** `abstract interface class SkinAuth { Future<SkinPrincipal?> authenticate(SkinCredentials credentials); }` — pinned at `cell_skin: 0.1.0` | ** `FEATURES-Skin.md` §13 (security SPI). | ** `example/lib/mock/rest_io.dart` (the demo opts into `AllowAllSkinAuth`). |
| `bind` | ** a requirement says "REST endpoint for the graph", "SSE stream of changes", "audit log over HTTP", or "curl-able manifest". | ** in-process calls (use `SkinClient`); speaking MCP (use the `McpAdapter` seam with an MCP SDK). | ** `static Future<RestAdapter> bind({required SkinMembrane membrane, required SkinAuth auth, ContextBridge contextBridge = const DescribeContextBridge(), Object? address, int port = 0, Set<String>? allowedHosts, Set<String>? allowedOrigins, int maxBodyBytes = 1048576, Duration requestTimeout = Duration(seconds: 30), Duration keepAliveInterval = Duration(seconds: 15)})` — pinned at `cell_skin: 0.1.0` | ** `FEATURES-Skin.md` §10 (REST adapter). | ** `example/lib/mock/rest_io.dart` (the demo's real adapter binding). |
| `open` | ** a requirement says "expose the graph over REST/MCP", "let remote callers apply commands", or "stream ledger entries to clients". | ** pure graph work (use `package:cell`), decisions (use `cell_flow`), books (use `cell_tissue`). | ** `static Future<SkinMembrane> open({required CellGraph graph, required SkinBindingTable bindings, SkinWhitelist? whitelist, Ledger? ledger, required EffectJournal journal, required void Function(Pulse<WireMessage>) send, Context inboundContext, Map<String, String>? descriptions, void Function(String)? onPolicyWarning})` — pinned at `cell_skin: 0.1.0` | ** `ARCHITECTURE-Skin.md` §2 (the four cells). | ** `example/lib/mock/mock_home.dart` (builds the Echo Home membrane). |

## How this matrix stays fresh

* `dart run tool/generate_api_chooser.dart` — regenerates this file.
* `test/api_chooser_up_to_date_test.dart` — fails CI if stale.

