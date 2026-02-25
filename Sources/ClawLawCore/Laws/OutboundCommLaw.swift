//
//  OutboundCommLaw.swift
//  ClawLaw
//
//  All outbound communications (email, etc.) require steward approval.
//  Non-communication actions abstain.
//

import SwiftVectorCore

public struct OutboundCommLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "OutboundCommLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        if case .sendEmail = action {
            return LawVerdict(
                lawID: lawID,
                decision: .escalate,
                reason: "Outbound communication requires steward approval"
            )
        }

        return LawVerdict(
            lawID: lawID,
            decision: .abstain,
            reason: "Not an outbound communication — outside jurisdiction"
        )
    }
}
