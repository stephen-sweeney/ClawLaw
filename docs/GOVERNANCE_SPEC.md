# ClawLaw Governance Specification

## OpenClaw Autonomous Agent Governance Framework

**Version:** 0.1.0-draft
**Author:** Seraphim
**Date:** February 15, 2026
**Status:** Initial Draft

> **Scope Note (Feb 19, 2026):** This document defines the full ClawLaw authority model
> including autonomy tiers (1-4), governance profiles, and delegation chains. **v1.0
> implements Laws 0/4/8 only** (boundary enforcement, budget governance, approval gates).
> Autonomy tiers, governance profiles, and delegation chains are deferred to v1.1+
> (see BACKLOG.md Epic E-010). For v1.0 requirements, architecture, and acceptance
> criteria, see HRD.md, PLD.md, and OUC.md respectively.

---

## 1. Foundational Principle

**State, not prompts, must be the authority.**

All agent behavior is governed by deterministic state transitions. No action may be taken by an autonomous agent based solely on prompt interpretation. Every permission, capability, and operational boundary must be expressed as an auditable state that can only be modified through explicitly authorized transitions.

---

## 2. Authority Model

### 2.1 The Human Authority

The human operator (Principal) retains ultimate authority over all agent operations. No governance configuration may remove or circumvent the Principal's authority. The following rights are non-delegable:

- **Merge authority** on all public repositories
- **Publication authority** on all externally visible content
- **Priority authority** — determination of what the agent works on and in what order
- **Tier escalation authority** — only the Principal may elevate an agent's autonomy tier
- **Shutdown authority** — the Principal may halt all agent operations at any time

### 2.2 Delegation Chains

Authority may be delegated from the Principal to the orchestrating agent (OpenClaw), and from OpenClaw to subordinate agents. Each level of delegation introduces governance requirements:

| Delegation Depth | Example | Governance Requirement |
|---|---|---|
| Level 0 | Principal acts directly | None — human judgment applies |
| Level 1 | Principal → OpenClaw | Tier-based permissions; audit trail required |
| Level 2 | Principal → OpenClaw → DevSwarm agent | Inherited tier ceiling; delegating agent cannot grant permissions it does not hold |
| Level 3+ | Deeper chains | Reserved; not currently authorized |

**Rule:** No agent in a delegation chain may grant a subordinate agent permissions exceeding its own. Authority is inherited downward with restriction, never amplification.

---

## 3. Autonomy Tiers

All agent operations are governed by a tiered autonomy model. Each tier defines the boundary between what an agent *can* do and what it *may* do.

### Tier 1 — Observe and Report

- Agent may read, analyze, and reason about project artifacts
- Agent may surface findings, recommendations, and risk assessments
- Agent may **not** create, modify, or delete any project artifacts
- Agent may **not** invoke development tools or external services
- **Use case:** Initial project onboarding; situational awareness

### Tier 2 — Propose

- All Tier 1 permissions, plus:
- Agent may draft plans, epics, tickets, and task breakdowns
- Agent may draft code changes in isolated branches
- Agent may submit pull requests for review
- Agent may **not** merge, deploy, or publish
- Agent may **not** proceed to the next ticket until the current ticket is reviewed and approved
- **Use case:** Public repositories; safety-critical development; SwiftVector and ClawLaw core

### Tier 3 — Execute Within Bounds

- All Tier 2 permissions, plus:
- Agent may merge its own pull requests on designated repositories
- Agent may iterate without per-ticket approval within defined scope
- Agent must halt and escalate if changes exceed defined boundaries (e.g., scope creep, dependency changes, security implications)
- **Boundary enforcement:** Automated checks define the "bounds" — test passage, scope containment, no new external dependencies without approval
- **Use case:** Private tooling; internal utilities; control panels

### Tier 4 — Autonomous Production

- All Tier 3 permissions, plus:
- Agent may create, revise, and finalize artifacts independently
- Agent operates as a production pipeline with publication as the sole gate
- Principal reviews and authorizes publication; all pre-publication work is autonomous
- **Use case:** Content creation; social media; marketing materials; generated media

### Tier Transitions

- Tier escalation requires **explicit Principal authorization** recorded as an auditable state change
- Tier de-escalation may be triggered by the Principal, by automated safety checks, or by the agent itself if it detects uncertainty
- No tier transition may occur implicitly or as a side effect of another operation
- All tier transitions are logged with timestamp, authorizing Principal, prior tier, new tier, and justification

---

## 4. Governance Profiles

Governance profiles bind a specific autonomy tier and operational constraints to a domain of work. A single OpenClaw instance may operate under multiple governance profiles simultaneously, with ClawLaw enforcing isolation between them.

### 4.1 Profile: Public Open Source

**Applies to:** SwiftVector, ClawLaw, and all public-facing repositories
**Autonomy Tier:** Tier 2 — Propose
**Rationale:** These repositories represent the Principal's professional thesis and public reputation. Every change must reflect deliberate, reviewed judgment.

**Operational Rules:**
- OpenClaw receives work direction from the Principal (PM role)
- OpenClaw decomposes work into epics, tickets, and tasks
- OpenClaw implements against approved tickets, one at a time
- OpenClaw submits PRs to GitHub and awaits review
- Work is blocked until the Principal approves and merges
- The Principal controls development pace through the review cadence

### 4.2 Profile: Private Tooling

**Applies to:** Internal utilities, control panels, optimization tools, development infrastructure
**Autonomy Tier:** Tier 3 — Execute Within Bounds
**Rationale:** Low blast radius, private audience, easily reversible. This is the learning ground for higher-autonomy operations.

**Operational Rules:**
- OpenClaw may iterate independently within defined scope boundaries
- Automated test passage is required before self-merge
- Changes that introduce new external dependencies require Principal approval
- Changes that affect security boundaries require Principal approval
- OpenClaw must surface a daily summary of changes made under this profile

### 4.3 Profile: Content Pipeline

**Applies to:** Social media content, blog posts, video scripts, marketing images, outreach materials
**Autonomy Tier:** Tier 4 — Autonomous Production
**Rationale:** The failure mode is a draft that doesn't get published. All pre-publication work can be autonomous.

**Operational Rules:**
- OpenClaw may create, revise, and prepare content independently
- OpenClaw may generate images, videos, and other media assets
- All content enters a publication queue for Principal review
- Nothing is published to any external platform without Principal authorization
- OpenClaw may schedule content for proposed publication times but may not execute publication

### 4.4 Profile: Research and Analysis

**Applies to:** Technical research, competitive analysis, documentation, creative writing projects
**Autonomy Tier:** Tier 1 — Observe and Report (default), escalable to Tier 2 per-task
**Rationale:** Research benefits from broad exploration but outputs may influence strategic decisions.

**Operational Rules:**
- OpenClaw may freely research, synthesize, and produce analysis documents
- Research outputs are delivered to the Principal as recommendations, not directives
- If research identifies actionable development work, OpenClaw may draft tickets but not self-assign them
- Creative writing projects operate at Tier 2 with the Principal reviewing and approving drafts

---

## 5. Observability and Audit

### 5.1 Audit Trail Requirements

Every agent action must produce an auditable record. The governance framework leverages existing tooling wherever possible:

- **Development actions** are recorded as Git commits, pull requests, and merge events
- **Ticket lifecycle** is recorded in the project management system (GitHub Issues/Projects)
- **Content pipeline** actions are recorded as draft artifacts with timestamps
- **Tier transitions** are recorded in a dedicated governance log
- **Delegation events** (OpenClaw invoking subordinate agents) are recorded with the delegated scope and inherited permissions

### 5.2 Governance Log

A persistent, append-only log records all governance-significant events:

```
[TIMESTAMP] [EVENT_TYPE] [AGENT] [PROFILE] [TIER] [DETAILS]
```

Event types include:
- `TIER_CHANGE` — autonomy tier escalation or de-escalation
- `TASK_ASSIGNED` — Principal assigns work to agent
- `TASK_STARTED` — agent begins work on assigned task
- `PR_SUBMITTED` — agent submits work for review
- `PR_APPROVED` — Principal approves submitted work
- `SELF_MERGE` — agent merges own work (Tier 3+ only)
- `CONTENT_QUEUED` — content enters publication queue
- `CONTENT_PUBLISHED` — Principal authorizes publication
- `DELEGATION` — agent delegates to subordinate agent
- `ESCALATION` — agent escalates decision to Principal
- `SAFETY_HALT` — automated or self-initiated halt

---

## 6. Safety and Boundary Enforcement

### 6.1 Hard Boundaries (Non-Negotiable)

These constraints cannot be overridden by any tier, profile, or delegation:

- No agent may modify its own governance configuration
- No agent may modify another agent's governance configuration
- No agent may access credentials or secrets outside its designated profile scope
- No agent may communicate externally (publish, send messages, make API calls to external services) without Principal authorization, except for authorized development tool integrations (e.g., GitHub API for PR submission)
- No agent may initiate financial transactions

### 6.2 Soft Boundaries (Configurable Per Profile)

These constraints are defined per governance profile and enforced by ClawLaw:

- Scope boundaries (what files, repos, or domains the agent may touch)
- Rate boundaries (how many changes per time period)
- Complexity boundaries (changes above a certain scope trigger escalation)
- Dependency boundaries (introduction of new dependencies triggers escalation)

### 6.3 Self-Governance

Agents are expected to participate in their own governance:

- An agent that detects it is operating outside its understood scope must halt and escalate
- An agent that encounters ambiguity in its instructions must request clarification rather than interpret
- An agent may voluntarily de-escalate its own tier if it assesses that a task carries higher risk than its current tier anticipates

---

## 7. Infrastructure Mapping

### Current Infrastructure (as of February 2026)

| Component | Device | Role |
|---|---|---|
| OpenClaw (primary) | Mac mini M4 Pro | Development orchestration; agent runtime |
| Development (mobile) | MacBook Pro M5 | Secondary development; remote access to mini |
| Communication | Dedicated business phone | Telegram prompting; operator interface |
| Planning (future) | Mac Studio | Local model inference; expanded compute |

### Account and Identity Separation

| Context | Identity | Billing |
|---|---|---|
| Strategic conversation (Claude) | Personal email | Business account |
| API access (OpenClaw orchestration) | agentincommand.ai | Business account |
| GitHub | TBD | Business account |
| Subordinate AI services (Gemini, Grok, Codex) | agentincommand.ai | Business account |

---

## 8. Open Questions

_Items requiring further resolution as operational experience develops:_

- [ ] Should OpenClaw have a single context with profile switching, or multiple isolated contexts per governance profile?
- [ ] What is the appropriate boundary definition format for Tier 3 "bounds"?
- [ ] How should governance rules be versioned and migrated as ClawLaw evolves?
- [ ] What metrics should be collected to evaluate whether a profile's tier is appropriately set?
- [ ] How should the governance model adapt when OpenClaw orchestrates multiple subordinate AI models with different capability profiles?
- [ ] What is the escalation protocol when a subordinate agent (e.g., a Codex instance) takes an action that OpenClaw's governance didn't anticipate?
- [ ] LLC restructuring implications: does the governance framework need to account for multi-entity ownership of different project assets?

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0-draft | 2026-02-15 | Initial draft — foundational principles, authority model, autonomy tiers, governance profiles |
