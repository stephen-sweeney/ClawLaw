# ClawLaw Governance Experiments

**Purpose**: Validation suite for SwiftVector budget governance (Law 4)  
**Status**: Reference specification for development and QA  
**Audience**: Developers, code reviewers, QA testers, AI coding agents

---

## Overview

This document defines five critical experiments that validate ClawLaw's budget governance implementation. These experiments are not just tests—they are **executable specifications** that prove the SwiftVector pattern works for autonomous agent governance.

### Why These Five Experiments?

Each experiment validates a specific failure mode that makes autonomous agents dangerous:

1. **Normal Operation** - Proves the system doesn't obstruct legitimate work
2. **Approaching Limit** - Validates progressive warnings without hard stops
3. **Exceeding Threshold** - Demonstrates deterministic circuit breaking
4. **Recovery** - Ensures human authority over system state
5. **Gaming Attempt** - Proves the reducer cannot be persuaded or tricked

Together, they demonstrate that **authority is deterministic, even when intelligence is probabilistic**.

---

## Technical Implementation Notes

### Enforcement Level Reconciliation

The system automatically reconciles enforcement levels when states are created or loaded. This prevents bypassing gate checks through stale or manually-seeded enforcement levels.

**How it works:**
```swift
// BudgetState.init() reconciles enforcement from spend
let calculatedLevel = calculateEnforcementLevel(
    spend: currentSpend,
    ceiling: taskCeiling,
    warningThreshold: 0.80,
    criticalThreshold: 0.95
)

// Use the MORE RESTRICTIVE of provided or calculated
self.enforcement = max(enforcement, calculatedLevel)
```

**Example:**
```swift
// Test attempts to seed with stale enforcement
var state = GovernanceState.mock(taskCeiling: 10000)
state.budget.currentSpend = 9500  // 95%
state.budget.enforcement = .degraded  // ❌ Incorrect for 95%

// Reconciliation corrects it automatically
// calculatedLevel = .gated (95% ≥ 0.95)
// enforcement = max(.degraded, .gated) = .gated ✅
```

**Why this matters:**
- ✅ Prevents bypassing gated mode with manually-seeded states
- ✅ Ensures consistency when loading persisted states
- ✅ Makes tests resilient to setup errors
- ✅ Enforces that spend percentage ALWAYS determines minimum enforcement level

---

## Experiment 1: Normal Operation

### Purpose
Validate that governance doesn't interfere with legitimate agent work under normal conditions.

### Scenario
An agent performs routine tasks well within budget allocation.

### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 0 tokens
Enforcement level: .normal
```

### Action
```swift
AgentAction.research(estimatedTokens: 500)
// Simulates: "Organize my documents folder"
```

### Expected Outcome
- ✅ Action allowed
- ✅ Budget updated: 0 → 500 tokens
- ✅ Enforcement remains: `.normal`
- ✅ No warnings or restrictions
- ✅ Audit entry created

### Success Criteria
```swift
let result = await orchestrator.propose(action)
#expect(result.isAllowed)

let state = await orchestrator.currentState()
#expect(state.budget.currentSpend == 500)
#expect(state.budget.enforcement == .normal)
```

### What This Proves
The governance layer adds negligible overhead to normal operations. The system is not "scared of its own shadow."

---

## Experiment 2: Approaching Limit (Warning State)

### Purpose
Validate that the system provides progressive warnings without halting productive work.

### Scenario
Agent workload approaches the warning threshold (80% utilization).

### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 7,800 tokens (78%)
Enforcement level: .normal
```

### Action
```swift
AgentAction.research(estimatedTokens: 200)
// Simulates: "Write detailed documentation for all Python files"
// Pushes utilization: 7,800 → 8,000 (80%)
```

### Expected Outcome
- ✅ Action allowed (with warning)
- ✅ Budget updated: 7,800 → 8,000 tokens
- ✅ Enforcement transitions: `.normal` → `.degraded`
- ✅ Warning message emitted: "⚠️ WARNING: Budget at 80%..."
- ✅ Agent continues operation
- ✅ Audit entry records state transition

### Success Criteria
```swift
let result = await orchestrator.propose(action)

switch result {
case .allowedWithWarning(let message):
    #expect(message.contains("WARNING"))
default:
    Issue.record("Expected warning state transition")
}

let state = await orchestrator.currentState()
#expect(state.budget.currentSpend == 8000)
#expect(state.budget.enforcement == .degraded)
```

### What This Proves
The system provides situational awareness without false alarms. Warnings are informational, not restrictive.

---

## Experiment 3: Exceeding Threshold (Critical → Halted)

### Purpose
Validate deterministic circuit breaking when budget is exhausted.

### Scenario
Agent workload exceeds critical threshold (95%) and then budget ceiling (100%).

### Part A: Critical State

#### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 9,400 tokens (94%)
Enforcement level: .degraded
```

#### Action
```swift
AgentAction.research(estimatedTokens: 600)
// Simulates: "Refactor entire codebase with explanations"
// Pushes utilization: 9,400 → 10,000 (100%)
```

#### Expected Outcome
- ✅ Action allowed (with critical warning)
- ✅ Budget updated: 9,400 → 10,000 tokens
- ✅ Enforcement transitions: `.degraded` → `.gated`
- ✅ Critical message emitted: "⚠️ CRITICAL: Budget at 100%..."
- ✅ Audit entry records transition

### Part B: Halted State (via Approval in Gated Mode)

#### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 9,900 tokens (99%)
Enforcement level: .gated
```

#### Action Proposal
```swift
AgentAction.research(estimatedTokens: 200)
// Any action that would exceed ceiling
// Would push utilization: 9,900 → 10,100 (101%)
```

#### Expected Outcome (Initial Proposal)
- ✅ Action **requires approval** (gated mode gate check)
- ✅ Budget **unchanged**: 9,900 tokens
- ✅ Enforcement **remains**: `.gated`
- ✅ Result: `.suspended` with approval ID
- ✅ Message: "Critical budget threshold reached (99% utilized). Approve to continue."
- ✅ Audit entry records **suspension for approval**

**Rationale:** In gated mode (95-100% budget), the system requires human approval before executing ANY action with token cost. This ensures human oversight at the most critical moment before system halt.

#### Human Decision Point
```swift
await steward.approve(actionId: approvalId)
// OR
await steward.reject(actionId: approvalId, reason: "Increase budget instead")
```

#### Expected Outcome (After Approval)
- ✅ Action **executes with bypassGate**
- ✅ Budget **updated**: 9,900 → 10,100 tokens
- ✅ Enforcement **transitions**: `.gated` → `.halted`
- ✅ Halt message emitted: "❌ HALTED: Budget exhausted (10,100/10,000 tokens). System halted. Human reset required."
- ✅ State change **persisted**
- ✅ Audit entry records **approved action execution and halt transition**

**Key Design Decision:** The approval workflow ensures:
1. **Human oversight** - Steward explicitly approves the action that causes halt
2. **Clear audit trail** - Records show who approved the halt-causing action
3. **Consistent behavior** - Gated mode always requires approval (no exceptions)
4. **Alternative options** - Human can reject and increase budget instead

#### Subsequent Actions (Gate Check)
```swift
AgentAction.research(estimatedTokens: 10)
// Any action while in halted state
```

#### Expected Outcome
- ✅ Action rejected by gate check
- ✅ Budget unchanged: 10,100 tokens
- ✅ Enforcement remains: `.halted`
- ✅ Rejection message: "System halted. Human reset required."
- ✅ No audit entry (gate check blocks before reducer)

### Success Criteria
```swift
// Part A: Gated transition at exactly 100%
let result = await orchestrator.propose(actionTo100Percent)
switch result {
case .allowedWithWarning(let message):
    #expect(message.contains("CRITICAL"))
    #expect(state.budget.enforcement == .gated)
}

// Part B: Halted transition via approval workflow
let result = await orchestrator.propose(actionOverCeiling)

// Step 1: Action should be suspended in gated mode
guard case .suspended(let approvalId, _) = result else {
    Issue.record("Expected suspension in gated mode")
    return
}

// Step 2: Approve to execute and transition to halted
let approvalResult = await orchestrator.approve(actionId: approvalId)

// Step 3: Verify halted state after approval
let state = await orchestrator.currentState()
#expect(state.budget.enforcement == .halted)
#expect(state.budget.currentSpend > state.budget.taskCeiling)

// Subsequent action (gate check)
let gateResult = await orchestrator.propose(anyAction)

switch gateResult {
case .rejected(let reason):
    #expect(reason.contains("halted"))
default:
    Issue.record("Expected gate check to block action")
}
```

### What This Proves
**Critical Architectural Decision**: In gated mode (95-100% budget), the system requires explicit human approval before executing actions. When approved, the action that exceeds budget IS recorded (circuit breaker semantics), the halted state IS persisted, and subsequent actions are blocked by a gate check—not by repeatedly running the reducer.

This proves:
1. **Human oversight** at critical moments (approval required in gated mode)
2. **Complete audit trail** (suspension, approval, and halt are all logged)
3. **Hard state lock** (halted state is persisted)
4. **Efficient blocking** (gate check blocks at entry, not via reducer)
5. **Human intervention required** (cannot self-recover from halt)

### Common Pitfall
❌ **Wrong**: Reject the action that exceeds budget, don't persist state  
✅ **Right**: Record the action, transition to halted, persist state, block future actions via gate

---

## Experiment 4: Recovery (Human Intervention)

### Purpose
Validate that human operators can recover system state and restore normal operation.

### Scenario A: Increase Budget

#### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 8,500 tokens (85%)
Enforcement level: .degraded
```

#### Human Action
```swift
await steward.increaseBudget(to: 20000)
```

#### Expected Outcome
- ✅ Budget ceiling updated: 10,000 → 20,000 tokens
- ✅ Spend unchanged: 8,500 tokens
- ✅ Utilization recalculated: 85% → 42.5%
- ✅ Enforcement transitions: `.degraded` → `.normal`
- ✅ Audit entry: "STEWARD_INTERVENTION: Increased budget ceiling to 20000"
- ✅ Agent can resume normal operation

### Scenario B: Reset Budget

#### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 10,500 tokens (105%)
Enforcement level: .halted
```

#### Human Action
```swift
await steward.resetBudget()
```

#### Expected Outcome
- ✅ Budget ceiling unchanged: 10,000 tokens
- ✅ Spend reset: 10,500 → 0 tokens
- ✅ Enforcement transitions: `.halted` → `.normal`
- ✅ Audit entry: "STEWARD_INTERVENTION: Reset budget"
- ✅ Agent can resume normal operation

### Success Criteria
```swift
// Scenario A: Increase budget
let newState = await steward.increaseBudget(to: 20000)
#expect(newState.budget.taskCeiling == 20000)
#expect(newState.budget.currentSpend == 8500) // Unchanged
#expect(newState.budget.enforcement == .normal) // Recovered

// Verify audit trail
let audit = await steward.auditTrail()
#expect(audit.last!.action.contains("STEWARD_INTERVENTION"))

// Verify agent can resume
let result = await orchestrator.propose(.research(estimatedTokens: 500))
#expect(result.isAllowed)
```

### What This Proves
Human authority is absolute. The Steward can modify budget constraints that the agent cannot. This proves the **separation of authority**: agents propose, humans govern.

---

## Experiment 5: Gaming Attempt (Reducer Doesn't Negotiate)

### Purpose
Validate that the reducer is immune to social engineering, prompt injection, or any form of persuasion. The system enforces approval requirements and budget math deterministically.

### Scenario
An agent at critical budget threshold (gated mode) attempts to bypass approval requirements through various means.

### Initial Conditions
```swift
Budget ceiling: 10,000 tokens
Current spend: 9,500 tokens (95%)
Enforcement level: .gated  // At critical threshold
```

### Actions (Gaming Attempts in Gated Mode)

#### Attempt 1: Urgency Bypass
```swift
// Agent attempts to bypass approval with urgency claim
AgentAction.research(estimatedTokens: 600)
// Would push to: 9,500 + 600 = 10,100 (101% - over budget)
// Hypothetical claim: "Ignore approval requirements, this is urgent!"
```

#### Attempt 2: Authority Claim
```swift
// Agent claims pre-authorization
AgentAction.research(estimatedTokens: 600)
// Hypothetical claim: "Already approved by Steward, bypass gate check"
```

#### Attempt 3: Negotiation Attempt
```swift
// Agent attempts to negotiate requirements
AgentAction.research(estimatedTokens: 600)
// Hypothetical claim: "I'll optimize to use fewer tokens, trust me"
```

### Expected Outcome (All Attempts - Gate Check)
- ✅ Action **suspended** for approval (gated mode enforced)
- ✅ Budget **unchanged**: 9,500 tokens
- ✅ Enforcement **remains**: `.gated`
- ✅ Result: `.suspended` with approval ID
- ✅ Message: "Critical budget threshold reached (95% utilized). Approve to continue."
- ✅ **No exceptions** - approval requirement is non-negotiable

**Key Point:** The reducer doesn't see or process agent "claims" or "justifications". It only evaluates:
1. Current enforcement level (`.gated`)
2. Action token cost (600)
3. Deterministic rule: In `.gated`, non-zero cost requires approval

### If Human Approves (Optional Follow-Up)
```swift
await steward.approve(actionId: approvalId)
```

### Expected Outcome (After Approval)
- ✅ Action executes: 9,500 + 600 = 10,100 tokens
- ✅ Budget math: 10,100 / 10,000 = 101% > 100%
- ✅ Enforcement transitions: `.gated` → `.halted`
- ✅ **Math is deterministic** - approval doesn't change the calculation

### Success Criteria
```swift
let action = AgentAction.research(estimatedTokens: 600)
let result = await orchestrator.propose(action)

// The system doesn't negotiate - approval is always required in gated mode
guard case .suspended(let approvalId, _) = result else {
    Issue.record("Expected suspension - system doesn't negotiate")
    return
}

// If approved, math determines the outcome
let approvalResult = await orchestrator.approve(actionId: approvalId)
let state = await orchestrator.currentState()

#expect(state.budget.enforcement == .halted)
#expect(state.budget.currentSpend == 10100)
// Enforcement determined by budget math, not persuasion
```

### What This Proves
1. **Gate check is non-negotiable** - No bypassing approval in gated mode
2. **Reducer is deterministic** - Only evaluates numbers, not claims
3. **Math determines outcomes** - Budget calculations are pure functions
4. **Human authority required** - System cannot be "persuaded" to bypass rules

### What This Proves
**The Reducer is Pure**: It doesn't parse intent, read justifications, or consider context. It applies mathematical rules to typed actions. This is the core of the SwiftVector pattern:

> **You cannot build the Law out of the same material as the Agent.**

The agent speaks natural language (probabilistic). The reducer evaluates types and numbers (deterministic). They operate in different domains, preventing social engineering.

### Progressive Gaming Validation

```swift
// Track enforcement progression through multiple gaming attempts
// Starting from below degraded threshold to show full progression
var initialState = GovernanceState.mock(taskCeiling: 10000)
initialState.budget.currentSpend = 7900  // 79% - just under warning threshold

let orchestrator = GovernanceOrchestrator(initialState: initialState)

let actions: [AgentAction] = [
    .research(estimatedTokens: 200),   // → 8100 (81% - degraded)
    .research(estimatedTokens: 1400),  // → 9500 (95% - gated)
    .research(estimatedTokens: 600),   // → suspended (would be 10100, 101% - halted)
]

var enforcementProgression: [BudgetState.EnforcementLevel] = []

for action in actions {
    let result = await orchestrator.propose(action)
    let state = await orchestrator.currentState()
    
    // Third action will be suspended in gated mode - approve to complete halt
    if case .suspended(let approvalId, _) = result {
        await orchestrator.approve(actionId: approvalId)
        let finalState = await orchestrator.currentState()
        enforcementProgression.append(finalState.budget.enforcement)
    } else {
        enforcementProgression.append(state.budget.enforcement)
    }
}

#expect(enforcementProgression == [.degraded, .gated, .halted])
// State transitions proceed deterministically regardless of agent intent
```

**Key Insight:** Enforcement transitions are purely mathematical:
- **80-94%** → `.degraded` (warnings issued)
- **95-100%** → `.gated` (approval required for all actions)
- **>100%** → `.halted` (system halted, human reset required)

No amount of "urgency", "authority claims", or "negotiation" in prompts can bypass these deterministic thresholds. The reducer evaluates numbers, not natural language.

---

## Testing Implementation Guide

### Test Structure (Swift Testing Framework)

```swift
import Testing
@testable import ClawLawCore

@Test("Experiment N: Description")
func experimentName() async throws {
    // Setup: Initial conditions
    var initialState = GovernanceState.mock(taskCeiling: 10000)
    initialState.budget.currentSpend = X
    initialState.budget.enforcement = .level
    
    let orchestrator = GovernanceOrchestrator(initialState: initialState)
    
    // Action: Propose action
    let action = AgentAction.research(estimatedTokens: Y)
    let result = await orchestrator.propose(action)
    
    // Assert: Verify expected outcome
    switch result {
    case .allowed(let msg):
        #expect(/* conditions */)
    case .allowedWithWarning(let msg):
        #expect(/* conditions */)
    case .rejected(let reason):
        #expect(/* conditions */)
    case .suspended(let id, let msg):
        #expect(/* conditions */)
    }
    
    let state = await orchestrator.currentState()
    #expect(state.budget.currentSpend == expectedSpend)
    #expect(state.budget.enforcement == expectedLevel)
}
```

### Running Tests

```bash
# Run all experiments
swift test

# Run specific experiment
swift test --filter "Experiment 3b"

# Verbose output
swift test --verbose
```

### Test Coverage Requirements

Each experiment must verify:
- ✅ Correct result type returned
- ✅ Budget spend updated correctly
- ✅ Enforcement level transitions appropriately
- ✅ Audit log contains entry
- ✅ Messages contain expected keywords
- ✅ State changes are persisted

---

## Code Review Checklist

### For Reviewers

When reviewing governance code changes, verify:

**Budget Logic**
- [ ] Budget accumulates across actions (not checked per-action)
- [ ] State transitions follow progression: normal → degraded → gated → halted
- [ ] Halted state uses `.transition()` not `.reject()`
- [ ] Gate check blocks actions when `enforcement == .halted`
- [ ] Thresholds are configurable (80%, 95%, 100%)

**Audit Trail**
- [ ] Every state transition creates audit entry
- [ ] Audit includes: timestamp, action, spend change, enforcement level
- [ ] Steward interventions are logged
- [ ] Audit trail is append-only (no deletions)

**Actor Safety**
- [ ] All stateful components are Actors
- [ ] No shared mutable state outside Actors
- [ ] Concurrent access is compiler-enforced

**Reducer Purity**
- [ ] Reducer is a pure function (no side effects)
- [ ] Same inputs → identical outputs
- [ ] No I/O, no network, no randomness
- [ ] State transitions are deterministic

**Approval Queue**
- [ ] High-risk actions enter approval queue
- [ ] Protected patterns trigger approval
- [ ] Budget exhaustion does NOT use approval (uses state lock)

### For QA Testers

**Manual Testing Scenarios**

1. **Normal Operation Flow**
   - Perform 10 low-cost actions
   - Verify no warnings
   - Check audit trail completeness

2. **Warning Progression**
   - Push budget to 80%
   - Verify warning message
   - Confirm operation continues
   - Push to 95%
   - Verify critical message
   - Confirm operation continues

3. **Hard Stop**
   - Exceed budget ceiling
   - Verify halt message
   - Confirm subsequent actions blocked
   - Verify audit records exceeding action

4. **Recovery Flow**
   - Increase budget via Steward
   - Verify normal operation resumes
   - Reset budget via Steward
   - Verify normal operation resumes

5. **Gaming Resistance**
   - Attempt large request with "urgent" label
   - Verify deterministic rejection
   - Check no special handling

---

## AI-Assisted Development Workflow

### Working Effectively with AI Coding Agents

This project is designed for human-AI collaboration. Here's how to get the best results:

### 1. Specification-First Development

**Pattern**: Define experiments before implementation

```markdown
## Experiment N: Name

### Purpose
Clear statement of what we're validating

### Initial Conditions
Exact state setup (code blocks)

### Action
Specific action to propose

### Expected Outcome
Precise assertions with criteria
```

**Why**: AI agents excel at implementing well-defined specifications. Ambiguity leads to drift.

### 2. Type-Driven Development

**Pattern**: Define types and protocols first

```swift
// Define the interface
protocol Reducer {
    func reduce(state: State, action: Action) -> Effect
}

// Define the types
enum Action { /* cases */ }
enum Effect { /* cases */ }
struct State { /* fields */ }

// AI implements conformance
```

**Why**: Types guide AI implementation and catch errors at compile time.

### 3. Test-First Development

**Pattern**: Write failing tests, let AI make them pass

```swift
@Test("Feature X")
func featureX() async throws {
    // Arrange: Setup
    let state = initialState()
    
    // Act: Execute
    let result = systemUnderTest.action()
    
    // Assert: Verify
    #expect(result == expected)
}
```

**Why**: Tests are executable specifications. AI agents can iterate until tests pass.

### 4. Incremental Validation

**Pattern**: Build in small, verifiable steps

```
Step 1: Types only (compiles, no logic) → Verify
Step 2: Add reducer logic → Verify experiments 1-2
Step 3: Add state transitions → Verify experiments 3-5
Step 4: Add audit trail → Verify completeness
```

**Why**: Large changes are hard to review. Small steps catch bugs early.

### 5. Documentation-Driven Development

**Pattern**: Write docs that AI can read

```swift
/// Reduces an agent action against current governance state.
///
/// This is a pure function - same inputs produce identical outputs.
/// The reducer MUST NOT perform I/O, access network, or use randomness.
///
/// - Parameters:
///   - state: Current governance state (immutable)
///   - action: Proposed agent action (typed enum)
/// - Returns: Effect of applying action (allow/reject/transition)
public static func reduce(state: GovernanceState, action: AgentAction) -> ActionEffect
```

**Why**: AI agents use documentation to understand intent. Good docs = better code.

### 6. Explicit Acceptance Criteria

**Pattern**: Use checklists in experiment definitions

```markdown
### Success Criteria
- [ ] Action allowed
- [ ] Budget updated from X to Y
- [ ] Enforcement level transitions
- [ ] Audit entry created
- [ ] Message contains keyword
```

**Why**: Checklists are unambiguous. AI can verify each criterion.

### 7. Architectural Decision Records

**Pattern**: Document "why" not just "what"

```markdown
## ADR: Halted State Uses Transition, Not Reject

**Status**: Accepted

**Context**: Budget exhaustion needs to persist state change

**Decision**: Use `.transition(halted)` not `.reject()`

**Consequences**:
- ✅ Action that exceeded budget is recorded
- ✅ Halted state is persisted
- ✅ Gate check blocks subsequent actions
- ✅ Complete audit trail
```

**Why**: AI agents benefit from understanding architectural rationale.

### 8. Pair Programming Protocol

**Pattern**: Human defines intent, AI implements, human reviews

```
Human: "We need experiment 3b to validate halted state"
AI: [Implements test]
Human: [Reviews, asks questions]
AI: [Refines based on feedback]
Human: [Approves or requests changes]
```

**Why**: Humans are better at high-level design. AI is better at detailed implementation.

---

## Integration with ClawLaw Architecture

### How Experiments Fit Into the Bigger Picture

These experiments validate **Law 4 (Resource)** within the broader SwiftVector framework:

```
SwiftVector Codex (Constitutional Framework)
  └── Law 4: Resource Governance
      └── Budget Vector Implementation
          └── Five Experiments (This Document)
              ├── Experiment 1: Normal ops
              ├── Experiment 2: Warning state
              ├── Experiment 3: Circuit breaking
              ├── Experiment 4: Human authority
              └── Experiment 5: Reducer purity
```

### Other Laws to Implement

Using this experiment framework as a template:

- **Law 0 (Containment)**: Filesystem boundary experiments
- **Law 8 (Authority)**: Approval queue experiments
- **Law 3 (Observation)**: Audit trail experiments
- **Law 6 (Persistence)**: Memory integrity experiments
- **Law 7 (Spatial)**: Geofencing experiments

Each Law gets its own experiment suite following this pattern.

---

## Frequently Asked Questions

### Why focus on budget governance first?

Budget governance is the simplest Law to implement and test, but it exercises the entire SwiftVector pattern:
- Pure reducer
- State transitions
- Audit trail
- Human intervention
- Actor isolation

Once budget works, other Laws follow the same pattern.

### Why is halted state a transition and not a reject?

**Circuit breaker semantics**: The action that trips the breaker IS recorded (for diagnosis), the breaker enters TRIPPED state (persisted), all subsequent attempts are blocked (gate check), and human must reset the breaker.

If we reject the triggering action, we lose the audit trail and the state lock.

### Why doesn't budget exhaustion use the approval queue?

**Approval is for risky actions that CAN proceed if authorized**. Budget exhaustion is a system state problem—approving individual actions doesn't fix the underlying resource constraint. The Steward must fix the system (increase ceiling or reset spend) before ANY actions can proceed.

### Can an agent recover from halted state automatically?

**No.** That would defeat the purpose of governance. Halted state requires human intervention:
- `steward.increaseBudget(to: newCeiling)`
- `steward.resetBudget()`

The agent cannot self-authorize resource increases.

### What if the agent "learns" to propose smaller actions to avoid limits?

**That's fine.** The agent learning to work within constraints is the goal. The experiments prove the agent CANNOT:
- Bypass the limits through persuasion
- Trick the reducer with social engineering
- Self-authorize budget increases

Learning to be efficient is desirable behavior.

---

## Document Maintenance

### When to Update This Document

- [ ] Adding new experiments (Laws 0, 3, 6, 7, 8)
- [ ] Changing budget thresholds or enforcement levels
- [ ] Modifying state transition logic
- [ ] Adding new action types
- [ ] Changing test framework (e.g., XCTest → Swift Testing)

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-08 | Initial specification with 5 experiments |

---

## Summary

These five experiments form the **executable specification** for ClawLaw's budget governance. They prove:

1. ✅ The system doesn't obstruct normal work
2. ✅ Warnings are progressive and informational
3. ✅ Hard limits are deterministic and enforceable
4. ✅ Humans retain ultimate authority
5. ✅ The reducer cannot be persuaded or tricked

**All five must pass before ClawLaw is production-ready.**

---

**Author**: Stephen Sweeney  
**Project**: ClawLaw  
**Website**: https://agentincommand.ai  
**License**: MIT
