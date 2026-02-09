//
//  Orchestrator.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// The Orchestrator manages the deterministic control loop.
/// State → Agent → Action → Reducer → New State
public actor GovernanceOrchestrator {
    
    // MARK: - State
    
    private let steward: Steward
    private let agentId: String
    
    // MARK: - Initialization
    
    public init(initialState: GovernanceState, agentId: String = "OpenClaw") {
        self.steward = Steward(initialState: initialState)
        self.agentId = agentId
    }
    
    // MARK: - Core Control Loop
    
    /// Propose an action for governance evaluation
    public func propose(_ action: AgentAction) async -> ProposalResult {
        let currentState = await steward.currentState()
        
        // Apply the reducer
        let effect = GovernanceReducer.reduce(state: currentState, action: action)
        
        // Handle the effect
        switch effect {
        case .allow(let newState):
            await steward.updateState(newState)
            return .allowed(message: "Action approved. \(formatBudgetStatus(newState))")
            
        case .transition(let newState, let message):
            await steward.updateState(newState)
            return .allowedWithWarning(message: message)
            
        case .reject(let reason):
            return .rejected(reason: reason)
            
        case .requireApproval(let level, let reason):
            let approvalId = await steward.submitForApproval(
                action: action,
                level: level,
                reason: reason,
                agentId: agentId
            )
            return .suspended(
                approvalId: approvalId,
                message: "Action requires \(level) authorization: \(reason)"
            )
        }
    }
    
    public enum ProposalResult {
        case allowed(message: String)
        case allowedWithWarning(message: String)
        case rejected(reason: String)
        case suspended(approvalId: UUID, message: String)
        
        public var isAllowed: Bool {
            switch self {
            case .allowed, .allowedWithWarning:
                return true
            default:
                return false
            }
        }
        
        public var message: String {
            switch self {
            case .allowed(let msg), .allowedWithWarning(let msg):
                return msg
            case .rejected(let reason):
                return "❌ REJECTED: \(reason)"
            case .suspended(_, let msg):
                return "⏸️ SUSPENDED: \(msg)"
            }
        }
    }
    
    // MARK: - Batch Operations
    
    /// Propose multiple actions in sequence
    public func proposeSequence(_ actions: [AgentAction]) async -> [ProposalResult] {
        var results: [ProposalResult] = []
        
        for action in actions {
            let result = await propose(action)
            results.append(result)
            
            // Stop processing if any action is rejected or suspended
            if !result.isAllowed {
                break
            }
        }
        
        return results
    }
    
    // MARK: - State Access
    
    public func currentState() async -> GovernanceState {
        return await steward.currentState()
    }
    
    public func budgetStatus() async -> Steward.BudgetStatus {
        return await steward.budgetStatus()
    }
    
    // MARK: - Steward Delegation
    
    /// Provides access to the Steward for human oversight
    public func getSteward() -> Steward {
        return steward
    }
    
    /// Reject a pending action
    public func reject(actionId: UUID, reason: String = "Denied by Steward") async {
        await steward.reject(actionId: actionId, reason: reason)
    }
    
    /// Approve a pending action
    public func approve(actionId: UUID) async -> Steward.ApprovalResult {
        return await steward.approve(actionId: actionId)
    }
    
    /// Increase the budget ceiling
    public func increaseBudget(to newCeiling: Int) async -> GovernanceState {
        return await steward.increaseBudget(to: newCeiling)
    }
    
    /// Reset the budget spend counter
    public func resetBudget() async -> GovernanceState {
        return await steward.resetBudget()
    }
    
    /// Get recent audit entries
    public func recentAuditEntries(limit: Int = 10) async -> [AuditEntry] {
        return await steward.recentAuditEntries(limit: limit)
    }
    
    /// Get pending approvals
    public func pendingApprovals() async -> [ApprovalQueue.PendingAction] {
        return await steward.pendingApprovals()
    }
    
    /// Get statistics
    public func statistics() async -> Steward.Statistics {
        return await steward.statistics()
    }
    
    // MARK: - Utility
    
    private func formatBudgetStatus(_ state: GovernanceState) -> String {
        let percent = Int(state.budget.utilizationRatio * 100)
        return "Budget: \(state.budget.currentSpend)/\(state.budget.taskCeiling) tokens (\(percent)%)"
    }
}
