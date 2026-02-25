//
//  ClawLawOrchestratorTests.swift
//  ClawLaw
//
//  Phase 5: Tests for the orchestrator wrapping BaseOrchestrator
//  with approval queue integration for escalated actions.
//

import Testing
import Foundation
import SwiftVectorCore
import SwiftVectorTesting
@testable import ClawLawCore

@Suite("ClawLawOrchestrator")
struct ClawLawOrchestratorTests {

    let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    func makeOrchestrator(
        taskCeiling: Int = 10000,
        writablePaths: Set<String> = ["/workspace"],
        protectedPatterns: Set<String> = [".ssh", "credentials"]
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

    // MARK: - Allowed actions flow through to reducer

    @Test("Research in normal state is allowed and deducts budget")
    func researchAllowed() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .research(id: fixedID, estimatedTokens: 500),
            agentID: "agent-1"
        )

        #expect(result.outcome == .applied)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 500)
    }

    @Test("Write to allowed path is applied")
    func writeAllowed() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: fixedID, path: "/workspace/test.txt", content: "data"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .applied)
    }

    // MARK: - Denied actions are blocked

    @Test("Write outside sandbox is denied by governance")
    func writeOutsideSandboxDenied() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: fixedID, path: "/etc/passwd", content: "hack"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .denied)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 0, "Budget unchanged on denial")
    }

    @Test("Halted enforcement denies all actions")
    func haltedDenied() async {
        // Construct initial state that is already halted (spend > ceiling)
        let haltedState = GovernanceState.mock(taskCeiling: 100).withBudget(
            BudgetState(taskCeiling: 100, currentSpend: 200, enforcement: .halted)
        )
        let orch = ClawLawOrchestrator(
            initialState: haltedState,
            clock: MockClock(),
            uuidGenerator: MockUUIDGenerator(sequential: 1)
        )
        let result = await orch.propose(
            .research(id: fixedID, estimatedTokens: 10),
            agentID: "agent-1"
        )

        #expect(result.outcome == .denied)
    }

    // MARK: - Escalated actions go to approval queue

    @Test("Delete file is escalated to approval queue")
    func deleteEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .deleteFile(id: fixedID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
        #expect(result.approvalID != nil)

        let pending = await orch.pendingApprovals()
        #expect(pending.count == 1)
    }

    @Test("Shell command is escalated to approval queue")
    func shellEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .executeShellCommand(id: fixedID, command: "ls"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    @Test("Send email is escalated to approval queue")
    func emailEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .sendEmail(id: fixedID, to: "a@b.com", subject: "hi", body: "test"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    @Test("Write to protected path is escalated")
    func protectedPathEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .writeFile(id: fixedID, path: "/workspace/.ssh/key", content: "secret"),
            agentID: "agent-1"
        )

        #expect(result.outcome == .escalated)
    }

    // MARK: - Approval queue resolution

    @Test("Approved escalated action is applied")
    func approveEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .deleteFile(id: fixedID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )
        guard let approvalID = result.approvalID else {
            Issue.record("Expected approval ID")
            return
        }

        let approved = await orch.approveEscalated(id: approvalID)
        #expect(approved)

        let state = await orch.currentState
        // deleteFile costs 50 tokens
        #expect(state.budget.currentSpend == 50)
    }

    @Test("Rejected escalated action does not affect state")
    func rejectEscalated() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .deleteFile(id: fixedID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )
        guard let approvalID = result.approvalID else {
            Issue.record("Expected approval ID")
            return
        }

        await orch.rejectEscalated(id: approvalID, reason: "Not now")

        let state = await orch.currentState
        #expect(state.budget.currentSpend == 0)

        let pending = await orch.pendingApprovals()
        #expect(pending.isEmpty)
    }

    // MARK: - Steward interventions bypass governance

    @Test("IncreaseBudget bypasses governance and applies directly")
    func increaseBudget() async {
        let orch = makeOrchestrator(taskCeiling: 1000)
        let result = await orch.propose(
            .increaseBudget(id: fixedID, newCeiling: 20000),
            agentID: "steward"
        )

        #expect(result.outcome == .applied)
        let state = await orch.currentState
        #expect(state.budget.taskCeiling == 20000)
    }

    @Test("ResetBudget bypasses governance and applies directly")
    func resetBudget() async {
        let orch = makeOrchestrator(taskCeiling: 10000)
        // Spend some budget first
        let _ = await orch.propose(
            .research(id: fixedID, estimatedTokens: 5000),
            agentID: "agent-1"
        )
        let result = await orch.propose(
            .resetBudget(id: fixedID),
            agentID: "steward"
        )

        #expect(result.outcome == .applied)
        let state = await orch.currentState
        #expect(state.budget.currentSpend == 0)
    }

    // MARK: - Governance trace is captured

    @Test("Proposal result includes governance trace")
    func governanceTracePresent() async {
        let orch = makeOrchestrator()
        let result = await orch.propose(
            .research(id: fixedID, estimatedTokens: 500),
            agentID: "agent-1"
        )

        #expect(result.trace != nil)
        #expect(result.trace?.jurisdictionID == "ClawLaw")
    }

    // MARK: - State access

    @Test("currentState reflects latest state")
    func currentStateAccess() async {
        let orch = makeOrchestrator(taskCeiling: 10000)
        let _ = await orch.propose(
            .research(id: fixedID, estimatedTokens: 300),
            agentID: "agent-1"
        )
        let _ = await orch.propose(
            .research(id: fixedID, estimatedTokens: 200),
            agentID: "agent-1"
        )

        let state = await orch.currentState
        #expect(state.budget.currentSpend == 500)
    }
}
