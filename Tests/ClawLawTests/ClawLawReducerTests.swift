//
//  ClawLawReducerTests.swift
//  ClawLaw
//
//  Phase 3: TDD tests for the pure budget mutation reducer.
//  The reducer handles ONLY budget math and steward interventions.
//  Governance (deny/escalate) is handled by Laws (Phase 2).
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("ClawLawReducer — Budget Mutation")
struct ClawLawReducerTests {

    let reducer = ClawLawReducer()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Budget deduction

    @Test("Research deducts estimated token cost from budget")
    func researchDeductsCost() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.currentSpend == 500)
        #expect(result.newState.budget.taskCeiling == 10000)
    }

    @Test("Write file deducts fixed cost")
    func writeDeductsCost() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.writeFile(id: actionID, path: "/workspace/f.txt", content: "data")
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.currentSpend == 100) // writeFile costs 100
    }

    @Test("Sequential actions accumulate spend")
    func sequentialSpend() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let r1 = reducer.reduce(
            state: state,
            action: .research(id: actionID, estimatedTokens: 300)
        )
        let r2 = reducer.reduce(
            state: r1.newState,
            action: .research(id: actionID, estimatedTokens: 200)
        )

        #expect(r2.newState.budget.currentSpend == 500)
    }

    // MARK: - Affordability rejection

    @Test("Action exceeding remaining budget is rejected")
    func cannotAfford() {
        let state = GovernanceState.mock(taskCeiling: 100)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 200)
        let result = reducer.reduce(state: state, action: action)

        #expect(!result.applied)
        #expect(result.newState.budget.currentSpend == 0, "Spend unchanged on rejection")
        #expect(result.rationale.contains("afford"))
    }

    @Test("Action exactly at budget limit is accepted")
    func exactBudget() {
        let state = GovernanceState.mock(taskCeiling: 500)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.currentSpend == 500)
    }

    // MARK: - Enforcement transitions

    @Test("Spend crossing warning threshold transitions to degraded")
    func transitionToDegraded() {
        // Warning at 80% of 10000 = 8000
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 8500)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.enforcement == .degraded)
    }

    @Test("Spend crossing critical threshold transitions to gated")
    func transitionToGated() {
        // Critical at 95% of 10000 = 9500
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 9600)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.enforcement == .gated)
    }

    @Test("Spend exceeding ceiling transitions to halted")
    func transitionToHalted() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 10001)

        // Can't afford — rejected before transition
        let result = reducer.reduce(state: state, action: action)
        #expect(!result.applied)
    }

    @Test("Enforcement reconciliation preserves monotonic guarantee")
    func enforcementReconciliation() {
        // Start at 79% (normal), add spend to push to 85% (degraded)
        let state = GovernanceState.mock(taskCeiling: 10000).withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 7900)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 600)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.currentSpend == 8500)
        #expect(result.newState.budget.enforcement == .degraded)
    }

    // MARK: - Steward interventions

    @Test("IncreaseBudget updates ceiling and recalculates enforcement")
    func increaseBudget() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 1000, currentSpend: 950, enforcement: .gated)
        )
        let action = GovernanceAction.increaseBudget(id: actionID, newCeiling: 20000)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.taskCeiling == 20000)
        #expect(result.newState.budget.currentSpend == 950)
        // 950/20000 = 4.75% → normal
        #expect(result.newState.budget.enforcement == .normal)
    }

    @Test("ResetBudget zeros spend and restores normal enforcement")
    func resetBudget() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 9800, enforcement: .gated)
        )
        let action = GovernanceAction.resetBudget(id: actionID)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState.budget.currentSpend == 0)
        #expect(result.newState.budget.enforcement == .normal)
    }

    @Test("ApproveAction is accepted with unchanged state")
    func approveAction() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let approvalId = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let action = GovernanceAction.approveAction(id: actionID, approvalId: approvalId)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState == state, "Approve is a queue op — state unchanged")
    }

    @Test("RejectAction is accepted with unchanged state")
    func rejectAction() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let approvalId = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
        let action = GovernanceAction.rejectAction(id: actionID, approvalId: approvalId, reason: "no")
        let result = reducer.reduce(state: state, action: action)

        #expect(result.applied)
        #expect(result.newState == state, "Reject is a queue op — state unchanged")
    }

    // MARK: - Zero-cost actions

    @Test("Steward actions have zero cost and don't affect spend")
    func stewardActionsZeroCost() {
        let state = GovernanceState.mock(taskCeiling: 10000).withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 5000)
        )
        let action = GovernanceAction.increaseBudget(id: actionID, newCeiling: 20000)
        let result = reducer.reduce(state: state, action: action)

        #expect(result.newState.budget.currentSpend == 5000, "Spend unchanged by steward action")
    }

    // MARK: - Immutability

    @Test("Original state is never mutated")
    func immutability() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let _ = reducer.reduce(
            state: state,
            action: .research(id: actionID, estimatedTokens: 5000)
        )

        #expect(state.budget.currentSpend == 0, "Original unchanged")
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same result")
    func determinism() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)

        let r1 = reducer.reduce(state: state, action: action)
        let r2 = reducer.reduce(state: state, action: action)

        #expect(r1.newState == r2.newState)
        #expect(r1.applied == r2.applied)
        #expect(r1.rationale == r2.rationale)
    }
}
