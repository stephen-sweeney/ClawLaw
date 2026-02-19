# ClawLaw High-Level Requirements Document

**Version:** 0.1.0
**Date:** February 18, 2026
**Author:** Product Management
**Status:** Draft
**Companion documents:** `docs/DOMAIN_NOTES.md`, `docs/GOVERNANCE_SPEC.md`, `docs/EXPERIMENTS.md`

---

## Background

### The Problem

OpenClaw is an open-source autonomous AI agent framework with 150,000+ GitHub stars that runs locally on a user's machine and connects to messaging platforms to execute real-world tasks: shell commands, browser automation, file management, email, and API calls. It operates with the full privileges of the user who launched it.

The agent's authority is governed by natural language prompts. This creates a fundamental mismatch: a non-deterministic system (an LLM) acting with deterministic privileges (filesystem, shell, network, API keys). The consequences are documented and ongoing:

- **30,000+ publicly exposed instances** with weak authentication, enabling remote code execution
- **12% of the ClawHub skill registry confirmed malicious** (341 of 2,857 skills)
- **Three disclosed CVEs** including CVSS 8.8 remote code execution
- **Infostealer campaigns** specifically targeting OpenClaw configuration and credentials
- **Enterprise bans** due to inability to govern agent behavior

The industry consensus (Singapore's Model AI Governance Framework, IBM, Palo Alto Networks, CrowdStrike) is that agent governance requires architectural enforcement. Nearly all existing frameworks remain at the policy-document level. No shipping product closes the gap between governance-as-policy and governance-as-architecture for desktop agent runtimes.

### The Opportunity

OpenClaw's creator joined OpenAI on February 14, 2026; the project is transitioning to an independent foundation with OpenAI sponsorship. This signals that personal agent runtimes are first-class platform infrastructure. The governance layer for these runtimes does not yet exist as a product.

### What ClawLaw Is

ClawLaw is a governance framework for desktop AI agents built on the SwiftVector architectural pattern. It enforces agent authority through deterministic state machines rather than prompts. The core mechanism is a **Reducer** — a pure function that evaluates every proposed agent action against the current governance state and returns a typed result (allow, reject, transition, or require approval). The agent cannot bypass, negotiate with, or prompt-inject around this evaluation.

ClawLaw v0.1.0-alpha exists as a working reference implementation with validated experiments for three governance Laws: Boundary (Law 0), Resource (Law 4), and Authority (Law 8).

### Baseline

The current baseline is OpenClaw's latest release (2026.2.x series) running on macOS. OpenClaw provides its own security audit CLI, VirusTotal integration for skills, secure-by-default configuration options, and a published threat model at trust.openclaw.ai. These are necessary but insufficient — they are configuration-dependent, not architecturally enforced.

---

## Goals

1. **G1 — Make ungoverned agent behavior structurally impossible.** Every agent action that touches the filesystem, network, shell, or external services must pass through a deterministic governance evaluation before execution, regardless of what the LLM outputs.

2. **G2 — Serve the full spectrum of users.** A seasoned engineer should be able to configure fine-grained governance policies. A non-technical user who is unaware of the risks should be protected by safe defaults without needing to understand the underlying architecture.

3. **G3 — Achieve adoption that attracts attention from OpenAI and the OpenClaw foundation.** ClawLaw should be the governance layer that OpenClaw users reach for, and that the OpenClaw project considers integrating or endorsing.

4. **G4 — Ship integration-ready governance before the ecosystem matures.** The window for establishing ClawLaw as the governance standard for OpenClaw is finite. The product must be usable with the current OpenClaw release, not a future hypothetical version.

5. **G5 — Demonstrate governance-as-architecture, not governance-as-policy.** ClawLaw's value proposition depends on the provable difference between prompt-based governance and state-machine governance. This must be demonstrable, not just claimed.

---

## Non-Goals

- **N1 — ClawLaw is not a general-purpose security product.** It does not replace antivirus, endpoint detection, network firewalls, or OS-level sandboxing. It governs agent behavior specifically.
- **N2 — ClawLaw does not aim to restrict OpenClaw's capabilities.** The goal is governed autonomy, not reduced functionality. Agents should remain powerful; their authority should be bounded.
- **N3 — ClawLaw does not replace OpenClaw's own security features.** VirusTotal scanning, the security audit CLI, and secure-by-default options are complementary. ClawLaw adds the architectural enforcement layer above them.
- **N4 — Multi-tenant or cloud-hosted governance is not in scope.** The initial product is a single-user, single-machine governance layer.
- **N5 — Building a competing agent framework is not in scope.** ClawLaw governs agents; it does not replace them.

---

## Personas & Use Cases

### Personas

**P1 — The Power User ("Alex")**
A software engineer or devops professional who runs OpenClaw for coding assistance, infrastructure automation, and multi-tool workflows. Alex understands the risks, has read the threat model, and wants granular control over what the agent can do. Alex expects configuration files, CLI tools, and programmatic APIs.

**P2 — The Casual User ("Jamie")**
A knowledge worker or creative professional who installed OpenClaw because it was on Hacker News and it seemed useful for managing email, scheduling, and research. Jamie does not know what prompt injection is, has not changed default configurations, and does not understand why running an agent with shell access is different from running a chat app. Jamie expects things to be safe by default.

**P3 — The Evaluator ("Morgan")**
An IT lead, security professional, or technical decision-maker assessing whether OpenClaw can be permitted in a team or organizational context. Morgan needs evidence that governance is enforceable (not just configured), auditable, and compliant with organizational security policies. Morgan expects audit logs, policy exports, and compliance reports.

### Use Cases

**UC-1: First-Run Safe Setup**
Jamie installs OpenClaw and ClawLaw together. Without any manual configuration, ClawLaw applies safe defaults: filesystem access is sandboxed to the user's workspace, shell commands require approval, outbound communication is gated, and a token budget prevents runaway costs. Jamie uses OpenClaw normally and is never aware of the governance layer unless an action is blocked or requires approval.

**UC-2: Budget Blowout Prevention**
Alex is running an overnight research task. At 80% of the configured token budget, ClawLaw issues a warning. At 95%, it enters gated mode — every new action requires Alex's approval. At 100%, it halts. Alex wakes up to a clear message and an audit trail showing exactly what happened, rather than a surprise API bill.

**UC-3: Skill Installation Governance** *(Future — v1.1+)*
Alex attempts to install a community skill from ClawHub. ClawLaw evaluates the skill's declared permissions (filesystem access, shell execution, network destinations) against the governance policy. If the skill requests capabilities above the current policy threshold, installation is blocked until Alex explicitly approves the elevated permissions, with the decision recorded in the audit trail.

> **Note:** Skill permission evaluation is out of scope for v1.0 (see Scope table — "Skill signing and provenance" deferred). v1.0 governs the *actions* skills execute, not the skill installation process itself. This use case is included to signal the product direction.

**UC-4: Credential Write Protection**
Jamie's OpenClaw attempts to write to a file in `~/.ssh/` or a file matching the pattern `credentials` or `.env`. ClawLaw's boundary enforcement immediately rejects the write if the path is outside the allowlist, or requires human approval if the path matches a protected pattern. The decision is logged.

> **Note:** v1.0 governs file *write* and *delete* operations. Read-access governance (preventing the agent from reading sensitive files) is not implemented in v1.0 and is tracked as OQ-10.

**UC-5: Enterprise Governance Audit**
Morgan requests a governance report for a compliance review. ClawLaw exports a structured audit trail showing: every action proposed by the agent, the governance decision for each (allowed, rejected, approved, suspended), the enforcement level at the time, and every human intervention. The report can be used to demonstrate that the agent operated within defined boundaries for the review period.

**UC-6: Incident Replay**
After a suspicious agent behavior, Alex replays the action log from the audit trail against the initial governance state. The replay produces identical enforcement decisions, proving that the governance was (or was not) correctly configured and that the behavior was (or was not) within policy.

**UC-7: Human Override and Recovery**
Alex's agent is halted after exceeding its token budget. Alex reviews the audit trail, determines the halt was expected, increases the budget ceiling, and resumes operations. The budget increase, the resume, and Alex's identity are recorded in the audit trail.

---

## Scope

### In Scope (v1.0)

| Area | Description |
|---|---|
| OpenClaw integration | Governance layer that intercepts and evaluates OpenClaw agent actions before execution |
| Boundary enforcement (Law 0) | Configurable filesystem allowlists and protected patterns. Network egress control (R3) is conditional on OQ-4 resolution; if no non-elevated-privilege mechanism exists on macOS, R3 defers to v1.1 |
| Budget enforcement (Law 4) | Token budget with deterministic enforcement transitions (normal → degraded → gated → halted) |
| Authority enforcement (Law 8) | Risk-tiered action classification with approval queue for high-risk operations |
| Audit trail | Append-only log of all governance-significant events with structured export |
| Safe defaults | Out-of-box governance configuration that protects casual users without manual setup |
| Human override | Steward interface for budget management, approval processing, and audit review |
| CLI tooling | Command-line interface for configuration, status, audit review, and governance management |
| Replay verification | Ability to replay an action log and verify governance decisions are deterministic |
| macOS support | Primary platform: macOS on Apple Silicon (M4 Pro) |

### Out of Scope (v1.0)

| Area | Rationale |
|---|---|
| Graphical monitoring dashboard | Deferred to v2.0; CLI and structured logs are sufficient for v1.0 |
| Multi-agent delegation chains | Governance spec defines this but implementation is deferred |
| Autonomy tier enforcement | Specified in governance spec; v1.0 uses budget-based and action-classification-based enforcement |
| Governance profile isolation | Specified in governance spec; v1.0 operates as a single governance context |
| Non-macOS platforms | Linux and Windows support deferred to v2.0 |
| Local model inference | Mac mini hardware supports it but governance of local models is deferred |
| Skill signing and provenance | Full supply-chain governance requires ecosystem cooperation; v1.0 provides permission-based gating |

---

## Requirements

### Boundary Enforcement (Law 0)

**R1 — The system shall reject any agent file-write action targeting a path outside the configured writable-path allowlist.**
*Rationale:* Containment is the most fundamental governance primitive. An agent with unrestricted filesystem access can exfiltrate data, modify system files, or persist malicious payloads.
*Acceptance:* An agent action proposing `writeFile(path: "/etc/passwd", ...)` when `/etc` is not in the allowlist is rejected before any I/O occurs. Paths are lexically normalized (resolving `.`, `..`, and redundant separators) before allowlist comparison. Symlink hardening is an integration/runtime policy concern, not a reducer responsibility. The rejection is recorded in the audit trail.

**R2 — The system shall require human approval for any agent file-write action targeting a file matching a configured protected pattern, even if the path is within the allowlist.**
*Rationale:* Sensitive files (`.ssh`, `credentials`, `.env`) require an additional gate beyond path-level containment because their compromise has outsized consequences. Protection is enforced at the governance-state level via a configurable pattern set, not hardcoded into action classification.
*Acceptance:* An agent action proposing `writeFile(path: "/workspace/.env", ...)` where `/workspace` is in the allowlist but `.env` is in the protected-patterns set triggers an approval requirement. The action is suspended until the human approves or rejects it.

**R3 — The system shall reject any agent action that would initiate outbound network connections to destinations not in the configured egress allowlist.**
*Rationale:* Data exfiltration and command-and-control communication require network access. Egress control limits the blast radius of a compromised agent.
*Acceptance:* An agent action that would contact a domain not in the egress allowlist is rejected. The rejection includes the attempted destination and is recorded in the audit trail.

> **Implementation gap:** No network egress control exists in the current v0.1.0 codebase. There is no network-related action type, no egress allowlist in governance state, and no enforcement mechanism. This requirement depends on OQ-4 (macOS egress control without elevated privileges). If OQ-4 cannot be resolved, R3 is deferred to v1.1. v1.0 will define the `networkRequest` action type and governance schema but will not enforce egress at the network level.

**R4 — The system shall ship with a default governance configuration file that restricts filesystem access to the user's workspace directory, protects `.ssh`, `credentials`, `.env`, and keychain-related paths, and sets a reasonable token budget ceiling.**
*Rationale:* Casual users (Persona P2) will not manually configure boundaries. Safe defaults must protect them from the most common attack surfaces documented in the domain notes.
*Acceptance:* A fresh installation with no user-created configuration applies the shipped default: writable paths include only `~/workspace` (or a platform-appropriate equivalent), protected patterns include `.ssh`, `credentials`, `.env`, and the budget ceiling is set to a reasonable default (see OQ-5). Any path not in the writable-paths set is denied. The default can be overridden by the user editing the configuration file.

> **Note:** The current codebase initializes `writablePaths` as an empty set, which blocks all writes. The shipped default configuration file must populate this set to meet this requirement. Network egress defaults depend on R3 resolution.

### Budget Enforcement (Law 4)

**R5 — The system shall track cumulative token spend for the agent and enforce deterministic enforcement level transitions at configurable thresholds.**
*Rationale:* Runaway API costs are one of the most common and immediate harms of ungoverned agents, as documented in the domain notes (Anthropic restricting subscribers routing heavy workloads).
*Acceptance:* Given a budget ceiling of 10,000 tokens and default thresholds (80% warning, 95% critical): spend reaching 8,000 (>=80%) transitions enforcement to `degraded`; spend reaching 9,500 (>=95%) transitions to `gated`; spend strictly exceeding 10,000 (>100%) transitions to `halted`. At exactly 100% (10,000/10,000), enforcement remains `gated`, not `halted`. Each transition is recorded in the audit trail.

**R6 — The system shall require human approval for all new agent actions with non-zero token cost when the enforcement level is `gated` (95-100% utilization).**
*Rationale:* Gated mode is the circuit breaker — the last chance for human judgment before the system halts. Zero-cost actions (e.g., read-only research with `estimatedTokens: 0`) pass through because they have no budget impact. High-risk action types (`deleteFile`, `executeShellCommand`, `sendEmail`) are independently gated by R10 regardless of cost.
*Acceptance:* When enforcement is `gated`, an action proposal with non-zero token cost triggers `requireApproval`. The action is suspended until the human approves or rejects.

**R7 — The system shall halt all agent execution when cumulative spend strictly exceeds the budget ceiling (>100%) and shall not resume without explicit human intervention.**
*Rationale:* Halted state is the hard stop. No automated recovery is permitted because the system's cost exposure has exceeded the human's configured threshold.
*Acceptance:* When enforcement is `halted`, all action proposals are rejected with a message indicating human reset is required. Only `increaseBudget` or `resetBudget` (Steward actions) can transition the system out of `halted`. Spend at exactly 100% remains `gated`, not `halted`.

**R8 — The system shall prevent any code path from setting an enforcement level less restrictive than what the current spend-to-ceiling ratio requires (enforcement reconciliation).**
*Rationale:* Without reconciliation, stale enforcement values from deserialization, initialization, or direct property assignment could bypass gated or halted mode. This was identified as a critical invariant in the validated experiments.
*Acceptance:* Given a spend of 9,500 out of 10,000 (95%), any attempt to set enforcement to `normal` or `degraded` results in enforcement remaining at `gated`. This holds regardless of how the governance state is constructed, initialized, or restored from storage.

### Authority Enforcement (Law 8)

**R9 — The system shall classify every agent action by authorization level and route actions above a configurable threshold to an approval queue.**
*Rationale:* Risk-tiered approval prevents high-consequence actions (file deletion, shell execution, outbound communication) from executing without human awareness.
*Acceptance:* Actions classified as `sensitive` or `systemMod` are routed to the approval queue. The human can approve (action executes) or reject (action is permanently blocked for that request). Both outcomes are recorded in the audit trail.

**R10 — The system shall always require human approval for agent actions that delete files, execute shell commands, or send outbound communications, regardless of enforcement level.**
*Rationale:* These three action categories have the highest blast radius. Even in `normal` enforcement, they should not execute without human awareness.
*Acceptance:* `deleteFile`, `executeShellCommand`, and `sendEmail` action types always trigger an approval requirement on first evaluation. Once a human has approved the action, it shall execute with budget impact applied (see R11).

**R11 — The system shall allow human-approved actions to execute with their budget impact and boundary checks applied, bypassing only the enforcement-level gate check and the action-type approval check that was already satisfied by the approval.**
*Rationale:* An approved action must still be evaluated for budget impact and boundary compliance, but it must not re-trigger the same approval requirement that the human already granted. The system skips the enforcement-level gate and the action-type approval gate, while applying all other governance checks.
*Acceptance:* A human-approved `deleteFile` action in gated mode executes: its token cost is applied to the budget, boundary checks are enforced, and the action does not re-enter the approval queue. If the token cost pushes spend above 100%, the system transitions to `halted` with the action's effects recorded in the audit trail.

> **Implementation gap:** The current v0.1.0 reducer re-triggers `requireApproval` for high-risk action types even on approved re-evaluation, preventing approved actions from executing. v1.0 must resolve this by allowing the approval bypass to skip both the enforcement-level gate check and the action-type validation gate for previously-approved actions.

### Audit & Observability

**R12 — The system shall produce an append-only audit trail recording every action proposed, the governance decision (allowed, rejected, transitioned, suspended), the enforcement level, and the role identifier of the actor (agent ID or "STEWARD" for human interventions).**
*Rationale:* Auditability is the foundation of governance. Without a complete trail, governance decisions cannot be reviewed, incidents cannot be investigated, and compliance cannot be demonstrated.
*Acceptance:* After any sequence of agent actions and human interventions, the audit trail contains one entry per event, each with: timestamp, action description, governance decision, prior and new spend, enforcement level, and actor role identifier.

**R13 — The system shall support deterministic replay: given an initial governance state and an action log, replaying the log shall produce identical governance decisions and identical final state.**
*Rationale:* Deterministic replay is the proof that governance is architectural, not probabilistic. It is also the mechanism for incident investigation (UC-6).
*Acceptance:* Given the same initial state and action sequence, two independent executions of the reducer produce byte-identical final states and identical decision sequences.

> **Blocked by A1:** This requirement cannot be validated until `Clock` and `IDGenerator` injection replaces the direct `Date()` and `UUID()` calls in the reducer's audit logging path. Resolution of A1 must be prioritized in the first development sprint (see RK-6).

**R14 — The system shall support structured export of the audit trail in a machine-readable format.**
*Rationale:* Persona P3 (the Evaluator) needs to import governance data into external compliance, SIEM, or reporting tools.
*Acceptance:* The audit trail can be exported as JSON. Each entry contains all fields from R12.

### OpenClaw Integration

**R15 — The system shall intercept OpenClaw agent actions at the tool-execution boundary and evaluate them against the governance state before the action is executed on the host.**
*Rationale:* Governance is only effective if it is evaluated before side effects occur. Post-hoc logging is observability, not governance.
*Acceptance:* An OpenClaw agent action that would be rejected by ClawLaw never reaches the host filesystem, shell, or network. The interception point is transparent to the agent (the agent receives a rejection or approval prompt, not a system error).

> **Assumption A2:** The most stable interception point in OpenClaw's architecture is yet to be determined. See Open Questions.

**R16 — The system shall be installable alongside the current OpenClaw release without requiring modification to OpenClaw's source code.**
*Rationale:* Adoption depends on ease of installation. Requiring a fork or patch of OpenClaw creates friction and divergence risk.
*Acceptance:* A user with an existing OpenClaw installation can add ClawLaw and have governance active within a defined setup process that does not modify OpenClaw's source tree.

> **Assumption A3:** OpenClaw's architecture provides a stable interception surface (e.g., HTTP middleware, tool-execution hook, or wrapper process) that does not require source modification. See Open Questions.

### Configuration & Defaults

**R17 — The system shall ship with a default governance configuration that protects users who perform no manual configuration.**
*Rationale:* Persona P2 (casual user) will not configure governance. Safe defaults are the difference between "protected by default" and "vulnerable by default."
*Acceptance:* A fresh installation with no user-created configuration file applies: workspace-scoped filesystem boundaries, protected patterns for sensitive files, a reasonable token budget ceiling, and approval requirements for high-risk actions.

**R18 — The system shall support user-defined governance configuration via a human-readable configuration file.**
*Rationale:* Persona P1 (power user) needs granular control over boundaries, budgets, thresholds, and approval policies.
*Acceptance:* A configuration file (format: YAML or JSON — see Open Questions) allows the user to specify: writable paths, protected patterns, budget ceiling, warning/critical thresholds, network egress allowlist (when R3 is active; commented-out in default config if R3 deferred), and per-action-type approval policy. The system validates the configuration at load time and rejects invalid configurations with clear error messages.

**R19 — The system shall prevent the governance configuration from being modified by the agent.**
*Rationale:* If the agent can modify its own governance, governance is meaningless. This is a hard boundary defined in the governance specification.
*Acceptance:* Any agent action that would write to, modify, or delete the governance configuration file is rejected by boundary enforcement, regardless of the action's authorization level or approval status.

### Human Override (Steward)

**R20 — The system shall provide a Steward interface that allows the human to: increase the budget ceiling, reset the budget, approve or reject pending actions, and review the audit trail.**
*Rationale:* Human-in-command authority is the foundational principle. The Steward interface is how the Principal exercises non-delegable rights.
*Acceptance:* Each Steward action (budget increase, reset, approve, reject) modifies governance state, is recorded in the audit trail with the human's identity, and takes effect immediately.

**R21 — The system shall provide a CLI for all Steward operations.**
*Rationale:* v1.0 does not include a graphical dashboard. The CLI is the primary Steward interface for all personas.
*Acceptance:* The CLI supports: `clawlaw status` (current enforcement, budget, pending approvals), `clawlaw approve <id>`, `clawlaw reject <id>`, `clawlaw budget increase <amount>`, `clawlaw budget reset`, `clawlaw audit [--export json]`, `clawlaw config validate`.

---

## Non-Functional Requirements

### Performance

**NFR-1 — Governance evaluation latency shall not exceed 10ms per action under normal operation.**
*Rationale:* Governance must be transparent to the user experience. OpenClaw tool execution (shell commands: ~100ms, browser automation: 1-3s) provides the latency budget. A 10ms governance overhead is imperceptible.
*Measurable target:* p99 latency < 10ms for `GovernanceReducer.reduce()` on Apple Silicon (M4 Pro).

**NFR-2 — The system shall support sustained action throughput of at least 10 actions per second with audit logging enabled.**
*Rationale:* A single OpenClaw agent executing tool calls at 100ms-3s per call produces a maximum of roughly 10 actions per second. Governance must not become the bottleneck even during the fastest tool-call sequences.
*Measurable target:* 10 actions/second sustained throughput with audit logging enabled, measured on M4 Pro.

### Reliability

**NFR-3 — The governance evaluation shall never crash, panic, or throw an unrecoverable error, regardless of input.**
*Rationale:* A governance crash is a governance bypass. The reducer must degrade to rejection (fail-closed), never to unhandled error (fail-open).
*Measurable target:* Zero unhandled exceptions in the reducer across the full fuzz-test input space.

**NFR-4 — The system shall fail closed: if the governance layer is unavailable or encounters an internal error, all agent actions shall be blocked until governance is restored.**
*Rationale:* Fail-open governance is not governance. A system that allows actions when it cannot evaluate them provides a false sense of security.
*Measurable target:* 100% of actions blocked during governance unavailability, validated by fault-injection test.

### Data Integrity

**NFR-5 — The audit trail shall be append-only.**
*Rationale:* An audit trail that can be modified after the fact provides no governance value for compliance or incident investigation.
*Measurable target:* No API, CLI command, or agent action can delete or modify existing audit entries. Whether tamper-evidence via hash chain is required for v1.0 is an open question (see OQ-9).

**NFR-6 — The audit trail shall be retained for a minimum of 90 days by default, configurable up to indefinite retention.**
*Rationale:* Enterprise compliance reviews (Persona P3) require historical data. 90 days covers most audit cycles.
*Measurable target:* Default retention of 90 days. Configuration option for custom retention period.

### Determinism

**NFR-7 — The governance reducer shall be a pure function: given identical inputs, it shall produce identical outputs in all executions.**
*Rationale:* Determinism is the core differentiator of governance-as-architecture vs. governance-as-policy. It enables replay (R13) and provable governance guarantees.
*Measurable target:* Determinism test (run reducer N times with same inputs, verify identical outputs) passes for all action types and enforcement levels. Zero non-deterministic dependencies in the reducer evaluation path.

> **Assumption A4:** Achieving NFR-7 requires injecting `Clock` and `IDGenerator` protocols to replace direct `Date()` and `UUID()` calls currently in the audit logging path within the reducer.

### Security

**NFR-8 — The governance layer shall not introduce new attack surface beyond what OpenClaw already exposes.**
*Rationale:* A governance product that creates new vulnerabilities undermines its own value proposition.
*Measurable target:* No new listening ports, no new network services, no new credential storage beyond what is required for governance configuration.

**NFR-9 — Governance configuration files shall be readable only by the owning user (file permissions 0600 or equivalent).**
*Rationale:* Governance configuration defines the agent's authority boundaries. If it is world-readable, an attacker can study the policy to find gaps.
*Measurable target:* Default file permissions are 0600. The system warns if permissions are more permissive.

### Portability

**NFR-10 — The core governance library (ClawLawCore) shall have no dependencies on UI frameworks, platform-specific APIs (beyond Foundation), or external services.**
*Rationale:* The governance engine must be embeddable in diverse contexts: CLI tools, server processes, test harnesses, and future GUI applications. SwiftVector invariants require that the core library remain a pure-logic layer.
*Measurable target:* `ClawLawCore` imports only `Foundation`. No imports of SwiftUI, UIKit, AppKit, or platform-specific frameworks.

---

## Success Metrics

| Metric | Target | Measurement Method |
|---|---|---|
| **Governance coverage** | 100% of OpenClaw tool-call action types are evaluated by ClawLaw before execution | Integration test suite with action-type coverage report |
| **Experiment validation** | All 5 budget governance experiments (EXPERIMENTS.md) plus boundary and authority test suites pass deterministically | Automated test suite (`swift test`) |
| **Safe-default protection** | A fresh install with no configuration blocks the top 5 attack vectors from the domain notes (exposed port, malicious skill execution (actions governed; installation governance deferred to v1.1), credential access, shell injection, runaway spend) | Manual test against attack-vector checklist |
| **Replay correctness** | 100% of replayed action logs produce identical final state | Replay verification test suite |
| **Adoption signal** | ClawLaw appears in OpenClaw community discussions, GitHub issues, or official documentation within 90 days of public release | Community monitoring |
| **Founder/OpenAI awareness** | Direct engagement (issue, PR comment, mention, or inquiry) from OpenClaw maintainers or OpenAI within 90 days | Community monitoring |
| **GitHub traction** | 500+ GitHub stars within 60 days of public release | GitHub metrics |
| **Install friction** | A user with an existing OpenClaw installation can add ClawLaw and have governance active in < 15 minutes | User testing |

---

## Assumptions

| ID | Assumption | Impact if Wrong |
|---|---|---|
| A1 | Deterministic replay (R13, NFR-7) requires replacing direct `Date()` and `UUID()` calls in the reducer's audit path with injected `Clock` and `IDGenerator` protocols. | Replay produces non-identical states; governance-as-architecture claim is undermined. Must be resolved before v1.0. |
| A2 | OpenClaw's architecture provides a stable interception surface for governance evaluation that does not require source modification. | If no stable surface exists, ClawLaw may need to operate as a process wrapper or proxy, increasing integration complexity. |
| A3 | OpenClaw's current release (2026.2.x) does not make breaking changes to its tool execution interface between now and ClawLaw v1.0 release. | Integration breaks and must be reworked. Mitigated by tracking OpenClaw releases and maintaining an adapter layer. |
| A4 | The Mac mini M4 Pro (64GB, 1TB) arriving in two weeks is sufficient hardware for running both OpenClaw and ClawLaw governance concurrently. | If resource-constrained, governance evaluation may need to be further optimized or OpenClaw workloads may need to be throttled. Low risk given hardware specs. |
| A5 | MIT license is compatible with ClawLaw's intended distribution model and does not create IP concerns with OpenClaw's license. | License conflict could block distribution or integration. Low risk — both are MIT. |
| A6 | Users who install ClawLaw are willing to accept a governance evaluation step before each agent action, provided latency is imperceptible (< 10ms). | If users perceive governance as slowing down the agent, adoption will suffer. Mitigated by NFR-1 performance target. |

---

## Open Questions

| ID | Question | Impact | Owner |
|---|---|---|---|
| OQ-1 | Which OpenClaw interception point is most stable for governance enforcement: the Gateway HTTP layer, the tool-execution layer, or a process wrapper? | Determines integration architecture (R15, R16) | Engineering |
| OQ-2 | What configuration file format should ClawLaw use: YAML, JSON, or a custom DSL? | Affects usability for P1 (power user) and tooling requirements | Product / Engineering |
| OQ-3 | ~~Should ClawLaw governance state be persisted to disk?~~ **Resolved: Yes.** R7 (halted state survives restart) and R12 (audit trail durability) require persistence. **Remaining question:** What format and write cadence should be used for state persistence? | Affects recovery after process restart, audit trail durability | Engineering |
| OQ-4 | How should network egress control (R3) be implemented on macOS without requiring elevated privileges or kernel extensions? | May constrain the implementation approach for Law 0 network boundaries | Engineering |
| OQ-5 | What is the appropriate default token budget ceiling for a casual user who has not configured a budget? | Must balance protection against runaway costs with not halting legitimate use | Product |
| OQ-6 | Should ClawLaw support real-time notification (e.g., system notification, Telegram message) when actions are suspended for approval? | Affects UX for approval workflow, especially for always-on deployments | Product |
| OQ-7 | How should ClawLaw handle OpenClaw's heartbeat/cron actions that execute without user prompts? | Autonomous actions may execute while the user is not present to approve; needs a policy decision | Product |
| OQ-8 | What is the migration path when SwiftVectorCore protocols are ready and ClawLaw types need to conform? | Affects API stability commitments and versioning strategy | Engineering |
| OQ-9 | Should the audit trail support cryptographic integrity verification (hash chain) in v1.0, or is filesystem-level protection sufficient? | Affects NFR-5 implementation complexity and compliance claims | Engineering / Product |
| OQ-10 | Should v1.0 govern file-read operations in addition to file-write and file-delete? | Affects credential protection scope (UC-4). Read governance would require a new `readFile` action type not currently in the codebase. | Product / Engineering |

---

## Risks & Dependencies

### Risks

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| RK-1 | OpenClaw changes its tool-execution interface in a breaking way before ClawLaw v1.0 ships | Medium | High — integration breaks | Implement an adapter layer between ClawLaw and OpenClaw; pin to a tested OpenClaw version |
| RK-2 | The interception surface required for R15 does not exist in OpenClaw without source modification | Medium | High — R16 cannot be met | Investigate process-wrapper and HTTP-proxy approaches as fallbacks during architecture phase |
| RK-3 | Governance evaluation latency exceeds 10ms when audit logging includes disk I/O | Low | Medium — user perceives slowdown | Async audit writes; in-memory buffer with periodic flush |
| RK-4 | Casual users (P2) find the approval workflow disruptive and disable governance | Medium | High — adoption failure | Tune safe defaults to minimize false-positive approvals; provide "silent audit" mode that logs but does not block low-risk actions |
| RK-5 | OpenClaw foundation establishes its own governance framework, making ClawLaw redundant | Low | Critical — market evaporates | Ship fast; demonstrate architectural governance before a policy-based alternative materializes |
| RK-6 | `Date()`/`UUID()` violations in the reducer are not resolved before v1.0, undermining the determinism claim | Low | High — core differentiator compromised | Prioritize Clock/IDGenerator injection in Week 1 of development sprint |

### Dependencies

| ID | Dependency | Status | Impact if Unavailable |
|---|---|---|---|
| D1 | Mac mini M4 Pro (64GB, 1TB) | Arriving ~March 4, 2026 | Development can proceed on existing hardware; integration testing with OpenClaw is blocked |
| D2 | OpenClaw 2026.2.x release | Available | Must track releases for breaking changes |
| D3 | SwiftVectorCore protocols | In development (v0.1.0 tagged) | ClawLaw can operate standalone; conformance migration is planned for v0.2.0 |
| D4 | API keys for LLM providers (Anthropic, OpenAI, etc.) | Not yet provisioned | Required for integration testing with live OpenClaw; mock testing can proceed without them |

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0 | 2026-02-18 | Initial draft |
