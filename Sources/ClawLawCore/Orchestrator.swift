//
//  Orchestrator.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  Wraps BaseOrchestrator with governance evaluation and approval queue.
//  The orchestrator evaluates ClawLawPolicy BEFORE submitting to base,
//  routing .escalate decisions to the ApprovalQueue instead of rejecting.
//

import Foundation
import SwiftVectorCore

// MARK: - Proposal Result

/// The outcome of proposing an action to the governance system.
public struct ProposalResult: Sendable {
    public let outcome: ProposalOutcome
    public let trace: CompositionTrace?
    public let approvalID: UUID?
    public let rationale: String

    public enum ProposalOutcome: Sendable, Equatable {
        case applied     // Governance allowed, reducer accepted
        case rejected    // Governance allowed, but reducer rejected (e.g. can't afford)
        case denied      // Governance denied outright
        case escalated   // Governance escalated — awaiting steward approval
    }
}

// MARK: - ClawLawOrchestrator

public actor ClawLawOrchestrator {

    private let base: BaseOrchestrator<GovernanceState, GovernanceAction, ClawLawReducer>
    private let policy: GovernancePolicy<GovernanceState, GovernanceAction>
    private let approvalQueue: ApprovalQueue
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerator

    public var currentState: GovernanceState {
        get async { await base.currentState }
    }

    public init(
        initialState: GovernanceState,
        clock: any Clock,
        uuidGenerator: any UUIDGenerator
    ) {
        // BaseOrchestrator runs WITHOUT governance — we handle it ourselves
        // to support .escalate routing to the approval queue.
        self.base = BaseOrchestrator(
            initialState: initialState,
            reducer: ClawLawReducer(),
            clock: clock,
            uuidGenerator: uuidGenerator,
            governancePolicy: nil
        )
        self.policy = ClawLawPolicy.defaultPolicy()
        self.approvalQueue = ApprovalQueue(clock: clock, uuidGenerator: uuidGenerator)
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    // MARK: - Action Proposal

    /// Propose an action through the full governance pipeline.
    ///
    /// Flow:
    /// 1. Steward actions bypass governance → submit directly to base
    /// 2. Evaluate governance policy → CompositionTrace
    /// 3. `.allow` → submit to base (reducer handles budget)
    /// 4. `.deny` → block, return trace
    /// 5. `.escalate` → queue for steward approval
    @discardableResult
    public func propose(_ action: GovernanceAction, agentID: String) async -> ProposalResult {
        // Steward interventions bypass governance
        if action.isStewardAction {
            let result = await base.submit(action, agentID: agentID)
            return ProposalResult(
                outcome: result.applied ? .applied : .rejected,
                trace: nil,
                approvalID: nil,
                rationale: result.rationale
            )
        }

        // Evaluate governance
        let state = await base.currentState
        let trace = policy.evaluate(
            state: state,
            action: action,
            correlationID: action.correlationID
        )

        switch trace.composedDecision {
        case .allow, .abstain:
            let result = await base.submit(action, agentID: agentID)
            return ProposalResult(
                outcome: result.applied ? .applied : .rejected,
                trace: trace,
                approvalID: nil,
                rationale: result.rationale
            )

        case .deny:
            return ProposalResult(
                outcome: .denied,
                trace: trace,
                approvalID: nil,
                rationale: denyRationale(from: trace)
            )

        case .escalate:
            let approvalID = await approvalQueue.submit(
                action: action,
                level: action.authorizationLevel,
                reason: escalateRationale(from: trace),
                agentId: agentID
            )
            return ProposalResult(
                outcome: .escalated,
                trace: trace,
                approvalID: approvalID,
                rationale: escalateRationale(from: trace)
            )
        }
    }

    // MARK: - Approval Queue

    /// Approve an escalated action and apply it through the reducer.
    @discardableResult
    public func approveEscalated(id: UUID) async -> Bool {
        guard let action = await approvalQueue.approve(id: id) else {
            return false
        }
        let result = await base.submit(action, agentID: "steward-approved")
        return result.applied
    }

    /// Reject an escalated action.
    public func rejectEscalated(id: UUID, reason: String) async {
        await approvalQueue.reject(id: id, reason: reason)
    }

    /// List all pending approval queue entries.
    public func pendingApprovals() async -> [ApprovalQueue.PendingAction] {
        await approvalQueue.listPending()
    }

    // MARK: - Audit & State

    public func auditLog() async -> EventLog<GovernanceAction> {
        await base.auditLog()
    }

    public nonisolated func stateStream() -> AsyncStream<GovernanceState> {
        base.stateStream()
    }

    // MARK: - Rationale helpers

    private func denyRationale(from trace: CompositionTrace) -> String {
        let denyReasons = trace.verdicts
            .filter { $0.decision == .deny }
            .map { "\($0.lawID): \($0.reason)" }
        return "Governance denied — \(denyReasons.joined(separator: "; "))"
    }

    private func escalateRationale(from trace: CompositionTrace) -> String {
        let escalateReasons = trace.verdicts
            .filter { $0.decision == .escalate }
            .map { "\($0.lawID): \($0.reason)" }
        return "Requires approval — \(escalateReasons.joined(separator: "; "))"
    }
}
