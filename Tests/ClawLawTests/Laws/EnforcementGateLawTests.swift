//
//  EnforcementGateLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("EnforcementGateLaw")
struct EnforcementGateLawTests {

    let law = EnforcementGateLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Halted → deny

    @Test("Halted enforcement denies all actions")
    func haltedDeniesAll() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 100, currentSpend: 200, enforcement: .halted)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 10)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .deny)
        #expect(verdict.lawID == "EnforcementGateLaw")
        #expect(verdict.reason.contains("halted"))
    }

    @Test("Halted denies even zero-cost steward actions")
    func haltedDeniesZeroCost() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 100, currentSpend: 200, enforcement: .halted)
        )
        let action = GovernanceAction.resetBudget(id: actionID)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .deny)
    }

    // MARK: - Gated + cost > 0 → escalate

    @Test("Gated enforcement escalates costly actions")
    func gatedEscalatesCostly() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 9600, enforcement: .gated)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
        #expect(verdict.lawID == "EnforcementGateLaw")
        #expect(verdict.reason.contains("gated"))
    }

    @Test("Gated allows zero-cost actions")
    func gatedAllowsZeroCost() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 9600, enforcement: .gated)
        )
        let action = GovernanceAction.resetBudget(id: actionID)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
    }

    // MARK: - Normal / Degraded → allow

    @Test("Normal enforcement allows all actions")
    func normalAllows() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
    }

    @Test("Degraded enforcement allows all actions")
    func degradedAllows() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 8500, enforcement: .degraded)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same verdict")
    func determinism() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 10000, currentSpend: 9600, enforcement: .gated)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
