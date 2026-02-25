//
//  Steward.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  Thin wrapper dispatching GovernanceAction steward interventions
//  through the ClawLawOrchestrator. The Steward is the human-facing
//  interface for budget management and approval queue resolution.
//

import Foundation
import SwiftVectorCore

public actor Steward {

    public let orchestrator: ClawLawOrchestrator
    private let uuidGenerator: any UUIDGenerator

    public init(
        initialState: GovernanceState,
        clock: any Clock,
        uuidGenerator: any UUIDGenerator
    ) {
        self.orchestrator = ClawLawOrchestrator(
            initialState: initialState,
            clock: clock,
            uuidGenerator: uuidGenerator
        )
        self.uuidGenerator = uuidGenerator
    }

    // MARK: - Budget Management

    public func increaseBudget(to newCeiling: Int) async {
        let id = uuidGenerator.next()
        let _ = await orchestrator.propose(
            .increaseBudget(id: id, newCeiling: newCeiling),
            agentID: "steward"
        )
    }

    public func resetBudget() async {
        let id = uuidGenerator.next()
        let _ = await orchestrator.propose(
            .resetBudget(id: id),
            agentID: "steward"
        )
    }

    // MARK: - Approval Queue

    public func approve(id: UUID) async -> Bool {
        await orchestrator.approveEscalated(id: id)
    }

    public func reject(id: UUID, reason: String) async {
        await orchestrator.rejectEscalated(id: id, reason: reason)
    }

    public func pendingApprovals() async -> [ApprovalQueue.PendingAction] {
        await orchestrator.pendingApprovals()
    }

    // MARK: - Status

    public func budgetStatus() async -> BudgetStatus {
        let state = await orchestrator.currentState
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
            """
            Budget: \(spent)/\(ceiling) tokens (\(utilizationPercent)%)
            Remaining: \(remaining) tokens
            Enforcement: \(enforcement.rawValue)
            """
        }
    }
}
