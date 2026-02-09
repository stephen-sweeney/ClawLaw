//
//  File.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Testing
import Foundation
@testable import ClawLawCore

@Suite("Governance Safety Tests")
struct SafetyTests {
    
    @Test("Sandbox rejects writes outside authorized workspace")
    func sandboxRejection() {
        // Arrange: Establish deterministic boundary
        let state = GovernanceState.mock(writablePaths: ["/Users/steward/workspace"])
        let action = AgentAction.writeFile(path: "/etc/passwd", content: "root:pass")
        
        // Act: Run through the pure-function Reducer
        let result = GovernanceReducer.reduce(state: state, action: action)
        
        // Assert: Verify enforcement using Swift Testing macros
        if case .reject(let reason) = result {
            #expect(reason.contains("outside authorized workspace"))
        } else {
            Issue.record("Safety violation: Reducer allowed write to system path.")
        }
    }

    @Test("Budget ceiling transitions system to degraded state")
    func budgetCircuitBreaker() {
        // Arrange: Set task-level cost limits at 80% to trigger degraded state
        var state = GovernanceState.mock(taskCeiling: 1000)
        state.budget.currentSpend = 700  // Start at 70%
        
        // Act: Evaluate state transition - adding 150 tokens = 85% total (triggers degraded)
        let action = AgentAction.research(estimatedTokens: 150)
        let result = GovernanceReducer.reduce(state: state, action: action)
        
        // Assert: Ensure the 'Budget Governor' transitioned the state
        if case .transition(let newState, let message) = result {
            #expect(newState.budget.enforcement == .degraded, "Should transition to degraded state")
            #expect(message.contains("WARNING"), "Should include warning message")
        } else {
            Issue.record("Budget failure: Reducer did not trigger circuit breaker. Got: \(result)")
        }
    }
}

