//
//  File.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// The heart of the SwiftVector pattern—a pure function for authority.
public struct GovernanceReducer {
    public static func reduce(state: GovernanceState, action: AgentAction) -> ActionEffect {
        switch action {
        case .writeFile(let path, _):
            // 1. Sandbox Check: Enforce filesystem boundaries
            guard state.writablePaths.contains(where: { path.hasPrefix($0) }) else {
                return .reject("Access denied: \(path) is outside authorized workspace.")
            }
            // 2. Pattern Check: Protect sensitive files (e.g., .ssh)
            if state.protectedPatterns.contains(where: { path.contains($0.replacingOccurrences(of: "*", with: "")) }) {
                return .requireApproval(level: .sensitive, reason: "Modification of protected file pattern.")
            }
            return .allow(state)
            
        case .research(let cost):
            // 3. Budget Check: Circuit breaker logic
            if cost > state.budget.taskCeiling {
                var newState = state
                newState.budget.enforcement = .degraded
                return .transition(newState)
            }
            return .allow(state)
            
        case .sendEmail:
            // 4. Always gate sensitive outbound operations
            return .requireApproval(level: .sensitive, reason: "Outbound communication requires human gate.")
        }
    }
}
