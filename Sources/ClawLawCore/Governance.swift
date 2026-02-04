//
//  File.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// Levels of authorization for agent actions.
public enum AuthorizationLevel: Int, Codable {
    case readOnly = 0, sandboxWrite = 1, externalNetwork = 2, sensitive = 3, systemMod = 4
}

/// The result of a Reducer's evaluation of a proposed action.
public enum ActionEffect {
    case allow(GovernanceState)
    case reject(String)
    case transition(GovernanceState)
    case requireApproval(level: AuthorizationLevel, reason: String)
}

/// Actions an agent can propose.
public enum AgentAction {
    case writeFile(path: String, content: String)
    case research(estimatedTokens: Int)
    case sendEmail(to: String, subject: String, body: String)
}

/// The deterministic state of the governance system.
public struct GovernanceState {
    public var writablePaths: [String]
    public var protectedPatterns: [String]
    public var budget: BudgetState
    
    public struct BudgetState {
        public var taskCeiling: Int
        public var currentSpend: Int
        public var enforcement: EnforcementLevel
    }

    public enum EnforcementLevel { case normal, degraded, gated, halted }

    public static func mock(writablePaths: [String] = [], protectedPatterns: [String] = [], taskCeiling: Int = 10000) -> GovernanceState {
        return GovernanceState(
            writablePaths: writablePaths,
            protectedPatterns: protectedPatterns,
            budget: BudgetState(taskCeiling: taskCeiling, currentSpend: 0, enforcement: .normal)
        )
    }
}
