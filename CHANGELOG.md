# Changelog

All notable changes to ClawLaw will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and documentation
- README with architecture overview and feature descriptions
- SwiftVector integration design
- Core protocol definitions:
  - `ContainmentState` — Filesystem and network boundaries
  - `BudgetGovernor` — Token consumption with circuit breaker states
  - `ApprovalQueue` — Human-in-the-loop authorization
  - `AuditLog` — Tamper-evident state transition history

### In Progress
- `ContainmentState` implementation
- Basic CLI scaffold

### Planned
- `BudgetGovernor` reducer implementation
- `ApprovalQueue` state machine
- Task classifier
- OpenClaw gateway integration

---

## Version History

### v0.1.0 — Foundation (Planned)
- Core protocol definitions
- ContainmentState implementation
- Basic CLI (`clawlaw init`, `clawlaw doctor`)

### v0.2.0 — Core Governance (Planned)
- BudgetGovernor reducer
- ApprovalQueue state machine
- Audit log with integrity verification

### v0.3.0 — Integration (Planned)
- OpenClaw gateway bridge
- End-to-end task flow
- Terminal approval interface

---

[Unreleased]: https://github.com/AeroSage/clawlaw/compare/main...HEAD
