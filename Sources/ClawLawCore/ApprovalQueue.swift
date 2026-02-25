//
//  ApprovalQueue.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  Phase 1: Updated to use GovernanceAction and injected Clock/UUIDGenerator.
//  The original logic is preserved in git history (commit before this branch).
//

import Foundation
import SwiftVectorCore

/// Actor-isolated approval queue for high-risk actions.
/// Implements Law 8 (Authority) - human command and approval.
public actor ApprovalQueue {

    // MARK: - Types

    public struct PendingAction: Identifiable, Sendable {
        public let id: UUID
        public let action: GovernanceAction
        public let level: AuthorizationLevel
        public let reason: String
        public let submittedAt: Date
        public let agentId: String?

        public init(
            id: UUID,
            action: GovernanceAction,
            level: AuthorizationLevel,
            reason: String,
            submittedAt: Date,
            agentId: String? = nil
        ) {
            self.id = id
            self.action = action
            self.level = level
            self.reason = reason
            self.submittedAt = submittedAt
            self.agentId = agentId
        }
    }

    public enum Resolution: Equatable, Sendable {
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
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerator

    // MARK: - Initialization

    public init(clock: any Clock, uuidGenerator: any UUIDGenerator) {
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    // MARK: - Submission

    /// Submit an action for human approval
    public func submit(
        action: GovernanceAction,
        level: AuthorizationLevel,
        reason: String,
        agentId: String? = nil
    ) -> UUID {
        let id = uuidGenerator.next()
        let pendingAction = PendingAction(
            id: id,
            action: action,
            level: level,
            reason: reason,
            submittedAt: clock.now(),
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
    public func approve(id: UUID) -> GovernanceAction? {
        guard let index = pending.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let action = pending[index].action
        pending.remove(at: index)
        resolved[id] = .approved(clock.now())
        return action
    }

    /// Reject an action with a reason
    public func reject(id: UUID, reason: String = "Denied by Steward") {
        pending.removeAll { $0.id == id }
        resolved[id] = .rejected(reason, clock.now())
    }

    /// Check if an action has been resolved
    public func isResolved(id: UUID) -> Resolution? {
        return resolved[id]
    }

    // MARK: - Bulk Operations

    /// Approve all pending actions below a certain authorization level
    public func approveAllBelow(level: AuthorizationLevel) -> [GovernanceAction] {
        let approved = pending.filter { $0.level < level }
        pending.removeAll { $0.level < level }

        let timestamp = clock.now()
        for action in approved {
            resolved[action.id] = .approved(timestamp)
        }

        return approved.map { $0.action }
    }

    /// Clear resolved actions older than specified age
    public func clearResolved(olderThan age: TimeInterval) {
        let cutoff = clock.now().addingTimeInterval(-age)
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

    public struct Statistics: Sendable {
        public let pendingCount: Int
        public let resolvedCount: Int
        public let byLevel: [AuthorizationLevel: Int]
    }
}
