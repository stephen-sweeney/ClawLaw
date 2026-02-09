# ClawLaw

**Governed Autonomy for Desktop Agents**

ClawLaw applies the [SwiftVector](https://agentincommand.ai) architectural pattern to desktop agent systems, providing deterministic governance for autonomous AI agents with tool access.

## Overview

ClawLaw implements three core governance vectors:

- **Law 0 (Containment)**: Filesystem and network boundaries
- **Law 4 (Resource)**: Token budget and thermal management  
- **Law 8 (Authority)**: Risk-tiered approval queue

These combine to create a constitutional framework that constrains agent authority while preserving intelligence.

## The Pattern

```
State → Agent → Action → Reducer → New State
```

- **State** is the single source of truth (typed, explicit, immutable)
- **Agents** propose actions but never mutate state directly
- **Reducer** is a pure function that validates and applies state transitions
- **Effects** execute side effects only after state transitions

## Quick Start

### Build

```bash
swift build
```

### Run Demo

```bash
swift run clawlaw demo
```

This runs an interactive demonstration showing:
- Normal operations under budget
- Protected resource handling
- Budget enforcement state transitions (normal → degraded → gated → halted)
- Steward intervention and recovery

### Run Tests

```bash
swift test
```

Tests validate all five governance experiments:

1. **Normal Operation**: "Organize my documents folder"
2. **Approaching Limit**: Warning state triggered at 80% budget
3. **Exceeding Threshold**: Critical → Halted state progression
4. **Recovery**: Human increases budget, system resumes
5. **Gaming Attempt**: Reducer doesn't negotiate, math is deterministic

## Architecture

### Core Types

- `GovernanceState`: The deterministic state (budget, paths, audit log)
- `AgentAction`: Typed action proposals from agents
- `ActionEffect`: Result of reducer evaluation
- `GovernanceReducer`: Pure function for authority

### Actors

- `GovernanceOrchestrator`: Manages the control loop
- `Steward`: Human-in-command interface
- `ApprovalQueue`: Isolated queue for high-risk actions

### Budget Enforcement Levels

| Level | Threshold | Behavior |
|-------|-----------|----------|
| **Normal** | 0-80% | Full capability, no restrictions |
| **Degraded** | 80-95% | Warning issued, continues with notice |
| **Gated** | 95-100% | New actions require approval |
| **Halted** | >100% | All actions blocked, human reset required |

## Example Usage

```swift
// Initialize governance
let initialState = GovernanceState.mock(
    writablePaths: ["/workspace"],
    protectedPatterns: [".ssh", "credentials"],
    taskCeiling: 10000
)

let orchestrator = GovernanceOrchestrator(initialState: initialState)
let steward = orchestrator.getSteward()

// Agent proposes action
let action = AgentAction.research(estimatedTokens: 500)
let result = await orchestrator.propose(action)

switch result {
case .allowed(let message):
    print("✅ \(message)")
case .allowedWithWarning(let message):
    print("⚠️  \(message)")
case .rejected(let reason):
    print("❌ \(reason)")
case .suspended(let approvalId, let message):
    print("⏸️  \(message)")
    // Wait for Steward approval
}

// Human intervention
if needsRecovery {
    await steward.increaseBudget(to: 20000)
    // or
    await steward.resetBudget()
}

// Review audit trail
let audit = await steward.auditTrail()
for entry in audit {
    print("[\(entry.enforcement)] \(entry.action)")
}
```

## Philosophy

From the [ClawLaw paper](https://agentincommand.ai/papers/clawlaw):

> *You cannot build the Law out of the same material as the Agent. You cannot build a prison out of water.*

Current agent frameworks attempt to constrain AI behavior through prompts—using the same probabilistic material to solve the problem it creates. ClawLaw separates **intelligence** (which should be fluid) from **authority** (which must be rigid).

The agent reasons freely. The state machine governs absolutely. Between them, the Reducer enforces the boundary.

## Project Status

**Version**: 0.1.0-alpha  
**Status**: Reference implementation in progress

This is a working implementation of the SwiftVector pattern applied to desktop agents. It demonstrates:

- ✅ Deterministic state transitions
- ✅ Complete audit trails
- ✅ Actor-isolated governance
- ✅ Budget-based circuit breaking
- ✅ Risk-tiered approval queues
- 🚧 Integration with OpenClaw (planned)
- 🚧 Real-time monitoring UI (planned)

## Related Projects

- **[SwiftVector](https://github.com/stephen-sweeney/SwiftVector)**: The core architectural pattern
- **[Chronicle Quest](https://github.com/stephen-sweeney/chronicle-quest)**: SwiftVector for narrative systems
- **[Flightworks GCS](https://github.com/stephen-sweeney/flightworks-gcs)**: SwiftVector for drone operations

## Documentation

- [SwiftVector Codex](https://agentincommand.ai/papers/swiftvector-codex) - Constitutional framework
- [SwiftVector Whitepaper](https://agentincommand.ai/papers/swiftvector-whitepaper) - Technical specification
- [ClawLaw Paper](https://agentincommand.ai/papers/clawlaw) - Desktop agent governance
- [The Agency Paradox](https://agentincommand.ai/papers/agency-paradox) - Human-in-command philosophy

## Contributing

ClawLaw is open for contributions. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Areas of focus:
- Additional Law implementations (Law 1-10)
- Integration adapters for agent frameworks
- Monitoring and visualization tools
- Certification tooling for regulated industries

## License

MIT License - See [LICENSE](LICENSE)

## Contact

**Author**: Stephen Sweeney  
**Email**: stephen@agentincommand.ai  
**Website**: https://agentincommand.ai  
**LinkedIn**: https://linkedin.com/in/macsweeney

---

*"Capability without governance is liability."*
