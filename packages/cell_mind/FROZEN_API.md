# Cell Mind — Frozen API (v1.1.0)

Frozen on: 2026-11-15
Frozen by: cell_mind 1.1.0 tag
Generator: tool/freeze_api.dart

Any change to this manifest requires a deprecation cycle or a MAJOR version bump.

## lib/src\agent.dart

### AgentSpec
- `final String name;`
- `final C cell;`
- `final DeputyContext mandate;`
- `final TestCell testRule;`
- `final Set<ReasoningStrategy> allowedStrategies;`
- `final Policy? policy;`
- `final VerdictPolicy? verdictPolicy;`
- `final Future<void> Function(dynamic pulse)? routeIn;`

### AgentRuntime
- `final String name;`
- `final C sourceCell;`
- `final Cell agentView;`
- `final CognitiveHandle agentHandle;`
- `final DeputyContext context;`
- `final TissueList<Decision> trace;`
- `final TissueList<Outcome> outcomes;`

### DebateOutcome
- `final Verdict winner;`
- `final int rounds;`
- `final Map<String, Map<String, Verdict>> votesByRound;`
- `final bool consensusReached;`
- `final Map<String, String?> agentStrategies;`

### debate (function)
- `Future<DebateOutcome> debate(({
  required List<AgentRuntime> participants,
  required Pulse question,
  required EffectJournal journal,
  int maxRounds = 3,
  double consensusThreshold = 0.7,
}))`

## lib/src\approval.dart

### ApprovalRequest
- `final String id;`
- `final Decision decision;`
- `final Defer verdict;`
- `final DateTime requestedAt;`
- `final int attempts;`
- `Map<String, dynamic> toMap() => {`

### ApprovalQueue
- `final TissueMap<String, ApprovalRequest<T>> pending;`
- `final ValueCell<T?> committed;`
- `final EffectJournal journal;`
- `final Duration ttl;`
- `final int maxPending;`
- `ApprovalQueue({`
- `Future<bool> submit(Decision decision) async {`
- `Future<void> dispose() async {`
- `final now = journal.clock();`
- `final expiredIds = <String>[];`

## lib/src\bridge.dart

### Tool (typedef)

- `= Future<Object?> Function(Map<String, dynamic> args)`

### completion (function)
- `Cell completion(({
  required Future<String> future,
  required String actor,
  required String prompt,
  required double confidence,
  required EffectJournal journal,
  PulseContext? baseContext,
  ReasoningStrategy strategy = ReasoningStrategy.probabilistic,
}))`

### streamCompletion (function)
- `Cell streamCompletion(({
  required Stream<String> tokens,
  required String actor,
  required String prompt,
  required EffectJournal journal,
  PulseContext? baseContext,
  bool cancelOnError = false,
}))`

### streamChunks (function)
- `Cell streamChunks(({
  required Stream<String> chunks,
  required String actor,
  required EffectJournal journal,
  Duration buffer = Duration.zero,
}))`

### toolRouter (function)
- `Cell toolRouter(({
  required Cell source,
  required Map<String, Tool> tools,
  required String actor,
  required EffectJournal journal,
  double minConfidence = 0.85,
  bool fireAndForget = false,
}))`

## lib/src\learning.dart

### TrainedPolicy
- `final Map<String, dynamic> policyBlock;`
- `final int decisionCount;`
- `final int resolvedCount;`
- `final DateTime trainedAt;`
- `final String algorithm;`
- `final double averageReward;`
- `Map<String, dynamic> toMap() => {`

### RewardFunction (typedef)

- `= double Function(Decision decision, Outcome outcome)`

### TrainingConfig
- `final int minSupport;`
- `final double minConfidence;`
- `final int maxRules;`
- `final Duration? window;`
- `final bool prune;`

### Trainer
- (sealed hierarchy — no public members)

### contextualBandit (function)
- `Trainer contextualBandit(())`

### trainOffline (function)
- `Future<TrainedPolicy> trainOffline(({
  required CognitiveHandle handle,
  required TissueList<Outcome> outcomes,
  required Context baseContext,
  required Trainer trainer,
  required EffectJournal journal,
  RewardFunction? reward,
  TrainingConfig? config,
}))`

## lib/src\outcomes.dart

### Outcome
- `final String decisionId;`
- `final double reward;`
- `final Map<String, dynamic>? metadata;`
- `final DateTime at;`
- `Map<String, dynamic> toMap() => {`

## lib/src\policy.dart

### Policy (typedef)

- `= TestCell<Cell>`

### ApplyCategory (enum)

### VerdictPolicy
- (sealed hierarchy — no public members)

### domainPolicy (function)
- `Policy domainPolicy(({
  Set<String>? additionalDomains,
  bool allowUntagged = false,
}))`

### requiresDomainPolicy (function)
- `Policy requiresDomainPolicy(())`

### compliancePolicy (function)
- `Policy compliancePolicy(({Set<String>? additionalCompliance}))`

### complianceOverlapPolicy (function)
- `Policy complianceOverlapPolicy(())`

### authorityPolicy (function)
- `Policy authorityPolicy(({
  Set<String>? additionalVerbs,
  String? Function(Function)? verbResolver,
}))`

### exactFunctionsPolicy (function)
- `Policy exactFunctionsPolicy((Set<Function> whitelist))`

### clearancePolicy (function)
- `Policy clearancePolicy(({
  Map<ApplyCategory, Clearance>? requirements,
  ApplyCategory Function(Function)? categoryResolver,
}))`

### isolationPolicy (function)
- `Policy isolationPolicy(())`

### sensitivityPolicy (function)
- `Policy sensitivityPolicy(({Sensitivity? defaultMax}))`

### confidencePolicy (function)
- `Policy confidencePolicy(({double min = 0.85, bool allowMissing = false}))`

### strategyPolicy (function)
- `Policy strategyPolicy((
  Set<ReasoningStrategy> allowed, {
  bool allowMissing = false,
}))`

### auditLevelPolicy (function)
- `Policy auditLevelPolicy(({AuditLevel min = AuditLevel.standard}))`

### actorPolicy (function)
- `Policy actorPolicy((Set<String> allowed, {bool allowMissing = false}))`

### purposePolicy (function)
- `Policy purposePolicy((Set<String> allowed, {bool allowMissing = false}))`

### notOlderThan (function)
- `Policy notOlderThan((
  Duration window, {
  required DateTime Function() clock,
}))`

### contextAware (function)
- `Policy contextAware(({
  bool requireDomain = true,
  bool requireCompliance = false,
  bool requireClearance = false,
  double minConfidence = 0.85,
  bool allowMissingConfidence = false,
}))`

### paranoid (function)
- `Policy paranoid(())`

### predicatePolicy (function)
- `Policy predicatePolicy((
  bool Function(dynamic object, {required Cell host}) predicate,
))`

### learnedPolicy (function)
- `Policy learnedPolicy(())`

### verdictPolicy (function)
- `VerdictPolicy verdictPolicy((
  FutureOr<Verdict> Function(
    dynamic object, {
    required Cell host,
    dynamic arguments,
  }) rule,
))`

### learnedVerdictPolicy (function)
- `VerdictPolicy learnedVerdictPolicy(())`

## lib/src\prompt_config.dart

### PromptConfig
- `final String id;`
- `final String version;`
- `final String description;`
- `final String systemPrompt;`
- `final String userTemplate;`
- `final Map<String, dynamic> outputSchema;`
- `final List<PromptExample> examples;`
- `final Map<String, dynamic> parameters;`
- `final Duration cacheTtl;`
- `final int maxPromptChars;`
- `PromptConfig(`
- `Map<String, dynamic> toMap() => {`

### PromptExample
- `final String context;`
- `final String decision;`
- `final String response;`
- `String render() =>`
- `Map<String, dynamic> toMap() => {`

### PromptConfigRegistry
- (sealed hierarchy — no public members)

### ConformanceCase
- `final Context context;`
- `final dynamic decision;`
- `final Verdict expected;`

### PromptConformanceReport
- `final int total;`
- `final int passed;`
- `final List<ConformanceFailure> failures;`
- `final Duration totalLatency;`
- `final Duration averageLatency;`
- `final String configId;`
- `final String configVersion;`

### ConformanceFailure
- `final ConformanceCase testCase;`
- `final Verdict actual;`
- `final String? reason;`

### conform (function)
- `Future<PromptConformanceReport> conform(({
  required PromptConfig config,
  required PromptFunction prompt,
  required List<ConformanceCase> cases,
  EffectJournal? journal,
}))`

## lib/src\prompt_policy.dart

### PromptFunction (typedef)

- `= Future<String> Function(String prompt)`

### ContextRenderer (typedef)

- `= String Function(Context context)`

### DecisionRenderer (typedef)

- `= String Function(
  dynamic object, {
  Cell? host,
  dynamic arguments,
})`

### VerdictParser (typedef)

- `= Verdict Function(String rawResponse)`

### promptedPolicy (function)
- `VerdictPolicy promptedPolicy(({
  required PromptFunction prompt,
  required EffectJournal journal,
  String? systemPrompt,
  ContextRenderer? contextRenderer,
  DecisionRenderer? decisionRenderer,
  VerdictParser? verdictParser,
  Duration? cacheTtl,
  int maxPromptChars = 32000,
}))`

### promptedPolicyWith (function)
- `VerdictPolicy promptedPolicyWith(({
  PromptConfig? config,
  String? configId,
  String? configVersion,
  required PromptFunction prompt,
  required EffectJournal journal,
  Verdict Function(String label)? labelToVerdict,
  Verdict Function(Map<String, dynamic> extracted)? extractionToVerdict,
  ContextRenderer? contextRenderer,
  DecisionRenderer? decisionRenderer,
  VerdictParser? verdictParser,
}))`

## lib/src\runtime.dart

### CognitiveHandle
- `final C cell;`
- `final Cell cognitive;`
- `final Policy policy;`
- `final TissueList<Decision> decisions;`
- `final IngressHandle<Pulse> outcomes;`

## lib/src\xai.dart

### NarrativeTemplate (enum)

### DecisionPath
- `final Decision decision;`
- `String toNarrative({NarrativeTemplate template = NarrativeTemplate.audit}) =>`

### Tracer
- `SpanContext get currentContext;`

### Span
- (sealed hierarchy — no public members)

### SpanContext
- `String get traceId;`
- `String get spanId;`

### SpanStatus (enum)

### explain (function)
- `DecisionPath explain((Decision decision))`

### explainPulse (function)
- `DecisionPath? explainPulse((Pulse pulse, CognitiveHandle handle))`

### explainSource (function)
- `List<DecisionPath> explainSource((Cell source, CognitiveHandle handle))`

### otelSpans (function)
- `List<Span> otelSpans((
  Iterable<Decision> decisions, {
  required Tracer tracer,
  String Function(Decision)? spanName,
  Map<String, Object?> Function(Decision)? extraAttributes,
}))`

