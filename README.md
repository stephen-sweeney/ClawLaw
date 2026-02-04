# ClawLaw

<p align="center">
  <img src="assets/clawlaw-header.png" alt="ClawLaw - Governed Autonomy" width="600">
</p>

<p align="center">
  <em>Original artwork from <strong>Claw Law</strong> (Iron Crown Enterprises, 1982)—the Rolemaster supplement<br>that codified rules for creatures with natural weapons. Forty years later, we're codifying rules for a different kind of creature.</em>
</p>

<h3 align="center">Governed Autonomy for OpenClaw</h3>

<p align="center"><strong>Use the full power. Keep control.</strong></p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SwiftVector](https://img.shields.io/badge/Built%20on-SwiftVector-orange)](https://github.com/AeroSage/swiftvector)
[![Status: Active Construction](https://img.shields.io/badge/Status-Active%20Construction-yellow)]()

---

## The Problem

OpenClaw is remarkable. It's an autonomous AI agent that can manage your email, control your browser, execute code, send messages, and run 24/7 as a genuine digital coworker. People are building extraordinary things with it.

It's also terrifying.

> "On one hand, it's cool that this thing can modify anything on my machine that I can. On the other, it's terrifying that it can modify anything on my machine that I can."
> — Hacker News user

The power that makes OpenClaw useful is the same power that makes it dangerous. There's no architectural boundary between "helpful assistant" and "agent that does something catastrophic." Control lives in prompts—and prompts can be subverted, ignored, or simply misunderstood.

Users respond by bolting on guardrails: sandboxes, allowlists, approval scripts, budget monitors. These help. But they're external to the system, inconsistent in application, and fragile under pressure.

**ClawLaw is the missing governance layer.**

---

## The Thesis

> *"State, not prompts, must be the authority."*

ClawLaw applies the [SwiftVector](https://agentincommand.ai) architecture to OpenClaw. Instead of hoping the agent follows instructions, ClawLaw enforces boundaries through deterministic state machines. The agent operates within state-defined contexts; it cannot modify those contexts through conversation.

The result: **governed autonomy**. Full capability within formal constraints. Power you can trust.

---

## Why Swift?

We built ClawLaw in Swift, not Python or TypeScript. This was a deliberate architectural choice.

You cannot reliably solve safety problems with the same tools that created them. Python is optimized for flexibility and dynamism; Swift is optimized for correctness and safety.

| Concern | Python/TypeScript | Swift |
|---------|-------------------|-------|
| **Type Safety** | Runtime errors | Compile-time guarantees |
| **Concurrency** | GIL / callback chaos | Actor isolation |
| **State Integrity** | Mutable by default | Explicit mutation |
| **Deployment** | 200MB environment | 5MB binary |
| **Startup** | Seconds | Milliseconds |

Specifically:

- **Type Safety as Governance:** We use Swift's type system to make illegal states unrepresentable. A file path isn't just a string; it's a validated `SandboxedPath`. You can't accidentally pass a network URL where a filesystem path is expected—the compiler prevents it.

- **Actor Isolation:** The governance state is protected by Swift Actors, ensuring that concurrent agent thoughts cannot race to corrupt the budget or approval queue. State transitions are serialized by design.

- **Resource Efficiency:** A 5MB compiled binary that runs with negligible overhead, leaving your RAM and thermal budget for the model. ClawLaw watches; it doesn't compete.

This is the [Swift at the Edge](https://agentincommand.ai/swift-at-the-edge) thesis in practice: when control matters, use a language built for control.

---

## Features

### 🛡️ Sandbox Envelope

Containment as state, not configuration.

- **Filesystem boundaries** — Define readable/writable paths as explicit state
- **Network allowlists** — Domains the agent may contact, enforced at the state layer
- **Isolation levels** — From workspace-only to full containerization
- **Transition controls** — Escalating containment requires authorization, not just a flag

```swift
let containment = ContainmentState(
    readablePaths: [workspace, "/usr/share/doc"],
    writablePaths: [workspace],
    allowedDomains: ["api.anthropic.com", "github.com"],
    isolationLevel: .session
)
```

The agent sees what containment allows. Period.

---

### 💰 Budget Governor

Cost control as state transitions, not external scripts.

- **Per-task ceilings** — No single task exceeds defined token limits
- **Session maximums** — Cumulative session spend with hard stops
- **Rolling window caps** — Daily/weekly budgets that reset automatically
- **Circuit breaker states** — Automatic degradation: cheaper model → human gate → halt

```swift
let budgetConfig = BudgetConfig(
    taskCeiling: 10_000,        // tokens per task
    sessionMaximum: 100_000,    // tokens per session
    windowCap: 500_000,         // tokens per 24h
    warningThreshold: 0.8,      // alert at 80%
    degradedModel: "claude-sonnet-4-5"  // fallback when over budget
)
```

When the budget governor transitions to `.degraded`, the model switches automatically. When it transitions to `.gated`, execution pauses for human approval. When it hits `.halted`, nothing runs until the window resets.

This isn't monitoring. It's enforcement.

---

### ✅ Approval Queue

Human-in-the-loop as a state machine, not a prompt suggestion.

- **Task classification** — Automatic categorization by risk level
- **Legible previews** — See exactly what you're approving: commands, file paths, domains, diffs
- **Timeout handling** — Configurable behavior when approvals aren't granted
- **Audit trail** — Every approval decision is a logged state transition

**Task Authorization Levels:**

| Level | Category | Examples | Default Policy |
|-------|----------|----------|----------------|
| 0 | Read-only | File listing, web search, status checks | Autonomous |
| 1 | Sandbox writes | Create/edit files in workspace | Autonomous |
| 2 | External network | API calls, outbound data | Human gate |
| 3 | Sensitive operations | Email send, purchases, messaging | Always human gate |
| 4 | System modification | Install skills, change config | Block by default |

```swift
let authConfig = AuthorizationConfig(
    autonomousThreshold: .sandboxWrite,  // Levels 0-1 run without approval
    approvalTimeout: .minutes(30),
    timeoutBehavior: .deny
)
```

The agent can't talk its way past Level 2. The state machine doesn't negotiate.

---

### 📋 Audit Log

Every action, every state transition, fully replayable.

- **Complete history** — What happened, when, in what state
- **State snapshots** — Before and after every transition
- **Replay capability** — Reconstruct any session from the log
- **Tamper-evident** — Hashed entries for integrity verification

```json
{
  "timestamp": "2026-02-03T14:32:01Z",
  "sessionId": "a1b2c3d4",
  "action": "writeFile",
  "path": "/workspace/report.md",
  "authorizationLevel": 1,
  "previousState": { "budget": { "sessionTokens": 45000 } },
  "newState": { "budget": { "sessionTokens": 47500 } },
  "result": "allowed",
  "hash": "sha256:e3b0c44298fc..."
}
```

When something goes wrong, you know exactly what happened and why. When something goes right, you can prove it.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ClawLaw Control Plane                    │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Containment │  │   Budget    │  │    Authorization    │ │
│  │    State    │  │    State    │  │       State         │ │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         │                │                     │            │
│         └────────────────┼─────────────────────┘            │
│                          │                                  │
│                   ┌──────┴──────┐                           │
│                   │   Composed  │                           │
│                   │   Reducer   │                           │
│                   └──────┬──────┘                           │
│                          │                                  │
│                   ┌──────┴──────┐                           │
│                   │  Audit Log  │                           │
│                   └──────┬──────┘                           │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │  OpenClaw   │
                    │   Gateway   │
                    └─────────────┘
```

ClawLaw sits between you and OpenClaw. Every task passes through the composed reducer. The reducer consults containment, budget, and authorization state. Only if all constraints are satisfied does the task reach the gateway.

The OpenClaw agent retains full capability—ClawLaw doesn't lobotomize it. But capability operates within governance. That's the difference between a powerful tool and a liability.

---

## How It Works

### The Reducer Model

ClawLaw implements the [SwiftVector](https://agentincommand.ai) architectural pattern. At its heart is the **Reducer**: a pure function that takes the current state and a proposed action, and returns a new state (or a rejection).

```
(CurrentState, Action) → NewState
```

Because it is a pure function, it is **deterministic**. Given the same inputs, it will *always* make the same decision. It cannot be "convinced" or "prompt engineered" or socially manipulated.

```swift
// From ClawLaw's GovernanceReducer
func reduce(state: GovernanceState, action: AgentAction) -> StateTransition {
    switch action {
    case .writeFile(let path, _):
        // 1. Constraint: Is path in sandbox?
        guard state.containment.allowsWrite(to: path) else {
            return .reject("Access denied: \(path) outside workspace")
        }
        
        // 2. Constraint: Is file protected?
        if state.containment.isProtected(path) {
            return .requireApproval(
                level: .sensitive, 
                reason: "Protected file: \(path.lastComponent)"
            )
        }
        
        // 3. Constraint: Do we have budget?
        guard state.budget.canAfford(action.estimatedCost) else {
            return .transition(to: .degraded)
        }
        
        // All constraints satisfied
        return .allow(updating: state.recordingAction(action))
        
    case .sendEmail(let to, _, _):
        // Level 3: Always requires human approval
        return .requireApproval(
            level: .sensitive,
            reason: "Outbound email to \(to)",
            preview: action.humanReadablePreview
        )
        
    case .installSkill(let skillId):
        // Level 4: Blocked by default
        return .reject("Skill installation requires manual override: \(skillId)")
    }
}
```

This code doesn't "suggest" that the agent shouldn't write outside the sandbox. It makes writing outside the sandbox **impossible**. The type system enforces it. The reducer enforces it. There's no prompt to subvert.

### Why State, Not Prompts?

OpenClaw (like all LLM-based agents) is controlled by prompts. System prompts define behavior; user prompts direct tasks. This works remarkably well—until it doesn't.

The problem: **prompts are suggestions, not constraints**. An adversarial input, a confused context, or simple misunderstanding can cause the agent to ignore or reinterpret its instructions. There's no formal boundary.

ClawLaw interposes a state machine. The agent cannot:
- Write outside `writablePaths` (containment state enforces)
- Spend beyond `taskCeiling` (budget state enforces)  
- Execute Level 3 actions without approval (authorization state enforces)

These aren't instructions the agent might follow. They're constraints the agent cannot violate. The state machine doesn't negotiate.

---

## Installation

### 🚧 Status: Active Construction

ClawLaw is currently being implemented using the **Building in Public** methodology. The architecture and protocols are defined; the implementation is progressing through the [SwiftVector OpenClaw Roadmap](https://agentincommand.ai/roadmap).

**What exists now:**
- ✅ Architecture design and protocol definitions
- ✅ Core SwiftVector reducer patterns
- 🔨 Sandbox envelope implementation (in progress)
- 📋 Budget governor (next milestone)
- 📋 Approval queue (planned)
- 📋 OpenClaw gateway integration (planned)

**To explore the architecture:**

```bash
# Clone the repository
git clone https://github.com/AeroSage/clawlaw.git
cd clawlaw

# View the module structure
open Package.swift

# Run existing tests
swift test

# Follow development progress
cat CHANGELOG.md
```

**To follow along:**
- Star the repo for updates
- Read the [Governed Autonomy series](https://agentincommand.ai/series/governed-autonomy) for context
- Join the discussion in Issues

### Prerequisites (for when it's ready)

- **Node.js ≥22** — Required for OpenClaw
- **OpenClaw** — Installed and configured ([OpenClaw docs](https://docs.clawd.bot/start/getting-started))
- **Swift ≥5.9** — For ClawLaw control plane
- **macOS 14+ or Linux** — Swift runtime support

### Target Installation (v0.2+)

Once core features are complete:

```bash
# Install via Homebrew (macOS)
brew install aerosage/tap/clawlaw

# Or build from source
git clone https://github.com/AeroSage/clawlaw.git
cd clawlaw
swift build -c release
cp .build/release/clawlaw /usr/local/bin/

# Initialize and connect
clawlaw init
clawlaw connect --gateway ws://127.0.0.1:18789
clawlaw doctor
```

---

## Configuration

ClawLaw uses a single configuration file at `~/.clawlaw/config.json`.

### Minimal Configuration

```json
{
  "gateway": {
    "url": "ws://127.0.0.1:18789",
    "token": "your-openclaw-gateway-token"
  },
  "governance": {
    "enabled": true
  }
}
```

This enables ClawLaw with sensible defaults: workspace-only writes, human gates on external network access, and a generous daily token budget.

### Full Configuration Reference

```json
{
  "gateway": {
    "url": "ws://127.0.0.1:18789",
    "token": "your-openclaw-gateway-token",
    "timeout": 30000
  },
  
  "containment": {
    "isolationLevel": "session",
    "readablePaths": [
      "~/clawd",
      "/usr/share/doc"
    ],
    "writablePaths": [
      "~/clawd/workspace"
    ],
    "allowedDomains": [
      "api.anthropic.com",
      "api.openai.com",
      "github.com",
      "*.githubusercontent.com"
    ],
    "blockedDomains": [
      "*.malware.example"
    ],
    "protectedPatterns": [
      "**/.ssh/*",
      "**/.aws/*",
      "**/credentials*"
    ]
  },
  
  "budget": {
    "taskCeiling": 10000,
    "sessionMaximum": 100000,
    "windowCap": 500000,
    "windowDuration": "24h",
    "warningThreshold": 0.8,
    "degradedModel": "anthropic/claude-sonnet-4-5",
    "enforcementPolicy": {
      "onWarning": "notify",
      "onDegraded": "switch_model",
      "onGated": "pause",
      "onHalted": "reject"
    }
  },
  
  "authorization": {
    "autonomousThreshold": 1,
    "approvalTimeout": "30m",
    "timeoutBehavior": "deny",
    "levelOverrides": {
      "send_email": 3,
      "send_slack": 2,
      "git_push": 2,
      "install_skill": 4,
      "modify_config": 4
    },
    "alwaysBlock": [
      "delete_system_files",
      "disable_clawlaw",
      "expose_credentials"
    ]
  },
  
  "audit": {
    "enabled": true,
    "logPath": "~/.clawlaw/audit.log",
    "format": "jsonl",
    "includeStateSnapshots": true,
    "hashAlgorithm": "sha256",
    "retention": "90d"
  },
  
  "ui": {
    "approvalInterface": "terminal",
    "showDiffs": true,
    "showDomains": true,
    "showEstimatedCost": true,
    "theme": "dark"
  }
}
```

### Configuration Options

#### Gateway

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | string | `ws://127.0.0.1:18789` | OpenClaw gateway WebSocket URL |
| `token` | string | — | Gateway authentication token |
| `timeout` | number | `30000` | Connection timeout in milliseconds |

#### Containment

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `isolationLevel` | enum | `"session"` | `none` / `workspace` / `session` / `full` |
| `readablePaths` | string[] | `["~/clawd"]` | Paths agent may read |
| `writablePaths` | string[] | `["~/clawd/workspace"]` | Paths agent may write |
| `allowedDomains` | string[] | `["api.anthropic.com"]` | Permitted domains (wildcards supported) |
| `blockedDomains` | string[] | `[]` | Blocked domains (overrides allowed) |
| `protectedPatterns` | string[] | `["**/.ssh/*"]` | Glob patterns requiring elevated approval |

#### Budget

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `taskCeiling` | number | `10000` | Maximum tokens per task |
| `sessionMaximum` | number | `100000` | Maximum tokens per session |
| `windowCap` | number | `500000` | Maximum tokens per rolling window |
| `windowDuration` | string | `"24h"` | Rolling window duration |
| `warningThreshold` | number | `0.8` | Budget fraction triggering warning |
| `degradedModel` | string | — | Fallback model when budget stressed |

#### Authorization

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `autonomousThreshold` | number | `1` | Highest level running without approval (0-4) |
| `approvalTimeout` | string | `"30m"` | Time before pending approval expires |
| `timeoutBehavior` | enum | `"deny"` | `deny` / `approve` / `escalate` |
| `levelOverrides` | object | `{}` | Custom levels for specific action types |
| `alwaysBlock` | string[] | `[]` | Actions that are never permitted |

#### Audit

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable state transition logging |
| `logPath` | string | `~/.clawlaw/audit.log` | Audit log file path |
| `format` | enum | `"jsonl"` | `jsonl` / `json` / `csv` |
| `includeStateSnapshots` | boolean | `true` | Include full state in entries |
| `hashAlgorithm` | string | `"sha256"` | Tamper detection hash |
| `retention` | string | `"90d"` | Log retention period |

---

## Commands

### Core Commands

```bash
# Initialize ClawLaw configuration
clawlaw init [--config <path>]

# Connect to OpenClaw gateway
clawlaw connect [--gateway <url>] [--token <token>]

# Check configuration and connectivity
clawlaw doctor

# Show current governance state
clawlaw status

# Show budget consumption
clawlaw budget [--reset-window]

# List pending approvals
clawlaw approvals list

# Approve a pending task
clawlaw approvals approve <task-id>

# Deny a pending task  
clawlaw approvals deny <task-id> [--reason <reason>]
```

### Audit Commands

```bash
# View recent audit entries
clawlaw audit [--last <n>] [--since <timestamp>]

# Export audit log
clawlaw audit export [--format <format>] [--output <path>]

# Verify audit log integrity
clawlaw audit verify

# Replay a session from audit log
clawlaw audit replay <session-id> [--dry-run]
```

### Configuration Commands

```bash
# Show current configuration
clawlaw config show

# Update a configuration value
clawlaw config set <key> <value>

# Validate configuration
clawlaw config validate

# Reset to defaults
clawlaw config reset [--confirm]
```

---

## Usage Examples

### Basic: Governed Task Execution

```bash
# Start ClawLaw (connects to your OpenClaw gateway)
clawlaw connect

# Execute a task through governance
clawlaw exec "Research competitors and summarize findings"

# Task classified as Level 1 (sandbox write) → executes autonomously
# Output saved to workspace, within budget, logged
```

### Approval Flow

```bash
# Task that requires approval
clawlaw exec "Send summary to team@company.com"

# ClawLaw response:
# ⏳ Task requires approval (Level 3: send_email)
# 
# Preview:
#   Action: send_email
#   To: team@company.com
#   Subject: Competitor Research Summary
#   Body: [148 words, 3 attachments]
#   Estimated cost: ~2,500 tokens
#
# Task ID: abc123
# Expires: 30 minutes
# 
# Run: clawlaw approvals approve abc123

# Approve the task
clawlaw approvals approve abc123
# ✓ Task approved and executed
```

### Budget Management

```bash
# Check current budget state
clawlaw budget

# Output:
# Budget Status
# ─────────────────────────────
# Task:     2,400 / 10,000 tokens (24%)
# Session:  45,000 / 100,000 tokens (45%)
# Window:   180,000 / 500,000 tokens (36%)
# 
# Enforcement: normal
# Window resets: 14h 23m
# 
# ████████░░░░░░░░░░░░ 36%

# After heavy usage:
clawlaw budget

# Output:
# Budget Status
# ─────────────────────────────
# Task:     0 / 10,000 tokens (0%) [reset]
# Session:  95,000 / 100,000 tokens (95%)
# Window:   450,000 / 500,000 tokens (90%)
# 
# Enforcement: ⚠️ degraded
# Model: claude-sonnet-4-5 (fallback)
# Window resets: 8h 12m
# 
# ██████████████████░░ 90%
```

### Audit Inspection

```bash
# What happened in the last hour?
clawlaw audit --since "1 hour ago"

# Output:
# TIME                 ACTION          TARGET              AUTH    RESULT
# ─────────────────────────────────────────────────────────────────────────
# 14:32:01  writeFile       /workspace/notes.md       L1      ✓ allowed
# 14:33:15  searchWeb       "competitor analysis"     L0      ✓ allowed
# 14:35:42  sendEmail       team@company.com          L3      ⏳ pending
# 14:38:01  [approval]      task:abc123               human   ✓ approved
# 14:38:05  sendEmail       team@company.com          L3      ✓ allowed
# 14:40:22  [budget]        normal → degraded         auto    ⚠️ transition

# Verify nothing was tampered with
clawlaw audit verify
# ✓ 847 entries verified
# ✓ Hash chain intact
# ✓ No gaps detected
```

---

## Roadmap

### v0.1 — Foundation (Current)
- [x] Architecture design
- [x] Core protocol definitions  
- [x] SwiftVector reducer patterns
- [ ] ContainmentState implementation
- [ ] Basic CLI scaffold

### v0.2 — Core Governance
- [ ] BudgetGovernor reducer
- [ ] ApprovalQueue state machine
- [ ] Task classifier
- [ ] Audit log with integrity verification

### v0.3 — Integration
- [ ] OpenClaw gateway bridge
- [ ] WebSocket protocol handler
- [ ] End-to-end task flow
- [ ] Terminal approval interface

### v0.4 — Polish
- [ ] Configuration validation
- [ ] Error recovery
- [ ] Performance optimization
- [ ] Documentation complete

### Future
- [ ] Web-based approval dashboard
- [ ] Multi-agent coordination
- [ ] Skill permission manifests
- [ ] Custom reducer plugins
- [ ] Diff-based file edit previews

---

## Contributing

ClawLaw is part of the [SwiftVector](https://agentincommand.ai) ecosystem. We welcome contributions that advance governed autonomy for AI agents.

### Ways to Contribute

- **Use it and report issues** — Real-world feedback shapes development
- **Propose governance patterns** — Document configurations that work
- **Submit implementations** — Code following the [contributing guide](CONTRIBUTING.md)
- **Write about it** — Blog posts, tutorials, case studies

### Development Setup

```bash
git clone https://github.com/AeroSage/clawlaw.git
cd clawlaw
swift build
swift test
```

### Code Style

- Swift API Design Guidelines
- Explicit types over inference for public APIs
- Reducers must be pure functions
- All state mutations through defined transitions

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## Related Projects

- **[SwiftVector](https://github.com/AeroSage/swiftvector)** — The core framework for state-based agent control
- **[OpenClaw](https://github.com/clawdbot/clawdbot)** — The autonomous AI assistant ClawLaw governs
- **[AgentInCommand.ai](https://agentincommand.ai)** — Articles, guides, and the governed autonomy thesis

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Peter Steinberger** and the OpenClaw community for building something worth governing
- The **SwiftVector** contributors for the architectural foundation
- Everyone asking "but how do we control this thing?"—you're why ClawLaw exists

---

<p align="center">
  <strong>Capability without governance is liability.</strong><br>
  <em>ClawLaw makes OpenClaw an asset.</em>
</p>

---

<p align="center">
  <a href="https://agentincommand.ai">AgentInCommand.ai</a> · 
  <a href="https://agentincommand.ai/series/governed-autonomy">Read the Series</a> · 
  <a href="https://github.com/AeroSage/clawlaw/issues">Discuss</a>
</p>
