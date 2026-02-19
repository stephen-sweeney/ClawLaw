# ClawLaw Product-Level Design

**Version:** 0.1.0
**Date:** February 19, 2026
**Author:** Engineering
**Status:** Draft
**Companion documents:** `docs/HRD.md`, `docs/DOMAIN_NOTES.md`, `docs/EXPERIMENTS.md`

---

## Overview

ClawLaw is a governance framework that interposes between OpenClaw (a locally-hosted autonomous AI agent) and the host operating system. It evaluates every proposed agent action through a deterministic reducer before the action reaches the filesystem, shell, or network. The system is built in Swift using the SwiftVector architectural pattern: typed state, typed actions, a pure-function reducer, and actor-isolated orchestration.

This design document turns the 21 requirements and 10 non-functional requirements from the HRD into concrete modules, data structures, interfaces, integration points, and deployment artifacts for ClawLaw v1.0 on macOS (Apple Silicon).

### System Context (Today)

The v0.1.0-alpha codebase consists of five source files in `ClawLawCore` (a Swift library) and one CLI executable target. The reducer, state machine, orchestrator, steward, and approval queue are functional and validated by 5 budget governance experiments, 3 boundary tests, 1 partial authority test (approval-only; execution after approval is not yet validated due to the R11 bypass limitation), 2 enforcement reconciliation tests, and 2 safety tests. The CLI provides `demo`, `test`, and `monitor` (placeholder) subcommands via Swift ArgumentParser. No integration with OpenClaw exists yet. No persistence layer exists. No configuration file system exists.

> **Note on current vs. target state:** Throughout this document, code samples and API definitions marked **[CURRENT]** describe v0.1.0-alpha as it exists today. Those marked **[TARGET v1.0]** describe the proposed implementation. Unmarked sections describe design decisions and flows that apply to both.

### Tech Stack

| Layer | Technology |
|---|---|
| Core governance library | Swift 5.9+, `ClawLawCore` (Foundation only) |
| CLI | Swift ArgumentParser, `clawlaw` executable |
| OpenClaw integration | Node.js HTTP middleware (proxy) — new |
| Persistence | JSON files on local filesystem — new |
| Configuration | YAML (via Yams) — new |
| Testing | Swift Testing framework, fuzz testing |
| Platform | macOS 13+ on Apple Silicon (M4 Pro primary). `Package.swift` also declares iOS 16 for future SwiftUI dashboard target; not used in v1.0. |

### Deployment Environment

Single-user, single-machine, local-only. ClawLaw runs as a co-process with OpenClaw on the same macOS host. No cloud infrastructure. No remote services. No listening ports beyond the local governance proxy (if HTTP interception strategy is chosen).

---

## Goals / Non-Goals

### Goals

1. **Close the interception gap.** Define and implement the mechanism by which ClawLaw evaluates OpenClaw actions before they execute on the host. (HRD G1, R15)
2. **Harden the reducer for determinism.** Eliminate all `Date()` and `UUID()` calls from the reducer path and inject `Clock`/`IDGenerator` protocols. (HRD G5, NFR-7, A1)
3. **Ship configuration and safe defaults.** Build a YAML-based configuration system with shipped defaults that protect casual users out of the box. (HRD G2, R4, R17, R18)
4. **Add persistence.** Governance state and audit trail survive process restarts. (HRD R7, R12, OQ-3)
5. **Resolve the R10/R11 approval bypass conflict.** Approved high-risk actions must execute without re-triggering the same approval gate. (HRD R10, R11)
6. **Build the Steward CLI.** Complete CLI for all governance operations: status, approve, reject, budget, audit, config validate. (HRD R20, R21)

### Non-Goals

- Graphical dashboard (v2.0).
- Multi-agent delegation chain enforcement (v2.0).
- Autonomy tier enforcement (v2.0; current enforcement is budget-based and action-classification-based).
- Governance profile isolation (v2.0; single governance context in v1.0).
- Network egress enforcement at the kernel/packet level (see Architecture Decision 4).
- Linux/Windows support (v2.0).

---

## Architecture

### Component Diagram

```
                                  ┌──────────────────────┐
                                  │    User / Steward     │
                                  │  (clawlaw CLI)        │
                                  └───────────┬───────────┘
                                              │ Steward commands
                                              ▼
┌───────────┐     ┌──────────────────────────────────────────────┐
│  OpenClaw │     │                  ClawLaw                      │
│  Gateway  │────▶│  ┌─────────────┐  ┌──────────────────┐       │
│ (Node.js) │     │  │  Intercept   │  │  Governance       │       │
│           │◀────│  │  Adapter     │──│  Orchestrator     │       │
│ port 18789│     │  │              │  │  (Actor)          │       │
└───────────┘     │  └─────────────┘  └────────┬─────────┘       │
                  │                            │                  │
                  │                   ┌────────▼─────────┐       │
                  │                   │  Governance        │       │
                  │                   │  Reducer           │       │
                  │                   │  (Pure Function)   │       │
                  │                   └────────┬─────────┘       │
                  │                            │                  │
                  │        ┌──────────┬────────┴────────┐        │
                  │        ▼          ▼                  ▼        │
                  │  ┌──────────┐ ┌──────────┐  ┌────────────┐  │
                  │  │ Approval │ │  State    │  │  Audit     │  │
                  │  │ Queue    │ │  Store    │  │  Writer    │  │
                  │  │ (Actor)  │ │ (Actor)   │  │  (Actor)   │  │
                  │  └──────────┘ └──────────┘  └────────────┘  │
                  │                                               │
                  │  ┌─────────────────────────────────────────┐ │
                  │  │  Configuration Loader                    │ │
                  │  │  (reads YAML, validates, emits State)    │ │
                  │  └─────────────────────────────────────────┘ │
                  └──────────────────────────────────────────────┘
```

### Module Breakdown

| Module | Target | Responsibility | HRD Requirements |
|---|---|---|---|
| `ClawLawCore` | Library | Reducer, state types, action types, protocols, audit entry | R1-R13, NFR-7, NFR-10 |
| `ClawLawPersistence` | Library | State serialization, audit file writer, state recovery | R7, R12, R14, NFR-5, NFR-6 |
| `ClawLawConfig` | Library | YAML parsing, validation, default config generation | R4, R17, R18, R19 |
| `ClawLawIntegration` | Library | OpenClaw adapter, action translator, response mapper | R15, R16 |
| `ClawLaw` (CLI) | Executable | Steward commands, daemon mode, config management | R20, R21 |

### Integration Abstraction

The `OpenClawAdapter` protocol (defined in `ClawLawIntegration`) is the stable seam between OpenClaw and ClawLaw governance. All downstream documentation — operational use cases, test plans, integration guides — should describe interception flows through this interface, not through a specific transport mechanism. Whether ClawLaw intercepts via HTTP proxy (AD-1 primary) or process wrapper (AD-1 fallback), the adapter contract is identical: translate tool call → propose `AgentAction` → return governance decision. Transport is a swappable implementation detail resolved in Phase 4.

**Package.swift dependency changes:**

| Dependency | Purpose | Used By |
|---|---|---|
| `swift-argument-parser` (existing) | CLI framework | `ClawLaw` |
| `Yams` (new) | YAML parsing | `ClawLawConfig` |

No other external dependencies. `ClawLawCore` remains Foundation-only per NFR-10.

---

## Data Model

### Governance State (Hardened)

**[CURRENT]** `GovernanceState` conforms to `Equatable` only. It does not conform to `Codable` or `Sendable`. No type in `ClawLawCore` conforms to `Sendable` today. The state uses `var` properties for the enforcement reconciliation mechanism. `BudgetState` already conforms to `Codable` with custom `init(from:)` and `encode(to:)`.

**Decision: Phased immutability.** Full `let` + `.with()` is the target architecture but requires significant refactoring of the reconciliation computed-property pattern. v1.0 adds `Codable` and `Sendable` conformance, retains `var` for reconciliation, and documents this as a known deviation with migration plan for v1.1.

**Conformance prerequisite chain:** Adding `Sendable` requires the full transitive closure: `BudgetState` (needs `Sendable`), `GovernanceState` (needs `Codable` + `Sendable`), `ActionEffect` (needs `Sendable`), `AuditEntry` (needs `Sendable`), `AgentAction` (already `Codable`, needs `Sendable`), `AuthorizationLevel` (needs `Sendable`).

```swift
// [TARGET v1.0]: add Codable + Sendable, retain var for reconciliation
public struct GovernanceState: Equatable, Codable, Sendable {
    public let id: UUID
    public var writablePaths: Set<String>
    public var protectedPatterns: Set<String>
    public var budget: BudgetState
    // auditLog removed from state — moved to AuditWriter (see below)
}
```

**Key change: Audit log extraction.** The in-memory `auditLog: [AuditEntry]` array currently inside `GovernanceState` is moved to a dedicated `AuditWriter` actor.

Rationale:
1. The audit log grows unboundedly, making synthesized `GovernanceState` `Equatable` comparison expensive. (Note: `ActionEffect`'s custom `Equatable` already works around this by comparing states by `id` only, so the evaluation hot path is unaffected. The issue is direct state-to-state comparison and memory growth.)
2. Replay does not require the audit log to be in state — replay verifies governance decisions, not the log itself.
3. Persistence requires append-only file writes, not in-memory array serialization.
4. This separation is consistent with the SwiftVector principle: the reducer produces state and effects; the effect system handles logging.

**Migration impact assessment.** Extracting the audit log is not a simple field removal. The following code currently writes directly to `state.auditLog`:

| File | Method | Line(s) | What it does |
|---|---|---|---|
| `GovernanceReducer.swift` | `logTransition` | 172 | Appends `AuditEntry` with `Date()` and `UUID()` inside the reducer |
| `GovernanceReducer.swift` | `increaseBudget` | 197 | Appends Steward intervention audit entry with `Date()` |
| `GovernanceReducer.swift` | `resetBudget` | 217 | Appends Steward intervention audit entry with `Date()` |
| `Steward.swift` | `logSuspension` | 95 | Appends suspension audit entry with `Date()` |

This extraction also resolves the `Date()` and `UUID()` violations in the reducer, because those calls exist in the `AuditEntry` construction inside `logTransition`. Removing `logTransition` from the reducer and replacing it with `AuditData` in `ActionEffect` eliminates the non-determinism at its source.

**[TARGET v1.0]:** The reducer returns audit data as part of `ActionEffect` (see below), and the orchestrator stamps `id`, `timestamp`, and `agentId` from injected dependencies before routing to the `AuditWriter`.

### ActionEffect (Extended)

**[CURRENT]** `ActionEffect` conforms to `Equatable` only (no `Sendable`). Its custom `Equatable` implementation compares `.allow` and `.transition` cases by `GovernanceState.id` only, not full state equality. v1.0 must update or replace this custom implementation when adding `AuditData` associated values.

```swift
// [CURRENT]
public enum ActionEffect: Equatable {
    case allow(GovernanceState)
    case reject(String)
    case transition(GovernanceState, message: String)
    case requireApproval(level: AuthorizationLevel, reason: String)
}

// [TARGET v1.0] — requires Sendable conformance chain (see Governance State section)
public enum ActionEffect: Equatable, Sendable {
    case allow(GovernanceState, auditData: AuditData)
    case reject(String, auditData: AuditData)
    case transition(GovernanceState, message: String, auditData: AuditData)
    case requireApproval(level: AuthorizationLevel, reason: String, auditData: AuditData)
}

public struct AuditData: Equatable, Sendable {
    public let action: String
    public let effect: String
    public let priorSpend: Int
    public let newSpend: Int
    public let enforcement: BudgetState.EnforcementLevel
}
```

**Tradeoff:** Adding `AuditData` to every case increases verbosity but makes the reducer's output fully self-describing without side effects. The orchestrator stamps `id`, `timestamp`, and `agentId` from injected dependencies before passing to the `AuditWriter`.

### AgentAction (Extended for Integration)

```swift
public enum AgentAction: Equatable, Codable, Sendable {
    // Existing
    case writeFile(path: String, content: String)
    case research(estimatedTokens: Int)
    case sendEmail(to: String, subject: String, body: String)
    case deleteFile(path: String)
    case executeShellCommand(command: String)

    // New for v1.0
    case networkRequest(destination: String, method: String)  // R3 (if OQ-4 resolved)
    case readFile(path: String)                                // if OQ-10 resolved
    case unknown(toolName: String, parameters: String)         // catch-all for unmapped OpenClaw tools
}
```

The `unknown` case is the integration safety net: any OpenClaw tool call that doesn't map to a known `AgentAction` is classified at the highest authorization level (`systemMod`) and requires approval. This prevents new OpenClaw tools from bypassing governance.

### AuditEntry (Hardened)

**[CURRENT]** `AuditEntry.init` has default parameters `id: UUID = UUID()` and `timestamp: Date = Date()`. Every callsite in the codebase relies on these defaults: `GovernanceReducer.logTransition` (line 162), `GovernanceReducer.increaseBudget` (line 188), `GovernanceReducer.resetBudget` (line 208), and `Steward.logSuspension` (line 86). Removing defaults breaks all four callsites plus test code.

**[TARGET v1.0]:** Defaults removed. All values explicitly provided by the orchestrator using injected `Clock` and `IDGenerator`.

```swift
public struct AuditEntry: Codable, Equatable, Sendable {
    public let id: UUID            // Injected by orchestrator via IDGenerator
    public let timestamp: Date     // Injected by orchestrator via Clock
    public let action: String
    public let effect: String
    public let priorSpend: Int
    public let newSpend: Int
    public let enforcement: BudgetState.EnforcementLevel
    public let agentId: String?

    // [TARGET v1.0] No default parameters — all values explicitly provided
    public init(
        id: UUID,
        timestamp: Date,
        action: String,
        effect: String,
        priorSpend: Int,
        newSpend: Int,
        enforcement: BudgetState.EnforcementLevel,
        agentId: String?
    ) { ... }
}
```

### Configuration Schema

```yaml
# ~/.clawlaw/config.yaml (default location)
# Shipped default is embedded in binary and written on first run

version: 1

boundary:
  writable_paths:
    - "~/workspace"
  protected_patterns:
    - ".ssh"
    - "credentials"
    - ".env"
    - "keychain"

budget:
  ceiling: 50000          # tokens — see OQ-5 for rationale
  warning_threshold: 0.80
  critical_threshold: 0.95

authority:
  always_approve:
    - deleteFile
    - executeShellCommand
    - sendEmail
  approval_threshold: sensitive   # actions at or above this level require approval

# network:                # Uncomment when R3 is implemented
#   egress_allowlist:
#     - "api.anthropic.com"
#     - "api.openai.com"

audit:
  retention_days: 90
  export_format: json

steward:
  role_identifier: "STEWARD"
```

**Validation rules (enforced at load time):**
- `version` must be `1`
- `writable_paths` must not be empty (prevents blocking all writes)
- `ceiling` must be > 0
- `warning_threshold` must be < `critical_threshold`
- Both thresholds must be in (0, 1)
- `always_approve` items must be valid `AgentAction` case names
- `approval_threshold` must be a valid `AuthorizationLevel` case name

### Persistence Schema

**State file:** `~/.clawlaw/state.json`

```json
{
  "id": "uuid",
  "writablePaths": ["~/workspace"],
  "protectedPatterns": [".ssh", "credentials", ".env"],
  "budget": {
    "taskCeiling": 50000,
    "currentSpend": 12300,
    "enforcement": "degraded",
    "warningThreshold": 0.80,
    "criticalThreshold": 0.95
  }
}
```

Written after every state-changing operation (post-reducer). Enforcement reconciliation runs on load, so stale enforcement values are corrected automatically (existing mechanism).

**Audit file:** `~/.clawlaw/audit/YYYY-MM-DD.jsonl`

One JSON object per line, appended. Daily rotation. Retention enforced by audit pruning (daily check, delete files older than `retention_days`).

```jsonl
{"id":"uuid","timestamp":"2026-03-05T14:23:01Z","action":"research(estimatedTokens: 500)","effect":"Budget: 0 → 500","priorSpend":0,"newSpend":500,"enforcement":"normal","agentId":"OpenClaw"}
```

---

## APIs & Contracts

### Determinism Protocols (A1 Resolution)

```swift
// Injected into orchestrator, used to stamp audit entries
public protocol Clock: Sendable {
    func now() -> Date
}

public protocol IDGenerator: Sendable {
    func generate() -> UUID
}

// Production implementations
public struct SystemClock: Clock, Sendable {
    public func now() -> Date { Date() }  // deterministic: production-only, not in reducer
}

public struct SystemIDGenerator: IDGenerator, Sendable {
    public func generate() -> UUID { UUID() }  // deterministic: production-only, not in reducer
}

// Test implementations for deterministic replay
public struct FixedClock: Clock, Sendable {
    public let dates: [Date]
    private let index: ManagedAtomic<Int>  // or actor-isolated counter
    public func now() -> Date { dates[index.wrappingIncrementThenLoad(ordering: .relaxed) - 1] }
}

public struct FixedIDGenerator: IDGenerator, Sendable {
    public let ids: [UUID]
    private let index: ManagedAtomic<Int>
    public func generate() -> UUID { ids[index.wrappingIncrementThenLoad(ordering: .relaxed) - 1] }
}
```

**Design note:** In the target architecture, `Clock` and `IDGenerator` are NOT passed to the reducer. The reducer will be a pure function with zero injected dependencies. These protocols are used by the `GovernanceOrchestrator` (and `Steward` and `ApprovalQueue`) to stamp values that currently use direct `Date()` and `UUID()` calls.

### Non-Determinism Inventory (Current v0.1.0)

The following table catalogs every `Date()` and `UUID()` call in the codebase, classified by severity:

| File | Method | Line(s) | Call | Classification | Resolution |
|---|---|---|---|---|---|
| `GovernanceReducer.swift` | `logTransition` | 163 | `Date()` | **Violation (in reducer)** | Remove: replaced by `AuditData` in `ActionEffect` |
| `GovernanceReducer.swift` | `increaseBudget` | 189 | `Date()` | **Violation (in reducer)** | Remove: Steward stamps via injected `Clock` |
| `GovernanceReducer.swift` | `resetBudget` | 209 | `Date()` | **Violation (in reducer)** | Remove: Steward stamps via injected `Clock` |
| `Governance.swift` | `AuditEntry.init` | 307-308 | `UUID()`, `Date()` | **Violation (default params)** | Remove defaults: all values explicitly provided |
| `Governance.swift` | `GovernanceState.init` | 338 | `UUID()` | **Acceptable (identity)** | Retain with `// deterministic:` comment — state ID is for identity, not replay |
| `Steward.swift` | `logSuspension` | 87 | `Date()` | **Must inject** | Steward receives `Clock`; stamps audit entries |
| `ApprovalQueue.swift` | `PendingAction.init` | 25, 29 | `UUID()`, `Date()` | **Must inject** | `ApprovalQueue` receives `Clock` + `IDGenerator` |
| `ApprovalQueue.swift` | `PendingAction.age` | 41 | `Date()` | **Acceptable (actor, not stored in state)** | Retain with `// deterministic:` comment — runtime computation only |
| `ApprovalQueue.swift` | `approve` | 104 | `Date()` | **Must inject** | `ApprovalQueue` receives `Clock` |
| `ApprovalQueue.swift` | `reject` | 111 | `Date()` | **Must inject** | `ApprovalQueue` receives `Clock` |
| `ApprovalQueue.swift` | `approveAllBelow` | 126 | `Date()` | **Must inject** | `ApprovalQueue` receives `Clock` |
| `ApprovalQueue.swift` | `clearResolved` | 136 | `Date()` | **Acceptable (actor, not stored in state)** | Retain with `// deterministic:` comment — cleanup computation only |

**Key insight:** The three "Violation (in reducer)" calls are the most critical because they break the determinism guarantee that enables replay (R13, NFR-7). The audit log extraction (see Data Model) resolves all three by moving audit entry construction out of the reducer entirely. The "Must inject" calls in `Steward` and `ApprovalQueue` are in actor methods (side-effect territory) and are less critical but should be injected for test determinism.

### Reducer Contract

The reducer signature is unchanged between v0.1.0 and v1.0. The behavior of `bypassGate` is expanded.

```swift
public struct GovernanceReducer {
    public static func reduce(
        state: GovernanceState,
        action: AgentAction,
        bypassGate: Bool = false
    ) -> ActionEffect
}
```

**[CURRENT] `bypassGate` behavior (v0.1.0):** When `bypassGate == true`:
1. Skip Phase 1 (enforcement-level gate check) — this works
2. Phase 2 (`validateAction`) runs unconditionally — `deleteFile`, `executeShellCommand`, and `sendEmail` **always** return `.requireApproval`, even on approved re-evaluation
3. Result: approved high-risk actions re-enter the approval queue and can never execute

This is a confirmed bug. The existing test suite acknowledges it with a comment: *"the reducer doesn't know the action was already approved"* (ClawLawTests.swift, line 429). The approval queue test works around it by rejecting instead of approving.

> **Current reducer is also not a pure function.** It calls `Date()` three times inside `logTransition`, `increaseBudget`, and `resetBudget` (see Non-Determinism Inventory). These violations are resolved by the audit log extraction described above.

**[TARGET v1.0] `bypassGate` behavior — R11 dual-bypass.** When `bypassGate == true`:
1. Skip Phase 1 (enforcement-level gate check) — existing behavior, retained
2. Skip Phase 2 action-type approval for `deleteFile`, `executeShellCommand`, `sendEmail` — **new behavior**
3. Still apply Phase 2 boundary checks (path allowlist, protected patterns) — safety preserved
4. Still apply Phase 3 budget impact — accounting preserved

This change is required by HRD R11 and is the minimum modification needed to make the approval workflow functional for high-risk actions.

### Orchestrator Contract

**[CURRENT]** The orchestrator has two stored properties (`steward: Steward`, `agentId: String`) and delegates all state management to the `Steward` actor. It does not accept `Clock`, `IDGenerator`, `AuditWriter`, or `StateStore`. It does not have `auditEntries` or `exportAudit` methods.

**[TARGET v1.0]:**

```swift
public actor GovernanceOrchestrator {
    private let steward: Steward
    private let agentId: String
    private let clock: Clock              // new
    private let idGenerator: IDGenerator  // new
    private let auditWriter: AuditWriter  // new
    private let stateStore: StateStore    // new

    public init(
        initialState: GovernanceState,
        agentId: String = "OpenClaw",
        clock: Clock = SystemClock(),
        idGenerator: IDGenerator = SystemIDGenerator(),
        auditWriter: AuditWriter,
        stateStore: StateStore
    )

    // Existing (retained)
    public func propose(_ action: AgentAction) async -> ProposalResult
    public func approve(actionId: UUID) async -> Steward.ApprovalResult
    public func reject(actionId: UUID, reason: String) async
    public func increaseBudget(to newCeiling: Int) async -> GovernanceState
    public func resetBudget() async -> GovernanceState
    public func currentState() async -> GovernanceState
    public func pendingApprovals() async -> [ApprovalQueue.PendingAction]

    // New for v1.0
    public func auditEntries(from: Date, to: Date) async -> [AuditEntry]
    public func exportAudit(format: ExportFormat) async throws -> Data
}
```

### Integration Adapter Contract

```swift
/// Translates OpenClaw tool calls into typed AgentActions
public protocol OpenClawAdapter: Sendable {
    /// Convert an OpenClaw tool invocation into a governance action
    func translate(toolName: String, parameters: [String: Any]) -> AgentAction

    /// Convert a governance decision into an OpenClaw-compatible response
    func respond(to effect: ActionEffect, originalTool: String) -> OpenClawResponse
}

public struct OpenClawResponse: Sendable {
    public let allowed: Bool
    public let message: String
    public let shouldRetry: Bool  // for approval workflow: agent should poll/wait
}
```

### CLI Interface Contract (R21)

**[CURRENT] CLI (v0.1.0):**
```
clawlaw demo [--budget N]   # Interactive governance demonstration
clawlaw test                # Run the five governance experiments
clawlaw monitor             # Placeholder for real-time monitoring
```

These commands are retained for development and demonstration purposes.

**[TARGET v1.0] CLI — new Steward commands:**
```
clawlaw status                          # Current enforcement, budget, pending approvals
clawlaw approve <id>                    # Approve a pending action
clawlaw reject <id> [--reason TEXT]     # Reject a pending action
clawlaw budget increase <amount>        # Increase budget ceiling
clawlaw budget reset                    # Reset spend to zero
clawlaw audit [--from DATE] [--to DATE] # View audit trail
clawlaw audit --export json             # Export audit as JSON
clawlaw config validate [--path FILE]   # Validate configuration file
clawlaw config init                     # Write default config to ~/.clawlaw/config.yaml
clawlaw daemon                          # Run governance proxy (integration mode)
```

### Message Formatting

**Design decision:** The current codebase uses emoji prefixes in governance messages (e.g., `"❌ HALTED"`, `"⚠️ CRITICAL"`, `"⏸️ SUSPENDED"`). These appear in reducer output, orchestrator results, and CLI display. Since audit trail messages are persisted to JSONL and may be consumed by SIEM tools (Persona P3), v1.0 adopts a dual-format approach:
- **Human-facing output** (CLI, adapter responses): retains emojis for readability
- **Audit trail entries** (`AuditData.effect`): uses plain-text descriptors only (e.g., `"HALTED"`, `"CRITICAL"`, `"SUSPENDED"`)

---

## Key Flows

### Flow 1: Agent Action Evaluation (Happy Path)

```
1. OpenClaw Gateway prepares tool call (e.g., writeFile)
2. Intercept Adapter receives tool call before execution
3. Adapter translates tool call → AgentAction.writeFile(path:content:)
4. Adapter calls Orchestrator.propose(action)
5. Orchestrator reads current GovernanceState
6. Orchestrator calls GovernanceReducer.reduce(state:action:)
7. Reducer Phase 1: enforcement level gate → pass (normal mode)
8. Reducer Phase 2: validateAction → path allowed, not protected → pass
9. Reducer Phase 3: applyBudgetImpact → cost applied, no transition
10. Reducer returns .allow(newState, auditData)
11. Orchestrator stamps AuditEntry with clock.now(), idGenerator.generate(), agentId
12. Orchestrator sends AuditEntry to AuditWriter (async, non-blocking)
13. Orchestrator persists newState via StateStore (async, non-blocking)
14. Orchestrator updates Steward's in-memory state
15. Orchestrator returns .allowed to Adapter
16. Adapter sends allow response to OpenClaw Gateway
17. OpenClaw Gateway executes the tool call on the host
```

### Flow 2: High-Risk Action Approval (R10/R11)

```
1. Agent proposes: AgentAction.deleteFile(path: "/workspace/old.txt")
2. Orchestrator → Reducer.reduce(state, action, bypassGate: false)
3. Reducer Phase 1: enforcement gate → pass (normal mode)
4. Reducer Phase 2: validateAction(deleteFile) → .requireApproval(sensitive, "File deletion requires human authorization")
5. Orchestrator stamps audit (SUSPENDED), writes to AuditWriter
6. Orchestrator submits to ApprovalQueue → returns approvalId
7. Adapter returns shouldRetry=true to OpenClaw (action suspended)
8. --- Human reviews via CLI: `clawlaw status` → sees pending action ---
9. Human runs: `clawlaw approve <approvalId>`
10. CLI → Orchestrator.approve(actionId)
11. Steward retrieves action from ApprovalQueue
12. Steward calls Reducer.reduce(state, action, bypassGate: true)    ← KEY
13. Reducer Phase 1: SKIPPED (bypassGate)
14. Reducer Phase 2: deleteFile → SKIPPED for action-type approval   ← NEW (R11 fix)
                      boundary check still runs → path allowed → pass
> **Note:** Steps 13-14 represent [TARGET v1.0] behavior. In v0.1.0, Phase 2 re-triggers `.requireApproval` for action-type approval even when `bypassGate == true`, preventing approved high-risk actions from executing. See Phase 0.
15. Reducer Phase 3: budget impact → cost applied
16. Reducer returns .allow(newState, auditData)
17. Orchestrator stamps audit (APPROVED + EXECUTED), writes to AuditWriter
18. Orchestrator persists state, returns .executed to CLI
19. Adapter notifies OpenClaw: action approved, proceed
20. OpenClaw executes the deletion
```

### Flow 3: Budget Exhaustion (Gated → Halted)

```
1. Current state: spend=9900, ceiling=10000, enforcement=gated
2. Agent proposes: research(estimatedTokens: 200)
3. Reducer Phase 1: enforcement == .gated → .requireApproval (gated gate)
4. Action suspended. Human notified.
5. Human approves via CLI
6. Steward → Reducer.reduce(state, action, bypassGate: true)
7. Reducer Phase 1: SKIPPED
8. Reducer Phase 2: research → no validation issues
9. Reducer Phase 3: spend 9900 + 200 = 10100, ratio = 1.01 > 1.0 → halted
10. Reducer returns .transition(newState, "HALTED: Budget exhausted")
11. Orchestrator persists halted state to disk
12. All subsequent proposals → immediate .reject("System halted")
13. Human must run: `clawlaw budget increase <amount>` or `clawlaw budget reset`
```

### Flow 4: Process Restart Recovery

```
1. ClawLaw process terminates (crash, manual stop, system restart)
2. On startup: ConfigLoader reads ~/.clawlaw/config.yaml
3. StateStore reads ~/.clawlaw/state.json
4. BudgetState.init(from: decoder) runs enforcement reconciliation
5. If spend was 9900/10000 and enforcement was stored as "normal" (bug/corruption):
   → reconciliation corrects to "gated"
6. If state.json missing: fresh state from config defaults
7. AuditWriter opens today's audit file in append mode
8. Orchestrator resumes with recovered state
9. Pending approvals in ApprovalQueue are lost on restart
   → Documented limitation: pending actions must be re-proposed
   → AuditWriter recorded the original SUSPENDED event for traceability
```

### Flow 5: Configuration Protection (R19)

```
1. Agent proposes: writeFile(path: "~/.clawlaw/config.yaml", content: "...")
2. Reducer Phase 2: path check
   a. Is ~/.clawlaw/ in writablePaths? → No (safe defaults exclude it) → REJECT
   b. Even if user adds ~/.clawlaw/ to writablePaths:
      → ConfigLoader adds "config.yaml" to protectedPatterns at load time (hardcoded)
      → Protected pattern match → .requireApproval
   c. Even if human approves: config reload detects agent-id ≠ STEWARD → reject
3. Configuration can only be modified by the human editing the file directly
```

---

## State & Edge Cases

### State Machine: Enforcement Levels

```
                   spend >= 80%              spend >= 95%            spend > 100%
    ┌─────────┐  ─────────────▶  ┌──────────┐  ──────────▶  ┌────────┐  ───────▶  ┌────────┐
    │  NORMAL │                  │ DEGRADED │               │ GATED  │            │ HALTED │
    └─────────┘  ◀─────────────  └──────────┘  ◀──────────  └────────┘  ◀───────  └────────┘
                  increaseBudget              increaseBudget            resetBudget
                  (ratio < 80%)              (ratio < 95%)            increaseBudget
                                                                      (ratio ≤ 100%)
```

**Transition invariant:** Enforcement can only increase via reducer. Decrease requires Steward intervention (`increaseBudget` or `resetBudget`), which recalculates from the new ratio.

### Edge Cases

| Scenario | Behavior | Rationale |
|---|---|---|
| Spend at exactly 100% (10000/10000) | `gated`, NOT `halted` | Code uses `ratio > 1.0` for halted; `>= criticalThreshold` for gated |
| Budget ceiling set to 0 | `halted` immediately | `calculateEnforcementLevel` returns `.halted` when `ceiling <= 0` |
| Zero-cost action in gated mode | Passes gated gate; Phase 2 may still catch it | Gated check is `action.tokenCost > 0`, so zero-cost actions pass. Phase 2 independently triggers `.requireApproval` for `deleteFile`, `executeShellCommand`, `sendEmail` based on action type, regardless of cost. These are two separate mechanisms. Note: no current action type has `tokenCost == 0` except `research(estimatedTokens: 0)` — all other types have fixed costs > 0. |
| Zero-cost research in gated mode | Allowed (passes gate and Phase 2) | `research(estimatedTokens: 0)` has tokenCost 0, passes gated gate check. Phase 2 allows research. Budget unaffected. |
| `bypassGate` on a boundary violation | Still rejected | Bypass only skips Phase 1 and Phase 2 action-type approval; boundary checks in Phase 2 still run |
| Config file missing on startup | Write shipped defaults, continue | First-run experience: safe defaults protect P2 users |
| Config file invalid YAML | Reject startup with clear error | Never fall back to no-governance; fail closed (NFR-4) |
| State file corrupt/invalid | Start from config defaults, log warning | Audit trail preserved in separate files; state is recoverable |
| Audit file full disk | Log warning, continue governance (in-memory) | Governance decisions must not depend on audit I/O (NFR-1) |
| Concurrent CLI + agent action | Actor isolation serializes access | `GovernanceOrchestrator` is an actor; all state mutations are serialized |
| OpenClaw sends unknown tool name | `AgentAction.unknown` → `systemMod` → requireApproval | Unknown tools get maximum scrutiny |

### Failure Modes

| Failure | Detection | Behavior | Recovery |
|---|---|---|---|
| Reducer throws (should be impossible) | `do/catch` in orchestrator | Reject action, log error (fail-closed) | Automatic; next action proceeds normally |
| State persistence fails | `StateStore.save()` throws | Log warning, continue with in-memory state | State recovers from last successful write on restart |
| Audit write fails | `AuditWriter.write()` throws | Log warning, continue governance | Audit gap documented; governance unaffected |
| OpenClaw adapter connection lost | Adapter health check | All actions blocked (fail-closed, NFR-4) | Adapter reconnects; pending actions re-proposed |
| Config file permissions wrong | Startup check | Warn user, refuse to start if world-readable | User fixes permissions manually |
| Approval queue lost on crash | Detected on restart (empty queue) | Prior SUSPENDED entries exist in audit | Agent re-proposes actions; human re-approves |

---

## Security & Privacy

### Threat Model (ClawLaw-Specific)

ClawLaw's threat model is narrower than OpenClaw's. ClawLaw does not defend against OS-level attacks, kernel exploits, or hardware compromise. It defends against:

1. **Agent-initiated boundary violation.** The agent attempts to write, delete, or execute outside governance boundaries. Defense: reducer rejects before I/O.
2. **Agent-initiated governance modification.** The agent attempts to modify its own configuration. Defense: R19 (config path protection, hardcoded).
3. **Stale enforcement bypass.** Deserialized or manually constructed state has incorrect enforcement. Defense: enforcement reconciliation in `BudgetState`.
4. **Approval bypass via re-proposal.** Agent re-proposes a rejected action hoping for different result. Defense: reducer is deterministic — same state + same action = same decision.
5. **Unknown tool escalation.** OpenClaw adds a new tool that ClawLaw doesn't recognize. Defense: `AgentAction.unknown` classified as `systemMod`.
6. **Path traversal.** The agent uses `../` sequences to escape the allowlist (e.g., `/workspace/../etc/passwd`). Defense: **Not yet implemented.** Current `isPathAllowed` uses `hasPrefix` string matching, which is vulnerable to traversal. v1.0 must add lexical path normalization (`.`, `..`, redundant separators) via `URL(fileURLWithPath:).standardized.path` before allowlist comparison. Note: Swift's `.standardized` performs lexical normalization only — it does not resolve symlinks (`.resolvingSymlinksInPath()` does). Symlink hardening is an integration/runtime policy concern, not a reducer responsibility. Added to Phase 1 task list.

### Attack Surface Minimization (NFR-8)

| Surface | Status |
|---|---|
| New listening ports | None unless HTTP proxy interception chosen (localhost only, bound to 127.0.0.1) |
| New network services | None; ClawLaw does not make outbound connections |
| Credential storage | Config file only; permissions 0600; no secrets stored (only paths, thresholds, patterns) |
| Process privileges | Same user as OpenClaw; no elevated privileges required |

### File Permissions (NFR-9)

```
~/.clawlaw/
  config.yaml          0600  (user read/write only)
  state.json           0600
  audit/
    2026-03-05.jsonl   0600
```

Permissions set on creation. Startup check warns and refuses to proceed if config or state files are more permissive than 0600.

---

## Performance & Reliability

### Latency Budget (NFR-1)

Target: p99 < 10ms for `GovernanceReducer.reduce()`.

The reducer is a pure function operating on in-memory structs. No I/O, no allocation beyond the return value, no locks (value types). Expected latency: < 1ms.

**Latency-sensitive path:**
1. `reduce()` — pure computation, < 1ms
2. Audit stamp — `clock.now()` + `idGenerator.generate()`, < 0.1ms
3. State persistence — **async**, non-blocking, off the critical path
4. Audit write — **async**, non-blocking, off the critical path

**Design decision:** State persistence and audit writes are fire-and-forget from the orchestrator's perspective. The orchestrator updates in-memory state synchronously and returns to the caller. Persistence happens asynchronously on a background task. If persistence fails, governance continues with in-memory state and logs a warning.

### Throughput (NFR-2)

Target: 10 actions/second sustained.

At < 1ms per `reduce()` call, the theoretical throughput is ~1000 actions/second. Actor serialization adds overhead but the bottleneck is OpenClaw's tool execution (100ms-3s per call), not governance evaluation. 10 actions/second is achievable with margin.

### Reliability (NFR-3, NFR-4)

**Fail-closed guarantee:** The orchestrator wraps all reducer calls in `do/catch`. On any unexpected error, the action is rejected with "Governance evaluation error: [description]". The system never allows an action when governance cannot evaluate it.

```swift
// In GovernanceOrchestrator.propose()
do {
    let effect = GovernanceReducer.reduce(state: currentState, action: action)
    // ... handle effect
} catch {
    // Fail closed: reject on any unexpected error
    return .rejected(reason: "Governance evaluation error: \(error.localizedDescription)")
}
```

**Note:** The reducer currently cannot throw (it returns `ActionEffect`, not `throws`). The `do/catch` is defensive against future changes or unexpected runtime errors in the orchestrator path.

---

## Observability

### Structured Logging

ClawLaw uses two logging channels:

1. **Audit trail** (structured, append-only, JSONL) — governance-significant events per R12. This is the compliance record.
2. **Operational log** (os_log / stderr) — startup, shutdown, config load, persistence errors, adapter health. This is for debugging.

### Health Indicators

The CLI `clawlaw status` command outputs:

```
ClawLaw v1.0.0
Enforcement:  gated
Budget:       9,500 / 10,000 (95%)
Pending:      2 actions awaiting approval
Uptime:       4h 23m
State file:   ~/.clawlaw/state.json (last write: 12s ago)
Audit file:   ~/.clawlaw/audit/2026-03-05.jsonl (247 entries today)
Config:       ~/.clawlaw/config.yaml (valid)
```

### Metrics (Future v2.0)

v1.0 does not expose structured metrics. The audit trail contains sufficient data to derive:
- Actions per hour/day
- Approval rate / rejection rate
- Time-to-approval for suspended actions
- Budget utilization over time
- Enforcement level transitions per day

---

## Migration / Rollout Plan

### Phase 0: Critical Fix (Pre-Sprint)

**Goal:** Make the approval→execute flow functional. This is a prerequisite for operational use case documentation and all integration testing.

| Task | Requirement | Depends On |
|---|---|---|
| Fix R11 dual-bypass in reducer: `bypassGate == true` must skip Phase 2 action-type approval for `deleteFile`, `executeShellCommand`, `sendEmail` while preserving boundary checks and budget impact | R10, R11 | None |
| Add R11 bypass test: approved `deleteFile` executes without re-entering approval queue | R11 | R11 fix |

**Validation gate:** `swift test` passes. An approved `deleteFile` action returns `.allow`, not `.requireApproval`, when re-evaluated with `bypassGate: true`.

### Phase 1: Core Hardening (Week 1-2)

**Goal:** Deterministic reducer, persistence, configuration.

| Task | Requirement | Depends On |
|---|---|---|
| Inject `Clock` + `IDGenerator` protocols | NFR-7, A1 | None |
| Remove `Date()` / `UUID()` from reducer path | NFR-7, A1 | Clock + IDGenerator |
| Extract audit log from `GovernanceState` | Internal | None |
| Implement `AuditWriter` actor (JSONL) | R12, NFR-5, NFR-6 | Audit extraction |
| Implement `StateStore` actor (JSON) | R7, OQ-3 | Audit extraction |
| Add `Codable` + `Sendable` to `GovernanceState` | NFR-7 | Audit extraction |
| Add `AuditData` to `ActionEffect` cases | R12 | Audit extraction |
| Determinism replay tests | R13, NFR-7 | Clock + IDGenerator |
| Add lexical path normalization (`.`, `..`, separators) to `isPathAllowed`/`isPathProtected` | R1, R2, Security | None |
| Add input validation to `increaseBudget` (reject `newCeiling <= 0`) | R20 | None |

**Validation gate:** `swift test` passes. Determinism tests verify identical replay. No `Date()` or `UUID()` in reducer path (grep scan clean). Lexical normalization test: `/workspace/../etc/passwd` is rejected.

### Phase 2: Configuration & Defaults (Week 2-3)

**Goal:** YAML configuration with safe defaults.

| Task | Requirement | Depends On |
|---|---|---|
| Add `Yams` dependency to `ClawLawConfig` target | R18 | None |
| Define configuration schema + validation | R18 | None |
| Implement `ConfigLoader` | R17, R18 | Schema |
| Ship default config (embedded in binary) | R4, R17 | ConfigLoader |
| First-run config write (`clawlaw config init`) | R4 | ConfigLoader |
| Config protection (hardcoded protected pattern) | R19 | ConfigLoader |
| Config validation CLI (`clawlaw config validate`) | R21 | ConfigLoader |

**Validation gate:** Fresh install with no config → safe defaults applied. `grep -rn 'Date()' Sources/ | grep -v 'deterministic:'` clean. Config validation rejects invalid files.

### Phase 3: CLI Completion (Week 3-4)

**Goal:** Full Steward CLI.

| Task | Requirement | Depends On |
|---|---|---|
| `clawlaw status` command | R21 | StateStore |
| `clawlaw approve <id>` command | R20, R21 | ApprovalQueue |
| `clawlaw reject <id>` command | R20, R21 | ApprovalQueue |
| `clawlaw budget increase <amount>` | R20, R21 | StateStore |
| `clawlaw budget reset` | R20, R21 | StateStore |
| `clawlaw audit` (view + export) | R14, R21 | AuditWriter |
| `clawlaw daemon` (governance proxy) | R15 | Integration adapter |

**Validation gate:** All CLI commands functional. `clawlaw status` reflects real-time governance state.

### Phase 4: OpenClaw Integration (Week 4-6)

**Goal:** Governance proxy intercepts OpenClaw tool calls.

| Task | Requirement | Depends On |
|---|---|---|
| Investigate OpenClaw interception surfaces | OQ-1 | Mac mini M4 Pro (D1) |
| Implement `OpenClawAdapter` | R15, R16 | Investigation complete |
| Action translator (tool name → AgentAction) | R15 | Adapter |
| Response mapper (ActionEffect → OpenClaw response) | R15 | Adapter |
| `clawlaw daemon` integration mode | R15 | Adapter |
| Integration tests with live OpenClaw | R15 | D1, D4 |
| Unknown tool handling | R15 | Adapter |

**Validation gate:** OpenClaw + ClawLaw running together. Agent action intercepted, evaluated, and allowed/rejected before host execution. Unknown tools classified as `systemMod`.

### Phase 5: Hardening & Release (Week 6-7)

**Goal:** Fuzz testing, documentation, release packaging.

| Task | Requirement | Depends On |
|---|---|---|
| Fuzz testing (reducer, config parser) | NFR-3 | All phases |
| Boundary test suite (Law 0 experiments) | R1, R2 | Phase 1 |
| Authority test suite (Law 8 experiments) | R9, R10, R11 | Phase 1 |
| Replay verification test suite | R13 | Phase 1 |
| File permission enforcement | NFR-9 | Phase 2 |
| README, installation guide | G3 | Phase 4 |
| Release binary (Homebrew formula) | G3, G4 | All phases |

---

## Testing Strategy

### Test Pyramid

| Level | Count (est.) | What | Tools |
|---|---|---|---|
| Unit (reducer) | 50+ | Every action type × every enforcement level × bypass variations | Swift Testing |
| Unit (config) | 20+ | Valid configs, invalid configs, edge cases, permission checks | Swift Testing |
| Unit (persistence) | 15+ | Write/read cycle, corruption recovery, concurrent access | Swift Testing |
| Integration | 20+ | Orchestrator + Steward + ApprovalQueue full workflows | Swift Testing (async) |
| Determinism | 10+ | Replay N times, verify identical output | Swift Testing |
| Fuzz | 1 suite | Random action sequences against random states | Swift Testing + custom fuzzer |
| E2E | 5+ | ClawLaw + OpenClaw live interaction | Manual + scripted (Phase 4) |

### Critical Test Categories

**Determinism tests (NFR-7, R13):**
```swift
@Test("Reducer determinism: identical inputs produce identical outputs")
func reducerDeterminism() {
    for (state, action) in testCases {
        let result1 = GovernanceReducer.reduce(state: state, action: action)
        let result2 = GovernanceReducer.reduce(state: state, action: action)
        #expect(result1 == result2)
    }
}
```

**Replay tests (R13):**
```swift
@Test("Replay produces identical final state")
func replayVerification() {
    let initial = GovernanceState.mock(taskCeiling: 10000)
    let actions: [AgentAction] = [ /* sequence */ ]
    let clock = FixedClock(dates: [...])
    let idGen = FixedIDGenerator(ids: [...])

    let finalState1 = replay(initial, actions, clock, idGen)
    let finalState2 = replay(initial, actions, clock.reset(), idGen.reset())
    #expect(finalState1 == finalState2)
}
```

**Enforcement reconciliation (R8):**
Existing tests in `ClawLawTests.swift` cover this comprehensively (5 patterns). Retain and expand.

**R11 dual-bypass tests:**
```swift
@Test("Approved deleteFile executes without re-triggering approval")
func approvedActionBypassesApprovalGate() async {
    let orchestrator = GovernanceOrchestrator(initialState: .mock(taskCeiling: 10000), ...)
    let result = await orchestrator.propose(.deleteFile(path: "/workspace/old.txt"))
    guard case .suspended(let id, _) = result else { Issue.record("Expected suspension"); return }

    let approval = await orchestrator.approve(actionId: id)
    guard case .executed = approval else { Issue.record("Expected execution, got \(approval)"); return }
    // Key assertion: action executed, not re-suspended
}
```

**Fail-closed tests (NFR-4):**
```swift
@Test("Governance unavailability blocks all actions")
func failClosed() async {
    // Simulate governance error (e.g., corrupt state)
    // Verify all actions rejected
}
```

---

## Alternatives Considered

### Architecture Decision 1: OpenClaw Interception Strategy

**Options investigated:**

| Strategy | Description | Pros | Cons |
|---|---|---|---|
| **A. HTTP proxy** | Run ClawLaw as a reverse proxy in front of OpenClaw's Gateway (port 18789) | No source modification; transparent to clients; inspects all tool calls | Adds network hop; must parse OpenClaw's HTTP protocol; OpenClaw must be configured to use proxy |
| **B. Process wrapper** | Launch OpenClaw as a child process of ClawLaw; intercept stdio/tool calls at the process boundary | Full control; no port changes | Fragile; depends on OpenClaw's startup sequence; may break with OpenClaw updates |
| **C. Filesystem hook (FUSE)** | Mount a governed filesystem overlay on the workspace directory | Transparent to OpenClaw; enforces at OS level | macOS FUSE support is deprecated; requires kernel extension or macFUSE; elevated privileges |
| **D. OpenClaw plugin/skill** | Package ClawLaw as an OpenClaw skill that wraps tool execution | Native integration; no external process | Skills can be bypassed; runs inside the governed process (fox guarding henhouse) |

**Decision: A (HTTP proxy) as primary, B (process wrapper) as fallback.**

HTTP proxy is the least invasive strategy that satisfies R16 (no source modification). It interposes between OpenClaw's clients (messaging platforms) and the Gateway. If OpenClaw's HTTP interface proves unsuitable (see OQ-1), the process wrapper provides a fallback that still avoids source modification.

**Tradeoff:** HTTP proxy adds ~1ms of network overhead per action. This is well within the 10ms latency budget (NFR-1). The proxy only intercepts tool-execution requests, not all Gateway traffic.

### Architecture Decision 2: Audit Log Storage

**Options:**

| Strategy | Pros | Cons |
|---|---|---|
| **A. In-memory array (current)** | Simple; no I/O | Lost on restart; grows unboundedly; makes state comparison expensive |
| **B. SQLite** | Rich queries; transactions; proven | External dependency; overkill for append-only log; complicates NFR-10 |
| **C. JSONL files (chosen)** | Append-only by design; human-readable; no dependencies; simple rotation | No indexed queries; export requires full scan |

**Decision: C (JSONL files).**

JSONL is the simplest format that satisfies R12 (append-only), R14 (structured export), NFR-5 (append-only integrity), and NFR-6 (retention). Daily rotation keeps files manageable. The audit trail for a single user on a single machine will not exceed thousands of entries per day — linear scan is sufficient for v1.0.

### Architecture Decision 3: Configuration Format

**Options:** JSON, YAML, TOML, custom DSL.

**Decision: YAML (via Yams library).**

YAML is human-readable, supports comments (critical for documenting governance policies), and is familiar to DevOps users (Persona P1). JSON lacks comments. TOML is less widely known. A custom DSL increases learning curve. The `Yams` library is well-maintained and adds minimal binary size.

**Tradeoff:** Adds one external dependency (`Yams`). This dependency is in `ClawLawConfig`, not `ClawLawCore`, preserving NFR-10.

### Architecture Decision 4: Network Egress Control (R3)

**Options investigated:**

| Strategy | Feasibility on macOS without elevated privileges |
|---|---|
| Network Extension (packet filter) | Requires kernel extension signing or System Extension entitlement (App Store / MDM only) |
| Application-layer proxy (SOCKS/HTTP) | Requires OpenClaw to route through proxy; configuration-dependent, not architectural |
| DNS-level blocking | Only blocks by domain; easily circumvented by IP; requires resolver modification |
| `sandbox-exec` profile | Deprecated by Apple; limited to App Sandbox |

**Decision: Defer R3 to v1.1.**

There is no macOS mechanism for user-space network egress filtering without elevated privileges or entitlements that are only available via the App Store or MDM. The HRD already documents this as OQ-4 with deferral contingency. v1.0 will define the `networkRequest` action type and governance schema, but enforcement will be at the action-classification level (require approval for network actions), not at the packet level.

### Architecture Decision 5: State Immutability

**Options:**

| Strategy | Pros | Cons |
|---|---|---|
| **A. Full `let` + `.with()` (SwiftVector target)** | Strongest invariant; prevents accidental mutation | Requires rewriting enforcement reconciliation; significant refactor |
| **B. `var` with reconciliation (current)** | Working; reconciliation is proven; tests pass | Weaker invariant; relies on computed property discipline |
| **C. Hybrid: `let` for identity, `var` for mutable fields** | Pragmatic; preserves reconciliation | Partial compliance; mixed signals |

**Decision: B for v1.0, migrate to A in v1.1.**

The enforcement reconciliation mechanism is the most critical safety feature in the codebase. It works today with `var` and computed property setters. Refactoring to `let` + `.with()` while preserving reconciliation semantics is non-trivial and risks introducing bugs in a safety-critical path. v1.0 adds `Codable` + `Sendable` conformance and documents the migration plan.

---

## Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-D1 | OpenClaw HTTP protocol undocumented or changes frequently | Medium | High | Pin to tested OpenClaw version; adapter layer isolates protocol details |
| R-D2 | YAML config parsing introduces security vulnerability (e.g., billion laughs) | Low | Medium | Use Yams with size limits; validate before applying; fuzz test parser |
| R-D3 | Async audit writes lose entries on crash | Medium | Low | Write-ahead: flush on every enforcement transition (not every action) |
| R-D4 | `bypassGate` dual-bypass introduces unintended permission escalation | Low | High | Comprehensive test matrix: every action type × bypassGate × every enforcement level |
| R-D5 | Mac mini M4 Pro delivery delayed past March 4 | Low | Medium | Development proceeds on existing hardware; integration testing blocked |
| R-D6 | State file corruption after crash during write | Low | Medium | Atomic writes (write to temp file, rename); state is recoverable from config defaults |

---

## Open Questions

| ID | Question | Design Impact | Status |
|---|---|---|---|
| DQ-1 | What is OpenClaw's HTTP protocol for tool execution? (request/response format, headers, auth) | Determines adapter implementation details. Operational use cases should reference the `OpenClawAdapter` protocol as the interception boundary; flows are transport-agnostic until DQ-1 is resolved. | **Blocked on D1 (Mac mini)** |
| DQ-2 | Should the governance proxy bind to a separate port or replace OpenClaw's port? | Affects installation instructions and client configuration | Requires investigation |
| DQ-3 | What is the right default budget ceiling (OQ-5)? 50,000 tokens? 100,000? | Affects P2 (casual user) experience | Needs user research |
| DQ-4 | Should `AuditWriter` flush synchronously on enforcement transitions (degraded/gated/halted)? | Tradeoff: latency vs. audit completeness on crash | Recommend: yes for transitions, async for normal actions |
| DQ-5 | Should the `unknown` action type classification be configurable (e.g., user can map new tool names to action types)? | Affects config schema and adapter flexibility | Recommend: yes, add `tool_mappings` to config v1.1 |
| DQ-6 | How should the CLI communicate with a running daemon? Unix socket? Shared state file? | Affects `clawlaw daemon` + `clawlaw status` architecture | Recommend: Unix domain socket at `~/.clawlaw/clawlaw.sock` |
| DQ-7 | Should `PendingAction` be persisted to survive daemon restart? | Affects approval workflow reliability | Recommend: yes, in `~/.clawlaw/pending.json`, for v1.1 |

---

## Traceability Matrix

| HRD Req | Design Element(s) | Test/Validation |
|---|---|---|
| R1 (path allowlist) | `GovernanceReducer.validateAction` → `state.isPathAllowed()` | Unit: denied path test (existing) |
| R2 (protected patterns) | `GovernanceReducer.validateAction` → `state.isPathProtected()` | Unit: protected pattern test (existing) |
| R3 (network egress) | `AgentAction.networkRequest` type defined; enforcement deferred v1.1 | Schema test; enforcement test deferred |
| R4 (safe defaults) | `ConfigLoader` + embedded default config + `clawlaw config init` | Integration: fresh install applies defaults |
| R5 (budget transitions) | `BudgetState.calculateEnforcementLevel` | Unit: Experiments 1-3 (existing) |
| R6 (gated approval) | `GovernanceReducer.reduce` Phase 1 gated check | Unit: Experiment 3b (approval workflow) + 3c (suspension) (existing) |
| R7 (halt + no auto-resume) | `GovernanceReducer.reduce` Phase 1 halted reject; `StateStore` persists halted | Unit: Experiment 3b, 3d (existing); Integration: restart recovery |
| R8 (enforcement reconciliation) | `BudgetState` computed property setters + `init(from: Decoder)` | Unit: 5-pattern reconciliation suite (existing) |
| R9 (action classification) | `AgentAction.authorizationLevel` computed property. Note: `writeFile` has dynamic classification based on path content (`.ssh`/`credentials` → `.sensitive`, else `.sandboxWrite`). This duplicates the `protectedPatterns` mechanism in `validateAction`. v1.0 should consider unifying these. | Unit: each action type classification |
| R10 (always-approve actions) | `GovernanceReducer.validateAction` for deleteFile/executeShellCommand/sendEmail | Unit: approval queue test (existing) |
| R11 (bypass dual-gate) | **[TARGET v1.0]** `GovernanceReducer.reduce` with `bypassGate: true` skipping Phase 1 + Phase 2 approval. **Not implemented in v0.1.0** — current `bypassGate` only skips Phase 1. | Unit: new R11 bypass test (does not exist yet) |
| R12 (audit trail) | `AuditWriter` actor + `AuditData` in `ActionEffect` + orchestrator stamping | Integration: audit completeness after workflow |
| R13 (deterministic replay) | `Clock`/`IDGenerator` injection + `FixedClock`/`FixedIDGenerator` in tests | Replay verification test suite |
| R14 (structured export) | `clawlaw audit --export json` + `AuditWriter.export()` | CLI test: export produces valid JSON |
| R15 (interception) | `OpenClawAdapter` + `clawlaw daemon` proxy | E2E: OpenClaw action intercepted before host execution |
| R16 (no source modification) | HTTP proxy strategy (AD-1) | E2E: unmodified OpenClaw + ClawLaw running together |
| R17 (default config) | `ConfigLoader` + embedded defaults | Integration: fresh install applies defaults |
| R18 (user config) | `ConfigLoader` + YAML parsing + validation | Unit: valid/invalid config tests |
| R19 (config protection) | Hardcoded protected pattern for config path | Unit: agent cannot write to config path |
| R20 (Steward interface) | `Steward` actor + CLI commands | Integration: CLI → Steward → state change |
| R21 (CLI) | `ClawLawCLI` with status/approve/reject/budget/audit/config subcommands | CLI test: each subcommand functional |
| NFR-1 (10ms latency) | Reducer is pure computation; persistence async | Benchmark: p99 < 10ms on M4 Pro |
| NFR-2 (10 actions/sec) | Actor serialization; async I/O | Throughput benchmark |
| NFR-3 (no crash) | Reducer returns `ActionEffect` (no throws); orchestrator `do/catch` | Fuzz test: zero crashes |
| NFR-4 (fail closed) | Orchestrator rejects on error; adapter blocks on disconnect | Fault injection test |
| NFR-5 (append-only audit) | JSONL append; no delete/modify API | API review: no mutation methods |
| NFR-6 (90-day retention) | `AuditWriter` daily rotation + pruning | Integration: old files pruned |
| NFR-7 (pure reducer) | No `Date()`, `UUID()`, `.random` in reducer; `AuditData` returned, not written | Grep scan + determinism tests |
| NFR-8 (no new surface) | Proxy on localhost only; no outbound connections | Architecture review |
| NFR-9 (file permissions) | `0600` on creation; startup check | Unit: permission check |
| NFR-10 (Core: Foundation only) | `ClawLawCore` target has zero dependencies | `grep -rn "^import " Sources/ClawLawCore/ | grep -Ev "(Foundation)"` |

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0 | 2026-02-19 | Initial draft |
