# ClawLaw Domain Notes

**Version:** 0.1.0
**Date:** February 18, 2026
**Purpose:** Ground any developer, architect, or AI agent in the problem space, technical landscape, and conceptual foundations that ClawLaw addresses. This is a reference document, not an essay.

---

## 1. The Problem: Autonomous Agents Without Governance

### 1.1 What Changed

In late 2025, desktop AI agents crossed from research curiosity to production reality. Tools like OpenClaw demonstrated that a single Node.js process, running locally, could connect to a user's messaging apps, execute shell commands, control a browser, manage files, send emails, and maintain persistent memory across sessions. Within weeks of going viral in January 2026, OpenClaw accumulated over 150,000 GitHub stars and a contributor base of 685+ developers.

These agents are not chatbots. They are **runtime environments with execution authority**: persistent processes that can take real-world actions on a user's machine, in their accounts, and across their network — continuously, autonomously, and with the full privileges of the user who launched them.

### 1.2 Why This Is a Governance Problem

The agent's authority is typically defined in natural language — system prompts, persona files, and user instructions. This creates a fundamental mismatch: **a non-deterministic system (an LLM) acting with deterministic privileges (filesystem, shell, network, API keys)**. Prompt injection, confused context, edge cases, or adversarial inputs can produce completions that ignore, reinterpret, or override the governance intent.

This is the core architectural tension ClawLaw exists to resolve.

### 1.3 The Stochastic Gap

The **Stochastic Gap** is the distance between human intent and probabilistic model output. In a simple chat interface, the consequences of a bad completion are limited to a wrong answer. In an agent with shell access and API keys, the consequences include data deletion, credential exfiltration, unauthorized transactions, and lateral movement through connected systems.

Prompt-based governance cannot close the Stochastic Gap because prompts are made of the same probabilistic material as the problem. The industry consensus (as articulated by Singapore's Model AI Governance Framework, IBM, Palo Alto Networks, and others) is that agent governance requires architectural enforcement, not policy documents. ClawLaw is an implementation of that enforcement.

---

## 2. OpenClaw: The Reference Agent Runtime

ClawLaw's initial governance target is OpenClaw. Understanding its architecture is essential for understanding what ClawLaw must govern.

### 2.1 What OpenClaw Is

OpenClaw is an open-source, locally-hosted autonomous AI agent framework. Originally created by Peter Steinberger as "Clawdbot" (November 2025), it was renamed to "Moltbot" (January 27, 2026) following Anthropic trademark concerns, then to "OpenClaw" (January 30, 2026). On February 14, 2026, Steinberger announced he was joining OpenAI, with OpenClaw transitioning to an independent open-source foundation under OpenAI sponsorship.

### 2.2 Architecture

OpenClaw's architecture centers on a **Gateway** — a single long-lived Node.js process (default port 18789) that handles:

- **Channel multiplexing**: WhatsApp, Telegram, Slack, Discord, Signal, iMessage (via BlueBubbles), Microsoft Teams, Google Chat, Matrix, and web/CLI interfaces
- **Session and memory management**: Per-sender or per-workspace isolation; memory persisted as local Markdown files (AGENTS.md, SOUL.md, etc.)
- **LLM integration**: Model-agnostic — supports Claude, GPT, DeepSeek, local models, and others
- **Tool execution**: Direct host access (shell, browser automation, filesystem) or optional Docker sandboxing
- **Autonomy layer**: Heartbeat scheduler, cron jobs, webhooks, and proactive reminders — the agent can wake itself and act without user prompts

### 2.3 Skills System

OpenClaw's extensibility comes from **skills** — plugins defined as Markdown files with JSON manifests that declare capabilities, permissions, and tool invocations. Skills are discoverable and installable via **ClawHub**, a public marketplace. The runtime selectively injects relevant skills per conversation turn rather than loading all skills into every prompt.

Skills are both the primary adoption driver and the primary attack surface (see Security Landscape below).

### 2.4 Usage Patterns

Observed deployment patterns relevant to ClawLaw's governance model:

| Pattern | Description | Governance Implication |
|---|---|---|
| Personal automation | Inbox triage, calendar management, reminders, errands | Budget and containment controls |
| Multi-tool workflows | Chaining web search, documents, scripts, cloud consoles | Action-level approval gates |
| Always-on hosting | VPS/container deployment, reachable via messaging | Exposure detection, secure defaults |
| Agent operations | Dashboards for managing agents, approvals, jobs, tokens | Audit trail, observability |
| Skill marketplaces | Installing community skills from ClawHub | Supply-chain governance |

### 2.5 Strategic Significance

OpenAI's involvement signals that personal agent runtimes are becoming first-class platform infrastructure, not niche hobby projects. The acquisition validates the architecture (local-first, model-agnostic, skill-extensible) while simultaneously accelerating demand for governance layers that make these runtimes deployable in regulated or enterprise contexts.

Enterprise reactions are already polarized: some organizations have moved to ban or restrict OpenClaw due to security concerns, creating an explicit market opening for a governance layer that makes agent use acceptable.

---

## 3. Security Landscape

OpenClaw's power is its primary risk vector. The security landscape is not theoretical — real-world attacks have been documented and are ongoing.

### 3.1 Known Attack Surfaces

**Exposed infrastructure.** Censys tracked growth from ~1,000 to over 21,000 publicly exposed OpenClaw instances in a single week (January 25–31, 2026). Bitsight observed 30,000+ across a broader window. Default configurations bind to all interfaces with weak authentication, enabling remote code execution and token theft.

**Supply-chain poisoning.** Researchers confirmed 341 malicious skills out of 2,857 on ClawHub — roughly 12% of the entire registry. Attacks included crypto-stealers, data exfiltration payloads, and social-engineering instructions embedded in skill definitions. A Cisco research team demonstrated a top-ranked skill silently exfiltrating data and injecting payloads.

**Prompt injection as tool-chain compromise.** In agent systems, prompt injection doesn't just produce wrong text — it can induce malicious sequences of tool calls (download, execute, exfiltrate, move laterally). The agent's tool access transforms a prompt-level attack into a system-level compromise.

**Credential and configuration theft.** Infostealer malware variants (e.g., Vidar) specifically target `openclaw.json`, gateway tokens, and `soul.md` files. These contain API keys, integration credentials, and the agent's persistent identity/memory.

**Persistent autonomy risks.** The heartbeat scheduler and self-modification capabilities mean a compromised agent can maintain a persistent foothold, executing rogue behaviors over extended periods with minimal visibility.

### 3.2 Critical Vulnerabilities (Disclosed)

| CVE | Type | Severity | Description |
|---|---|---|---|
| CVE-2026-25253 | CWE-669 (Incorrect Resource Transfer) | CVSS 8.8 | Remote code execution; patched in v2026.1.29 |
| CVE-2026-24763 | Command injection | High | Arbitrary command execution via unsanitized input |
| CVE-2026-25157 | Command injection | High | Second injection vector in gateway input handling |

*CVE details sourced from security research as of February 2026. Verify against NVD/MITRE for current status.*

### 3.3 OpenClaw's Own Security Response

OpenClaw maintainers have responded with VirusTotal integration for skill scanning (announced February 7, 2026), a security audit CLI command, secure-by-default configuration options, and a published threat model (trust.openclaw.ai) covering six risk categories: input manipulation, auth/access, data security, infrastructure, operations, and supply chain.

These are necessary but insufficient. The fundamental model — user-managed, high-privilege local execution with an open skill marketplace — means security remains configuration-dependent. ClawLaw's thesis is that governance must be architectural, not optional.

---

## 4. The Governance Gap

### 4.1 Industry Consensus Without Implementation

Every major consultancy, standards body, and technology company agrees on what agent governance requires:

- Bounded autonomy with tiered permissions
- Human oversight at decision points
- Auditable action trails
- Real-time monitoring and intervention
- Risk-tiered approval workflows

Singapore's Model AI Governance Framework for Agentic AI (January 22, 2026) — the world's first dedicated governance model for agentic AI — formalized these requirements across four dimensions: risk assessment and bounding, meaningful human accountability, technical controls and processes, and end-user responsibility.

Nearly all of these remain at the policy-document level. The gap is between **governance-as-policy** (guidelines, frameworks, checklists) and **governance-as-architecture** (deterministic constraints enforced at the system level).

### 4.2 Governance-as-Policy vs. Governance-as-Architecture

| Dimension | Policy Approach | Architecture Approach |
|---|---|---|
| Authority source | Natural language rules | Typed state machine |
| Enforcement mechanism | Agent interpretation | Reducer evaluation |
| Failure mode | Agent ignores or misinterprets rule | Action structurally impossible |
| Auditability | Best-effort logging | Deterministic replay |
| Adaptability | Edit the document | State transition via authorized action |

ClawLaw's core thesis: **governance that depends on the agent correctly interpreting and following rules will fail under adversarial conditions, edge cases, or simple confusion. Governance must be enforced at the architectural level, before the agent's reasoning is invoked.**

---

## 5. SwiftVector: The Constitutional Framework

### 5.1 What SwiftVector Is

SwiftVector is a general-purpose framework for deterministic AI agent control, built in Swift. It provides the architectural primitives — state machines, reducers, audit infrastructure, and actor-isolated execution — that governance layers are built on.

The relationship: **SwiftVector is the kernel; ClawLaw is the policy layer.** SwiftVector defines how governance is enforced (mechanism); ClawLaw defines what is enforced (policy). This separation is analogous to an OS kernel vs. a security framework.

### 5.2 The SwiftVector Codex

The SwiftVector Codex defines eleven composable **Laws** organized into four groups:

| Group | Laws | Domain |
|---|---|---|
| **Foundational** | Law 0 (Boundary), Law 1 (Context), Law 2 (Delegation), Law 3 (Observation) | What the agent can touch, know, delegate, and what is recorded |
| **Sustainability** | Law 4 (Resource), Law 5 (Sovereignty) | What the agent can spend; what it cannot self-modify |
| **World State** | Law 6 (Persistence), Law 7 (Spatial Safety) | How state is preserved; physical/spatial constraints |
| **Operational** | Law 8 (Authority), Law 9 (Lifecycle), Law 10 (Protocol) | Who decides; how agents are created/destroyed; communication rules |

ClawLaw v0.1.0 implements three of these Laws: **Law 0 (Boundary)**, **Law 4 (Resource)**, and **Law 8 (Authority)**.

### 5.3 The Core Pattern

The SwiftVector control loop:

```
State → Agent Proposes Action → Reducer Evaluates → Effect → New State
```

**State** is modeled as Swift value types (structs with `Equatable` conformance). The reducer operates on copies, preventing shared mutation. `BudgetState` and `AuditEntry` conform to `Codable`. The target architecture calls for `let` properties with `.with()` builder methods and full `Sendable` conformance; the current v0.1.0 implementation uses `var` properties for development ergonomics.

**Agents** observe state (read-only) and generate proposals (typed actions). They never mutate state directly.

**The Reducer** is a pure function: `(State, Action) → ActionEffect`. The `ActionEffect` type has four cases:
- `.allow(newState)` — action permitted, state updated
- `.reject(reason)` — action denied with explanation
- `.transition(newState, message:)` — action triggered an enforcement level change (e.g., entering gated or halted mode)
- `.requireApproval(level:, reason:)` — action requires human authorization before execution

The reducer accepts an optional `bypassGate` parameter, used by the Steward when executing previously-approved actions that would otherwise be blocked by gated-mode checks.

The target invariant is full determinism: no side effects, no I/O, no `Date()`, no `UUID()`, no randomness. The current v0.1.0 implementation has known violations — `AuditEntry` defaults use `Date()` and `UUID()` directly within the reducer's logging path. Production hardening will inject `Clock` and `IDGenerator` protocols per SwiftVector invariant requirements.

**Effects** execute post-transition (logging, notifications, external calls). They are outside the reducer.

This pattern makes governance **deterministic and replayable**: replaying the same action log against the same initial state must produce identical final state. Full replay correctness depends on resolving the `Date()`/`UUID()` violations noted above.

---

## 6. ClawLaw: The Governance Jurisdiction

### 6.1 What ClawLaw Is

ClawLaw is a governance **jurisdiction** — a domain-specific application of SwiftVector's constitutional framework to the desktop agent domain, initially targeting OpenClaw. It defines the specific laws, boundaries, budget thresholds, and approval workflows that govern an agent's authority on a user's machine.

The name references *Claw Law* (1982) — a supplement for the Rolemaster tabletop RPG system that codified combat mechanics for creatures with natural weapons. The book didn't make monsters weaker; it made them playable. ClawLaw doesn't restrict agents; it makes them governable.

### 6.2 Three Laws Implemented (v0.1.0)

**Law 0 — The Boundary Law (Containment)**
Defines what the agent can touch. Filesystem paths are validated against an explicit allowlist (`writablePaths`). Protected pattern enforcement operates at two levels: (1) action-level classification in `AgentAction.authorizationLevel` hardcodes `.ssh` and `credentials` as sensitive, and (2) state-level pattern matching via `GovernanceState.isPathProtected()` checks a configurable set (default: `.ssh`, `credentials`, `.env`). Network boundaries (planned) will specify reachable domains and ports.

**Law 4 — The Resource Law (Budget)**
Defines what the agent can spend. Token consumption triggers deterministic enforcement level transitions:

| Utilization | Enforcement Level | Behavior |
|---|---|---|
| 0–80% | Normal | Full capability |
| 80–95% | Degraded | Warnings issued, continues |
| 95–100% | Gated | All actions require human approval |
| >100% | Halted | System suspended, human reset required |

The budget system includes **enforcement reconciliation** — a mechanism that prevents any code path (property assignment, initialization, deserialization) from setting an enforcement level less restrictive than what the current spend requires. This is implemented via computed property setters that use `max(provided, calculated)`.

**Law 8 — The Authority Law (Approval)**
Defines what requires human approval. Actions are classified by authorization level (readOnly → sandboxWrite → externalNetwork → sensitive → systemMod). The `externalNetwork` level is defined but currently unused in action classification. High-risk operations (file deletion, shell execution, outbound communication) enter an approval queue. The agent waits; the human decides. When the Steward approves a queued action, the reducer is re-invoked with the `bypassGate` flag, which skips enforcement-level gate checks while still applying the action's budget impact and validation logic. Unapproved execution is structurally impossible.

### 6.3 The Autonomy Tier Model

ClawLaw defines four tiers of agent autonomy, each representing a governance posture:

| Tier | Name | May Do | May Not Do | Use Case |
|---|---|---|---|---|
| 1 | Observe & Report | Read, analyze, surface findings | Create, modify, delete, invoke tools | Initial onboarding, situational awareness |
| 2 | Propose | Draft plans, write code, submit PRs | Merge, deploy, publish | Public repos, safety-critical work |
| 3 | Execute Within Bounds | Self-merge within scope, iterate independently | Exceed defined boundaries, add dependencies | Private tooling, internal utilities |
| 4 | Autonomous Production | Create and finalize artifacts independently | Publish without human authorization | Content pipeline, marketing |

Tier escalation requires explicit human authorization recorded as an auditable state change. Agents can voluntarily de-escalate. No tier transition can occur implicitly.

> **Implementation status:** The autonomy tier model is specified in the governance specification (`docs/GOVERNANCE_SPEC.md`) and is not yet implemented in code. Current v0.1.0 enforcement is budget-based (Law 4) and action-classification-based (Law 8). Tier enforcement is planned for v0.2.0+.

### 6.4 Governance Profiles

Profiles bind a specific autonomy tier and operational constraints to a domain of work. A single agent instance may operate under multiple profiles simultaneously, with ClawLaw enforcing isolation between them:

- **Public Open Source** (Tier 2): SwiftVector, ClawLaw repos — every change reviewed
- **Private Tooling** (Tier 3): Internal utilities — self-merge within bounds
- **Content Pipeline** (Tier 4): Social media, blog — autonomous production, publication gated
- **Research & Analysis** (Tier 1, escalable to 2): Technical research — findings delivered as recommendations

> **Implementation status:** Governance profiles are specified but not yet implemented in code. The current v0.1.0 implementation operates with a single governance context. Profile isolation is planned for v0.2.0+.

### 6.5 The Authority Model

The human operator (Principal) retains non-delegable rights: merge authority, publication authority, priority authority, tier escalation, and shutdown. Authority may be delegated through a chain (Principal → OpenClaw → subordinate agents), but no agent may grant permissions exceeding its own. Authority is inherited downward with restriction, never amplification.

### 6.6 Key Architectural Components (Current Implementation)

| Component | File | Role |
|---|---|---|
| `GovernanceState` | `Governance.swift` | Single source of truth: budget, paths, protections, audit log |
| `BudgetState` | `Governance.swift` | Token budget with enforcement reconciliation |
| `GovernanceReducer` | `GovernanceReducer.swift` | Pure function: `(State, Action) → Effect` |
| `GovernanceOrchestrator` | `Orchestrator.swift` | Actor-isolated control loop |
| `Steward` | `Steward.swift` | Actor managing human authority and interventions |
| `ApprovalQueue` | `ApprovalQueue.swift` | Actor-isolated queue for gated actions |

---

## 7. Key Concepts and Glossary

**ActionEffect** — The return type of the reducer. Four cases: `.allow` (action permitted), `.reject` (action denied), `.transition` (enforcement level changed), `.requireApproval` (human authorization needed).

**Agent** — An autonomous software process that observes state, reasons about it, and proposes actions. In the SwiftVector model, agents propose but never mutate state directly.

**Approval Flow** — The canonical governance sequence for actions requiring human authorization: propose → suspend (action enters approval queue) → human reviews → approve or reject → execute (with budget impact and boundary checks) or block. Defined by HRD R10/R11. The approval flow is the mechanism by which Law 8 (Authority) is exercised.

**Approval Queue** — An actor-isolated queue where high-risk actions wait for human authorization before execution.

**Authorization Level** — A five-tier classification of action risk: readOnly, sandboxWrite, externalNetwork, sensitive, systemMod. Higher levels require more scrutiny and human approval.

**Audit Trail** — An append-only log of all governance-significant events: actions proposed, effects applied, enforcement transitions, human interventions. Must support deterministic replay.

**Codex** — The SwiftVector Codex: the constitutional document defining the eleven Laws that govern agent behavior across domains.

**Enforcement Level** — The current operational posture of the budget system (normal, degraded, gated, halted). Transitions are deterministic based on spend-to-ceiling ratio.

**Enforcement Reconciliation** — The mechanism ensuring enforcement levels cannot be downgraded below what budget utilization requires, regardless of how state is constructed or modified.

**Governance Gate** — A point in any workflow where human judgment is required before work proceeds. Everything between gates is agent execution; gates are non-negotiable human decision points.

**Governance Profile** — A binding of autonomy tier and operational constraints to a specific domain of work.

**Interception Boundary** — The abstract interface (`OpenClawAdapter` protocol) through which OpenClaw tool calls enter ClawLaw governance evaluation. The interception boundary is transport-agnostic: whether ClawLaw intercepts via HTTP proxy, process wrapper, or another mechanism, the adapter contract is identical. Operational use cases and test plans should reference this abstraction, not a specific transport.

**Jurisdiction** — A domain-specific application of SwiftVector's framework. ClawLaw is the desktop agent jurisdiction; FlightLaw (drones) and ChronicleLaw (narrative) are other jurisdictions applying the same constitutional pattern.

**Law** — A composable governance module in the SwiftVector Codex. Each Law addresses a specific dimension of agent authority (boundaries, resources, observation, delegation, etc.).

**Principal** — The human operator who holds ultimate authority over all agent operations. Non-delegable rights include merge, publication, priority, tier escalation, and shutdown.

**Reducer** — A pure function that takes current state and a proposed action, returns an `ActionEffect`. Deterministic, side-effect-free, non-negotiable. The heart of governance enforcement.

**Steward** — Has two related meanings: (1) the `Steward` actor in ClawLawCore that manages governance state, the approval queue, budget interventions, and audit access; and (2) the human role exercising Principal authority through the CLI (`clawlaw approve`, `clawlaw budget`, etc.). Context disambiguates: "the Steward actor" refers to the software component; "the Steward" in workflow descriptions refers to the human operator.

**Stochastic Gap** — The distance between human intent and probabilistic model output. The fundamental reason prompt-based governance fails for agents with execution authority.

**SwiftVector** — The general-purpose framework for deterministic AI agent control. Provides the kernel (state machines, reducers, audit, actors) on which jurisdictions like ClawLaw are built.

---

## 8. Evaluation of Preliminary Domain Notes

Two preliminary domain note documents were generated by other AI models (Grok, OpenAI) as research inputs. This section evaluates their contributions and limitations.

### 8.1 Grok Domain Notes — Evaluation

**Strengths:**
- Strong factual timeline with specific dates, names, and events (Clawdbot → Moltbot → OpenClaw naming history, Steinberger's move to OpenAI)
- Excellent security risk table mapping risk categories to specific vectors, real-world examples, and potential ClawLaw controls
- Good enumeration of specific technical details: port 18789, Node.js gateway, ClawHub, VirusTotal integration
- Useful coverage of the OpenAI acquisition's strategic significance

**Weaknesses:**
- Framed primarily as a product/market opportunity document rather than a technical domain reference
- Lacks explanation of the SwiftVector architectural pattern, the reducer model, or how ClawLaw actually implements governance
- Security section is comprehensive on threats but does not connect to the architectural response (how deterministic state machines address each risk)
- Contains no glossary or conceptual framework — a developer would understand the threats but not the solution approach
- Over-focuses on ClawLaw's commercial opportunity at the expense of technical grounding
- Some statistics (200,000+ GitHub stars, 685 contributors, 12,500+ commits) appear inflated relative to other sources; other sources report 150,000+ stars

**Material incorporated:** Timeline facts, security risk categorization, specific CVE and exposure data (cross-verified against independent research), strategic significance framing.

**Material discarded:** Commercial opportunity framing (belongs in PRD, not domain notes), inflated statistics where contradicted by other sources, product management recommendations (out of scope for domain notes).

### 8.2 OpenAI Domain Notes — Evaluation

**Strengths:**
- Excellent structural organization: 11 numbered sections with clear PM-oriented framing
- Strong conceptual clarity on what OpenClaw is (Section 1) — the distinction between "model UI" and "runtime that can execute" is precisely the right framing
- Security risks section (Section 4) organized by control theme, which maps naturally to governance architecture
- Concrete use cases with acceptance criteria (Section 7) — useful for future PRD work
- Good treatment of open questions (Section 11) that reflect genuine engineering uncertainties
- Correctly identifies the core tension: governance must not kill the "it just works" experience that drove adoption

**Weaknesses:**
- Almost entirely forward-looking (what ClawLaw *should* build) rather than grounding in what exists. Contains no reference to the actual codebase, the reducer pattern, the enforcement reconciliation mechanism, or the five validated experiments
- Proposed "Law Sets" (Identity & Authority, Capabilities & Least Privilege, etc.) do not align with the existing SwiftVector Codex numbering or structure. This creates a parallel taxonomy that would confuse developers
- No mention of SwiftVector, the Codex, or the deterministic state machine architecture — the core technical foundation is absent
- "Metrics that matter" section (Section 9) is premature for a domain notes document
- The document reads as a PM brief for a product that doesn't exist yet, rather than domain grounding for a product that does

**Material incorporated:** Structural organization approach, the "runtime that can execute" framing, security risk categorization by control theme, open questions (adapted), use-case patterns.

**Material discarded:** Alternative Law numbering (conflicts with Codex), metrics section (belongs in PRD), acceptance criteria (belongs in PRD), competitive positioning (belongs in PRD), proposed capability set (would need to be reconciled with Codex before inclusion).

### 8.3 Summary Assessment

| Dimension | Grok | OpenAI |
|---|---|---|
| Factual accuracy | High (specific dates, CVEs, numbers) | High (concepts, architecture) |
| Technical depth | Moderate (threats yes, architecture no) | Low (no codebase grounding) |
| Structural clarity | Low (essay-like, loosely organized) | High (numbered sections, clear headings) |
| Domain grounding | Good (OpenClaw specifics) | Good (conceptual framing) |
| ClawLaw awareness | Surface (mentions governance overlay) | None (proposes alternative framework) |
| Usefulness for developers | Moderate (need to extract from narrative) | Low (would mislead on architecture) |

Neither document is sufficient on its own. Grok provides the facts; OpenAI provides the structure. Neither connects to the existing codebase or the SwiftVector constitutional framework. This document synthesizes both while grounding everything in the actual implementation.

---

## 9. Open Questions

Carried forward from the governance specification and research, requiring resolution through operational experience:

1. **Integration surface:** Which OpenClaw boundary is most stable for enforcement — the Gateway HTTP layer, the tool execution layer, or a wrapper around the entire process?
2. **Skill governance:** Should ClawLaw treat skills as a generic supply-chain problem (signing, scanning, provenance) or as a domain-specific policy problem (per-skill permission manifests)?
3. **Context isolation:** Should a single OpenClaw instance use profile switching or multiple isolated contexts per governance profile?
4. **Enterprise minimum:** What is the minimal control set required for an organization to permit OpenClaw internally (policy distribution, MDM hooks, SIEM export)?
5. **Multi-model delegation:** How should governance adapt when OpenClaw orchestrates subordinate models with different capability profiles?
6. **UX preservation:** How to keep governance from destroying the conversational simplicity that drove OpenClaw's adoption?
7. **Replay verification:** What is the performance and storage cost of maintaining full replay capability for audit purposes?

---

## 10. References

### Project Sources
- ClawLaw repository: `/Sources/ClawLawCore/`
- SwiftVector Codex: https://agentincommand.ai/papers/swiftvector-codex
- ClawLaw Governance Specification: `docs/GOVERNANCE_SPEC.md`
- Governance Experiments: `docs/EXPERIMENTS.md`

### OpenClaw
- OpenClaw official site: https://openclaw.ai/
- OpenClaw GitHub: https://github.com/openclaw/openclaw
- OpenClaw documentation: https://docs.openclaw.ai/
- OpenClaw trust and threat model: https://trust.openclaw.ai/

### Security Research
- Cisco: "Personal AI Agents like OpenClaw Are a Security Nightmare" — https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare
- CrowdStrike: "What Security Teams Need to Know About OpenClaw" — https://www.crowdstrike.com/en-us/blog/what-security-teams-need-to-know-about-openclaw-ai-super-agent/
- Bitdefender: "Technical Advisory: OpenClaw Exploitation in Enterprise Networks" — https://businessinsights.bitdefender.com/technical-advisory-openclaw-exploitation-enterprise-networks
- Adversa AI: "OpenClaw security 101: Vulnerabilities & hardening" — https://adversa.ai/blog/openclaw-security-101-vulnerabilities-hardening-2026/
- SecurityWeek: "Vulnerability Allows Hackers to Hijack OpenClaw AI Assistant" — https://www.securityweek.com/vulnerability-allows-hackers-to-hijack-openclaw-ai-assistant/

### Governance Frameworks
- Singapore Model AI Governance Framework for Agentic AI (January 2026) — https://www.bakermckenzie.com/en/insight/publications/2026/01/singapore-governance-framework-for-agentic-ai-launched
- IBM: "AI Agent Governance: Big Challenges, Big Opportunities" — https://www.ibm.com/think/insights/ai-agent-governance
- Palo Alto Networks: "A Complete Guide to Agentic AI Governance" — https://www.paloaltonetworks.com/cyberpedia/what-is-agentic-ai-governance

### Media Coverage
- CNBC: "From Clawdbot to Moltbot to OpenClaw" — https://www.cnbc.com/2026/02/02/openclaw-open-source-ai-agent-rise-controversy-clawdbot-moltbot-moltbook.html
- Nature: "OpenClaw AI chatbots are running amok" — https://www.nature.com/articles/d41586-026-00370-w
- Wikipedia: OpenClaw — https://en.wikipedia.org/wiki/OpenClaw
