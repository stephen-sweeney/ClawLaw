//
//  DeletionApprovalLaw.swift
//  ClawLaw
//
//  All file deletions require steward approval. No exceptions.
//  Non-delete actions abstain.
//

import SwiftVectorCore

public struct DeletionApprovalLaw: Law {
    public typealias S = GovernanceState
    public typealias A = GovernanceAction

    public let lawID = "DeletionApprovalLaw"

    public init() {}

    public func evaluate(state: GovernanceState, action: GovernanceAction) -> LawVerdict {
        if case .deleteFile = action {
            return LawVerdict(
                lawID: lawID,
                decision: .escalate,
                reason: "File deletion requires steward approval"
            )
        }

        return LawVerdict(
            lawID: lawID,
            decision: .abstain,
            reason: "Not a deletion action — outside jurisdiction"
        )
    }
}
