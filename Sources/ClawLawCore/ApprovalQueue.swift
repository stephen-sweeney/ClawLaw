//
//  ApprovalQueue.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// Actor-isolated approval queue for high-risk actions.
/// Implements Law 8 (Authority) - human command and approval.
public actor ApprovalQueue {
    
    // MARK: - Types
    
    public struct PendingAction: Identifiable, Codable {
        public let id: UUID
        public let action: AgentAction
        public let level: AuthorizationLevel
        public let reason: String
        public let submittedAt: Date
        public let agentId: String?
        
        public init(
            id: UUID = UUID(),
            action: AgentAction,
            level: AuthorizationLevel,
            reason: String,
            submittedAt: Date = Date(),
            agentId: String? = nil
        ) {
            self.id = id
            self.action = action
            self.level = level
            self.reason = reason
            self.submittedAt = submittedAt  // Use the parameter, not Date()
            self.agentId = agentId
        }
        
        public var age: TimeInterval {
            return Date().timeIntervalSince(submittedAt)
        }
    }
    
    public enum Resolution: Equatable {
        case approved(Date)
        case rejected(String, Date)
        
        public var timestamp: Date {
            switch self {
            case .approved(let date):
                return date
            case .rejected(_, let date):
                return date
            }
        }
    }
    
    // MARK: - State
    
    private var pending: [PendingAction] = []
    private var resolved: [UUID: Resolution] = [:]
    
    // MARK: - Submission
    
    /// Submit an action for human approval
    public func submit(
        action: AgentAction,
        level: AuthorizationLevel,
        reason: String,
        agentId: String? = nil
    ) -> UUID {
        let pendingAction = PendingAction(
            action: action,
            level: level,
            reason: reason,
            agentId: agentId
        )
        pending.append(pendingAction)
        return pendingAction.id
    }
    
    // MARK: - Review
    
    /// List all pending actions awaiting approval
    public func listPending() -> [PendingAction] {
        return pending
    }
    
    /// Get a specific pending action by ID
    public func getPending(id: UUID) -> PendingAction? {
        return pending.first { $0.id == id }
    }
    
    // MARK: - Resolution
    
    /// Approve an action and return it for execution
    public func approve(id: UUID) -> AgentAction? {
        guard let index = pending.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let action = pending[index].action
        pending.remove(at: index)
        resolved[id] = .approved(Date())
        return action
    }
    
    /// Reject an action with a reason
    public func reject(id: UUID, reason: String = "Denied by Steward") {
        pending.removeAll { $0.id == id }
        resolved[id] = .rejected(reason, Date())
    }
    
    /// Check if an action has been resolved
    public func isResolved(id: UUID) -> Resolution? {
        return resolved[id]
    }
    
    // MARK: - Bulk Operations
    
    /// Approve all pending actions below a certain authorization level
    public func approveAllBelow(level: AuthorizationLevel) -> [AgentAction] {
        let approved = pending.filter { $0.level < level }
        pending.removeAll { $0.level < level }
        
        let timestamp = Date()
        for action in approved {
            resolved[action.id] = .approved(timestamp)
        }
        
        return approved.map { $0.action }
    }
    
    /// Clear resolved actions older than specified age
    public func clearResolved(olderThan age: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-age)
        resolved = resolved.filter { _, resolution in
            resolution.timestamp >= cutoff
        }
    }
    
    // MARK: - Statistics
    
    public func statistics() -> Statistics {
        return Statistics(
            pendingCount: pending.count,
            resolvedCount: resolved.count,
            byLevel: Dictionary(grouping: pending, by: { $0.level })
                .mapValues { $0.count }
        )
    }
    
    public struct Statistics {
        public let pendingCount: Int
        public let resolvedCount: Int
        public let byLevel: [AuthorizationLevel: Int]
    }
}
