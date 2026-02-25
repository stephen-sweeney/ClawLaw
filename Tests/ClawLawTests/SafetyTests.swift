//
//  SafetyTests.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  End-to-end safety invariant tests exercising the full governance
//  pipeline: Laws → Orchestrator → Reducer → Audit.
//  These verify the critical safety properties that ClawLaw guarantees.
//

import Testing
import Foundation
import SwiftVectorCore
import SwiftVectorTesting
@testable import ClawLawCore

@Suite("Governance Safety Invariants")
struct SafetyTests {

    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    func makeOrchestrator(
        taskCeiling: Int = 10000,
        writablePaths: Set<String> = ["/workspace"],
        protectedPatterns: Set<String> = [".ssh", "credentials", ".env"]
    ) -> ClawLawOrchestrator {
        let state = GovernanceState.mock(
            writablePaths: writablePaths,
            protectedPatterns: protectedPatterns,
            taskCeiling: taskCeiling
        )
        return ClawLawOrchestrator(
            initialState: state,
            clock: MockClock(),
            uuidGenerator: MockUUIDGenerator(sequential: 1)
        )
    }

    // MARK: - Sandbox enforcement

    @Test("Sandbox rejects writes outside authorized workspace")
    func sandboxEnforcement() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: actionID, path: "/etc/passwd", content: "root:pass"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .denied)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 0, "No budget consumed on denial")
    }

    @Test("Sandbox allows writes inside authorized workspace")
    func sandboxAllowsWorkspace() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: actionID, path: "/workspace/notes.txt", content: "hello"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .applied)
    }

    // MARK: - Budget circuit breaker

    @Test("Budget transitions through enforcement levels as spend increases")
    func budgetCircuitBreaker() async {
        let orch = makeOrchestrator(taskCeiling: 1000)

        // Spend to 85% → degraded
        let r1 = await orch.propose(
            .research(id: actionID, estimatedTokens: 850),
            agentID: "agent-1"
        )
        #expect(r1.outcome == .applied)
        var state = await orch.currentState
        #expect(state.budget.enforcement == .degraded)

        // Spend to 96% → gated
        let r2 = await orch.propose(
            .research(id: actionID, estimatedTokens: 110),
            agentID: "agent-1"
        )
        #expect(r2.outcome == .applied)
        state = await orch.currentState
        #expect(state.budget.enforcement == .gated)

        // Further spend in gated mode → escalated (not directly applied)
        let r3 = await orch.propose(
            .research(id: actionID, estimatedTokens: 10),
            agentID: "agent-1"
        )
        #expect(r3.outcome == .escalated, "Gated mode requires approval for costly actions")
    }

    // MARK: - Protected patterns

    @Test("Write to .ssh path requires steward approval")
    func protectedSSH() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: actionID, path: "/workspace/.ssh/id_rsa", content: "key"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    @Test("Write to credentials file requires steward approval")
    func protectedCredentials() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: actionID, path: "/workspace/credentials.json", content: "{}"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    // MARK: - High-risk action escalation

    @Test("All file deletions require steward approval")
    func deletionRequiresApproval() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .deleteFile(id: actionID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 0, "No budget consumed on escalation")
    }

    @Test("All shell commands require steward approval")
    func shellRequiresApproval() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .executeShellCommand(id: actionID, command: "rm -rf /"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    @Test("All outbound communications require steward approval")
    func emailRequiresApproval() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .sendEmail(id: actionID, to: "ceo@corp.com", subject: "Urgent", body: "..."),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    // MARK: - Halted system

    @Test("Halted enforcement blocks all actions including research")
    func haltedBlocksEverything() async {
        let haltedState = GovernanceState.mock(taskCeiling: 100).withBudget(
            BudgetState(taskCeiling: 100, currentSpend: 200, enforcement: .halted)
        )
        let orch = ClawLawOrchestrator(
            initialState: haltedState,
            clock: MockClock(),
            uuidGenerator: MockUUIDGenerator(sequential: 1)
        )

        let result = await orch.propose(
            .research(id: actionID, estimatedTokens: 1),
            agentID: "agent-1"
        )

        #expect(result.outcome == .denied)
    }

    // MARK: - Steward recovery

    @Test("Steward can reset budget to restore normal operation")
    func stewardRecovery() async {
        let steward = Steward(
            initialState: GovernanceState.mock(taskCeiling: 1000),
            clock: MockClock(),
            uuidGenerator: MockUUIDGenerator(sequential: 1)
        )

        // Spend to gated
        let _ = await steward.orchestrator.propose(
            .research(id: actionID, estimatedTokens: 960),
            agentID: "agent-1"
        )
        var status = await steward.budgetStatus()
        #expect(status.enforcement == .gated)

        // Steward resets
        await steward.resetBudget()

        status = await steward.budgetStatus()
        #expect(status.spent == 0)
        #expect(status.enforcement == .normal)

        // Agent can operate normally again
        let result = await steward.orchestrator.propose(
            .research(id: actionID, estimatedTokens: 100),
            agentID: "agent-1"
        )
        #expect(result.outcome == .applied)
    }

    // MARK: - Multi-violation trace

    @Test("Delete of protected file outside sandbox captures all violations")
    func multiViolationTrace() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .deleteFile(id: actionID, path: "/etc/.ssh/key"),
            agentID: "agent-1"
        )

        // SandboxBoundaryLaw denies (outside workspace)
        // denyWins → final decision is denied
        #expect(result.outcome == .denied)

        // Trace should show verdicts from multiple laws
        guard let trace = result.trace else {
            Issue.record("Expected governance trace")
            return
        }
        let denyVerdicts = trace.verdicts.filter { $0.decision == .deny }
        let escalateVerdicts = trace.verdicts.filter { $0.decision == .escalate }
        #expect(!denyVerdicts.isEmpty, "At least one deny from SandboxBoundaryLaw")
        #expect(!escalateVerdicts.isEmpty, "At least one escalate from DeletionApprovalLaw or ProtectedPatternLaw")
    }

    // MARK: - Approval workflow end-to-end

    @Test("Escalated action approved by steward is applied with budget deduction")
    func approvalWorkflow() async {
        let orch = makeOrchestrator()

        // Agent proposes deletion → escalated
        let proposal = await orch.propose(
            .deleteFile(id: actionID, path: "/workspace/temp.txt"),
            agentID: "agent-1"
        )
        #expect(proposal.outcome == .escalated)
        guard let approvalID = proposal.approvalID else {
            Issue.record("Expected approval ID")
            return
        }

        // Steward approves
        let approved = await orch.approveEscalated(id: approvalID)
        #expect(approved)

        // Budget is deducted (deleteFile costs 50)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 50)

        // Queue is empty
        let pending = await orch.pendingApprovals()
        #expect(pending.isEmpty)
    }

    // MARK: - Determinism

    @Test("Identical action sequences produce identical final state")
    func determinism() async {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let clock = MockClock()
        let uuids = MockUUIDGenerator(sequential: 1)

        let orch1 = ClawLawOrchestrator(
            initialState: state, clock: clock, uuidGenerator: uuids
        )
        let _ = await orch1.propose(
            .research(id: actionID, estimatedTokens: 300), agentID: "a"
        )
        let _ = await orch1.propose(
            .research(id: actionID, estimatedTokens: 200), agentID: "a"
        )
        let state1 = await orch1.currentState

        // Reset mocks and replay
        clock.reset()
        uuids.reset()

        let orch2 = ClawLawOrchestrator(
            initialState: state, clock: clock, uuidGenerator: uuids
        )
        let _ = await orch2.propose(
            .research(id: actionID, estimatedTokens: 300), agentID: "a"
        )
        let _ = await orch2.propose(
            .research(id: actionID, estimatedTokens: 200), agentID: "a"
        )
        let state2 = await orch2.currentState

        #expect(state1 == state2, "Identical sequences must produce identical state")
        #expect(state1.stateHash() == state2.stateHash(), "State hashes must match")
    }
}
