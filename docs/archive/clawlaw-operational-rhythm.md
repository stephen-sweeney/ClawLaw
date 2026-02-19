# ClawLaw Operational Rhythm

## Agile Workflow for Human-Agent Collaboration

**Version:** 0.1.0-draft
**Author:** Seraphim
**Date:** February 15, 2026
**Status:** Initial Draft
**Parent Document:** ClawLaw Governance Specification v0.1.0

---

## 1. Purpose

This document defines the operational rhythm governing collaboration between the Principal (human operator) and the autonomous agent (OpenClaw). It adapts agile methodology to a human-agent team structure operating across multiple domains of work — not limited to software development.

The core premise: **agile is a governance rhythm, not a development methodology.** Its ceremonies exist to enforce alignment, visibility, and adaptation between collaborating actors with different capabilities and different levels of authority. These properties are more important, not less, when one of the actors is an autonomous agent.

---

## 2. Workstreams

All work is organized into parallel workstreams, each governed by its own backlog and governed by its governance profile (see Governance Specification, Section 4). The agent operates across all workstreams simultaneously; the Principal allocates attention across them based on priority.

### Active Workstreams

| Workstream | Domain | Governance Profile | Backlog Owner |
|---|---|---|---|
| Core Development | SwiftVector, ClawLaw, OpenClaw | Public Open Source (Tier 2) | Principal |
| Product Development | Flightworks Control, application software | Public Open Source (Tier 2) | Principal |
| Internal Tooling | Control panels, automation, optimization | Private Tooling (Tier 3) | Shared — agent proposes, Principal approves |
| Content & Outreach | Social media, blog, video, marketing | Content Pipeline (Tier 4) | Shared — agent produces, Principal publishes |
| Research & Analysis | Technical research, competitive intel, documentation | Research (Tier 1-2) | Agent-driven with Principal steering |
| Business Operations | Invoicing, client communication, proposals, scheduling | TBD | Principal with agent support |
| Creative Projects | ChronicleEngine, NarrativeDemo, creative writing | Research/Propose (Tier 2) | Principal |

_Workstreams may be added, archived, or restructured as the business evolves._

---

## 3. Cadences

The operational rhythm is built on nested cadences — daily, weekly, and periodic cycles that create natural checkpoints for alignment, review, and adaptation.

### 3.1 Daily Rhythm

The day has a defined structure that creates collaboration touchpoints without requiring constant attention from the Principal.

#### Morning Brief (Agent → Principal)

**When:** Available when the Principal starts work
**Duration:** 2-3 minute read
**Purpose:** Align on the day; surface anything that needs attention

The agent prepares a structured brief covering:

**Status across workstreams:**
- What was completed since last brief
- What is currently in progress
- What is blocked awaiting Principal action (PRs to review, content to approve, decisions needed)

**Today's proposed focus:**
- What the agent intends to work on, in priority order
- Estimated scope for each item
- Any workstream that will be idle today and why

**Flags and escalations:**
- Anything the agent encountered that warrants Principal awareness
- Decisions the agent deferred rather than made on its own
- Risks, anomalies, or emerging issues across any workstream

**Recommendations (clearly labeled as such):**
- Priority reordering suggestions with reasoning
- Opportunities the agent has identified
- Process improvements based on observed friction

**Principal response:** The Principal reviews the brief and either confirms the proposed focus, redirects priorities, or addresses blocked items. This response constitutes the work authorization for the day.

#### Midday Check-in (Optional, Agent-Initiated)

**When:** Midday or when a significant milestone is reached
**Trigger:** Agent-initiated when there is material progress to report or a decision point has been reached
**Purpose:** Prevent drift; surface blockers before end of day

This is not a standing ceremony. The agent initiates it when:
- A deliverable is ready for review earlier than expected
- A blocker has emerged that will waste cycles if not addressed
- The agent has completed its planned work and needs new direction
- Something in the environment has changed (e.g., a dependency update, a client communication)

#### Evening Wrap (Agent → Principal)

**When:** End of the agent's active work period or end of Principal's work day
**Duration:** 1-2 minute read
**Purpose:** Close the loop on the day; set up tomorrow

The agent prepares a brief covering:

- What was accomplished today, by workstream
- What remains in progress and its state
- Items queued for tomorrow
- Any overnight tasks the agent will execute autonomously (Tier 3+ only, per governance profile)
- Updated blockers list

---

### 3.2 Weekly Rhythm

#### Sprint Planning (Principal-Led, Weekly)

**When:** Start of week (Monday or Principal's preferred start day)
**Duration:** 15-30 minutes of active engagement
**Purpose:** Set the week's priorities across all workstreams

**Inputs:**
- Agent prepares a sprint proposal: suggested tickets, priorities, and capacity allocation across workstreams
- Principal reviews prior week's outcomes
- Principal brings external context the agent may not have (client conversations, business development, personal priorities)

**Outputs:**
- Approved sprint backlog for the week
- Priority ranking across workstreams (not just within them)
- Any tier adjustments for the week (e.g., temporarily elevating a private tooling task to Tier 2 because it's becoming important enough to review closely)
- Explicit "do not work on" list if needed — items the agent might reasonably pick up but shouldn't this week

**Rule:** The sprint backlog is a commitment framework, not a command. The agent may suggest mid-sprint adjustments through the daily rhythm, but unilateral reprioritization is not permitted.

#### Weekly Review (End of Week)

**When:** End of week (Friday or Principal's preferred end day)
**Duration:** 15-30 minutes of active engagement
**Purpose:** Evaluate the week; capture learnings

**Structure:**
- Completed work across all workstreams — what shipped, what was published, what was delivered
- Incomplete work — what carried over and why
- Velocity assessment — is the current capacity allocation across workstreams appropriate?
- Governance assessment — did the tier assignments feel right? Were there moments where the agent had too much or too little autonomy?
- Agent self-assessment — the agent surfaces its own observations about where it struggled, where it was uncertain, and where it sees process friction

---

### 3.3 Periodic Rhythm

#### Monthly Retrospective

**When:** First working day of the month
**Duration:** 30-60 minutes of active engagement
**Purpose:** Strategic alignment and process evolution

**Structure:**
- Review of the month's outcomes against goals
- Workstream health assessment — are any workstreams starved for attention? Are any overinvested?
- Governance evolution — are tier assignments still appropriate? Should any profiles be adjusted?
- Business alignment — are the agent's activities tracking toward business outcomes (revenue, reputation, strategic positioning)?
- Infrastructure assessment — is the hardware, tooling, and account structure still serving the work?
- Goal setting for the coming month — Principal sets or adjusts strategic direction

#### Quarterly Strategic Review

**When:** End of each quarter
**Duration:** Extended session (1-2 hours)
**Purpose:** Step back from execution to evaluate direction

- Business trajectory assessment
- Technology stack and capability evaluation
- Governance model effectiveness — is ClawLaw working as designed? What needs to change?
- Workstream relevance — should any be retired? Should new ones be created?
- Capacity planning — is it time to add infrastructure (Mac Studio), additional AI services, or new agent contexts?
- Public positioning — how is the thought leadership work landing? What should shift?

---

## 4. Backlog Structure

### 4.1 Unified Backlog Model

Each workstream maintains its own backlog, but all backlogs share a common ticket structure to enable cross-workstream prioritization and reporting.

#### Ticket Structure

```
ID:             [WORKSTREAM]-[NUMBER]
Title:          [Descriptive title]
Workstream:     [Which workstream this belongs to]
Type:           Epic | Story | Task | Bug | Research | Content
Priority:       P0 (Critical) | P1 (High) | P2 (Medium) | P3 (Low)
Status:         Proposed | Approved | In Progress | In Review | Done | Archived
Assigned Tier:  [Autonomy tier under which this work is executed]
Estimated Scope: S | M | L | XL
Created By:     Principal | Agent
Approved By:    Principal (required for all tickets entering "Approved" status)
Dependencies:   [Cross-references to other tickets]
Acceptance:     [What "done" looks like — defined before work begins]
```

### 4.2 Cross-Workstream Prioritization

Not all workstreams are equal at any given time. The Principal maintains a workstream priority order that governs how the agent allocates capacity when there is contention.

Example:
```
Week of 2026-02-16:
1. Core Development (SwiftVector governance tests) — 40%
2. Business Operations (StackMint proposal) — 20%
3. Content & Outreach (launch materials) — 20%
4. Internal Tooling (control panel MVP) — 15%
5. Research (local model evaluation) — 5%
```

These allocations are set during sprint planning and may be adjusted through the daily rhythm.

### 4.3 Agent-Proposed Work

The agent may identify work that the Principal has not explicitly requested. This work enters the backlog as **Proposed** and cannot move to **Approved** without Principal authorization. Examples:

- Agent notices a dependency has a security advisory → proposes a ticket to update it
- Agent identifies that a blog post could be written about a recently completed feature → proposes content ticket
- Agent observes that a refactoring would reduce technical debt → proposes development ticket
- Agent finds a relevant grant opportunity during research → proposes business operations ticket

The agent's ability to propose work is a feature, not a risk, as long as the Principal retains approval authority over what gets executed.

---

## 5. Communication Protocols

### 5.1 Channels and Their Purpose

| Channel | Direction | Purpose | Governance |
|---|---|---|---|
| Morning Brief | Agent → Principal | Daily alignment | Required; agent must produce |
| Evening Wrap | Agent → Principal | Daily closure | Required; agent must produce |
| Midday Check-in | Agent → Principal | Ad hoc updates | Optional; agent-initiated |
| Telegram (business phone) | Principal → Agent | Real-time direction, quick decisions | Tier-appropriate responses only |
| PR Reviews (GitHub) | Agent → Principal → Agent | Code review cycle | Required for Tier 2 work |
| Publication Queue | Agent → Principal | Content approval | Required for all external content |
| Escalation Alert | Agent → Principal | Urgent governance flag | Agent must escalate immediately; cannot defer |

### 5.2 Asynchronous-First Principle

The operational rhythm is designed to be **asynchronous by default**. The agent works continuously; the Principal engages at natural touchpoints. Synchronous interaction (real-time conversation, live pairing) is available but not required for the system to function.

This is a deliberate design choice. It means:
- The agent must be capable of productive work between touchpoints
- The agent must be capable of self-blocking when it reaches a governance boundary rather than guessing
- The Principal must be able to catch up on agent activity through the brief/wrap cycle without having been present
- All context necessary to understand agent decisions must be captured in the audit trail, not in ephemeral conversation

### 5.3 Interrupts

The Principal may interrupt the agent's planned work at any time via Telegram or direct conversation. Interrupts are classified as:

- **Redirect:** Change priority or focus. Agent acknowledges, adjusts, and logs the change.
- **Halt:** Stop current work immediately. Agent preserves state, halts, and awaits direction.
- **Query:** Principal needs information. Agent responds without disrupting current work.
- **Override:** Principal countermands a governance rule for a specific action. Agent logs the override, executes, and resumes normal governance. Overrides do not persist — they are one-time exceptions.

---

## 6. Adaptation and Learning

### 6.1 Process Improvement Loop

The operational rhythm is itself subject to iteration. The agent is expected to observe its own operational effectiveness and surface process improvement proposals:

- "The midday check-in is triggering too frequently and disrupting flow — propose reducing the trigger threshold"
- "Content workstream tickets are consistently underestimated — propose revising the scoping model"
- "Morning briefs are too long — propose a condensed format for days with minimal activity"

The Principal evaluates these proposals during the weekly review.

### 6.2 Governance Friction Log

The agent maintains a running log of moments where governance rules created friction — where the rules prevented the agent from doing something it assessed would have been beneficial. This log is reviewed during the monthly retrospective.

This is not an argument for loosening governance. It is a data source for calibrating governance. Some friction is intentional and valuable — it means the guardrails are working. Some friction indicates the rules are miscalibrated for the actual risk profile.

### 6.3 Velocity Tracking

The agent tracks its own throughput across workstreams over time. This data informs:

- Capacity allocation decisions during sprint planning
- Identification of workstreams that consistently under-deliver (possibly under-resourced or poorly scoped)
- Evaluation of whether tier adjustments have impacted productivity
- Long-term infrastructure planning (when does the Principal need more compute?)

---

## 7. Relationship to Governance Specification

This Operational Rhythm document is subordinate to the ClawLaw Governance Specification. In the event of any conflict between operational convenience and governance constraints, **governance prevails**.

The daily brief may recommend a priority change, but it cannot authorize one.
The agent may propose a tier escalation, but it cannot execute one.
The sprint backlog may allocate capacity, but it cannot override a hard boundary.

The operational rhythm makes the governance model *livable*. The governance model makes the operational rhythm *safe*.

---

## 8. Open Questions

- [ ] What is the right tool for backlog management? GitHub Projects? A dedicated system? Something the agent builds as internal tooling?
- [ ] Should the morning brief format be standardized as a template, or should the agent adapt its format to the day's content?
- [ ] How should the agent handle weekend and off-hours work? Should there be a different governance posture for unsupervised periods?
- [ ] What is the right escalation urgency model for Telegram interrupts? Should there be a priority classification for agent-initiated messages?
- [ ] How should sprint velocity be normalized across workstreams with fundamentally different work types?
- [ ] At what point does the operational data collected here become valuable enough to publish as a case study?

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0-draft | 2026-02-15 | Initial draft — cadences, backlog structure, communication protocols, adaptation framework |
