//
//  StewardTests.swift
//  ClawLaw
//
//  Phase 5: Tests for the thin Steward wrapper dispatching
//  GovernanceAction cases through the orchestrator.
//

import Testing
import Foundation
import SwiftVectorCore
import SwiftVectorTesting
@testable import ClawLawCore

@Suite("Steward")
struct StewardTests {

    let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    func makeSteward(taskCeiling: Int = 10000) -> Steward {
        let state = GovernanceState.mock(taskCeiling: taskCeiling)
        return Steward(
            initialState: state,
            clock: MockClock(),
            uuidGenerator: MockUUIDGenerator(sequential: 1)
        )
    }

    // MARK: - Budget status

    @Test("Budget status reflects current state")
    func budgetStatus() async {
        let steward = makeSteward(taskCeiling: 10000)
        let status = await steward.budgetStatus()

        #expect(status.ceiling == 10000)
        #expect(status.spent == 0)
        #expect(status.remaining == 10000)
        #expect(status.enforcement == .normal)
    }

    // MARK: - Steward interventions

    @Test("IncreaseBudget updates ceiling through orchestrator")
    func increaseBudget() async {
        let steward = makeSteward(taskCeiling: 1000)
        await steward.increaseBudget(to: 20000)

        let status = await steward.budgetStatus()
        #expect(status.ceiling == 20000)
    }

    @Test("ResetBudget zeros spend through orchestrator")
    func resetBudget() async {
        let steward = makeSteward(taskCeiling: 10000)

        // Spend some budget through the orchestrator
        let _ = await steward.orchestrator.propose(
            .research(id: fixedID, estimatedTokens: 5000),
            agentID: "agent-1"
        )

        await steward.resetBudget()

        let status = await steward.budgetStatus()
        #expect(status.spent == 0)
        #expect(status.enforcement == .normal)
    }

    // MARK: - Approval management

    @Test("Approve escalated action through steward")
    func approveAction() async {
        let steward = makeSteward()

        // Propose a deletable action (will be escalated)
        let result = await steward.orchestrator.propose(
            .deleteFile(id: fixedID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )
        guard let approvalID = result.approvalID else {
            Issue.record("Expected approval ID")
            return
        }

        let approved = await steward.approve(id: approvalID)
        #expect(approved)
    }

    @Test("Reject escalated action through steward")
    func rejectAction() async {
        let steward = makeSteward()

        let result = await steward.orchestrator.propose(
            .deleteFile(id: fixedID, path: "/workspace/old.txt"),
            agentID: "agent-1"
        )
        guard let approvalID = result.approvalID else {
            Issue.record("Expected approval ID")
            return
        }

        await steward.reject(id: approvalID, reason: "Not authorized")

        let pending = await steward.pendingApprovals()
        #expect(pending.isEmpty)
    }

    // MARK: - Pending approvals

    @Test("Steward lists pending approvals")
    func listPending() async {
        let steward = makeSteward()

        let _ = await steward.orchestrator.propose(
            .deleteFile(id: fixedID, path: "/workspace/a.txt"),
            agentID: "agent-1"
        )
        let _ = await steward.orchestrator.propose(
            .executeShellCommand(id: fixedID, command: "ls"),
            agentID: "agent-1"
        )

        let pending = await steward.pendingApprovals()
        #expect(pending.count == 2)
    }
}
