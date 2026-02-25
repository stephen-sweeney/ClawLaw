//
//  Steward.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  PHASE 1 STUB: The Steward will be refactored to a thin wrapper
//  dispatching GovernanceAction cases through the orchestrator in Phase 5.
//
//  The original Steward logic is preserved in git history.
//

import Foundation
import SwiftVectorCore

/// Placeholder Steward for Phase 1 compilation.
/// Phase 5 will refactor this to dispatch GovernanceAction cases
/// through the ClawLawOrchestrator.
public actor Steward {

    private var state: GovernanceState
    private let approvalQueue: ApprovalQueue

    public init(
        initialState: GovernanceState,
        clock: any Clock,
        uuidGenerator: any UUIDGenerator
    ) {
        self.state = initialState
        self.approvalQueue = ApprovalQueue(clock: clock, uuidGenerator: uuidGenerator)
    }

    public func currentState() -> GovernanceState {
        return state
    }

    public func budgetStatus() -> BudgetStatus {
        return BudgetStatus(
            ceiling: state.budget.taskCeiling,
            spent: state.budget.currentSpend,
            remaining: state.budget.remainingBudget,
            utilizationPercent: Int(state.budget.utilizationRatio * 100),
            enforcement: state.budget.enforcement
        )
    }

    public struct BudgetStatus: Sendable {
        public let ceiling: Int
        public let spent: Int
        public let remaining: Int
        public let utilizationPercent: Int
        public let enforcement: BudgetState.EnforcementLevel

        public var description: String {
            return """
            Budget: \(spent)/\(ceiling) tokens (\(utilizationPercent)%)
            Remaining: \(remaining) tokens
            Enforcement: \(enforcement.rawValue)
            """
        }
    }
}
