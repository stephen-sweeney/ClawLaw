//
//  ClawLawPolicy.swift
//  ClawLaw
//
//  Factory composing all 6 ClawLaw governance laws with denyWins.
//

import SwiftVectorCore

public enum ClawLawPolicy {
    public static func defaultPolicy() -> GovernancePolicy<GovernanceState, GovernanceAction> {
        GovernancePolicy(
            laws: [
                AnyLaw(EnforcementGateLaw()),
                AnyLaw(SandboxBoundaryLaw()),
                AnyLaw(ProtectedPatternLaw()),
                AnyLaw(DeletionApprovalLaw()),
                AnyLaw(ShellCommandApprovalLaw()),
                AnyLaw(OutboundCommLaw()),
            ],
            compositionRule: .denyWins,
            jurisdictionID: "ClawLaw"
        )
    }
}
