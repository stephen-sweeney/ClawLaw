//
//  GovernanceReducer.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  Pure budget mutation reducer. Governance (deny/escalate) is handled
//  by Laws (Phase 2). This reducer handles ONLY:
//  - Token cost deduction and affordability checks
//  - Enforcement level transitions (via BudgetState reconciliation)
//  - Steward interventions (budget increase, reset)
//  - Queue-only actions (approve/reject pass through unchanged)
//

import SwiftVectorCore

public struct ClawLawReducer: Reducer, Sendable {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public init() {}

    public func reduce(state: GovernanceState, action: GovernanceAction) -> ReducerResult<GovernanceState> {
        switch action {
        // MARK: - Steward interventions

        case .increaseBudget(_, let newCeiling):
            // Steward override: recalculate enforcement from scratch
            // (withCeiling preserves old enforcement via max(), but steward
            // interventions should allow enforcement to relax)
            let newBudget = BudgetState(
                taskCeiling: newCeiling,
                currentSpend: state.budget.currentSpend,
                enforcement: .normal,
                warningThreshold: state.budget.warningThreshold,
                criticalThreshold: state.budget.criticalThreshold
            )
            return .accepted(
                state.withBudget(newBudget),
                rationale: "Budget ceiling increased to \(newCeiling)"
            )

        case .resetBudget:
            return .accepted(
                state.withBudget(state.budget.reset()),
                rationale: "Budget reset — spend zeroed, enforcement restored to normal"
            )

        case .approveAction, .rejectAction:
            // Queue operations — no state mutation, handled by orchestrator
            return .accepted(state, rationale: "Approval queue operation acknowledged")

        // MARK: - Agent actions (budget deduction)

        default:
            return deductBudget(state: state, action: action)
        }
    }

    // MARK: - Budget deduction

    private func deductBudget(
        state: GovernanceState,
        action: GovernanceAction
    ) -> ReducerResult<GovernanceState> {
        let cost = action.tokenCost

        guard state.budget.canAfford(cost) else {
            return .rejected(
                state,
                rationale: "Cannot afford \(cost) tokens — \(state.budget.remainingBudget) remaining of \(state.budget.taskCeiling)"
            )
        }

        let newSpend = state.budget.currentSpend + cost
        let newBudget = state.budget.withSpend(newSpend)
        let newState = state.withBudget(newBudget)

        return .accepted(
            newState,
            rationale: "Budget: \(state.budget.currentSpend) → \(newSpend) tokens (\(newBudget.enforcement.rawValue))"
        )
    }
}
