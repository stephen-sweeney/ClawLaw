//
//  ShellCommandApprovalLaw.swift
//  ClawLaw
//
//  All shell command execution requires steward approval.
//  Non-shell actions abstain.
//

import SwiftVectorCore

public struct ShellCommandApprovalLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "ShellCommandApprovalLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        if case .executeShellCommand = action {
            return LawVerdict(
                lawID: lawID,
                decision: .escalate,
                reason: "Shell command execution requires steward approval"
            )
        }

        return LawVerdict(
            lawID: lawID,
            decision: .abstain,
            reason: "Not a shell command — outside jurisdiction"
        )
    }
}
