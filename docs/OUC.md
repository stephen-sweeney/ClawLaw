# ClawLaw Operational Use Case Document

**Version:** 0.1.0
**Date:** February 19, 2026
**Author:** Product Management
**Status:** Draft
**Companion documents:** `docs/HRD.md`, `docs/PLD.md`, `docs/DOMAIN_NOTES.md`

---

## 1. Executive Summary

ClawLaw is a governance framework for desktop AI agents. It interposes a deterministic state machine between an autonomous agent (OpenClaw) and the host operating system, evaluating every proposed action through a pure-function reducer before the action reaches the filesystem, shell, or network.

**Demo promise:** ClawLaw prevents overnight spend blowouts and blocks destructive actions without trusting prompts.

This document defines the operational use cases that demonstrate that promise. It specifies three hero flows — budget blowout prevention, destructive action control, and protected resource handling — with sufficient detail for an engineering team to build a functional demonstration and for an evaluator to verify governance claims against observable behavior.

**Scope:** This document covers operational behavior for ClawLaw v1.0 on macOS (single user, single machine). It does not cover internal architecture, module design, or API contracts — those belong to the PLD. It does not cover requirements rationale — that belongs to the HRD. This document answers: *what does governance look like from the operator's chair?*

**Critical deviation from PLD:** This document adopts a stricter audit posture than the PLD for the demo configuration. Where the PLD specifies "audit write fails → log warning, continue governance" (Failure Modes table), this document specifies **block all actions and require human intervention**. Rationale: for a demo, governance that cannot prove it governed is functionally ungoverned. Audit integrity is a hard dependency in this operational context. The PLD posture remains the correct production default; this deviation is scoped to the demo configuration.

---

## 2. Operational Context

### 2.1 Environment

ClawLaw operates on a single macOS machine (Apple Silicon) alongside an OpenClaw agent instance. The operator runs both processes locally. There is no cloud infrastructure, no remote services, and no multi-user access. The governance proxy (if HTTP interception is used) binds to localhost only.

### 2.2 Why Governance Matters Operationally

OpenClaw executes tool calls — shell commands, file operations, browser automation, outbound communication — with the full privileges of the user who launched it. The agent's decisions about what to execute are driven by an LLM: a probabilistic system that can be misdirected by prompt injection, confused context, adversarial skill payloads, or simple misinterpretation.

The operational consequence: without governance, an agent running overnight can exhaust an API budget, delete files it was not supposed to touch, exfiltrate data through outbound channels, or execute arbitrary shell commands — all while producing reasonable-looking explanations for its behavior.

ClawLaw closes this gap by making every action pass through a deterministic evaluation before execution. The operator defines boundaries, budgets, and approval requirements. The reducer enforces them. The audit trail proves it.

### 2.3 What Governance Is Not

Governance is not restriction. A governed agent retains full capability within its authorized boundaries. Governance does not reduce what the agent can do — it bounds what it may do, and it proves what it did.

---

## 3. Actors, Roles, Responsibilities

### 3.1 The Steward (Human Operator)

The Steward is the human who operates ClawLaw. The Steward holds Principal authority — the non-delegable rights to:

- **Set boundaries:** Configure writable paths, protected patterns, and budget ceilings
- **Approve or reject:** Process actions in the approval queue
- **Intervene:** Increase budgets, reset spend counters, resume halted systems
- **Audit:** Review the governance trail for any period of operation
- **Configure:** Define and modify governance policy via configuration file

The Steward exercises authority through the CLI (`clawlaw approve`, `clawlaw budget`, `clawlaw status`, etc.) or by directly editing the configuration file. No agent action can grant, modify, or revoke Steward authority.

All Steward actions are recorded in the audit trail with the role identifier "STEWARD."

### 3.2 The Agent (OpenClaw)

The agent is the autonomous software process that proposes actions. In this operational context, the agent is an OpenClaw instance. The agent:

- **Proposes** actions (file writes, deletions, shell commands, research, outbound communication)
- **Receives** governance decisions (allowed, rejected, suspended pending approval)
- **Waits** when an action is suspended — it cannot proceed until the Steward decides
- **Cannot** modify governance configuration, bypass the reducer, or escalate its own authority

The agent does not know it is governed in the architectural sense — it receives allow/reject responses indistinguishable from normal tool-call outcomes. From the agent's perspective, a rejected write is the same as a permission error.

### 3.3 Interaction Model

```
Agent proposes action
  → Reducer evaluates (deterministic, < 1ms)
    → Allowed: action executes on host
    → Rejected: action blocked, agent receives denial
    → Suspended: action enters approval queue
      → Steward reviews via CLI
        → Approved: action executes with budget impact
        → Rejected: action permanently blocked
```

Every path through this model produces an audit entry.

---

## 4. System Boundaries and Default Governance Posture

### 4.1 Default Configuration

A fresh ClawLaw installation applies these defaults without requiring operator configuration:

| Parameter | Default Value | Rationale |
|---|---|---|
| Writable paths | `~/workspace` | Agent can only write within the operator's workspace directory |
| Protected patterns | `.ssh`, `credentials`, `.env`, `keychain` | Sensitive files require human approval even within writable paths |
| Budget ceiling | 50,000 tokens | Sufficient for a day of moderate agent use; prevents overnight runaway |
| Warning threshold | 80% (40,000 tokens) | Early warning before critical zone |
| Critical threshold | 95% (47,500 tokens) | Enters gated mode — every non-zero-cost action requires approval |
| Always-approve actions | `deleteFile`, `executeShellCommand`, `sendEmail` | These action types always require human approval regardless of enforcement level |
| Audit retention | 90 days | Covers standard audit review cycles |
| Audit format | JSONL (daily rotation) | Append-only, one entry per line, machine-readable |
| File permissions | 0600 | Configuration, state, and audit files readable only by owning user |

### 4.2 Enforcement Levels

The budget system operates through four deterministic enforcement levels:

| Utilization | Enforcement Level | Behavior |
|---|---|---|
| 0% to <80% | **Normal** | Full agent capability. All actions evaluated but only boundary violations and always-approve actions are gated. |
| >=80% to <95% | **Degraded** | Warnings issued on enforcement transition. Agent continues operating. Operator is notified via CLI status. |
| >=95% to 100% | **Gated** | All agent actions with non-zero token cost require Steward approval before execution. |
| >100% | **Halted** | All agent actions are rejected. No automated recovery. Only Steward intervention (`increaseBudget` or `resetBudget`) can resume operations. |

**Critical boundary:** At exactly 100% utilization (e.g., 50,000/50,000 tokens), enforcement is **gated**, not halted. Halted requires spend strictly exceeding the ceiling.

### 4.3 Enforcement Reconciliation

No code path — property assignment, initialization, deserialization, or manual construction — can set an enforcement level less restrictive than what the current spend-to-ceiling ratio requires. The system computes the enforcement level from the ratio and takes the maximum of the computed level and any explicitly set level: `enforcement = max(provided, calculated)`.

This means a corrupted or stale state file that records `normal` enforcement with 95% spend is automatically corrected to `gated` on load. The operator never needs to worry about stale enforcement states.

### 4.4 Token Costs

Each action type has a defined token cost applied to the budget on execution:

| Action Type | Token Cost | Authorization Level |
|---|---|---|
| `research` | Variable (agent-declared) | readOnly |
| `writeFile` | 100 | sandboxWrite (or sensitive if path matches `.ssh`/`credentials`) |
| `deleteFile` | 50 | sensitive (always requires approval) |
| `executeShellCommand` | 200 | systemMod (always requires approval) |
| `sendEmail` | 150 | sensitive (always requires approval) |

### 4.5 Boundary Enforcement

- **Path allowlist:** Agent file operations are evaluated against configured writable paths. Any path outside the allowlist is rejected before I/O occurs. Paths are lexically normalized (resolving `.`, `..`, and redundant separators) before comparison.
- **Protected patterns:** Paths matching a protected pattern (e.g., `.ssh`, `credentials`, `.env`) require human approval even if the path is within the allowlist.
- **Configuration protection:** The governance configuration file itself is hardcoded as a protected resource. No agent action can modify governance policy.

---

## 5. Primary Use Cases (DEMO HERO FLOWS)

### Use Case A: Budget Blowout Prevention (Law 4 — Resource)

**Demo narrative:** An agent running an overnight research task hits budget thresholds. The operator wakes to a governed system, not a surprise bill.

#### Trigger

The agent's cumulative token spend crosses a configured enforcement threshold (warning at 80%, critical at 95%, halt at >100%).

#### Preconditions

- ClawLaw is running with default configuration (ceiling: 50,000 tokens, warning: 80%, critical: 95%)
- Agent is executing a sequence of research actions
- Enforcement level is `normal`
- Audit writer is operational and writing to the daily JSONL file

#### Main Flow

1. Agent proposes `research(estimatedTokens: 500)` actions repeatedly over time.
2. Each action passes through the reducer: enforcement level check (Phase 1) → action validation (Phase 2) → budget impact (Phase 3).
3. Each action is allowed; token cost is applied; an audit entry is written.
4. At spend = 40,000 (80%), the reducer detects the threshold crossing and returns `.transition` with enforcement upgraded to `degraded`. The transition message and the new enforcement level are recorded in the audit trail.
5. Agent continues operating. Actions are still allowed.
6. At spend = 47,500 (95%), the reducer returns `.transition` with enforcement upgraded to `gated`. Every subsequent action with non-zero token cost now returns `.requireApproval` instead of `.allow`.
7. Agent actions are suspended. The approval queue accumulates pending actions.
8. Operator checks status via CLI and sees: current enforcement, budget utilization, and pending approvals.
9. Operator has three choices:
   - **Approve individual actions** — each approved action executes with budget impact applied.
   - **Increase the budget ceiling** — if the new ratio drops below thresholds, enforcement relaxes accordingly.
   - **Let the system hold** — no actions execute; budget is preserved.
10. If cumulative spend strictly exceeds 50,000 tokens (>100%), enforcement transitions to `halted`. All subsequent actions are rejected with "System halted. Human reset required."
11. Operator must run `increaseBudget` or `resetBudget` to resume. Both interventions are recorded in the audit trail with Steward attribution.

#### Alternate Flows

**A-ALT-1: Operator increases budget before gated mode.**
At step 6, before spend reaches 95%, the operator proactively increases the ceiling to 100,000. The new ratio (47,500/100,000 = 47.5%) is below the warning threshold. Enforcement remains `normal`. The budget increase is recorded in the audit trail.

**A-ALT-2: Zero-cost action in gated mode.**
At step 7, the agent proposes `research(estimatedTokens: 0)`. The gated-mode gate check evaluates `action.tokenCost > 0`, which is false. The action passes Phase 1 and Phase 2 (research has no action-type gate). The action is allowed without approval. No budget impact. Audit entry records the allow decision.

**A-ALT-3: Spend lands exactly at 100%.**
Agent spend reaches exactly 50,000/50,000 tokens. Utilization ratio is 1.0 (100%). Enforcement is `gated`, **not** `halted`. The agent's next non-zero-cost action requires approval. Only if an approved action pushes spend above 50,000 does the system transition to `halted`.

#### Failure Flows

**A-FAIL-1: Audit write failure during budget transition.**
The audit writer fails to write the transition entry (e.g., disk full). In the demo configuration, **all subsequent actions are blocked** until the audit writer is restored. Rationale: a governance transition that is not recorded cannot be proven. The operator must resolve the disk issue and restart.

> **Deviation:** The PLD specifies "log warning, continue governance" for audit write failures. This document adopts the stricter posture for the demo. See Executive Summary.

**A-FAIL-2: State persistence failure.**
The state file cannot be written after a budget transition. The system continues operating with in-memory state and logs a warning. On process restart, state recovers from the last successful write. If no state file exists, the system starts from configuration defaults. The audit trail (separate files) preserves the record of what occurred.

**A-FAIL-3: Process crash during halted state.**
ClawLaw terminates while enforcement is `halted`. On restart, the state file is loaded. Enforcement reconciliation detects that spend exceeds the ceiling and re-establishes `halted` enforcement. The system does not resume agent operations automatically.

#### Audit Entries

Each of the following events produces an audit entry with fields: `id`, `timestamp`, `action`, `effect`, `priorSpend`, `newSpend`, `enforcement`, `agentId`.

| Event | `action` | `effect` | `enforcement` |
|---|---|---|---|
| Research action allowed | `research(estimatedTokens: 500)` | `Budget: 39500 → 40000` | `degraded` |
| Degraded transition | `research(estimatedTokens: 500)` | `Budget: 39500 → 40000` | `degraded` |
| Gated transition | `research(estimatedTokens: 500)` | `Budget: 47000 → 47500` | `gated` |
| Halted transition | (approved action) | `Budget: 49900 → 50100` | `halted` |
| Budget increase | `STEWARD_INTERVENTION: Increased budget ceiling to 100000` | `Enforcement: halted → normal` | `normal` |
| Budget reset | `STEWARD_INTERVENTION: Reset budget` | `Enforcement: halted → normal` | `normal` |

#### Acceptance Criteria

| ID | Criterion |
|---|---|
| **AC-A01** | The system shall transition enforcement from `normal` to `degraded` when cumulative spend reaches or exceeds 80% of the configured ceiling. |
| **AC-A02** | The system shall transition enforcement from `degraded` to `gated` when cumulative spend reaches or exceeds 95% of the configured ceiling. |
| **AC-A03** | The system shall transition enforcement to `halted` when cumulative spend strictly exceeds 100% of the configured ceiling. |
| **AC-A04** | The system shall require Steward approval for all agent actions with non-zero token cost when enforcement is `gated`. |
| **AC-A05** | The system shall reject all agent actions when enforcement is `halted`, with a message indicating human intervention is required. |
| **AC-A06** | The system shall not transition to `halted` when spend is exactly equal to the ceiling; enforcement shall remain `gated`. |
| **AC-A07** | The system shall allow zero-cost actions (e.g., `research(estimatedTokens: 0)`) in gated mode without requiring approval. |
| **AC-A08** | The system shall record every enforcement transition in the audit trail with prior spend, new spend, and the new enforcement level. |
| **AC-A09** | The system shall allow the Steward to increase the budget ceiling, with enforcement recalculated from the new ratio. |
| **AC-A10** | The system shall allow the Steward to reset the budget spend counter to zero, restoring `normal` enforcement. |
| **AC-A11** | The system shall record all Steward budget interventions in the audit trail with role identifier "STEWARD." |
| **AC-A12** | The system shall prevent any code path from setting an enforcement level less restrictive than what the current spend-to-ceiling ratio requires (enforcement reconciliation). |

---

### Use Case B: Destructive Action Control (Law 8 — Authority)

**Demo narrative:** An agent attempts to delete a file. The system suspends the action, notifies the operator, and waits. No deletion occurs without human authorization.

#### Trigger

The agent proposes an action classified as always-requiring-approval: `deleteFile`, `executeShellCommand`, or `sendEmail`.

#### Preconditions

- ClawLaw is running with default configuration
- The target file (`/workspace/old-report.txt`) is within the configured writable paths
- Enforcement level is `normal`
- Audit writer is operational

#### Main Flow

1. Agent proposes `deleteFile(path: "/workspace/old-report.txt")`.
2. The reducer evaluates the action:
   - **Phase 1 (enforcement gate):** Enforcement is `normal`. Not halted or gated. Passes.
   - **Phase 2 (action validation):** `deleteFile` is classified as `sensitive` and always returns `.requireApproval` with reason "File deletion requires human authorization."
3. The orchestrator records the suspension in the audit trail.
4. The orchestrator submits the action to the approval queue and returns a suspension response with an `approvalId`.
5. The agent receives a "suspended, awaiting approval" response. The file is untouched.
6. The operator runs `clawlaw status` and sees the pending action: action type, target path, reason for suspension, and time submitted.
7. The operator reviews and runs `clawlaw approve <approvalId>`.
8. The Steward retrieves the action from the approval queue and re-evaluates it through the reducer with the bypass flag set:
   - **Phase 1 (enforcement gate):** Skipped (bypass active).
   - **Phase 2 (action validation):** Action-type approval for `deleteFile` is skipped (bypass active). Boundary checks still run: path is within writable paths, path does not match protected patterns. Passes.
   - **Phase 3 (budget impact):** Token cost (50) is applied to the budget. If this triggers an enforcement transition, the transition is recorded.
9. The reducer returns `.allow` with the updated state.
10. The orchestrator records the approval and execution in the audit trail.
11. The action executes on the host. The file is deleted.

#### Alternate Flows

**B-ALT-1: Operator rejects the action.**
At step 7, the operator runs `clawlaw reject <approvalId> --reason "Keep that file"`. The action is permanently blocked for this request. The rejection, including the operator's reason, is recorded in the audit trail. The agent receives a rejection response.

**B-ALT-2: Shell command approval in gated mode.**
The agent proposes `executeShellCommand(command: "rm -rf /workspace/temp")` while enforcement is `gated`. The reducer hits two independent gates:
- Phase 1: Gated mode requires approval for all non-zero-cost actions (token cost 200 > 0).
- Phase 2: `executeShellCommand` always requires approval.
The action is suspended once (not twice). The operator approves once. On re-evaluation with bypass:
- Phase 1: Skipped.
- Phase 2: Action-type approval skipped. No boundary check applicable to shell commands.
- Phase 3: Token cost (200) applied.
Action executes.

**B-ALT-3: Approved action triggers halted state.**
The agent proposes `sendEmail(to: "team@company.com", subject: "Status", body: "...")` with spend at 49,900/50,000. The action is suspended (always-approve gate). Operator approves. On re-evaluation: budget impact adds 150, pushing spend to 50,050 (>100%). The reducer returns `.transition` to `halted`. The email action's budget impact is recorded, but the system is now halted. The email sends (the action was approved), but all subsequent actions are blocked until the Steward intervenes.

**B-ALT-4: Approved action targeting protected path.**
The agent proposes `deleteFile(path: "/workspace/.env.backup")`. The action is suspended by the always-approve gate. Operator approves. On re-evaluation with bypass: Phase 2 boundary check detects `.env` in the protected patterns set. The action returns `.requireApproval` for the protected-pattern gate — a separate gate from the action-type gate. The action re-enters the approval queue. The operator must approve the protected-pattern gate separately.

> **Note:** This two-gate behavior is the correct operational posture: approving a deletion does not automatically approve access to a protected resource. Each governance concern is evaluated independently.

#### Failure Flows

**B-FAIL-1: Approval queue lost on process restart.**
ClawLaw crashes while actions are pending in the approval queue. On restart, the queue is empty. The original suspension events exist in the audit trail. The agent must re-propose the actions. The operator must re-approve.

**B-FAIL-2: Audit write failure during suspension.**
The audit writer fails while recording the suspension event. In the demo configuration, the action is blocked and no suspension is recorded. The operator must resolve the audit writer issue before governance can resume.

#### Audit Entries

| Event | `action` | `effect` | `agentId` |
|---|---|---|---|
| Action suspended | `deleteFile(path: "/workspace/old-report.txt")` | `SUSPENDED: File deletion requires human authorization` | `OpenClaw` |
| Action approved | `deleteFile(path: "/workspace/old-report.txt")` | `APPROVED: Budget: 12300 → 12350` | `STEWARD` |
| Action rejected | `deleteFile(path: "/workspace/old-report.txt")` | `REJECTED: Keep that file` | `STEWARD` |

#### Acceptance Criteria

| ID | Criterion |
|---|---|
| **AC-B01** | The system shall require Steward approval for every `deleteFile` action, regardless of enforcement level. |
| **AC-B02** | The system shall require Steward approval for every `executeShellCommand` action, regardless of enforcement level. |
| **AC-B03** | The system shall require Steward approval for every `sendEmail` action, regardless of enforcement level. |
| **AC-B04** | The system shall not execute a suspended action on the host until the Steward explicitly approves it. |
| **AC-B05** | The system shall allow a Steward-approved action to execute without re-triggering the same action-type approval gate. |
| **AC-B06** | The system shall apply boundary checks (path allowlist, protected patterns) to approved actions during re-evaluation. |
| **AC-B07** | The system shall apply budget impact to approved actions during re-evaluation. |
| **AC-B08** | The system shall record the suspension, approval or rejection, and execution of every gated action in the audit trail. |
| **AC-B09** | The system shall allow the Steward to reject a suspended action with an optional reason, permanently blocking it. |
| **AC-B10** | The system shall treat each governance gate (action-type, protected-pattern, enforcement-level) as an independent concern requiring separate approval if triggered independently. |

---

### Use Case C: Protected Resource Handling (Law 0 — Boundary)

**Demo narrative:** An agent attempts to write to a sensitive path. The system blocks the attempt before any I/O occurs — whether the path is outside the workspace entirely, or matches a protected pattern within it.

#### Trigger

The agent proposes a file operation targeting a path that is either (a) outside the configured writable-path allowlist or (b) matching a configured protected pattern.

#### Preconditions

- ClawLaw is running with default configuration (writable paths: `~/workspace`; protected patterns: `.ssh`, `credentials`, `.env`, `keychain`)
- Enforcement level is `normal`
- Audit writer is operational

#### Main Flow (Scenario 1: Path Outside Allowlist)

1. Agent proposes `writeFile(path: "/etc/crontab", content: "...")`.
2. The reducer evaluates the action:
   - **Phase 1 (enforcement gate):** Normal mode. Passes.
   - **Phase 2 (action validation):** `isPathAllowed("/etc/crontab")` checks whether `/etc` has a prefix match in the writable paths set (`~/workspace`). It does not. Returns `.reject("Access denied: /etc/crontab is outside authorized workspace")`.
3. The action is rejected immediately. No I/O occurs. No file is written.
4. The rejection is recorded in the audit trail.
5. The agent receives a denial response.

#### Main Flow (Scenario 2: Protected Pattern Within Allowlist)

1. Agent proposes `writeFile(path: "/workspace/.env", content: "API_KEY=sk-...")`.
2. The reducer evaluates the action:
   - **Phase 1 (enforcement gate):** Normal mode. Passes.
   - **Phase 2 (action validation):** `isPathAllowed("/workspace/.env")` — path is within `~/workspace`. Passes. `isPathProtected("/workspace/.env")` — path contains `.env`, which matches the protected patterns set. Returns `.requireApproval(level: .sensitive, reason: "Modification of protected file pattern")`.
3. The action is suspended. The file is untouched.
4. The operator reviews via CLI and decides:
   - **Approve:** Action executes with budget impact (100 tokens for writeFile). The write occurs.
   - **Reject:** Action is permanently blocked. The file remains untouched.

#### Alternate Flows

**C-ALT-1: Path traversal attempt.**
Agent proposes `writeFile(path: "/workspace/../etc/passwd", content: "...")`. The path is lexically normalized to `/etc/passwd` before evaluation. `isPathAllowed("/etc/passwd")` returns false. The action is rejected. The traversal attempt is recorded in the audit trail.

**C-ALT-2: Agent targets governance configuration.**
Agent proposes `writeFile(path: "~/.clawlaw/config.yaml", content: "ceiling: 999999999")`. The path is not in the writable paths set (safe defaults exclude `~/.clawlaw/`). The action is rejected. Even if an operator were to add `~/.clawlaw/` to the writable paths, the configuration file path is hardcoded as a protected pattern — the action would require approval. Even if approved, the configuration loader verifies the writer's identity and rejects agent-authored changes.

**C-ALT-3: Multiple protected patterns match.**
Agent proposes `writeFile(path: "/workspace/.ssh/credentials", content: "...")`. The path matches both `.ssh` and `credentials` in the protected patterns set. The action triggers a single `.requireApproval` — the system does not queue separate approvals per pattern match. One approval covers the protected-pattern gate for this action.

**C-ALT-4: Delete operation on protected path.**
Agent proposes `deleteFile(path: "/workspace/.env.backup")`. Two independent gates fire:
1. `deleteFile` always requires approval (action-type gate, Phase 2).
2. `.env` matches a protected pattern (boundary gate, Phase 2).
The action is suspended. On approval with bypass: the action-type gate is skipped, but the boundary check still runs and detects the protected pattern. The action re-enters the approval queue for the protected-pattern gate.

#### Failure Flows

**C-FAIL-1: Path normalization fails on malformed input.**
Agent proposes a path with null bytes or invalid UTF-8. The path normalization function produces a sanitized or empty path. An empty or invalid path cannot match any writable-path prefix. The action is rejected. The reducer never crashes on malformed input.

**C-FAIL-2: Writable paths set is empty.**
The configuration specifies an empty writable paths set (e.g., operator deleted all entries). All file write and delete operations are rejected. This is the most restrictive possible configuration and is fail-closed by design.

#### Audit Entries

| Event | `action` | `effect` | `enforcement` |
|---|---|---|---|
| Path rejection | `writeFile(path: "/etc/crontab", ...)` | `REJECTED: Access denied — outside workspace` | `normal` |
| Protected pattern suspension | `writeFile(path: "/workspace/.env", ...)` | `SUSPENDED: Protected file pattern` | `normal` |
| Traversal rejection | `writeFile(path: "/workspace/../etc/passwd", ...)` | `REJECTED: Access denied — outside workspace` | `normal` |
| Config protection | `writeFile(path: "~/.clawlaw/config.yaml", ...)` | `REJECTED: Access denied — outside workspace` | `normal` |

#### Acceptance Criteria

| ID | Criterion |
|---|---|
| **AC-C01** | The system shall reject any agent file-write action targeting a path outside the configured writable-path allowlist. |
| **AC-C02** | The system shall reject any agent file-delete action targeting a path outside the configured writable-path allowlist. |
| **AC-C03** | The system shall require Steward approval for any agent file-write action targeting a path matching a configured protected pattern, even if the path is within the allowlist. |
| **AC-C04** | The system shall lexically normalize paths (resolving `.`, `..`, and redundant separators) before evaluating them against the allowlist. |
| **AC-C05** | The system shall reject path traversal attempts (e.g., `/workspace/../etc/passwd`) after normalization. |
| **AC-C06** | The system shall reject any agent action targeting the governance configuration file, regardless of allowlist membership. |
| **AC-C07** | The system shall not perform any I/O for a rejected action. The rejection shall occur before the action reaches the host filesystem. |
| **AC-C08** | The system shall record every boundary violation (rejection or protected-pattern suspension) in the audit trail. |

---

## 6. Threat Model and Abuse Cases

This threat model is scoped to governance-level threats — what can go wrong within the governed operational context. It does not cover OS-level attacks, kernel exploits, or hardware compromise.

| # | Threat | Attack Vector | Governance Control | Acceptance Criteria |
|---|---|---|---|---|
| T1 | **Budget exhaustion** | Agent runs expensive research tasks overnight without limit | Enforcement transitions at 80%/95%/100%+ thresholds; gated mode requires approval; halted mode blocks all actions | AC-A01 through AC-A06 |
| T2 | **Unauthorized file deletion** | Agent deletes files the operator did not intend to remove | `deleteFile` always requires approval regardless of enforcement level | AC-B01, AC-B04, AC-B05 |
| T3 | **Unauthorized shell execution** | Agent executes arbitrary shell commands | `executeShellCommand` always requires approval; classified at highest authorization level (systemMod) | AC-B02, AC-B04 |
| T4 | **Data exfiltration via email** | Agent sends sensitive data to external recipients | `sendEmail` always requires approval | AC-B03, AC-B04 |
| T5 | **Filesystem escape** | Agent writes outside workspace via absolute path | Path allowlist check rejects paths without matching prefix | AC-C01, AC-C07 |
| T6 | **Path traversal** | Agent uses `../` sequences to escape workspace | Lexical path normalization before allowlist comparison | AC-C04, AC-C05 |
| T7 | **Credential access** | Agent writes to `.ssh`, `.env`, or `credentials` paths | Protected pattern matching requires approval even within allowlist | AC-C03, AC-C06 |
| T8 | **Governance self-modification** | Agent modifies its own governance configuration to weaken controls | Config path hardcoded as protected; config loader rejects agent-authored changes | AC-C06 |
| T9 | **Stale enforcement bypass** | Deserialized or manually constructed state has incorrect enforcement level | Enforcement reconciliation: `max(provided, calculated)` on every state construction, initialization, and deserialization | AC-A12 |
| T10 | **Approval bypass via re-proposal** | Agent re-proposes a rejected action hoping for a different outcome | Reducer is deterministic: same state + same action = same decision | AC-B05, AC-C07 |
| T11 | **Unknown tool escalation** | OpenClaw adds a new tool type not mapped to a governance action | `unknown` action type classified at systemMod (highest authorization level); requires approval | AC-X01 |
| T12 | **Audit trail gap** | System operates without recording governance decisions | Demo configuration: audit write failure blocks all actions | AC-X02, AC-X03 |
| T13 | **Process restart enforcement loss** | System restarts with stale state file showing incorrect enforcement | Enforcement reconciliation on state load corrects enforcement to match spend ratio | AC-A12 |
| T14 | **Concurrent state corruption** | Simultaneous CLI and agent operations produce inconsistent state | Actor isolation serializes all state mutations through the orchestrator | AC-X04 |

---

## 7. Audit, Observability, and Evidence

### 7.1 Audit Trail Format

The audit trail is an append-only sequence of structured entries stored as JSONL (JSON Lines). Each line is a complete, self-contained JSON object.

**Storage:** `~/.clawlaw/audit/YYYY-MM-DD.jsonl` — daily rotation, one file per day.

**Permissions:** 0600 (readable only by owning user).

**Retention:** 90 days by default (configurable). Files older than the retention period are pruned by a daily cleanup check.

### 7.2 Audit Entry Fields

Every governance-significant event produces an entry with these fields:

| Field | Type | Description |
|---|---|---|
| `id` | UUID | Unique identifier for this entry |
| `timestamp` | ISO 8601 | When the event occurred |
| `action` | String | Description of the proposed action (e.g., `"deleteFile(path: /workspace/old.txt)"`) |
| `effect` | String | Governance decision and outcome (e.g., `"REJECTED: Access denied"`, `"Budget: 12300 → 12500"`) |
| `priorSpend` | Integer | Token spend before this event |
| `newSpend` | Integer | Token spend after this event |
| `enforcement` | String | Enforcement level at the time of the event (`normal`, `degraded`, `gated`, `halted`) |
| `agentId` | String | Identifier of the actor: agent ID (e.g., `"OpenClaw"`) or `"STEWARD"` for human interventions |

### 7.3 Example Entry

```jsonl
{"id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890","timestamp":"2026-03-05T14:23:01Z","action":"research(estimatedTokens: 500)","effect":"Budget: 39500 → 40000","priorSpend":39500,"newSpend":40000,"enforcement":"degraded","agentId":"OpenClaw"}
```

### 7.4 Governance Events That Produce Audit Entries

- Agent action allowed
- Agent action rejected (boundary violation, halted mode)
- Agent action suspended (awaiting approval)
- Agent action approved by Steward
- Agent action rejected by Steward
- Enforcement level transition (normal → degraded → gated → halted)
- Steward budget increase
- Steward budget reset

### 7.5 Audit Export

The CLI command `clawlaw audit --export json` produces a JSON array of all entries within the specified date range. This export is intended for compliance review (evaluator persona) and integration with external SIEM or reporting tools.

### 7.6 Observability

The CLI command `clawlaw status` provides a real-time snapshot:

- Current enforcement level
- Budget utilization (current spend / ceiling, percentage)
- Number of pending approvals
- Last state file write timestamp
- Today's audit entry count
- Configuration validation status

### 7.7 Demo Audit Posture

In the demo configuration, audit integrity is a hard dependency:

- **If the audit writer cannot write an entry, all governance actions are blocked.**
- The system will not allow, reject, or suspend actions if the governance decision cannot be recorded.
- The operator must resolve the audit issue (e.g., free disk space) and restart the governance process.

This is stricter than the production default (which logs a warning and continues governance). The rationale: a demo that claims governance-as-architecture must prove every decision was governed. An unrecorded decision is an ungoverned decision.

---

## 8. Failure Modes and Operational Recovery

ClawLaw follows a **fail-closed** posture: when the system cannot evaluate an action, the action is blocked. The system never allows an action it cannot govern.

### 8.1 Failure Mode Table

| Failure | Detection | Behavior (Demo Config) | Operator Recovery |
|---|---|---|---|
| **Reducer error** | Exception caught by orchestrator | Action rejected; error logged; next action proceeds normally | Automatic — no intervention needed |
| **State persistence failure** | `StateStore.save()` throws | Warning logged; governance continues with in-memory state | State recovers from last successful write on restart |
| **Audit write failure** | `AuditWriter.write()` throws | **All actions blocked** until audit is restored | Free disk space or resolve I/O issue; restart governance process |
| **OpenClaw adapter disconnection** | Adapter health check failure | All actions blocked (fail-closed) | Adapter reconnects automatically; pending actions must be re-proposed |
| **Configuration file missing** | Startup check | Default configuration written; governance starts with safe defaults | No intervention needed (first-run experience) |
| **Configuration file invalid** | Startup validation | System refuses to start; error message identifies the invalid field | Operator fixes the configuration file and restarts |
| **Configuration file permissions wrong** | Startup permission check | System warns and refuses to start if files are more permissive than 0600 | Operator fixes permissions (`chmod 600`) |
| **State file corrupt** | Deserialization failure | System starts from configuration defaults; warning logged | Audit trail preserves the record of prior operations |
| **Approval queue lost on crash** | Empty queue detected on restart | Prior SUSPENDED entries exist in audit trail | Agent re-proposes actions; operator re-approves |
| **Process crash during halted state** | State file loaded on restart | Enforcement reconciliation re-establishes `halted` | Operator must run `increaseBudget` or `resetBudget` |

### 8.2 Recovery Principles

1. **Governance state is recoverable.** The state file is written after every state change. If corrupt, the system starts from configuration defaults. The audit trail (separate files) is never lost when state is lost.

2. **Audit trail is durable.** Daily JSONL files are independent. A corruption in one file does not affect other days. The trail is append-only — a crash during write may lose the last partial entry but does not corrupt prior entries.

3. **Pending approvals are volatile.** The approval queue is in-memory only (v1.0). On crash, pending actions are lost. The operator can review the audit trail to see what was pending and the agent can re-propose. Persistence for the approval queue is planned for v1.1.

4. **Enforcement reconciliation is automatic.** On every startup, state load, and property assignment, the enforcement level is reconciled against the spend ratio. No manual intervention is required to correct stale enforcement.

---

## 9. Non-Goals and Roadmap Notes

### 9.1 Not in Scope for v1.0

| Item | Status | Notes |
|---|---|---|
| Graphical monitoring dashboard | Deferred to v2.0 | CLI and structured logs are sufficient for v1.0 |
| Multi-agent delegation chains | Deferred to v2.0 | Governance spec defines this; not implemented |
| Autonomy tier enforcement | Deferred to v2.0 | v1.0 uses budget-based and action-classification enforcement |
| Governance profile isolation | Deferred to v2.0 | v1.0 operates as a single governance context |
| Network egress enforcement (R3) | Conditional on OQ-4 | No macOS mechanism exists for user-space egress filtering without elevated privileges; v1.0 defines the action type and schema but defers enforcement |
| Non-macOS platforms | Deferred to v2.0 | Linux and Windows support planned |
| Skill signing and provenance | Deferred to v1.1 | v1.0 governs the actions skills execute, not the installation process |
| File-read governance | Tracked as OQ-10 | v1.0 governs writes and deletes; read governance requires a new action type |
| Persistent approval queue | Deferred to v1.1 | v1.0 queue is in-memory only; lost on crash |
| Real-time notifications | Tracked as OQ-6 | System notifications or messaging alerts for suspended actions |
| Cryptographic audit integrity | Tracked as OQ-9 | Hash-chain verification for tamper evidence; filesystem permissions used in v1.0 |
| Deterministic replay | Blocked by A1 | Requires Clock/IDGenerator injection to replace Date()/UUID() calls in reducer path; Phase 1 resolves this |

### 9.2 Known v0.1.0 Limitations Affecting Demo

| Limitation | Impact on Demo | Resolution |
|---|---|---|
| **R11 bug:** Approved high-risk actions re-trigger approval and cannot execute | Use Case B cannot complete the approval→execute flow | Phase 0 fix: `bypassGate` must skip Phase 2 action-type approval |
| **Non-deterministic audit entries:** `Date()` and `UUID()` called inside reducer | Replay verification (Use Case A audit review) produces different IDs and timestamps | Phase 1: Clock/IDGenerator injection |
| **No path normalization:** `isPathAllowed` uses `hasPrefix` string matching | Use Case C path traversal (C-ALT-1) is not defended | Phase 1: lexical normalization |
| **No persistence:** State and audit are in-memory only | Process restart loses all governance state | Phase 1: StateStore and AuditWriter |
| **No configuration system:** Defaults are hardcoded in test helpers | Operator cannot customize boundaries or budget | Phase 2: YAML configuration |

---

## 10. Acceptance Criteria Summary

### Use Case A — Budget Blowout Prevention (Law 4)

| ID | Criterion |
|---|---|
| AC-A01 | The system shall transition enforcement to `degraded` at >=80% utilization. |
| AC-A02 | The system shall transition enforcement to `gated` at >=95% utilization. |
| AC-A03 | The system shall transition enforcement to `halted` at >100% utilization. |
| AC-A04 | The system shall require approval for all non-zero-cost actions in `gated` mode. |
| AC-A05 | The system shall reject all actions in `halted` mode. |
| AC-A06 | The system shall remain `gated` (not `halted`) at exactly 100% utilization. |
| AC-A07 | The system shall allow zero-cost actions in `gated` mode without approval. |
| AC-A08 | The system shall record every enforcement transition in the audit trail. |
| AC-A09 | The system shall allow the Steward to increase the budget ceiling. |
| AC-A10 | The system shall allow the Steward to reset the budget spend counter. |
| AC-A11 | The system shall record all Steward interventions with "STEWARD" attribution. |
| AC-A12 | The system shall enforce enforcement reconciliation (no downgrade below calculated level). |

### Use Case B — Destructive Action Control (Law 8)

| ID | Criterion |
|---|---|
| AC-B01 | The system shall require approval for every `deleteFile` action. |
| AC-B02 | The system shall require approval for every `executeShellCommand` action. |
| AC-B03 | The system shall require approval for every `sendEmail` action. |
| AC-B04 | The system shall not execute a suspended action until the Steward approves it. |
| AC-B05 | The system shall allow approved actions to execute without re-triggering the same approval gate. |
| AC-B06 | The system shall apply boundary checks to approved actions on re-evaluation. |
| AC-B07 | The system shall apply budget impact to approved actions on re-evaluation. |
| AC-B08 | The system shall record suspension, approval/rejection, and execution in the audit trail. |
| AC-B09 | The system shall allow the Steward to reject suspended actions with an optional reason. |
| AC-B10 | The system shall treat each governance gate as an independent concern. |

### Use Case C — Protected Resource Handling (Law 0)

| ID | Criterion |
|---|---|
| AC-C01 | The system shall reject file-write actions outside the writable-path allowlist. |
| AC-C02 | The system shall reject file-delete actions outside the writable-path allowlist. |
| AC-C03 | The system shall require approval for writes to protected patterns within the allowlist. |
| AC-C04 | The system shall lexically normalize paths before allowlist evaluation. |
| AC-C05 | The system shall reject path traversal attempts after normalization. |
| AC-C06 | The system shall reject any agent action targeting the governance configuration. |
| AC-C07 | The system shall not perform I/O for rejected actions. |
| AC-C08 | The system shall record every boundary violation in the audit trail. |

### Cross-Cutting

| ID | Criterion |
|---|---|
| AC-X01 | The system shall classify unknown action types at the highest authorization level (systemMod) and require approval. |
| AC-X02 | The system shall block all actions when the audit writer is unavailable (demo configuration). |
| AC-X03 | The system shall write an audit entry for every governance decision (allow, reject, suspend, approve). |
| AC-X04 | The system shall serialize all state mutations through actor isolation, preventing concurrent corruption. |
| AC-X05 | The system shall fail closed: if governance evaluation encounters an error, the action shall be rejected. |
| AC-X06 | The system shall not start if the configuration file is invalid or has incorrect permissions. |
| AC-X07 | The system shall restore enforcement reconciliation on every process restart. |

---

## 11. Open Questions

| ID | Question | Impact | Status |
|---|---|---|---|
| OQ-A1 | What is the right default budget ceiling for a casual user? 50,000 tokens is a working assumption, not a validated choice. | If too low, legitimate use halts unexpectedly. If too high, budget governance is not demonstrated in the demo. | Requires user testing |
| OQ-A2 | Should enforcement transitions produce system-level notifications (macOS Notification Center) in addition to CLI status? | Affects whether the operator notices a transition if they are not watching the CLI. | Product decision pending |
| OQ-B1 | How should the agent experience a suspended action? Should the adapter return a "retry later" signal, a "pending" status, or block the connection? | Affects agent UX and whether the agent can do other work while an action is pending. | Depends on OpenClaw adapter design (DQ-1) |
| OQ-B2 | Should there be a timeout on pending approvals? What happens if the operator never reviews? | Actions could remain pending indefinitely, blocking agent progress. | Product decision pending |
| OQ-C1 | Should `readFile` actions be governed in v1.0? An agent reading `/workspace/.env` can exfiltrate its contents even if writes are blocked. | Credential protection (Use Case C) is incomplete without read governance. | Tracked as HRD OQ-10 |
| OQ-C2 | Should symlink resolution be added to path normalization? Lexical normalization does not follow symlinks — an agent could create a symlink from an allowed path to a protected target. | Depends on whether the agent can create symlinks (a write operation that would be governed) and whether symlink-following is a reducer concern or an integration/runtime concern. | Engineering investigation needed |
| OQ-X1 | What is the operational procedure when the audit writer fails in production (non-demo) mode? The PLD says "continue governance." How does the operator learn about the gap? | An audit gap during a compliance review is a finding. The operator needs to know it happened. | Needs alerting design |

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0 | 2026-02-19 | Initial draft |
