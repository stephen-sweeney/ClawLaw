# ClawLaw Product Backlog

**Version:** 0.1.0
**Date:** February 19, 2026
**Author:** Product Management
**Status:** Draft
**Companion documents:** `docs/HRD.md`, `docs/PLD.md`, `docs/OUC.md`, `docs/DOMAIN_NOTES.md`

---

## Methodology

- **Framework:** Scrum-like with 1-week sprints
- **Sprint cadence:** 7 sprints (Sprint 0 through Sprint 6), approximately 7 weeks
- **Velocity assumption:** 25–30 story points per sprint (single developer)
- **Prioritization:** P0 (must ship for v1.0) / P1 (should ship) / P2 (nice to have) / P3 (deferred to v1.1+)
- **Estimation:** Fibonacci story points (1, 2, 3, 5, 8, 13)
- **Statuses:** Backlog / Ready / In Progress / Done / Blocked

---

## Release Overview

**Release:** ClawLaw v1.0.0
**Target:** 7 weeks from sprint start (~late March / early April 2026)
**Scope:** Governance framework for OpenClaw desktop agent on macOS (Apple Silicon). Budget enforcement, boundary enforcement, authority enforcement, audit trail, CLI, OpenClaw integration.
**Total story points (P0 + P1):** ~196 across 47 stories
**Critical path:** Phase 0 (R11 fix) → Phase 1 (determinism + persistence) → Phase 2 (config) → Phase 3 (CLI) → Phase 4 (integration) → Phase 5 (hardening + release)

---

## Epic Summary

| Epic | Title | Phase | Sprint(s) | Priority | Points | Dependencies |
|---|---|---|---|---|---|---|
| **E-001** | Critical Fix: Approval Execution | Phase 0 | Sprint 0 | P0 | 8 | None |
| **E-002** | Determinism & Audit Extraction | Phase 1a | Sprint 1 | P0 | 34 | E-001 |
| **E-003** | Persistence Layer | Phase 1b | Sprint 1–2 | P0 | 21 | E-002 |
| **E-004** | Boundary Hardening | Phase 1c | Sprint 2 | P0 | 10 | None |
| **E-005** | Configuration System | Phase 2 | Sprint 2–3 | P0 | 23 | E-003 |
| **E-006** | Steward CLI | Phase 3 | Sprint 3–4 | P0 | 29 | E-003, E-005 |
| **E-007** | OpenClaw Integration | Phase 4 | Sprint 4–6 | P0 | 34 | E-006, SP-001, D1 |
| **E-008** | Hardening & Quality | Phase 5a | Sprint 6–7 | P1 | 26 | E-001–E-007 |
| **E-009** | Release Preparation | Phase 5b | Sprint 7 | P1 | 11 | E-008 |
| **E-010** | Deferred / v1.1+ | — | — | P2–P3 | — | — |

---

## Sprint Plan

| Sprint | Week | Focus | Epics | Key Milestone |
|---|---|---|---|---|
| **Sprint 0** | Week 0 | Critical fix | E-001 | Approval→execute flow works |
| **Sprint 1** | Week 1 | Determinism, audit extraction | E-002 | Pure reducer; AuditData in ActionEffect |
| **Sprint 2** | Week 2 | Persistence, boundaries, config start | E-003, E-004, E-005 | State survives restart; paths normalized |
| **Sprint 3** | Week 3 | Config completion, CLI start | E-005, E-006 | YAML config loads; safe defaults ship |
| **Sprint 4** | Week 4 | CLI completion, integration start | E-006, E-007 | Full Steward CLI operational |
| **Sprint 5** | Week 5 | OpenClaw integration | E-007 | Adapter intercepts tool calls |
| **Sprint 6** | Week 6 | Integration completion, hardening start | E-007, E-008 | E2E: OpenClaw + ClawLaw running together |
| **Sprint 7** | Week 7 | Hardening, release | E-008, E-009 | v1.0.0 tagged and published |

---

## E-001: Critical Fix — Approval Execution

**Phase 0 (Pre-Sprint) | Priority: P0 | Sprint 0 | 8 points**

The approval→execute flow is broken in v0.1.0. When a Steward approves a high-risk action (deleteFile, executeShellCommand, sendEmail), the reducer re-triggers `.requireApproval` because `bypassGate` only skips Phase 1 (enforcement gate), not Phase 2 (action-type approval). Approved actions can never execute. This blocks all three OUC hero flows.

**Dependencies:** None
**Blocked by:** Nothing
**Blocks:** E-002 through E-009 (all subsequent work assumes a working approval flow)

---

### S-001: Fix R11 dual-bypass in reducer

**As a** Steward (P1), **I want** approved high-risk actions to execute after I approve them, **so that** the approval workflow is functional and I can authorize destructive actions when appropriate.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R10, R11 |
| **Acceptance Criteria** | AC-B04, AC-B05, AC-B06, AC-B07 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] When `bypassGate == true`, Phase 1 (enforcement gate) is skipped [existing behavior]
- [ ] When `bypassGate == true`, Phase 2 action-type approval for `deleteFile`, `executeShellCommand`, `sendEmail` is skipped [new behavior — R11 fix]
- [ ] When `bypassGate == true`, Phase 2 boundary checks (path allowlist, protected patterns) still run [safety preserved]
- [ ] When `bypassGate == true`, Phase 3 budget impact is still applied [accounting preserved]
- [ ] `swift test` passes with no regressions

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-001 | Modify `GovernanceReducer.reduce()` to accept `bypassGate` in Phase 2 `validateAction`, skipping action-type approval for always-approve types while preserving boundary checks | 2 days | None | Ready |
| T-002 | Update `validateAction` to check `bypassGate` parameter and skip `.requireApproval` return for deleteFile/executeShellCommand/sendEmail when true | 1 day | T-001 | Ready |

---

### S-002: R11 bypass test suite

**As an** engineer, **I want** comprehensive tests proving approved actions execute correctly, **so that** the R11 fix is validated and regression-protected.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R11 |
| **Acceptance Criteria** | AC-B05, AC-B10 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Test: approved `deleteFile` returns `.allow`, not `.requireApproval`, when re-evaluated with `bypassGate: true`
- [ ] Test: approved `executeShellCommand` returns `.allow` with `bypassGate: true`
- [ ] Test: approved `sendEmail` returns `.allow` with `bypassGate: true`
- [ ] Test: `bypassGate: true` on a boundary violation still returns `.reject` (safety preserved)
- [ ] Test: `bypassGate: true` applies token cost to budget (accounting preserved)
- [ ] Test: approved `deleteFile` on a protected pattern re-triggers protected-pattern approval (independent gate)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-003 | Write R11 bypass test: approved deleteFile executes without re-entering approval queue | 0.5 days | T-001 | Ready |
| T-004 | Write test matrix: every action type × bypassGate × every enforcement level | 1 day | T-001 | Ready |
| T-005 | Write test: bypassGate preserves boundary checks and budget impact | 0.5 days | T-001 | Ready |

---

## E-002: Determinism & Audit Extraction

**Phase 1a | Priority: P0 | Sprint 1 | 34 points**

The reducer is not a pure function. It calls `Date()` three times in the audit logging path and relies on `UUID()` defaults in `AuditEntry`. The audit log is an unbounded in-memory array inside `GovernanceState`, making state comparison expensive and replay impossible. This epic extracts audit logging from the reducer, introduces `AuditData` in `ActionEffect`, injects `Clock`/`IDGenerator` protocols, and adds `Codable`/`Sendable` conformance — resolving assumption A1 and enabling R13 (deterministic replay).

**Dependencies:** E-001 (working approval flow)
**Blocks:** E-003 (persistence needs AuditData), E-008 (replay tests)

---

### S-003: Inject Clock and IDGenerator protocols

**As an** engineer, **I want** all timestamp and UUID generation to go through injected protocols, **so that** the system supports deterministic replay and test isolation.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | NFR-7, R13 |
| **Acceptance Criteria** | AC-X04 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `Clock` protocol defined with `now() -> Date`
- [ ] `IDGenerator` protocol defined with `generate() -> UUID`
- [ ] `SystemClock` and `SystemIDGenerator` production implementations exist
- [ ] `FixedClock` and `FixedIDGenerator` test implementations exist
- [ ] Orchestrator, Steward, and ApprovalQueue accept injected `Clock` and `IDGenerator`
- [ ] No `Date()` or `UUID()` calls in reducer path (`grep` scan clean, excluding `// deterministic:` exceptions)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-006 | Define `Clock` and `IDGenerator` protocols in ClawLawCore | 0.5 days | None | Ready |
| T-007 | Implement `SystemClock`, `SystemIDGenerator`, `FixedClock`, `FixedIDGenerator` | 1 day | T-006 | Ready |
| T-008 | Inject `Clock` + `IDGenerator` into `GovernanceOrchestrator` init | 0.5 days | T-007 | Ready |
| T-009 | Inject `Clock` into `Steward` actor; replace `Date()` calls | 0.5 days | T-007 | Ready |
| T-010 | Inject `Clock` + `IDGenerator` into `ApprovalQueue` actor; replace all `Date()`/`UUID()` calls | 1 day | T-007 | Ready |

---

### S-004: Extract audit log from GovernanceState

**As an** engineer, **I want** the audit log moved out of governance state into a dedicated writer, **so that** state comparison is efficient, persistence is possible, and the reducer has no side effects.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 8 |
| **Requirements** | R12, NFR-7 |
| **Acceptance Criteria** | AC-X03 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `GovernanceState.auditLog` property removed
- [ ] `AuditData` struct defined (action, effect, priorSpend, newSpend, enforcement)
- [ ] `ActionEffect` cases carry `AuditData` associated values
- [ ] Reducer returns `AuditData` in every `ActionEffect` case — no audit writes inside the reducer
- [ ] Orchestrator stamps `id`, `timestamp`, `agentId` from injected dependencies before routing to writer
- [ ] `logTransition` method removed from reducer (was the primary `Date()` violation)
- [ ] `increaseBudget` and `resetBudget` no longer call `Date()` directly

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-011 | Define `AuditData` struct (Equatable, Sendable, Codable) | 0.5 days | None | Ready |
| T-012 | Add `AuditData` associated value to all four `ActionEffect` cases | 1 day | T-011 | Ready |
| T-013 | Update `GovernanceReducer.reduce()` to populate `AuditData` instead of appending to `state.auditLog` | 2 days | T-012 | Ready |
| T-014 | Remove `logTransition`, `Date()` calls from `increaseBudget` and `resetBudget` in reducer | 1 day | T-013 | Ready |
| T-015 | Remove `auditLog` property from `GovernanceState` | 0.5 days | T-013 | Ready |
| T-016 | Update orchestrator to stamp `AuditEntry` from `AuditData` + injected deps, route to writer | 1 day | T-008, T-015 | Ready |
| T-017 | Remove `AuditEntry.init` default parameters for `id` and `timestamp` | 0.5 days | T-016 | Ready |
| T-018 | Update all existing tests for new `ActionEffect` signatures | 1 day | T-012 | Ready |

---

### S-005: Add Codable and Sendable conformance chain

**As an** engineer, **I want** all core types to conform to Codable and Sendable, **so that** state can be persisted to disk and safely shared across actor boundaries.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | NFR-7 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `GovernanceState` conforms to `Codable` and `Sendable`
- [ ] `BudgetState` conforms to `Sendable` (already `Codable`)
- [ ] `ActionEffect` conforms to `Sendable`
- [ ] `AuditEntry` conforms to `Sendable` (already `Codable`)
- [ ] `AgentAction` conforms to `Sendable` (already `Codable`)
- [ ] `AuthorizationLevel` conforms to `Sendable`
- [ ] `swift build` succeeds with strict concurrency checking

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-019 | Add `Sendable` conformance to `BudgetState`, `AgentAction`, `AuthorizationLevel`, `AuditEntry` | 1 day | None | Ready |
| T-020 | Add `Codable` + `Sendable` to `GovernanceState` (retain `var` for reconciliation; document deviation) | 1 day | T-015 | Ready |
| T-021 | Add `Sendable` to `ActionEffect` (update custom `Equatable` for `AuditData`) | 1 day | T-012 | Ready |

---

### S-006: Determinism replay tests

**As an** evaluator (P3), **I want** proof that replaying an action log against the same initial state produces identical governance decisions, **so that** I can verify governance is architectural, not probabilistic.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R13, NFR-7 |
| **Acceptance Criteria** | AC-A08, AC-A12 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Test: run reducer N times with identical inputs → identical `ActionEffect` outputs
- [ ] Test: replay action sequence against initial state with `FixedClock`/`FixedIDGenerator` → byte-identical final state
- [ ] Test: two independent replays produce identical audit entry sequences
- [ ] Determinism grep scan: `grep -rn "Date()" --include="*.swift" Sources/ | grep -v "// deterministic:"` returns zero results

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-022 | Write reducer determinism test (N identical runs → identical outputs) for all action types × enforcement levels | 1 day | T-013 | Ready |
| T-023 | Write replay verification test (action sequence → identical final state) with FixedClock/FixedIDGenerator | 1.5 days | T-008, T-013 | Ready |
| T-024 | Add CI grep scan for Date()/UUID()/random() violations per SwiftVector invariants | 0.5 days | T-014 | Ready |

---

### S-007: Remove AuditEntry default parameters

**As an** engineer, **I want** all `AuditEntry` values explicitly provided (no `Date()`/`UUID()` defaults), **so that** non-determinism cannot be introduced by accident at any callsite.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | NFR-7, A1 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `AuditEntry.init` has no default parameter values for `id` or `timestamp`
- [ ] All callsites updated to provide explicit values from injected dependencies
- [ ] `swift build` succeeds; `swift test` passes

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-025 | Remove `id: UUID = UUID()` and `timestamp: Date = Date()` defaults from `AuditEntry.init` | 0.5 days | T-016 | Ready |
| T-026 | Update all remaining callsites (Steward, ApprovalQueue, tests) to provide explicit values | 1 day | T-025 | Ready |

---

## E-003: Persistence Layer

**Phase 1b | Priority: P0 | Sprint 1–2 | 21 points**

Governance state and audit trail exist only in memory. Process restart loses everything. This epic adds a `StateStore` actor for JSON state persistence and an `AuditWriter` actor for JSONL append-only audit files with daily rotation and retention.

**Dependencies:** E-002 (AuditData must exist before AuditWriter can consume it)
**Blocks:** E-005 (config loader initializes state via StateStore), E-006 (CLI reads from persistence)

---

### S-008: Implement AuditWriter actor

**As an** evaluator (P3), **I want** an append-only, durable audit trail persisted to disk, **so that** I can review governance decisions after the fact and produce compliance reports.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 8 |
| **Requirements** | R12, R14, NFR-5, NFR-6 |
| **Acceptance Criteria** | AC-X02, AC-X03 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `AuditWriter` actor writes JSONL entries to `~/.clawlaw/audit/YYYY-MM-DD.jsonl`
- [ ] One JSON object per line, appended (append-only — no delete/modify API)
- [ ] Daily rotation: new file each day
- [ ] Retention: files older than configured `retention_days` (default 90) are pruned
- [ ] File permissions: 0600 on creation
- [ ] Synchronous flush on enforcement transitions (degraded/gated/halted); async for normal actions
- [ ] Export method: returns `[AuditEntry]` for a date range
- [ ] Write failure behavior configurable: demo mode blocks all actions; production mode logs warning and continues

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-027 | Define `AuditWriter` actor protocol and JSONL implementation | 2 days | T-011 | Ready |
| T-028 | Implement daily file rotation and append-only writes | 1 day | T-027 | Ready |
| T-029 | Implement retention pruning (delete files older than `retention_days`) | 0.5 days | T-028 | Ready |
| T-030 | Implement export method (date range → `[AuditEntry]` via JSONL parsing) | 1 day | T-028 | Ready |
| T-031 | Implement configurable write-failure behavior (block vs. warn+continue) | 0.5 days | T-027 | Ready |
| T-032 | Set file permissions to 0600 on creation | 0.5 days | T-027 | Ready |

---

### S-009: Implement StateStore actor

**As a** power user (P1), **I want** governance state to survive process restarts, **so that** budget enforcement, halted state, and pending configuration persist across sessions.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R7, OQ-3 |
| **Acceptance Criteria** | AC-X07 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `StateStore` actor writes `GovernanceState` to `~/.clawlaw/state.json`
- [ ] Atomic writes: write to temp file, rename to target (prevents corruption on crash)
- [ ] State written after every state-changing operation
- [ ] Enforcement reconciliation runs on load (stale enforcement corrected automatically)
- [ ] Missing state file → fresh state from configuration defaults
- [ ] Corrupt state file → fresh state from defaults, warning logged
- [ ] File permissions: 0600 on creation

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-033 | Define `StateStore` actor protocol and JSON file implementation | 1 day | T-020 | Ready |
| T-034 | Implement atomic writes (temp file + rename) | 0.5 days | T-033 | Ready |
| T-035 | Implement state recovery: load from file, handle missing/corrupt, enforce reconciliation | 1 day | T-033 | Ready |
| T-036 | Set file permissions to 0600 on creation | 0.5 days | T-033 | Ready |

---

### S-010: Integrate persistence into orchestrator

**As an** engineer, **I want** the orchestrator to use `AuditWriter` and `StateStore` for all state changes, **so that** persistence is automatic and transparent to the rest of the system.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R7, R12 |
| **Acceptance Criteria** | AC-A08, AC-A11, AC-B08 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Orchestrator accepts `AuditWriter` and `StateStore` in init
- [ ] After every `reduce()` call, orchestrator stamps `AuditEntry` and routes to `AuditWriter`
- [ ] After every state-changing operation, orchestrator persists via `StateStore`
- [ ] State persistence is async (non-blocking on critical path)
- [ ] Audit write for enforcement transitions is synchronous

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-037 | Add `AuditWriter` and `StateStore` dependencies to `GovernanceOrchestrator` init | 0.5 days | T-027, T-033 | Ready |
| T-038 | Wire orchestrator `propose()` to stamp AuditEntry and route to writer | 1 day | T-037 | Ready |
| T-039 | Wire orchestrator `approve()`/`reject()` to write audit and persist state | 1 day | T-037 | Ready |
| T-040 | Wire orchestrator `increaseBudget()`/`resetBudget()` to write audit and persist state | 0.5 days | T-037 | Ready |

---

### S-011: Persistence integration tests

**As an** engineer, **I want** tests proving state survives restart and audit trail is durable, **so that** persistence correctness is verified.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R7, R12 |
| **Acceptance Criteria** | AC-X07 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Test: state written, process simulated restart, state recovered with correct enforcement
- [ ] Test: audit entries written, file parsed, entries match originals
- [ ] Test: corrupt state file → fresh state from defaults, no crash
- [ ] Test: audit retention prunes old files, preserves recent

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-041 | Write StateStore round-trip test (write, recover, verify reconciliation) | 1 day | T-035 | Ready |
| T-042 | Write AuditWriter round-trip test (write entries, parse JSONL, verify) | 0.5 days | T-028 | Ready |
| T-043 | Write corruption recovery test (corrupt JSON → defaults) | 0.5 days | T-035 | Ready |

---

## E-004: Boundary Hardening

**Phase 1c | Priority: P0 | Sprint 2 | 10 points**

Path validation uses `hasPrefix` string matching, which is vulnerable to traversal attacks (`/workspace/../etc/passwd`). This epic adds lexical path normalization and input validation hardening.

**Dependencies:** None (can run in parallel with E-003)
**Blocks:** E-008 (boundary test suite depends on normalization)

---

### S-012: Lexical path normalization

**As a** casual user (P2), **I want** path traversal attempts blocked automatically, **so that** my sensitive files are protected even if the agent crafts clever paths.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R1, R2 |
| **Acceptance Criteria** | AC-C04, AC-C05 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Paths are lexically normalized (resolving `.`, `..`, redundant separators) before allowlist comparison
- [ ] `/workspace/../etc/passwd` normalizes to `/etc/passwd` and is rejected
- [ ] `/workspace/./subdir/../file.txt` normalizes to `/workspace/file.txt` and is allowed (if in allowlist)
- [ ] Normalization uses `URL(fileURLWithPath:).standardized.path` (lexical only — no symlink resolution)
- [ ] Both `isPathAllowed` and `isPathProtected` apply normalization before evaluation
- [ ] Malformed paths (null bytes, empty strings) are rejected safely (no crash)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-044 | Add path normalization function using `URL.standardized.path` | 1 day | None | Ready |
| T-045 | Apply normalization in `isPathAllowed` before `hasPrefix` check | 0.5 days | T-044 | Ready |
| T-046 | Apply normalization in `isPathProtected` before `contains` check | 0.5 days | T-044 | Ready |

---

### S-013: Path normalization test suite

**As an** engineer, **I want** comprehensive tests for path traversal defense, **so that** boundary enforcement is verified against known attack patterns.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R1, R2 |
| **Acceptance Criteria** | AC-C01, AC-C02, AC-C05 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Test: `../` traversal rejected after normalization
- [ ] Test: `./` sequences resolved correctly
- [ ] Test: redundant separators (`//`) normalized
- [ ] Test: empty path rejected
- [ ] Test: normal allowed path still allowed after normalization
- [ ] Test: protected pattern still detected after normalization

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-047 | Write traversal attack test suite (10+ path patterns) | 1 day | T-044 | Ready |
| T-048 | Write edge case tests (empty, null, Unicode, extremely long paths) | 0.5 days | T-044 | Ready |

---

### S-014: Input validation hardening

**As an** engineer, **I want** `increaseBudget` to reject invalid inputs (e.g., `newCeiling <= 0`), **so that** Steward operations cannot produce invalid governance states.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 2 |
| **Requirements** | R20 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `increaseBudget(newCeiling: 0)` returns unchanged state or error
- [ ] `increaseBudget(newCeiling: -1)` returns unchanged state or error
- [ ] Test coverage for invalid inputs

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-049 | Add guard clause to `increaseBudget`: reject `newCeiling <= 0` | 0.5 days | None | Ready |
| T-050 | Write tests for invalid budget ceiling inputs | 0.5 days | T-049 | Ready |

---

## E-005: Configuration System

**Phase 2 | Priority: P0 | Sprint 2–3 | 23 points**

No configuration system exists. Defaults are hardcoded in test helpers. This epic adds YAML-based configuration with safe defaults, validation, config protection, and first-run experience.

**Dependencies:** E-003 (state initialization uses StateStore)
**Blocks:** E-006 (CLI commands read from config), E-007 (daemon uses config for proxy settings)

---

### S-015: YAML configuration schema and validation

**As a** power user (P1), **I want** a well-defined YAML configuration file with validation, **so that** I can customize governance policy and get clear error messages for invalid configurations.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R18 |
| **Acceptance Criteria** | AC-X06 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Configuration schema defined: version, boundary (writable_paths, protected_patterns), budget (ceiling, warning_threshold, critical_threshold), authority (always_approve, approval_threshold), network (egress_allowlist — commented out), audit (retention_days, export_format), steward (role_identifier)
- [ ] Validation rules enforced at load time: version == 1, writable_paths non-empty, ceiling > 0, warning < critical, both thresholds in (0,1), always_approve items are valid action types, approval_threshold is valid authorization level
- [ ] Invalid config → clear error message identifying the invalid field
- [ ] System refuses to start with invalid config (fail-closed)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-051 | Add `Yams` dependency to Package.swift `ClawLawConfig` target | 0.5 days | None | Ready |
| T-052 | Define `ClawLawConfiguration` struct matching YAML schema | 1 day | None | Ready |
| T-053 | Implement validation rules (all constraints from PLD Section 4.3) | 1 day | T-052 | Ready |
| T-054 | Write validation test suite (valid configs, every invalid variant) | 1 day | T-053 | Ready |

---

### S-016: ConfigLoader implementation

**As an** engineer, **I want** a `ConfigLoader` that reads YAML, validates, and emits initialized `GovernanceState`, **so that** the system can start from a configuration file.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R17, R18 |
| **Acceptance Criteria** | AC-X06 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `ConfigLoader` reads `~/.clawlaw/config.yaml` (default path)
- [ ] `ConfigLoader` accepts custom path via parameter
- [ ] Valid config → initialized `GovernanceState` with all values from config
- [ ] Invalid config → error with field-level diagnostic
- [ ] Missing config → trigger first-run default generation (S-017)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-055 | Implement `ConfigLoader`: parse YAML via Yams, validate, emit state | 2 days | T-052, T-053 | Ready |
| T-056 | Implement custom path support (`--config PATH` parameter) | 0.5 days | T-055 | Ready |

---

### S-017: Safe defaults and first-run experience

**As a** casual user (P2), **I want** ClawLaw to protect me out of the box with no configuration required, **so that** I am safe by default without understanding the governance system.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R4, R17 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Default config embedded in binary
- [ ] First run: if no config file exists, write defaults to `~/.clawlaw/config.yaml`
- [ ] Defaults: writable_paths=[~/workspace], protected_patterns=[.ssh, credentials, .env, keychain], ceiling=50000, warning=0.80, critical=0.95, always_approve=[deleteFile, executeShellCommand, sendEmail], retention=90 days
- [ ] `clawlaw config init` writes defaults (or overwrites with confirmation)
- [ ] File permissions 0600 on creation

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-057 | Embed default configuration in binary | 0.5 days | T-052 | Ready |
| T-058 | Implement first-run detection and default config generation | 1 day | T-055 | Ready |
| T-059 | Implement `clawlaw config init` subcommand | 0.5 days | T-058 | Ready |
| T-060 | Set 0600 permissions on generated config file | 0.5 days | T-058 | Ready |

---

### S-018: Configuration protection

**As a** casual user (P2), **I want** the agent to be unable to modify governance configuration, **so that** a compromised agent cannot weaken its own controls.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R19 |
| **Acceptance Criteria** | AC-C06 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `config.yaml` path hardcoded as a protected pattern in `ConfigLoader` (added to `protectedPatterns` at load time)
- [ ] Agent write to `~/.clawlaw/config.yaml` is rejected by boundary enforcement (path outside default writable set) or triggers approval (if path were in writable set)
- [ ] Config loader rejects agent-authored changes (writer identity check)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-061 | Hardcode config path in protected patterns at `ConfigLoader` load time | 0.5 days | T-055 | Ready |
| T-062 | Write test: agent writeFile to config path → rejected | 0.5 days | T-061 | Ready |

---

### S-019: Configuration validation CLI

**As a** power user (P1), **I want** a CLI command to validate my configuration file before starting ClawLaw, **so that** I can catch errors without starting the daemon.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 2 |
| **Requirements** | R21 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `clawlaw config validate` validates default path
- [ ] `clawlaw config validate --path FILE` validates custom path
- [ ] Valid config → success message
- [ ] Invalid config → field-level error messages
- [ ] Non-existent file → clear error

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-063 | Implement `clawlaw config validate` subcommand | 1 day | T-055 | Ready |

---

### S-020: Startup permission check

**As a** power user (P1), **I want** ClawLaw to refuse to start if configuration or state files have unsafe permissions, **so that** governance policy is not exposed to other users on the system.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | NFR-9 |
| **Acceptance Criteria** | AC-X06 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Startup checks permissions on `config.yaml`, `state.json`, and `audit/` directory
- [ ] If any file is more permissive than 0600, system warns and refuses to start
- [ ] Clear error message: "File X has permissions Y, expected 0600. Run `chmod 600 X` to fix."

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-064 | Implement startup permission check for all governance files | 1 day | T-055 | Ready |
| T-065 | Write test: world-readable config → startup refused with diagnostic | 0.5 days | T-064 | Ready |

---

## E-006: Steward CLI

**Phase 3 | Priority: P0 | Sprint 3–4 | 29 points**

The CLI has only `demo`, `test`, and `monitor` subcommands. This epic adds all Steward commands: status, approve, reject, budget increase, budget reset, audit view, audit export, and daemon mode.

**Dependencies:** E-003 (persistence layer), E-005 (configuration system)
**Blocks:** E-007 (daemon command is the integration entry point)

---

### S-021: `clawlaw status` command

**As a** Steward (P1), **I want** a single command that shows current enforcement, budget, and pending approvals, **so that** I can assess governance state at a glance.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R21 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Output includes: enforcement level, budget utilization (current/ceiling, percentage), pending approval count, last state file write timestamp, today's audit entry count, config validation status
- [ ] Reads from `StateStore` and `AuditWriter`
- [ ] Works when daemon is running or when reading from persisted files

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-066 | Implement `clawlaw status` subcommand reading from state file and audit directory | 2 days | T-033, T-027 | Ready |

---

### S-022: `clawlaw approve` and `clawlaw reject` commands

**As a** Steward (P1), **I want** to approve or reject pending actions from the CLI, **so that** I can exercise authority over the agent's high-risk operations.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R20, R21 |
| **Acceptance Criteria** | AC-B04, AC-B08, AC-B09 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `clawlaw approve <id>` approves a pending action; action executes with budget impact
- [ ] `clawlaw reject <id>` rejects a pending action; action permanently blocked
- [ ] `clawlaw reject <id> --reason TEXT` records the operator's reason
- [ ] Approval/rejection recorded in audit trail with "STEWARD" attribution
- [ ] Invalid ID → clear error message
- [ ] Approval of non-existent action → clear error

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-067 | Implement `clawlaw approve <id>` subcommand | 1.5 days | T-037 | Ready |
| T-068 | Implement `clawlaw reject <id> [--reason TEXT]` subcommand | 1 day | T-037 | Ready |
| T-069 | Implement CLI↔daemon communication for approve/reject (SP-005 resolution) | 1 day | SP-005 | Blocked |

---

### S-023: `clawlaw budget` commands

**As a** Steward (P1), **I want** to increase the budget ceiling or reset spend from the CLI, **so that** I can recover from gated or halted states without restarting.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 3 |
| **Requirements** | R20, R21 |
| **Acceptance Criteria** | AC-A09, AC-A10, AC-A11 |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `clawlaw budget increase <amount>` increases ceiling; enforcement recalculated
- [ ] `clawlaw budget reset` resets spend to zero; enforcement returns to `normal`
- [ ] Both operations recorded in audit trail with "STEWARD" attribution
- [ ] Invalid amount (<=0, non-numeric) → clear error

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-070 | Implement `clawlaw budget increase <amount>` subcommand | 1 day | T-037 | Ready |
| T-071 | Implement `clawlaw budget reset` subcommand | 0.5 days | T-037 | Ready |

---

### S-024: `clawlaw audit` commands

**As an** evaluator (P3), **I want** to view and export the audit trail from the CLI, **so that** I can produce compliance reports and investigate incidents.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R14, R21 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] `clawlaw audit` displays recent audit entries (human-readable table)
- [ ] `clawlaw audit --from DATE --to DATE` filters by date range
- [ ] `clawlaw audit --export json` outputs machine-readable JSON array
- [ ] `clawlaw audit --export json --from DATE --to DATE` combined filtering + export
- [ ] Export produces valid JSON parseable by standard tools

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-072 | Implement `clawlaw audit` view mode (human-readable table) | 1.5 days | T-030 | Ready |
| T-073 | Implement `--from`/`--to` date filtering | 0.5 days | T-072 | Ready |
| T-074 | Implement `--export json` output mode | 1 day | T-072 | Ready |

---

### S-025: `clawlaw daemon` command

**As a** power user (P1), **I want** a daemon mode that runs the governance proxy, **so that** ClawLaw can intercept OpenClaw tool calls in real time.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R15, R21 |
| **Acceptance Criteria** | — |
| **Status** | Blocked (SP-001, SP-005) |

**Acceptance criteria:**
- [ ] `clawlaw daemon` starts the governance proxy
- [ ] Proxy accepts connections from CLI commands (approve, reject, status, budget)
- [ ] Clean shutdown on SIGINT/SIGTERM
- [ ] Startup loads config, recovers state, opens audit writer

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-075 | Implement `clawlaw daemon` startup: config load, state recovery, audit writer init | 1.5 days | T-055, T-035 | Ready |
| T-076 | Implement daemon communication channel (Unix socket per SP-005) | 1.5 days | SP-005 | Blocked |
| T-077 | Implement clean shutdown with SIGINT/SIGTERM handling | 0.5 days | T-075 | Ready |

---

### S-026: CLI integration tests

**As an** engineer, **I want** tests for every CLI command, **so that** Steward operations are verified end-to-end.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R21 |
| **Acceptance Criteria** | — |
| **Status** | Ready |

**Acceptance criteria:**
- [ ] Test: `clawlaw status` outputs correct enforcement, budget, pending count
- [ ] Test: `clawlaw approve` + `clawlaw reject` workflows
- [ ] Test: `clawlaw budget increase` + `clawlaw budget reset` workflows
- [ ] Test: `clawlaw audit --export json` produces valid JSON
- [ ] Test: `clawlaw config validate` with valid and invalid configs

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-078 | Write CLI integration test suite (all subcommands, valid + error cases) | 2 days | T-066–T-074 | Ready |

---

## E-007: OpenClaw Integration

**Phase 4 | Priority: P0 | Sprint 4–6 | 34 points**

ClawLaw governance is isolated from OpenClaw until an integration adapter is built. This epic implements the `OpenClawAdapter` protocol, the action translator, the response mapper, and the integration proxy — enabling ClawLaw to intercept real OpenClaw tool calls.

**Dependencies:** E-006 (daemon command), SP-001 (interception surface investigation), D1 (Mac mini)
**Blocks:** E-008 (E2E tests), E-009 (release requires working integration)

---

### S-027: OpenClaw interception surface investigation

**As an** engineer, **I want** to understand OpenClaw's tool-execution boundary, **so that** I can design an adapter that intercepts tool calls without modifying OpenClaw source.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 5 |
| **Requirements** | R15, R16 |
| **Acceptance Criteria** | — |
| **Status** | Blocked (D1 — Mac mini) |

> This is a combined spike/story. Output: documented interception strategy and adapter design. See also SP-001.

**Acceptance criteria:**
- [ ] OpenClaw's HTTP protocol for tool execution documented (request/response format, headers)
- [ ] Primary interception strategy selected (HTTP proxy or process wrapper)
- [ ] Fallback strategy documented
- [ ] Adapter protocol design validated against actual OpenClaw traffic

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-079 | Install OpenClaw on Mac mini; capture tool-execution traffic | 2 days | D1 | Blocked |
| T-080 | Document HTTP protocol: request format, response format, headers, auth | 1 day | T-079 | Blocked |
| T-081 | Validate HTTP proxy interception strategy against live traffic | 1 day | T-080 | Blocked |

---

### S-028: Implement OpenClawAdapter protocol

**As an** engineer, **I want** a transport-agnostic adapter that translates OpenClaw tool calls to typed governance actions, **so that** the governance system is decoupled from OpenClaw's specific protocol.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 8 |
| **Requirements** | R15, R16 |
| **Acceptance Criteria** | AC-X01 |
| **Status** | Blocked (S-027) |

**Acceptance criteria:**
- [ ] `OpenClawAdapter` protocol: `translate(toolName:parameters:) -> AgentAction`
- [ ] `OpenClawAdapter` protocol: `respond(to:originalTool:) -> OpenClawResponse`
- [ ] Known tool mappings: writeFile, deleteFile, executeShellCommand, sendEmail, research (+ variants)
- [ ] Unknown tools → `AgentAction.unknown(toolName:parameters:)` → classified as `systemMod`
- [ ] Response mapper: `.allow` → proceed, `.reject` → deny, `.requireApproval` → retry/pending

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-082 | Implement `OpenClawAdapter` protocol and HTTP proxy adapter | 3 days | T-080 | Blocked |
| T-083 | Implement action translator: tool name → AgentAction (with unknown fallback) | 2 days | T-082 | Blocked |
| T-084 | Implement response mapper: ActionEffect → OpenClawResponse | 1 day | T-082 | Blocked |

---

### S-029: Governance proxy daemon

**As a** power user (P1), **I want** ClawLaw to run as a proxy that intercepts OpenClaw traffic, **so that** governance is enforced transparently on every tool call.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 8 |
| **Requirements** | R15 |
| **Acceptance Criteria** | AC-C07 |
| **Status** | Blocked (S-028) |

**Acceptance criteria:**
- [ ] Proxy binds to localhost (127.0.0.1) only
- [ ] All OpenClaw tool calls pass through governance evaluation before host execution
- [ ] Rejected actions never reach the host filesystem/shell/network
- [ ] Approved/allowed actions forwarded to OpenClaw Gateway for execution
- [ ] Health check endpoint for adapter connectivity

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-085 | Implement HTTP proxy server in `clawlaw daemon` | 2 days | T-082 | Blocked |
| T-086 | Wire proxy to orchestrator: intercept → translate → propose → respond | 2 days | T-085 | Blocked |
| T-087 | Implement health check and reconnection logic | 1 day | T-085 | Blocked |

---

### S-030: OpenClaw integration tests

**As an** engineer, **I want** end-to-end tests with live OpenClaw, **so that** governance interception is validated against real agent behavior.

| Field | Value |
|---|---|
| **Priority** | P0 |
| **Points** | 8 |
| **Requirements** | R15, R16 |
| **Acceptance Criteria** | AC-B04, AC-C01, AC-C07 |
| **Status** | Blocked (D1, D4) |

**Acceptance criteria:**
- [ ] Test: OpenClaw tool call intercepted before host execution
- [ ] Test: writeFile outside allowlist → rejected before I/O
- [ ] Test: deleteFile → suspended, approved → executed
- [ ] Test: unknown tool → classified as systemMod, requires approval
- [ ] Test: OpenClaw functions normally with ClawLaw proxy active (no breakage)
- [ ] Test: ClawLaw proxy down → OpenClaw actions blocked (fail-closed)

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-088 | Write E2E test: governance interception with live OpenClaw | 3 days | T-086, D1, D4 | Blocked |
| T-089 | Write E2E test: fail-closed behavior when proxy unavailable | 1 day | T-086 | Blocked |

---

## E-008: Hardening & Quality

**Phase 5a | Priority: P1 | Sprint 6–7 | 26 points**

Comprehensive testing: fuzz testing, boundary experiments, authority experiments, replay verification, fail-closed validation, and performance benchmarks.

**Dependencies:** E-001 through E-007 (all implementation complete)
**Blocks:** E-009 (release)

---

### S-031: Fuzz testing

**As an** engineer, **I want** the reducer and config parser fuzz-tested against random inputs, **so that** no input can crash governance evaluation.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 5 |
| **Requirements** | NFR-3 |
| **Acceptance Criteria** | AC-X05 |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Fuzz test: random `AgentAction` × random `GovernanceState` × random `bypassGate` → no crash
- [ ] Fuzz test: random YAML strings → config parser no crash, invalid input rejected
- [ ] Fuzz test: random path strings → normalization no crash
- [ ] Zero unhandled exceptions across full fuzz input space

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-090 | Implement reducer fuzz test (random inputs, verify no crash) | 2 days | T-001 | Backlog |
| T-091 | Implement config parser fuzz test (random YAML, verify no crash) | 1 day | T-055 | Backlog |
| T-092 | Implement path normalization fuzz test | 0.5 days | T-044 | Backlog |

---

### S-032: Boundary enforcement test suite (Law 0)

**As an** engineer, **I want** comprehensive boundary enforcement tests, **so that** filesystem containment is validated for all scenarios.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 5 |
| **Requirements** | R1, R2 |
| **Acceptance Criteria** | AC-C01, AC-C02, AC-C03, AC-C08 |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Test: every file operation type × allowed path × disallowed path × protected path
- [ ] Test: config path protection (hardcoded)
- [ ] Test: path traversal variants (10+ patterns)
- [ ] Audit trail contains rejection entries for all blocked operations

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-093 | Expand boundary test suite to cover all action types × path categories | 2 days | T-047 | Backlog |

---

### S-033: Authority enforcement test suite (Law 8)

**As an** engineer, **I want** comprehensive authority enforcement tests, **so that** the approval workflow is validated for all action types and enforcement levels.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 5 |
| **Requirements** | R9, R10, R11 |
| **Acceptance Criteria** | AC-B01, AC-B02, AC-B03, AC-B05, AC-B06, AC-B07, AC-B10 |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Test matrix: every action type × every enforcement level × bypassGate true/false
- [ ] Test: independent governance gates fire and require separate approvals
- [ ] Test: approved action budget impact applied correctly
- [ ] Test: approved action boundary checks still enforced

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-094 | Write full action type × enforcement level × bypass test matrix | 2 days | T-004 | Backlog |

---

### S-034: Fail-closed validation

**As an** evaluator (P3), **I want** proof that governance unavailability blocks all actions, **so that** I can trust the fail-closed guarantee.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 3 |
| **Requirements** | NFR-4 |
| **Acceptance Criteria** | AC-X02, AC-X05 |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Test: simulated governance error → all actions rejected
- [ ] Test: audit write failure (demo config) → all actions blocked
- [ ] Test: adapter disconnection → all actions blocked
- [ ] Zero actions allowed during any simulated unavailability

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-095 | Write fault-injection tests for fail-closed behavior (reducer error, audit failure, adapter disconnect) | 2 days | T-086 | Backlog |

---

### S-035: Performance benchmarks

**As an** engineer, **I want** latency and throughput benchmarks, **so that** NFR-1 and NFR-2 targets are verified on production hardware.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 3 |
| **Requirements** | NFR-1, NFR-2 |
| **Acceptance Criteria** | — |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Benchmark: reducer `p99 < 10ms` on M4 Pro
- [ ] Benchmark: sustained 10 actions/second with audit logging enabled
- [ ] Results documented in test output

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-096 | Write reducer latency benchmark (p99 measurement) | 1 day | D1 | Backlog |
| T-097 | Write throughput benchmark (sustained actions/second with audit) | 1 day | D1 | Backlog |

---

### S-036: Replay verification test suite

**As an** evaluator (P3), **I want** a dedicated replay verification suite, **so that** deterministic replay is proven beyond individual unit tests.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 5 |
| **Requirements** | R13 |
| **Acceptance Criteria** | AC-A12 |
| **Status** | Backlog |

**Acceptance criteria:**
- [ ] Test: 100-action sequence replayed twice → identical final state
- [ ] Test: replay across all enforcement transitions (normal → degraded → gated → halted → recovery)
- [ ] Test: replay with approval workflow (propose → suspend → approve → execute)
- [ ] Test: replay with mixed action types and human interventions

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-098 | Write comprehensive replay verification suite (4 test scenarios) | 2 days | T-023 | Backlog |

---

## E-009: Release Preparation

**Phase 5b | Priority: P1 | Sprint 7 | 11 points**

Documentation, packaging, and distribution for public release.

**Dependencies:** E-008 (all tests pass)
**Blocks:** Nothing (final epic)

---

### S-037: README and installation guide

**As a** casual user (P2), **I want** clear installation instructions and a quick-start guide, **so that** I can add ClawLaw to my OpenClaw setup in under 15 minutes.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 3 |
| **Requirements** | G3, G4 |
| **Acceptance Criteria** | — |
| **Status** | Backlog |

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-099 | Write README.md with project overview, install instructions, quick-start demo | 1.5 days | All epics | Backlog |
| T-100 | Write INSTALL.md with detailed prerequisites, build from source, verify installation | 1 day | T-099 | Backlog |

---

### S-038: Release packaging

**As a** power user (P1), **I want** to install ClawLaw via Homebrew, **so that** I can add governance with a single command.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 5 |
| **Requirements** | G3, G4 |
| **Acceptance Criteria** | — |
| **Status** | Backlog |

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-101 | Create GitHub release workflow (tag, build, attach binaries) | 1.5 days | All epics | Backlog |
| T-102 | Write Homebrew formula for `clawlaw` | 1 day | T-101 | Backlog |
| T-103 | Generate binary checksums and signing | 0.5 days | T-101 | Backlog |

---

### S-039: ClawLawCore import verification

**As an** engineer, **I want** CI verification that ClawLawCore imports only Foundation, **so that** the pure-logic constraint is enforced automatically.

| Field | Value |
|---|---|
| **Priority** | P1 |
| **Points** | 3 |
| **Requirements** | NFR-10 |
| **Acceptance Criteria** | — |
| **Status** | Backlog |

#### Tasks

| ID | Task | Effort | Dependencies | Status |
|---|---|---|---|---|
| T-104 | Add CI check: `grep -rn "^import " Sources/ClawLawCore/ | grep -Ev "(Foundation\|os)"` must return zero results | 0.5 days | None | Backlog |
| T-105 | Add CI check: `grep -rn "Date()" --include="*.swift" Sources/ | grep -v "// deterministic:"` must return zero results | 0.5 days | T-024 | Backlog |

---

## E-010: Deferred / v1.1+

**Priority: P2–P3 | Not scheduled**

Items explicitly deferred from v1.0 scope. Tracked here for completeness and roadmap planning.

---

### S-040: Network egress enforcement (R3)

**Priority:** P2 | **Requirements:** R3 | **Status:** Blocked (OQ-4)

No macOS mechanism exists for user-space network egress filtering without elevated privileges. v1.0 defines the `networkRequest` action type and schema but defers enforcement. If OQ-4 is resolved, this moves to P0.

---

### S-041: File-read governance (OQ-10)

**Priority:** P2 | **Requirements:** OQ-10 | **Status:** Backlog

v1.0 governs writes and deletes. Read governance requires a new `readFile` action type. Without it, credential protection is incomplete (agent can read `.env` even if writes are blocked).

---

### S-042: Persistent approval queue (DQ-7)

**Priority:** P2 | **Requirements:** DQ-7 | **Status:** Backlog

v1.0 queue is in-memory. Pending approvals lost on crash. Persist to `~/.clawlaw/pending.json` for v1.1.

---

### S-043: Autonomy tier enforcement

**Priority:** P3 | **Requirements:** Governance spec | **Status:** Backlog

Four autonomy tiers (Observe, Propose, Execute, Autonomous) defined in governance spec. v1.0 uses budget-based and action-classification enforcement instead.

---

### S-044: Governance profile isolation

**Priority:** P3 | **Requirements:** Governance spec | **Status:** Backlog

Profiles bind autonomy tiers to work domains. v1.0 operates as a single governance context.

---

### S-045: Graphical monitoring dashboard

**Priority:** P3 | **Requirements:** Non-goal for v1.0 | **Status:** Backlog

SwiftUI dashboard for real-time governance visualization. Deferred to v2.0.

---

### S-046: Multi-platform support

**Priority:** P3 | **Requirements:** Non-goal for v1.0 | **Status:** Backlog

Linux and Windows support. v1.0 is macOS-only.

---

### S-047: Cryptographic audit integrity (OQ-9)

**Priority:** P2 | **Requirements:** NFR-5 (enhanced) | **Status:** Backlog

Hash-chain verification for tamper-evidence. v1.0 uses filesystem permissions (0600) only.

---

## Spikes / Research

Spikes are time-boxed investigations that resolve open questions blocking story refinement or implementation.

| ID | Question | Time Box | Blocks | Source | Status |
|---|---|---|---|---|---|
| **SP-001** | Which OpenClaw interception point is most stable? (HTTP gateway, tool execution, process wrapper) | 3 days | S-027, S-028 | OQ-1 | Blocked (D1) |
| **SP-002** | Can macOS network egress be controlled without elevated privileges? | 2 days | S-040 | OQ-4 | Backlog |
| **SP-003** | What is the right default budget ceiling for casual users? | 1 day (user research) | S-017 | OQ-5, DQ-3 | Backlog |
| **SP-004** | Should `AuditWriter` flush synchronously on enforcement transitions? | 0.5 days | S-008 | DQ-4 | Ready |
| **SP-005** | How should CLI communicate with running daemon? Unix socket vs. shared state file? | 1 day | S-022, S-025 | DQ-6 | Ready |
| **SP-006** | Should symlink resolution be added to path normalization? | 1 day | S-012 | OQ-C2 | Backlog |
| **SP-007** | How should OpenClaw heartbeat/cron actions be governed? | 0.5 days | S-029 | OQ-7 | Backlog |

---

## Traceability Matrix

### OUC Acceptance Criteria → Stories

| AC | Criterion (abbreviated) | Story |
|---|---|---|
| AC-A01 | Transition to `degraded` at >=80% | S-006 (replay tests validate transitions) |
| AC-A02 | Transition to `gated` at >=95% | S-006 |
| AC-A03 | Transition to `halted` at >100% | S-006 |
| AC-A04 | Require approval for non-zero-cost in gated | S-006, S-033 |
| AC-A05 | Reject all in halted | S-006, S-033 |
| AC-A06 | Gated (not halted) at exactly 100% | S-006, S-033 |
| AC-A07 | Allow zero-cost in gated without approval | S-033 |
| AC-A08 | Record enforcement transitions in audit | S-010 |
| AC-A09 | Steward can increase budget | S-023 |
| AC-A10 | Steward can reset budget | S-023 |
| AC-A11 | Steward interventions with "STEWARD" attribution | S-010, S-023 |
| AC-A12 | Enforcement reconciliation (no downgrade) | S-006, S-011, S-036 |
| AC-B01 | Require approval for deleteFile | S-002, S-033 |
| AC-B02 | Require approval for executeShellCommand | S-002, S-033 |
| AC-B03 | Require approval for sendEmail | S-002, S-033 |
| AC-B04 | No execution until Steward approves | S-001, S-022, S-030 |
| AC-B05 | Approved actions execute without re-triggering gate | S-001, S-002 |
| AC-B06 | Boundary checks on approved actions | S-001, S-002 |
| AC-B07 | Budget impact on approved actions | S-001, S-002 |
| AC-B08 | Record suspension/approval/rejection in audit | S-010, S-022 |
| AC-B09 | Steward can reject with reason | S-022 |
| AC-B10 | Independent governance gates | S-002, S-033 |
| AC-C01 | Reject writes outside allowlist | S-013, S-032 |
| AC-C02 | Reject deletes outside allowlist | S-013, S-032 |
| AC-C03 | Require approval for protected patterns | S-032 |
| AC-C04 | Lexical path normalization | S-012 |
| AC-C05 | Reject traversal after normalization | S-012, S-013 |
| AC-C06 | Reject agent writes to governance config | S-018 |
| AC-C07 | No I/O for rejected actions | S-029, S-030 |
| AC-C08 | Record boundary violations in audit | S-010, S-032 |
| AC-X01 | Unknown tools → systemMod | S-028 |
| AC-X02 | Block actions when audit unavailable (demo) | S-008, S-034 |
| AC-X03 | Audit entry for every decision | S-008, S-010 |
| AC-X04 | Actor isolation (no concurrent corruption) | S-003, S-005 |
| AC-X05 | Fail-closed on error | S-031, S-034 |
| AC-X06 | Refuse to start with invalid config/permissions | S-015, S-020 |
| AC-X07 | Enforcement reconciliation on restart | S-009, S-011 |

### HRD Requirements → Stories

| Requirement | Stories |
|---|---|
| R1 (path allowlist) | S-012, S-013, S-032 |
| R2 (protected patterns) | S-012, S-013, S-032 |
| R3 (network egress) | S-040 (deferred) |
| R4 (safe defaults) | S-017 |
| R5 (budget transitions) | S-006, S-036 |
| R6 (gated approval) | S-033 |
| R7 (halt + no auto-resume) | S-009, S-011 |
| R8 (enforcement reconciliation) | S-006, S-011, S-036 |
| R9 (action classification) | S-033 |
| R10 (always-approve) | S-001, S-002, S-033 |
| R11 (bypass dual-gate) | S-001, S-002 |
| R12 (audit trail) | S-004, S-008, S-010 |
| R13 (deterministic replay) | S-003, S-006, S-036 |
| R14 (structured export) | S-024 |
| R15 (interception) | S-027, S-028, S-029, S-030 |
| R16 (no source modification) | S-027, S-028 |
| R17 (default config) | S-016, S-017 |
| R18 (user config) | S-015, S-016 |
| R19 (config protection) | S-018 |
| R20 (Steward interface) | S-022, S-023, S-014 |
| R21 (CLI) | S-019, S-021, S-022, S-023, S-024, S-025, S-026 |
| NFR-1 (10ms latency) | S-035 |
| NFR-2 (10 actions/sec) | S-035 |
| NFR-3 (no crash) | S-031 |
| NFR-4 (fail-closed) | S-034 |
| NFR-5 (append-only audit) | S-008 |
| NFR-6 (90-day retention) | S-008 |
| NFR-7 (pure reducer) | S-003, S-004, S-005, S-006, S-007 |
| NFR-8 (no new attack surface) | S-029 (proxy on localhost only) |
| NFR-9 (file permissions) | S-020 |
| NFR-10 (Core: Foundation only) | S-039 |

---

## Risk Register

### Product Risks (from HRD)

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| RK-1 | OpenClaw changes tool-execution interface before v1.0 | Medium | High | Adapter layer isolates protocol; pin to tested version | Engineering |
| RK-2 | No interception surface exists without source modification | Medium | High | HTTP proxy (primary) + process wrapper (fallback) | Engineering |
| RK-3 | Governance latency exceeds 10ms with audit I/O | Low | Medium | Async audit writes; sync only on transitions | Engineering |
| RK-4 | Casual users find approval disruptive and disable governance | Medium | High | Tune defaults; provide silent audit mode for low-risk actions | Product |
| RK-5 | OpenClaw foundation ships competing governance framework | Low | Critical | Ship fast; demonstrate architectural governance first | Product |
| RK-6 | Date()/UUID() not resolved before v1.0 | Low | High | Prioritized in Sprint 1 (E-002) | Engineering |

### Design Risks (from PLD)

| ID | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| R-D1 | OpenClaw HTTP protocol undocumented or unstable | Medium | High | Adapter layer; pin to tested version | Engineering |
| R-D2 | YAML parser vulnerability (billion laughs) | Low | Medium | Yams with size limits; fuzz test | Engineering |
| R-D3 | Async audit writes lose entries on crash | Medium | Low | Sync flush on enforcement transitions | Engineering |
| R-D4 | bypassGate dual-bypass creates permission escalation | Low | High | Full test matrix (S-002) | Engineering |
| R-D5 | Mac mini delivery delayed | Low | Medium | Development on current hardware; integration blocked | Engineering |
| R-D6 | State file corruption on crash during write | Low | Medium | Atomic writes; recoverable from config defaults | Engineering |

---

## Definition of Done

### Story

A story is **Done** when:
- [ ] All acceptance criteria pass
- [ ] All tasks complete
- [ ] Unit tests written and passing (`swift test`)
- [ ] No `Date()`/`UUID()` violations introduced (grep scan clean)
- [ ] No forbidden imports in ClawLawCore
- [ ] Code reviewed
- [ ] Audit trail entries produced for all governance-significant operations

### Sprint

A sprint is **Done** when:
- [ ] All P0 stories for the sprint are Done
- [ ] `swift build` succeeds
- [ ] `swift test` passes with zero failures
- [ ] Sprint validation gate (from PLD) passes
- [ ] No regressions in previously-completed stories
- [ ] Determinism grep scan clean

### Release (v1.0)

The release is **Done** when:
- [ ] All P0 stories Done (37 stories)
- [ ] All P1 stories Done or explicitly deferred with justification (10 stories)
- [ ] All 37 OUC acceptance criteria validated
- [ ] OpenClaw + ClawLaw E2E tests pass
- [ ] Fuzz tests: zero crashes
- [ ] Performance benchmarks meet NFR-1 and NFR-2
- [ ] README and installation guide complete
- [ ] Homebrew formula published
- [ ] GitHub release tagged

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 0.1.0 | 2026-02-19 | Initial draft |
