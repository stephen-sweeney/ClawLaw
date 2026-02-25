//
//  ProtectedPatternLaw.swift
//  ClawLaw
//
//  Protected file pattern enforcement. Escalates any path-bearing
//  action that matches a configured protected pattern (e.g. .ssh,
//  credentials). Non-path actions abstain.
//

import SwiftVectorCore

public struct ProtectedPatternLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "ProtectedPatternLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        guard let path = action.targetPath else {
            return LawVerdict(
                lawID: lawID,
                decision: .abstain,
                reason: "Action has no filesystem path — outside jurisdiction"
            )
        }

        if state.isPathProtected(path) {
            return LawVerdict(
                lawID: lawID,
                decision: .escalate,
                reason: "Path \(path) matches protected pattern — steward approval required"
            )
        }

        return LawVerdict(
            lawID: lawID,
            decision: .allow,
            reason: "Path \(path) does not match any protected pattern"
        )
    }
}
