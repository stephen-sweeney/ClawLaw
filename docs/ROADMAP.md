# SwiftVector / ClawLaw Integration Roadmap

## Technical Architecture and Implementation Plan

**Version:** 0.1.0-draft
**Author:** Seraphim
**Date:** February 15, 2026
**Status:** Pre-Implementation

> **Scope Note (Feb 19, 2026):** This document captures the long-term architectural vision
> spanning 5 phases (16+ weeks). **v1.0 implementation is specified in PLD.md** (PLD Phases
> 0-5 correspond to Roadmap Phases 1-4). Dashboard (Roadmap Phase 4), external integration
> (Phase 5), StackMint integration, and compile-time enforcement are post-v1.0 work.
> For the v1.0 sprint plan and backlog, see BACKLOG.md.

---

## 1. Architectural Vision

SwiftVector and ClawLaw are separate concerns that compose into a unified governance system for autonomous AI agents.

**SwiftVector** is the foundation — a framework for deterministic AI agent control. It provides the state machine architecture, the compile-time guarantees, and the runtime enforcement that make agent behavior predictable and auditable. SwiftVector answers the question: *how do you ensure an agent does only what it's authorized to do?*

**ClawLaw** is the governance layer built on SwiftVector. It defines the policies, tiers, permissions, and operational rules that determine what an agent is authorized to do in a given context. ClawLaw answers the question: *who decides what the agent may do, and how are those decisions enforced?*

The relationship is analogous to an operating system kernel and its security policy framework. SwiftVector is the kernel — it enforces. ClawLaw is the policy — it defines what to enforce. Neither is useful without the other. Together, they provide governance-as-architecture rather than governance-as-policy.

---

## 2. Core Architectural Principles

These principles constrain all design decisions in the roadmap.

### 2.1 State Authority

All agent permissions and behavioral boundaries are expressed as explicit state. No agent action may be authorized by prompt content alone. The state machine is the single source of truth for what an agent may do at any given moment.

**Implication:** Every governance rule in ClawLaw must compile down to a state or state transition in SwiftVector. If a rule cannot be expressed as state, it cannot be enforced deterministically and must be redesigned.

### 2.2 Compile-Time Guarantees

Swift's type system is used to make entire categories of governance violations impossible at compile time. Invalid state transitions, unauthorized tier escalations, and permission boundary violations should be caught by the compiler, not by runtime checks.

**Implication:** The governance model is encoded in Swift's type system. Tier definitions, permission sets, and transition rules are types, not configuration. This is the core differentiator from every other governance framework — they validate at runtime; SwiftVector rejects at compile time.

### 2.3 Separation of Mechanism and Policy

SwiftVector provides the mechanism (state machines, transition enforcement, audit logging). ClawLaw provides the policy (tier definitions, governance profiles, operational rules). A different governance policy could be built on SwiftVector without modifying SwiftVector itself.

**Implication:** SwiftVector's API surface must be general enough to support governance models beyond ClawLaw. ClawLaw is the flagship policy implementation, but SwiftVector is the reusable platform.

### 2.4 Auditability by Default

Every state transition, every permission check, every governance decision produces an auditable record. Audit is not an add-on feature — it is intrinsic to the state machine's operation.

**Implication:** The audit trail is a first-class architectural component, not a logging afterthought. The data model for audit events must be defined before any enforcement logic is implemented.

---

## 3. System Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Human Principal                    │
│         (decisions, approvals, overrides)            │
└─────────────┬───────────────────────┬───────────────┘
              │                       │
              ▼                       ▼
┌─────────────────────┐   ┌─────────────────────────┐
│   Operator Interface │   │   Governance Dashboard   │
│  (Telegram, CLI, UI) │   │  (audit, metrics, state) │
└─────────┬───────────┘   └───────────┬─────────────┘
          │                           │
          ▼                           ▼
┌─────────────────────────────────────────────────────┐
│                      ClawLaw                         │
│              Governance Policy Layer                 │
│                                                     │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ Tier Engine  │ │   Profile    │ │  Delegation   │ │
│  │             │ │   Manager    │ │   Chain       │ │
│  └──────┬──────┘ └──────┬───────┘ └──────┬───────┘ │
│         │               │                │         │
│  ┌──────┴───────────────┴────────────────┴───────┐ │
│  │           Policy Decision Engine               │ │
│  │  (evaluates: can this agent do this action     │ │
│  │   in this context at this tier?)               │ │
│  └──────────────────┬────────────────────────────┘ │
└─────────────────────┼──────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                    SwiftVector                       │
│            Deterministic Control Layer               │
│                                                     │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ State Machine│ │  Transition  │ │    Audit     │ │
│  │   Engine     │ │  Enforcer    │ │   Emitter    │ │
│  └──────┬──────┘ └──────┬───────┘ └──────┬───────┘ │
│         │               │                │         │
│  ┌──────┴───────────────┴────────────────┴───────┐ │
│  │           Agent Runtime Interface              │ │
│  │  (the boundary through which agents interact   │ │
│  │   with the governed system)                    │ │
│  └──────────────────┬────────────────────────────┘ │
└─────────────────────┼──────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                 Agent Execution Layer                 │
│                                                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────┐ │
│  │  OpenClaw  │ │  DevSwarm │ │  Content Pipeline │ │
│  │ Orchestr.  │ │  Agents   │ │     Agents        │ │
│  └───────────┘ └───────────┘ └───────────────────┘ │
│                                                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────────────┐ │
│  │  Claude   │ │  Gemini   │ │   Grok / Codex    │ │
│  │  (Opus)   │ │           │ │                   │ │
│  └───────────┘ └───────────┘ └───────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## 4. SwiftVector Core Components

### 4.1 State Machine Engine

The heart of SwiftVector. Manages the lifecycle of governed states and enforces valid transitions.

**Key types:**

```swift
// A governed state — the fundamental unit of SwiftVector
protocol GovernedState: Hashable, Codable {
    associatedtype Transition: StateTransition
    func canTransition(via: Transition) -> Bool
    func applying(_ transition: Transition) -> Self
}

// A state transition — must be explicitly defined
protocol StateTransition: Hashable, Codable {
    associatedtype Authorization: TransitionAuthorization
    var requiredAuthorization: Authorization { get }
}

// Who or what can authorize a transition
enum TransitionAuthorization {
    case principal          // Only the human operator
    case agent              // The agent itself (e.g., voluntary de-escalation)
    case automated          // System-level (e.g., test passage triggers)
    case inherited          // Delegated from a higher authority
}
```

**Compile-time enforcement:** Invalid transitions are not runtime errors — they are type errors. If a `Tier2State` has no defined transition to `Tier3State` that carries `TransitionAuthorization.agent`, then an agent attempting to self-escalate to Tier 3 doesn't fail at runtime. It doesn't compile.

### 4.2 Transition Enforcer

Validates that a requested state transition is authorized before allowing it to proceed.

**Responsibilities:**
- Verify that the requesting entity holds the required authorization level
- Verify that the transition is valid from the current state
- Verify that all preconditions for the transition are satisfied
- Block the transition and emit an escalation event if any check fails
- Forward valid transitions to the State Machine Engine for execution

### 4.3 Audit Emitter

Produces an immutable record of every governance-significant event.

**Audit event structure:**

```swift
struct AuditEvent: Codable {
    let id: UUID
    let timestamp: Date
    let eventType: AuditEventType
    let agentId: AgentIdentifier
    let profileId: GovernanceProfileIdentifier
    let previousState: AnyGovernedState
    let newState: AnyGovernedState
    let transition: AnyStateTransition
    let authorization: TransitionAuthorization
    let authorizedBy: AuthorityIdentifier  // who approved this
    let metadata: [String: String]
}

enum AuditEventType {
    case tierChange
    case taskAssigned
    case taskStarted
    case prSubmitted
    case prApproved
    case selfMerge
    case contentQueued
    case contentPublished
    case delegation
    case escalation
    case safetyHalt
    case overrideApplied
    case boundaryViolationAttempt
}
```

### 4.4 Agent Runtime Interface

The API surface through which agents interact with the governed system. Every agent action passes through this interface; there is no way to bypass it.

**Key operations:**

```swift
protocol AgentRuntime {
    // Query: What am I allowed to do right now?
    func permissions(for agent: AgentIdentifier) -> PermissionSet
    
    // Query: What tier am I operating at?
    func currentTier(for agent: AgentIdentifier) -> AutonomyTier
    
    // Query: What profile governs this workstream?
    func profile(for workstream: WorkstreamIdentifier) -> GovernanceProfile
    
    // Request: I want to do this action
    func request(_ action: GovernedAction, 
                 by agent: AgentIdentifier) -> ActionResult
    
    // Report: I've completed this work
    func report(_ completion: WorkCompletion, 
                by agent: AgentIdentifier) -> AcknowledgmentResult
    
    // Escalate: I need human decision
    func escalate(_ decision: EscalationRequest, 
                  by agent: AgentIdentifier) -> EscalationResult
    
    // Self-govern: I'm reducing my own tier
    func voluntaryDeescalation(by agent: AgentIdentifier, 
                                reason: String) -> TierChangeResult
}
```

---

## 5. ClawLaw Governance Components

### 5.1 Tier Engine

Manages the autonomy tier state for each agent and workstream combination. Built on SwiftVector's state machine.

```swift
enum AutonomyTier: Int, GovernedState, Comparable {
    case observeAndReport = 1
    case propose = 2
    case executeWithinBounds = 3
    case autonomousProduction = 4
    
    // Define valid transitions
    enum Transition: StateTransition {
        case escalate(to: AutonomyTier)
        case deescalate(to: AutonomyTier)
        
        var requiredAuthorization: TransitionAuthorization {
            switch self {
            case .escalate: return .principal    // Only human can escalate
            case .deescalate: return .agent      // Agent can self-deescalate
            }
        }
    }
}
```

### 5.2 Profile Manager

Manages governance profiles — the binding of a tier, a permission set, and operational rules to a specific domain of work.

```swift
struct GovernanceProfile: Codable {
    let id: GovernanceProfileIdentifier
    let name: String
    let workstreams: [WorkstreamIdentifier]
    let defaultTier: AutonomyTier
    let maxTier: AutonomyTier            // Ceiling — cannot be exceeded even by Principal
    let permissions: PermissionSet
    let boundaries: BoundarySet
    let escalationTriggers: [EscalationTrigger]
}

struct PermissionSet: Codable {
    let canRead: [ResourcePattern]
    let canWrite: [ResourcePattern]
    let canExecute: [ToolPattern]
    let canDelegate: Bool
    let canPropose: Bool
    let canMerge: Bool
    let canPublish: Bool
}

struct BoundarySet: Codable {
    let scopePatterns: [ResourcePattern]     // What files/repos/domains
    let rateLimits: RateLimitConfiguration   // How many changes per period
    let complexityThreshold: Int             // Changes above this trigger escalation
    let dependencyPolicy: DependencyPolicy   // New deps require approval?
}
```

### 5.3 Delegation Chain Manager

Tracks and enforces authority delegation from the Principal through the orchestrator to subordinate agents.

```swift
struct DelegationChain: Codable {
    let principal: AuthorityIdentifier
    let links: [DelegationLink]
    
    // Validates that no link in the chain exceeds its delegator's authority
    func validate() -> Result<Void, DelegationViolation>
}

struct DelegationLink: Codable {
    let delegator: AuthorityIdentifier
    let delegate: AgentIdentifier
    let grantedPermissions: PermissionSet    // Must be subset of delegator's permissions
    let grantedMaxTier: AutonomyTier         // Must be <= delegator's tier
    let scope: DelegationScope               // What this delegation covers
    let expiration: DelegationExpiration      // Time-bound or task-bound
}
```

### 5.4 Policy Decision Engine

The central evaluation point. For every agent action, it assembles the current state (tier, profile, permissions, delegation chain) and produces a deterministic allow/deny/escalate decision.

```swift
enum PolicyDecision {
    case allow(auditEvent: AuditEvent)
    case deny(reason: DenialReason, auditEvent: AuditEvent)
    case escalate(to: AuthorityIdentifier, reason: EscalationReason, auditEvent: AuditEvent)
}

// Every decision, including denials, produces an audit event.
// This is non-optional.
```

---

## 6. Integration Points

### 6.1 OpenClaw Integration

OpenClaw is the first consumer of the SwiftVector/ClawLaw stack. It serves as both the reference implementation and the proving ground.

**Integration surface:**
- OpenClaw's orchestrator uses the `AgentRuntime` protocol for all governed actions
- OpenClaw's configuration maps to ClawLaw `GovernanceProfile` definitions
- OpenClaw's communication channels (Telegram, CLI) map to the Operator Interface
- OpenClaw's task management maps to ClawLaw's workstream and ticket model

**What this means in practice:** When OpenClaw receives a task via Telegram, the message is parsed into an action request. The action request passes through the Policy Decision Engine. The engine evaluates the agent's current tier, the applicable governance profile, and the action's permission requirements. If allowed, the action proceeds and an audit event is emitted. If denied, the agent receives a denial with a reason. If the action requires escalation, the agent blocks and notifies the Principal.

### 6.2 External AI Model Integration

SwiftVector/ClawLaw governs the *orchestrator*, not the subordinate models directly. When OpenClaw delegates a task to Gemini, Grok, or Codex, the governance applies to the delegation, not to the subordinate model's internal behavior.

**What is governed:**
- Whether the orchestrator may delegate this task at all (permission check)
- What information the orchestrator may pass to the subordinate (scope boundary)
- What the subordinate's output may be used for (tier constraint)
- Whether the subordinate's output requires review before integration (governance gate)

**What is not governed (by this system):**
- The subordinate model's internal reasoning
- The subordinate model's safety alignment (that's the model provider's responsibility)
- The subordinate model's output quality (that's an evaluation concern, not a governance concern)

### 6.3 GitHub Integration

GitHub is the primary governance gate for development work. The integration is lightweight because GitHub already provides the machinery.

**Mapping:**
- ClawLaw Tier 2 (Propose) → Agent creates branches, commits, and PRs. Agent cannot merge.
- ClawLaw Tier 3 (Execute Within Bounds) → Agent may merge after automated checks pass.
- Governance profile scope boundaries → Mapped to repository and path permissions.
- Audit events → Correlated with Git commit hashes and PR identifiers.

### 6.4 Potential StackMint Integration

_Placeholder for collaborative architecture with StackMint.ai_

**Hypothesis:** If StackMint operates as an AI infrastructure platform and ClawLaw operates as a governance layer, the integration opportunity is ClawLaw providing the governance-as-architecture layer that StackMint's platform currently lacks.

**Potential integration patterns:**
- ClawLaw as a governance module within StackMint's agent orchestration pipeline
- SwiftVector's state machine engine as the enforcement mechanism for StackMint's policy definitions
- Shared audit trail format enabling cross-platform governance visibility
- ClawLaw governance profiles as a configuration layer for StackMint-hosted agents

_Architecture to be defined pending collaborative discussion._

---

## 7. Implementation Phases

### Phase 0: Foundation (Weeks 1-3) — Current Phase

**Objective:** Establish the minimal viable governance stack and begin collecting operational data.

**Deliverables:**
- [ ] OpenClaw operational on Mac mini with basic configuration
- [ ] Governance Specification document (v0.1.0) — COMPLETE
- [ ] Operational Rhythm document (v0.1.0) — COMPLETE
- [ ] Manual governance enforcement (human follows the spec; system doesn't enforce it yet)
- [ ] Begin daily brief / evening wrap cadence
- [ ] Begin governance friction log
- [ ] Document observed patterns that inform SwiftVector type design

**Key outcome:** Real operational data from running a governed agent workflow manually. This data directly informs the type system design in Phase 1.

### Phase 1: SwiftVector Core (Weeks 4-8)

**Objective:** Implement the foundational state machine engine and audit system.

**Deliverables:**
- [ ] `GovernedState` protocol and type hierarchy
- [ ] `StateTransition` protocol with compile-time authorization enforcement
- [ ] `TransitionEnforcer` with validation logic
- [ ] `AuditEmitter` with persistent, append-only event log
- [ ] `AgentRuntime` protocol definition
- [ ] Unit tests using Swift Testing framework
- [ ] Documentation: SwiftVector API reference

**Key design input:** Phase 0's governance friction log identifies which state transitions need to be modeled. Don't design the type system in the abstract — design it from observed behavior.

### Phase 2: ClawLaw Policy Layer (Weeks 6-10, overlapping with Phase 1)

**Objective:** Implement the governance policy layer on top of SwiftVector.

**Deliverables:**
- [ ] `AutonomyTier` enum with governed transitions
- [ ] `GovernanceProfile` structure with permission and boundary sets
- [ ] `DelegationChain` with validation
- [ ] `PolicyDecisionEngine` — the central allow/deny/escalate evaluator
- [ ] Tier transition enforcement (only Principal can escalate; agent can de-escalate)
- [ ] Profile-workstream binding
- [ ] Unit tests
- [ ] Documentation: ClawLaw governance model reference

### Phase 3: OpenClaw Integration (Weeks 8-12)

**Objective:** Connect the governance stack to OpenClaw's runtime.

**Deliverables:**
- [ ] OpenClaw orchestrator refactored to use `AgentRuntime` protocol
- [ ] Telegram operator interface connected to governance state queries
- [ ] Morning brief generation informed by governance state
- [ ] Governance gate enforcement for PR submission and merge
- [ ] Governance gate enforcement for content publication
- [ ] Escalation notification flow (agent → Telegram → Principal)
- [ ] Integration tests: end-to-end governance enforcement scenarios

### Phase 4: Dashboard and Observability (Weeks 10-14)

**Objective:** Make the governance system visible and inspectable.

**Deliverables:**
- [ ] Governance dashboard (web-based, built as internal tooling under Tier 3)
- [ ] Real-time tier and profile state visualization
- [ ] Audit event stream viewer
- [ ] Governance friction log aggregation and analysis
- [ ] Velocity metrics by workstream
- [ ] Delegation chain visualization

### Phase 5: External Integration and Hardening (Weeks 12-16+)

**Objective:** Prepare for external consumption — either as a product component, an integration with StackMint, or a reference implementation for the open source community.

**Deliverables:**
- [ ] API stabilization and semantic versioning
- [ ] Integration guide for third-party agent orchestrators
- [ ] Security audit of governance enforcement boundaries
- [ ] Performance benchmarking under multi-agent load
- [ ] Case study documentation from Phases 0-4 operational experience
- [ ] Public repository preparation (if open sourcing)

---

## 8. Technical Decisions — Open

| Decision | Options | Depends On |
|---|---|---|
| Audit storage backend | SQLite (local) vs. PostgreSQL (networked) vs. append-only log file | Scale expectations; single-node vs. distributed |
| Governance profile storage | Compiled into binary vs. configuration file vs. database | How frequently profiles change; who changes them |
| Operator interface protocol | REST API vs. WebSocket vs. direct Telegram bot integration | Latency requirements; mobile access patterns |
| Dashboard technology | SwiftUI (native) vs. web-based (React/HTML) | Deployment target; who needs to see it |
| Multi-agent communication | Direct protocol vs. message queue vs. shared state store | Number of concurrent agents; coordination complexity |
| StackMint integration pattern | Plugin/module vs. API gateway vs. shared runtime | StackMint's architecture (pending discussion) |

---

## 9. Success Criteria

### Phase 0 (Foundation)
- OpenClaw is operational and producing daily briefs
- Governance is being followed manually with observed friction documented
- At least 2 weeks of operational data collected before Phase 1 design decisions

### Phase 1-2 (Core Implementation)
- All governance rules from the specification are expressible as SwiftVector state
- Invalid tier escalations are caught at compile time, not runtime
- 100% of state transitions produce audit events
- Zero governance bypasses possible through the AgentRuntime interface

### Phase 3-4 (Integration and Visibility)
- OpenClaw cannot take a governed action without passing through the policy decision engine
- Principal can inspect governance state and audit trail in real time
- Morning briefs accurately reflect governance state
- Governance friction is measurable and trending downward over time

### Phase 5 (External Readiness)
- A third-party agent orchestrator can integrate SwiftVector/ClawLaw using published documentation
- The system has operated under real workload for at least 8 weeks
- At least one case study with quantitative data is publishable

---

## 10. Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Over-engineering governance before operational data exists | Build the wrong abstractions; waste time | Phase 0 is explicitly manual; type design follows observation |
| Swift's type system is insufficient for some governance rules | Rules that can't be compile-time enforced become runtime checks | Identify these early; document which rules are compile-time vs. runtime enforced |
| Agent orchestrator evolution outpaces governance layer | Governance becomes a bottleneck to capability | Separation of mechanism (SwiftVector) and policy (ClawLaw) allows policy to evolve independently |
| StackMint integration requires architectural compromises | Core principles diluted for compatibility | Define non-negotiable architectural principles before integration discussion |
| Scope creep from multi-workstream ambition | Too many features, nothing ships | Phase gates with clear deliverables; each phase is independently valuable |
| Solo developer bandwidth | Can't execute 16-week roadmap alone | Prioritize ruthlessly; Phase 0-2 are the minimum viable governance stack |

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0-draft | 2026-02-15 | Initial draft — architecture, components, phases, integration points |
