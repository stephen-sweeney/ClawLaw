# ClawLaw: Three-Week Development Sprint (Corrected)

**Pre-Mini Preparation Plan**  
**Period:** February 17 – March 9, 2026  
**Hardware Target:** Mac mini M4 Pro (64GB / 1TB) — arrives ~March 9  
**Development Machine:** MacBook Pro M5  
**AI Workflow:** Claude Code (CLI), Codex (review), Claude (planning)

---

## Actual Starting Position

### SwiftVector (0.1.0 tagged, HEAD at Phase 2)

The repo is a working Swift package with this structure:

```
Sources/SwiftVectorCore/
├── State.swift                  # State protocol + SHA256 hash
├── Action.swift                 # Action protocol + ActionProposal
├── Reducer.swift                # Reducer protocol + ReducerResult + AnyReducer
├── Effect.swift                 # Effect protocol + EffectRunner + NoEffect
├── Agent.swift                  # Agent protocol (Phase 2.1)
├── Orchestrator.swift           # Orchestrator protocol with replay
├── BaseOrchestrator.swift       # Concrete orchestrator with audit + state stream
├── Audit/
│   ├── AuditEvent.swift         # Generic audit entry with hash chain
│   ├── AuditEventType.swift     # Event type variants
│   └── EventLog.swift           # Append-only log with verification + replay
└── Determinism/
    ├── Clock.swift              # Injectable time
    ├── UUIDGenerator.swift      # Injectable IDs
    └── RandomSource.swift       # Injectable randomness

Sources/SwiftVectorTesting/
├── SwiftVectorTesting.swift
└── Determinism/
    ├── MockClock.swift
    ├── MockRandomSource.swift
    └── MockUUIDGenerator.swift
```

**What exists:** Core protocols, determinism primitives, tamper-evident audit log with hash chain, replay verification, Agent and Orchestrator extraction, NarrativeDemo fully migrated and importing Core. Tests pass. Tag 0.1.0 shipped.

### ClawLaw (standalone, not yet importing SwiftVectorCore)

```
Sources/ClawLawCore/
├── Governance.swift             # GovernanceState, AuthorizationLevel, AgentAction, ActionEffect
├── GovernanceReducer.swift      # Static reduce function
└── (main.swift in CLI target)
```

**What exists:** Working governance types with five validated experiments (normal ops, threshold warnings, circuit breaking, human recovery, gaming resistance). But these types are standalone — they don't conform to SwiftVectorCore protocols. The reducer is a static method, not a protocol conformer. There's no audit trail, no determinism injection, no hash chain.

### The Gap

ClawLaw has proven governance logic. SwiftVectorCore has proven infrastructure. They need to connect. Once they do, ClawLaw gets audit trails, replay verification, and deterministic testing for free. And ClawLaw becomes a provable SwiftVector jurisdiction, not just a conceptual one.

---

## Week 1: ClawLaw Becomes a SwiftVector Jurisdiction (Feb 17–23)

### Day 1-2: Import SwiftVectorCore and Refactor Types

**Goal:** ClawLaw imports SwiftVectorCore. Existing types conform to Core protocols. All existing tests still pass.

**Package.swift change:**
```swift
dependencies: [
    .package(path: "../SwiftVector")  // local path during development
]
// target depends on "SwiftVectorCore"
```

**Type migrations:**

| Current ClawLaw Type | Conforms To | Key Changes |
|----------------------|-------------|-------------|
| `GovernanceState` | `State` | Gets `stateHash()` for free. Add `Codable`. |
| `AgentAction` | `Action` | Add `actionDescription`, stored `correlationID` |
| `GovernanceReducer` | `Reducer` | Instance method instead of static. Returns `ReducerResult<GovernanceState>` instead of `ActionEffect` |
| `ActionEffect` | Replaced by `ReducerResult<GovernanceState>` | `.allow` → `.accepted`, `.reject` → `.rejected` |

**The hard decision — `ActionEffect` vs `ReducerResult`:**

Current ClawLaw has four outcomes: `.allow`, `.reject`, `.transition`, `.requireApproval`. SwiftVectorCore's `ReducerResult` has two: `.accepted` and `.rejected`. The approval queue concept needs to be modeled differently — likely as a state transition where the new state has the action parked in a pending queue, which is accepted (state changed) but the action itself is deferred. This is architecturally cleaner anyway.

```swift
// Before: ActionEffect mixed outcomes
case .requireApproval(level: .sensitive, reason: "Outbound communication")

// After: ReducerResult with state that includes pending queue
var newState = state
newState.pendingApprovals.append(PendingAction(action: action, reason: reason))
newState.enforcement = .gated
return .accepted(newState, rationale: "Action queued for human approval: \(reason)")
```

**Claude Code directive:**
```
Add SwiftVectorCore as a local path dependency to ClawLaw. Refactor 
GovernanceState to conform to State protocol (add Codable conformance). 
Refactor AgentAction to conform to Action protocol (add actionDescription 
and stored correlationID). Convert GovernanceReducer from a static method 
struct to a Reducer protocol conformer returning ReducerResult<GovernanceState>. 
Replace ActionEffect with ReducerResult, modeling approval requirements as 
state transitions with a pending queue. All existing test assertions must 
still pass with updated types.
```

### Day 3: Wire Up Audit Infrastructure

**Goal:** Every governance decision is recorded in SwiftVectorCore's EventLog with hash chain integrity.

ClawLaw's reducer already makes accept/reject decisions. Now those decisions flow into an `EventLog<ClawAction>` automatically. This is where BaseOrchestrator comes in — it already handles audit logging and state streaming.

Create a `ClawOrchestrator` that extends or wraps `BaseOrchestrator`:

```swift
actor ClawOrchestrator {
    private let orchestrator: BaseOrchestrator<GovernanceState, ClawAction, ClawReducer>
    
    func submit(_ action: ClawAction, agentID: String) async -> ReducerResult<GovernanceState> {
        await orchestrator.submit(action, agentID: agentID)
    }
    
    func verifyAuditTrail() async -> EventLogVerificationResult {
        await orchestrator.eventLog.verify()
    }
}
```

**What this gives you immediately:**
- Every governance decision has a tamper-evident hash chain
- Replay verification can prove the reducer is deterministic
- The full audit trail is serializable for incident review
- State changes are streamed via AsyncSequence

### Day 4-5: Budget Law with Real API Costs

**Goal:** Extend the budget system from abstract token counts to real dollar-denominated API cost tracking.

This is the first governance module you'll need on Day 1 with OpenClaw.

```swift
public struct APIBudgetState: Codable {
    public var dailyCeiling: Decimal
    public var monthlyCeiling: Decimal
    public var currentDailySpend: Decimal
    public var currentMonthlySpend: Decimal
    public var enforcement: EnforcementLevel
    public var costLog: [CostEntry]
    
    public struct CostEntry: Codable {
        let timestamp: Date
        let provider: String
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let estimatedCost: Decimal
    }
}
```

Include cost configs for the models you'll use: Claude Haiku ($0.25/$1.25 per M), Claude Sonnet ($3/$15), GPT-4o-mini ($0.15/$0.60), GPT-4o ($2.50/$10), Gemini Flash (free tier), Grok.

The budget check happens in the reducer — an `apiCall` action includes the model and estimated tokens, the reducer calculates cost, checks against ceilings, and transitions enforcement levels:

- Under 70% of daily ceiling → `.normal`
- 70-90% → `.degraded` (route to cheaper models)
- 90-100% → `.gated` (require approval for each call)
- Over ceiling → `.halted` (reject all API calls)

---

## Week 2: OpenClaw Integration Protocol (Feb 24 – Mar 2)

### Day 1-2: Define the Interception Protocol

**Goal:** Define typed actions for everything OpenClaw can do, and the governance verdict for each.

OpenClaw is Node.js. ClawLaw is Swift. Integration is process-level — ClawLaw runs as a sidecar that intercepts actions before execution.

```swift
public enum OpenClawAction: Action {
    case shellCommand(command: String, workingDirectory: String)
    case fileWrite(path: String, content: String)
    case fileDelete(path: String)
    case browserNavigate(url: String)
    case apiCall(provider: String, model: String, estimatedTokens: Int)
    case messageSend(platform: String, recipient: String, content: String)
    
    public var actionDescription: String {
        switch self {
        case .shellCommand(let cmd, _): return "Shell: \(cmd.prefix(80))"
        case .fileWrite(let path, _): return "Write: \(path)"
        case .fileDelete(let path): return "Delete: \(path)"
        case .browserNavigate(let url): return "Navigate: \(url)"
        case .apiCall(let provider, let model, let tokens): 
            return "API: \(provider)/\(model) (~\(tokens) tokens)"
        case .messageSend(let platform, let to, _): 
            return "Message: \(platform) → \(to)"
        }
    }
    
    // Stored for audit trail stability
    public let id: UUID
    public var correlationID: UUID { id }
}
```

Build a local HTTP server in Swift that accepts JSON-encoded actions and returns governance verdicts. This is the integration seam.

### Day 3-4: The Three Laws as Composable Reducers

**Goal:** Implement Law 0 (Containment), Law 4 (Budget), and Law 8 (Authorization) as separate reducers that compose.

Each Law is its own reducer. The `ClawReducer` composes them — an action must pass ALL Laws:

```swift
struct ClawReducer: Reducer {
    let containment: ContainmentReducer  // Law 0
    let budget: BudgetReducer            // Law 4
    let authorization: AuthorizationReducer  // Law 8
    
    func reduce(state: GovernanceState, action: OpenClawAction) 
        -> ReducerResult<GovernanceState> {
        
        // Laws evaluated in order. First rejection wins.
        let laws: [(String, (GovernanceState, OpenClawAction) -> ReducerResult<GovernanceState>)] = [
            ("Law 0: Containment", containment.reduce),
            ("Law 4: Budget", budget.reduce),
            ("Law 8: Authorization", authorization.reduce),
        ]
        
        var currentState = state
        for (name, law) in laws {
            let result = law(currentState, action)
            if !result.applied {
                return .rejected(state, rationale: "[\(name)] \(result.rationale)")
            }
            currentState = result.newState
        }
        return .accepted(currentState, rationale: "All laws satisfied")
    }
}
```

**Law 0 — Containment:**
- Sandboxed filesystem paths (allowlist)
- Protected patterns (`.ssh`, `.gnupg`, `.env`, system dirs)
- Network domain allowlist
- Shell command filtering (`rm -rf /`, `sudo`, `chmod 777`)

**Law 4 — Budget:**
- Per-model cost calculation from Week 1
- Daily/monthly circuit breakers
- Enforcement level transitions

**Law 8 — Authorization:**
- Risk tier classification per action type
- Pending approval queue as state
- Auto-deny on timeout for high-risk actions

### Day 5: YAML Configuration

**Goal:** Users configure ClawLaw's Laws via a config file, not code changes.

```yaml
containment:
  writable_paths: [~/Projects, ~/Downloads/scratch]
  protected_patterns: [.ssh, .gnupg, .env]
  allowed_domains: [api.anthropic.com, api.openai.com]
  blocked_commands: ["rm -rf /", "sudo", "chmod 777"]

budget:
  daily_ceiling: 5.00
  monthly_ceiling: 50.00
  models:
    claude-haiku: { input_per_million: 0.25, output_per_million: 1.25 }
    claude-sonnet: { input_per_million: 3.00, output_per_million: 15.00 }
    gpt-4o-mini: { input_per_million: 0.15, output_per_million: 0.60 }

authorization:
  auto_permit: [file_read, browser_navigate]
  require_approval: [file_delete, message_send]
  always_deny: [credential_access, system_modification]
```

Parse with `Codable` + JSON (zero external dependencies) or `Yams` for YAML.

---

## Week 3: Hardening & Mini Preparation (Mar 3–9)

### Day 1-2: Replay Verification for Governance

**Goal:** Prove ClawLaw's governance is deterministic using SwiftVectorCore's replay infrastructure.

Write a test that:
1. Records a full session of OpenClaw actions through the governance layer
2. Serializes the EventLog
3. Replays it against the same reducer
4. Asserts byte-identical outcomes via `EventLog.verifyReplay()`

This is the core SwiftVector promise applied to ClawLaw. If replay verification passes, you can prove to anyone — StackMint, regulators, partners — that governance decisions are deterministic and tamper-evident.

### Day 3: Developer API Account Setup

Non-code work. Get keys and caps set before the Mini arrives.

| Provider | Account URL | Starting Cap |
|----------|------------|--------------|
| Anthropic | console.anthropic.com | $20/month |
| OpenAI | platform.openai.com | $15/month |
| X.ai | console.x.ai | $10/month |
| Google | aistudio.google.com | $5/month (free tier first) |

Total: **$50/month** initial. ClawLaw's budget governance tells you where to adjust.

Store keys in `.env`, add `.env` to ClawLaw's containment protected patterns — the agent can never read its own keys.

### Day 4: Documentation Sync

- ClawLaw README showing it as a SwiftVector jurisdiction with dependency
- QUICKSTART.md: install, configure, run, test with curl
- Update SwiftVector README to reference ClawLaw as first external consumer
- Architecture decision record for the `ActionEffect` → `ReducerResult` migration

### Day 5: Mac Mini Day-One Runbook

```markdown
## Mac Mini First Boot Runbook

### System Setup (30 min)
- [ ] Complete macOS setup
- [ ] Install Xcode, Homebrew, Ollama, Node.js

### Verify SwiftVector + ClawLaw (15 min)
- [ ] Clone both repos
- [ ] swift build on SwiftVector — must succeed
- [ ] swift build on ClawLaw — must succeed  
- [ ] swift test on both — all green

### OpenClaw Installation (1 hour)
- [ ] Clone and install OpenClaw (M4 native — no Intel issues)
- [ ] Configure basic messaging gateway
- [ ] Verify basic operation WITHOUT ClawLaw

### ClawLaw Integration (1 hour)
- [ ] Build ClawLaw release binary
- [ ] Copy clawlaw.yaml to ~/.config/clawlaw/
- [ ] Add API keys to .env
- [ ] Start governance server
- [ ] Configure OpenClaw to route through ClawLaw
- [ ] Send test action, verify verdict
- [ ] Run real task, verify audit log
```

---

## Success Criteria

By March 9:

- [ ] ClawLaw imports SwiftVectorCore — provably a SwiftVector jurisdiction
- [ ] Governance decisions recorded in tamper-evident EventLog
- [ ] Three Laws (Containment, Budget, Authorization) as composable reducers
- [ ] Real API cost tracking for 6+ model configurations
- [ ] HTTP interception server accepting OpenClaw actions
- [ ] YAML-driven configuration
- [ ] Replay verification passing — governance is provably deterministic
- [ ] API accounts set up with spending caps
- [ ] Mini runbook ready for Day 1 execution
