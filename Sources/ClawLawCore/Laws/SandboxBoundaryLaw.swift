//
//  SandboxBoundaryLaw.swift
//  ClawLaw
//
//  Filesystem sandbox enforcement. Denies any path-bearing action
//  (write, delete) that targets a path outside the configured
//  writable paths. Non-path actions abstain.
//

import SwiftVectorCore

public struct SandboxBoundaryLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "SandboxBoundaryLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        guard let path = action.targetPath else {
            return LawVerdict(
                lawID: lawID,
                decision: .abstain,
                reason: "Action has no filesystem path — outside jurisdiction"
            )
        }

        if state.isPathAllowed(path) {
            return LawVerdict(
                lawID: lawID,
                decision: .allow,
                reason: "Path \(path) is within sandbox"
            )
        }

        return LawVerdict(
            lawID: lawID,
            decision: .deny,
            reason: "Path \(path) is outside sandbox boundary"
        )
    }
}
