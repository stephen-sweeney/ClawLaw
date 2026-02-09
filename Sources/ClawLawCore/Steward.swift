//
//  Steward.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// The Steward is the human-in-command.
/// Provides the interface for human oversight and intervention.
public actor Steward {
    
    // MARK: - State
    
    private var state: GovernanceState
    private let approvalQueue: ApprovalQueue
    
    // MARK: - Initialization
    
    public init(initialState: GovernanceState) {
        self.state = initialState
        self.approvalQueue = ApprovalQueue()
    }
    
    // MARK: - State Access
    
    public func currentState() -> GovernanceState {
        return state
    }
    
    public func updateState(_ newState: GovernanceState) {
        state = newState
    }
    
    // MARK: - Budget Management
    
    /// Increase the budget ceiling (Experiment 4: Recovery)
    public func increaseBudget(to newCeiling: Int) -> GovernanceState {
        state = GovernanceReducer.increaseBudget(state: state, newCeiling: newCeiling)
        return state
    }
    
    /// Reset the budget spend counter
    public func resetBudget() -> GovernanceState {
        state = GovernanceReducer.resetBudget(state: state)
        return state
    }
    
    /// Get current budget status
    public func budgetStatus() -> BudgetStatus {
        return BudgetStatus(
            ceiling: state.budget.taskCeiling,
            spent: state.budget.currentSpend,
            remaining: state.budget.remainingBudget,
            utilizationPercent: Int(state.budget.utilizationRatio * 100),
            enforcement: state.budget.enforcement
        )
    }
    
    public struct BudgetStatus {
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
    
    // MARK: - Approval Queue Management
    
    /// Submit an action for approval (called by orchestrator)
    public func submitForApproval(
        action: AgentAction,
        level: AuthorizationLevel,
        reason: String,
        agentId: String? = nil
    ) async -> UUID {
        return await approvalQueue.submit(
            action: action,
            level: level,
            reason: reason,
            agentId: agentId
        )
    }
    
    /// List all pending approvals
    public func pendingApprovals() async -> [ApprovalQueue.PendingAction] {
        return await approvalQueue.listPending()
    }
    
    /// Get a specific pending action
    public func getPendingAction(id: UUID) async -> ApprovalQueue.PendingAction? {
        return await approvalQueue.getPending(id: id)
    }
    
    /// Approve an action and return the new state
    public func approve(actionId: UUID) async -> ApprovalResult {
        guard let action = await approvalQueue.approve(id: actionId) else {
            return .notFound
        }
        
        // Apply the action through the reducer with bypassGate = true
        // This allows approved actions to execute even in gated mode
        let effect = GovernanceReducer.reduce(state: state, action: action, bypassGate: true)
        
        switch effect {
        case .allow(let newState):
            state = newState
            return .executed(newState)
            
        case .transition(let newState, let message):
            state = newState
            return .executedWithWarning(newState, message: message)
            
        case .reject(let reason):
            return .rejected(reason)
            
        case .requireApproval:
            // This should rarely happen now that we bypass gating
            // Could still occur if action-specific validation requires additional approval
            return .rejected("Action requires additional approval due to validation rules")
        }
    }
    
    /// Reject an action
    public func reject(actionId: UUID, reason: String = "Denied by Steward") async {
        await approvalQueue.reject(id: actionId, reason: reason)
    }
    
    /// Approve all pending actions below a certain risk level
    public func approveAllBelow(level: AuthorizationLevel) async -> [ApprovalResult] {
        let actions = await approvalQueue.approveAllBelow(level: level)
        
        var results: [ApprovalResult] = []
        for action in actions {
            // Use bypassGate for batch approvals too
            let effect = GovernanceReducer.reduce(state: state, action: action, bypassGate: true)
            switch effect {
            case .allow(let newState):
                state = newState
                results.append(.executed(newState))
            case .transition(let newState, let message):
                state = newState
                results.append(.executedWithWarning(newState, message: message))
            case .reject(let reason):
                results.append(.rejected(reason))
            case .requireApproval:
                results.append(.rejected("Requires additional approval"))
            }
        }
        
        return results
    }
    
    public enum ApprovalResult {
        case executed(GovernanceState)
        case executedWithWarning(GovernanceState, message: String)
        case rejected(String)
        case notFound
    }
    
    // MARK: - Audit Trail
    
    /// Get the complete audit trail
    public func auditTrail() -> [AuditEntry] {
        return state.auditLog
    }
    
    /// Get recent audit entries
    public func recentAuditEntries(limit: Int = 10) -> [AuditEntry] {
        return Array(state.auditLog.suffix(limit))
    }
    
    /// Export audit trail as JSON
    public func exportAuditTrail() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state.auditLog)
    }
    
    // MARK: - Workspace Management
    
    /// Add a path to the writable workspace
    public func addWritablePath(_ path: String) {
        state.writablePaths.insert(path)
    }
    
    /// Remove a path from the writable workspace
    public func removeWritablePath(_ path: String) {
        state.writablePaths.remove(path)
    }
    
    /// Add a protected file pattern
    public func addProtectedPattern(_ pattern: String) {
        state.protectedPatterns.insert(pattern)
    }
    
    /// Remove a protected file pattern
    public func removeProtectedPattern(_ pattern: String) {
        state.protectedPatterns.remove(pattern)
    }
    
    // MARK: - Statistics
    
    public func statistics() async -> Statistics {
        let queueStats = await approvalQueue.statistics()
        
        return Statistics(
            totalActions: state.auditLog.count,
            budgetUtilization: state.budget.utilizationRatio,
            currentEnforcement: state.budget.enforcement,
            pendingApprovals: queueStats.pendingCount,
            writablePaths: state.writablePaths.count,
            protectedPatterns: state.protectedPatterns.count
        )
    }
    
    public struct Statistics {
        public let totalActions: Int
        public let budgetUtilization: Double
        public let currentEnforcement: BudgetState.EnforcementLevel
        public let pendingApprovals: Int
        public let writablePaths: Int
        public let protectedPatterns: Int
        
        public var description: String {
            return """
            === ClawLaw Statistics ===
            Total Actions: \(totalActions)
            Budget Utilization: \(Int(budgetUtilization * 100))%
            Enforcement Level: \(currentEnforcement.rawValue)
            Pending Approvals: \(pendingApprovals)
            Writable Paths: \(writablePaths)
            Protected Patterns: \(protectedPatterns)
            """
        }
    }
}
