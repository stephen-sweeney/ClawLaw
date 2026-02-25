//
//  EnforcementGateLaw.swift
//  ClawLaw
//
//  Budget enforcement gating. Implements the first governance check:
//  halted systems are fully denied, gated systems require approval
//  for any action that costs tokens.
//

import SwiftVectorCore

public struct EnforcementGateLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "EnforcementGateLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        switch state.budget.enforcement {
        case .halted:
            return LawVerdict(
                lawID: lawID,
                decision: .deny,
                reason: "Budget enforcement halted — all actions denied until steward reset"
            )
        case .gated where action.tokenCost > 0:
            return LawVerdict(
                lawID: lawID,
                decision: .escalate,
                reason: "Budget gated — approval required for actions costing \(action.tokenCost) tokens"
            )
        case .gated, .degraded, .normal:
            return LawVerdict(
                lawID: lawID,
                decision: .allow,
                reason: "Enforcement level \(state.budget.enforcement.rawValue) permits action"
            )
        }
    }
}
