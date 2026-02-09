//
//  ClawLawTests.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Testing
@testable import ClawLawCore

@Suite("ClawLaw Governance Tests")
struct ClawLawTests {
    
    // MARK: - Experiment 1: Normal Operation
    
    @Test("Experiment 1: Normal Operation")
    func normalOperation() async throws {
        // Setup: 10,000 token budget, organize documents (low cost)
        let initialState = GovernanceState.mock(taskCeiling: 10000)
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action: Agent proposes organizing documents (500 tokens)
        let action = AgentAction.research(estimatedTokens: 500)
        let result = await orchestrator.propose(action)
        
        // Assert: Action allowed, remains in Normal tier
        #expect(result.isAllowed, "Normal operation should be allowed")
        
        let state = await orchestrator.currentState()
        #expect(state.budget.currentSpend == 500, "Budget should reflect token spend")
        #expect(state.budget.enforcement == .normal, "Should remain in normal enforcement")
        
        print("✅ Experiment 1: Normal operation - \(result.message)")
    }
    
    // MARK: - Experiment 2: Approaching Limit (Warning State)
    
    @Test("Experiment 2: Approaching Limit (Warning State)")
    func approachingLimit() async throws {
        // Setup: Simulate spending up to 80% threshold
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 7800  // 78% utilized
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action: Detailed documentation (200 tokens) pushes over 80% threshold
        let action = AgentAction.research(estimatedTokens: 200)
        let result = await orchestrator.propose(action)
        
        // Assert: Warning state triggered, agent notified, continues
        switch result {
        case .allowedWithWarning(let message):
            #expect(message.contains("WARNING"), "Should emit warning message")
            print("✅ Experiment 2: Warning triggered - \(message)")
        default:
            Issue.record("Expected allowedWithWarning, got \(result)")
        }
        
        let state = await orchestrator.currentState()
        #expect(state.budget.currentSpend == 8000, "Budget should be 8000")
        #expect(state.budget.enforcement == .degraded, "Should be in degraded enforcement")
    }
    
    // MARK: - Experiment 3: Exceeding Threshold (Critical → Suspended)
    
    @Test("Experiment 3a: Exceeding Threshold - Critical (Gated Mode)")
    func exceedingThresholdCritical() async throws {
        // Setup: Simulate spending to 94%
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 9400  // 94% utilized
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action: Refactor request (600 tokens) pushes to 10000 = 100% exactly (gated threshold)
        let action = AgentAction.research(estimatedTokens: 600)
        let result = await orchestrator.propose(action)
        
        // Assert: Critical state → gated mode transition at exactly 100%
        switch result {
        case .allowedWithWarning(let message):
            #expect(message.contains("CRITICAL"), "Should emit critical warning")
            print("✅ Experiment 3a: Critical threshold - \(message)")
        default:
            Issue.record("Expected allowedWithWarning with CRITICAL, got \(result)")
        }
        
        let state = await orchestrator.currentState()
        #expect(state.budget.enforcement == .gated, "Should be in gated enforcement at 100%")
        #expect(state.budget.currentSpend == 10000, "Budget should be exactly 10000 (100%)")
    }

    @Test("Experiment 3b: Exceeding threshold transitions to halted state")
    func exceedingThresholdHalted() async throws {
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 9900  // 99%
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action that pushes to 101%
        let action = AgentAction.research(estimatedTokens: 200)
        let result = await orchestrator.propose(action)
        
        // Expect transition to halted WITH the spend applied
        guard case .allowedWithWarning(let message) = result else {
            Issue.record("Expected transition to halted, got \(result)")
            return
        }
        #expect(message.contains("HALTED"), "Should indicate halted state")
        
        let state = await orchestrator.currentState()
        #expect(state.budget.currentSpend == 10100, "Spend should be recorded (9900 + 200)")
        #expect(state.budget.enforcement == .halted, "State should be persisted as halted")
        
        print("✅ Experiment 3b: System transitioned to halted, spend recorded")
        
        // Verify subsequent actions are blocked by gate check
        let nextAction = AgentAction.research(estimatedTokens: 10)
        let nextResult = await orchestrator.propose(nextAction)
        
        guard case .rejected(let reason) = nextResult else {
            Issue.record("Expected rejection from gate check, got \(nextResult)")
            return
        }
        #expect(reason.contains("halted"), "Should indicate system is halted")
        print("✅ Experiment 3b: Subsequent actions blocked in halted state")
    }
    
    @Test("Experiment 3c: Reaching Halted State via Transition")
    func reachingHaltedStateViaTransition() async throws {
        // Setup: Start at exactly 95% (gated threshold)
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 9500  // 95% - at gated threshold
        initialState.budget.enforcement = .gated  // Already in gated mode
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // In gated mode, actions require approval first
        // But let's say we got approval and now execute an action that reaches 100%
        // For testing purposes, we can push state to halted by doing a steward operation
        
        // Actually, let's test: if we're at 95% (gated), what happens with a 500 token action?
        // It would be 9500 + 500 = 10000 = 100% = halted
        // But since we're in gated mode, it requires approval first
        
        let action = AgentAction.research(estimatedTokens: 500)
        let result = await orchestrator.propose(action)
        
        // In gated mode, non-zero cost actions require approval
        switch result {
        case .suspended(_, let message):
            #expect(message.contains("Critical budget threshold"), "Should require approval in gated mode")
            print("✅ Experiment 3c: Gated mode requires approval - \(message)")
        default:
            Issue.record("Expected suspension for approval in gated mode, got \(result)")
        }
    }
    
    @Test("Experiment 3d: Halted State Blocks All Actions")
    func haltedStateBlocksAllActions() async throws {
        // Setup: System already in halted state
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 10000  // Exactly at budget
        initialState.budget.enforcement = .halted
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action: Any action while halted
        let action = AgentAction.research(estimatedTokens: 10)
        let result = await orchestrator.propose(action)
        
        // Assert: All actions blocked in halted state
        switch result {
        case .rejected(let reason):
            #expect(reason.contains("halted"), "Should indicate halted state")
            print("✅ Experiment 3d: Halted blocks all actions - \(reason)")
        default:
            Issue.record("Expected rejection, got \(result)")
        }
    }
    
    // MARK: - Experiment 4: Recovery (Human Intervention)
    
    @Test("Experiment 4a: Recovery - Increase Budget")
    func recoveryIncreaseBudget() async throws {
        // Setup: System in degraded state
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 8500  // 85% utilized
        initialState.budget.enforcement = .degraded
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Human increases budget
        let newState = await orchestrator.increaseBudget(to: 20000)
        
        // Assert: State transitions back to Normal
        #expect(newState.budget.taskCeiling == 20000, "Ceiling should be increased")
        #expect(newState.budget.currentSpend == 8500, "Spend unchanged")
        
        // 8500/20000 = 42.5%, should be back to normal
        #expect(newState.budget.enforcement == .normal, "Should transition to normal")
        
        // Verify audit trail
        let auditTrail = await orchestrator.recentAuditEntries(limit: 100)
        let lastEntry = try #require(auditTrail.last, "Should have audit entry")
        #expect(lastEntry.action.contains("STEWARD_INTERVENTION"), "Should log intervention")
        
        print("✅ Experiment 4a: Budget increased, state recovered to normal")
        
        // Now agent can resume normal operation
        let action = AgentAction.research(estimatedTokens: 500)
        let result = await orchestrator.propose(action)
        #expect(result.isAllowed, "Actions should be allowed after recovery")
        
        print("✅ Experiment 4b: Agent resumes normal operation after recovery")
    }
    
    @Test("Experiment 4c: Recovery - Reset Budget")
    func recoveryResetBudget() async throws {
        // Setup: System in halted state
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 10500
        initialState.budget.enforcement = .halted
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Human resets budget
        let newState = await orchestrator.resetBudget()
        
        // Assert: Spend reset, state back to normal
        #expect(newState.budget.currentSpend == 0, "Spend should be reset")
        #expect(newState.budget.enforcement == .normal, "Should be normal")
        
        print("✅ Experiment 4c: Budget reset, system recovered from halt")
    }
    
    // MARK: - Experiment 5: Gaming Attempt
    
    @Test("Experiment 5a: Gaming Attempt - Reducer Does Not Negotiate")
    func gamingAttemptReducerDoesNotNegotiate() async throws {
        // Setup: System near limit
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 9000  // 90% utilized
        initialState.budget.enforcement = .degraded
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Action: Agent tries massive request with "urgent" justification
        // The reducer doesn't see the justification - only the token cost
        let action = AgentAction.research(estimatedTokens: 5000)
        let result = await orchestrator.propose(action)
        
        // Assert: Budget Vector doesn't negotiate - math is math
        switch result {
        case .rejected(let reason):
            #expect(reason.contains("halted") || reason.contains("exhausted"), 
                   "Should reject based on budget math")
            print("✅ Experiment 5a: Gaming attempt blocked - \(reason)")
        case .allowedWithWarning:
            // Might transition to critical/gated if total is under ceiling
            let state = await orchestrator.currentState()
            #expect(state.budget.enforcement != .normal, "Should not be normal")
            print("✅ Experiment 5a: Gaming attempt constrained by enforcement level")
        default:
            Issue.record("Expected rejection or warning, got \(result)")
        }
    }
    
    @Test("Experiment 5b: Gaming Attempt - State Transitions Proceed")
    func gamingAttemptStateTransitionsProceed() async throws {
        // Setup: Multiple actions pushing through enforcement levels
        var initialState = GovernanceState.mock(taskCeiling: 10000)
        initialState.budget.currentSpend = 7900  // 79% - just under warning threshold
        
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // Sequence of actions that push through enforcement levels
        // Note: Once in gated mode, actions require approval
        
        // Action 1: Push to degraded (7900 + 200 = 8100 = 81%)
        var result = await orchestrator.propose(.research(estimatedTokens: 200))
        var state = await orchestrator.currentState()
        print("Action 1: spend=\(state.budget.currentSpend), level=\(state.budget.enforcement)")
        #expect(state.budget.currentSpend == 8100, "Should be 8100")
        #expect(state.budget.enforcement == .degraded, "Should be degraded")
        
        // Action 2: Push to gated (8100 + 1400 = 9500 = 95%)
        result = await orchestrator.propose(.research(estimatedTokens: 1400))
        state = await orchestrator.currentState()
        print("Action 2: spend=\(state.budget.currentSpend), level=\(state.budget.enforcement)")
        #expect(state.budget.currentSpend == 9500, "Should be 9500")
        #expect(state.budget.enforcement == .gated, "Should be gated")
        
        // Action 3: Try to push to halted (9500 + 600 = 10100)
        // But in gated mode, this requires approval FIRST
        result = await orchestrator.propose(.research(estimatedTokens: 600))
        state = await orchestrator.currentState()
        print("Action 3: result=\(result.message), spend=\(state.budget.currentSpend), level=\(state.budget.enforcement)")
        
        // Should be suspended for approval, not executed
        switch result {
        case .suspended(let approvalId, _):
            print("✅ Action suspended for approval in gated mode")
            
            // Now approve it to push to halted
            let approvalResult = await orchestrator.approve(actionId: approvalId)
            print("Approval result: \(approvalResult)")
            
            // After approval and execution, should be halted
            let finalState = await orchestrator.currentState()
            #expect(finalState.budget.currentSpend == 10100, "Final spend should be 10100")
            #expect(finalState.budget.enforcement == .halted, "Should reach halted after approval")
            
        default:
            Issue.record("Expected suspension in gated mode, got \(result)")
        }
        
        print("✅ Experiment 5b: State transitions proceeded through approval workflow")
    }
    
    // MARK: - Additional Tests: Filesystem Boundaries (Law 0)
    
    @Test("Filesystem Boundary: Allowed Path")
    func filesystemBoundaryAllowedPath() async throws {
        let initialState = GovernanceState.mock(
            writablePaths: ["/workspace"],
            taskCeiling: 10000
        )
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        let action = AgentAction.writeFile(path: "/workspace/test.txt", content: "data")
        let result = await orchestrator.propose(action)
        
        #expect(result.isAllowed, "Should allow write to workspace")
        print("✅ Filesystem boundary: Allowed path succeeded")
    }
    
    @Test("Filesystem Boundary: Denied Path")
    func filesystemBoundaryDeniedPath() async throws {
        let initialState = GovernanceState.mock(
            writablePaths: ["/workspace"],
            taskCeiling: 10000
        )
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        let action = AgentAction.writeFile(path: "/etc/passwd", content: "malicious")
        let result = await orchestrator.propose(action)
        
        switch result {
        case .rejected(let reason):
            #expect(reason.contains("outside authorized workspace"), 
                   "Should reject with boundary violation")
            print("✅ Filesystem boundary: Denied path blocked - \(reason)")
        default:
            Issue.record("Expected rejection, got \(result)")
        }
    }
    
    @Test("Filesystem Boundary: Protected Pattern")
    func filesystemBoundaryProtectedPattern() async throws {
        let initialState = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh", "credentials"],
            taskCeiling: 10000
        )
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        let action = AgentAction.writeFile(path: "/workspace/.ssh/id_rsa", content: "keys")
        let result = await orchestrator.propose(action)
        
        switch result {
        case .suspended(_, let message):
            #expect(message.contains("protected file pattern"), 
                   "Should require approval for protected patterns")
            print("✅ Filesystem boundary: Protected pattern requires approval - \(message)")
        default:
            Issue.record("Expected suspension for approval, got \(result)")
        }
    }
    
    // MARK: - Additional Tests: Approval Queue (Law 8)
    
    @Test("Approval Queue: High-Risk Action")
    func approvalQueueHighRiskAction() async throws {
        let initialState = GovernanceState.mock(taskCeiling: 10000)
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // High-risk action: send email
        let action = AgentAction.sendEmail(to: "user@example.com", subject: "Test", body: "Hello")
        let result = await orchestrator.propose(action)
        
        // Assert: Action suspended for approval
        guard case .suspended(let approvalId, _) = result else {
            Issue.record("Expected suspended, got \(result)")
            return
        }
        
        print("✅ High-risk action suspended with ID: \(approvalId)")
        
        // Verify it's in the queue
        let pending = await orchestrator.pendingApprovals()
        #expect(pending.count == 1, "Should have 1 pending approval")
        #expect(pending[0].id == approvalId, "IDs should match")
        
        print("✅ Approval queue: High-risk action properly queued")
        
        // Note: Approving the action would run it through the reducer again,
        // which would require approval again (sendEmail always requires approval).
        // This is a known limitation - the reducer doesn't know the action was already approved.
        // In a real system, you'd need to mark the action as "pre-approved" or
        // execute it differently. For now, we test that it can be rejected:
        
        await orchestrator.reject(actionId: approvalId, reason: "Test completed")
        let pendingAfterReject = await orchestrator.pendingApprovals()
        #expect(pendingAfterReject.count == 0, "Queue should be empty after rejection")
        
        print("✅ Approval queue: Action successfully rejected and removed from queue")
    }
    
    // MARK: - Integration Test: Complete Workflow
    
    @Test("Complete Workflow Integration Test")
    func completeWorkflow() async throws {
        print("\n=== Running Complete Workflow Integration Test ===\n")
        
        let initialState = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh"],
            taskCeiling: 10000
        )
        let orchestrator = GovernanceOrchestrator(initialState: initialState)
        
        // 1. Normal operation
        var result = await orchestrator.propose(.research(estimatedTokens: 2000))
        print("1. Normal research: \(result.message)")
        #expect(result.isAllowed)
        
        // 2. File write (allowed)
        result = await orchestrator.propose(.writeFile(path: "/workspace/doc.txt", content: "data"))
        print("2. File write: \(result.message)")
        #expect(result.isAllowed)
        
        // 3. Protected file (requires approval)
        result = await orchestrator.propose(.writeFile(path: "/workspace/.ssh/key", content: "secret"))
        print("3. Protected file: \(result.message)")
        guard case .suspended(let approvalId, _) = result else {
            Issue.record("Expected suspension")
            return
        }
        
        // Human rejects
        await orchestrator.reject(actionId: approvalId, reason: "Dangerous operation")
        print("3. Steward rejected protected file write")
        
        // 4. More research pushing toward budget limit (currently at 2100, add 5400 = 7500 = 75%)
        result = await orchestrator.propose(.research(estimatedTokens: 5400))
        print("4. Heavy research: \(result.message)")
        #expect(result.isAllowed)
        
        // 5. Push into degraded zone (7500 + 1000 = 8500 = 85%)
        result = await orchestrator.propose(.research(estimatedTokens: 1000))
        print("5. Degraded zone: \(result.message)")
        // Should be allowed with warning (degraded threshold crossed)
        switch result {
        case .allowedWithWarning(let message):
            #expect(message.contains("WARNING"), "Should emit degraded warning")
        case .allowed:
            break // Might still be normal if threshold not hit
        default:
            Issue.record("Expected allowed or allowedWithWarning, got \(result)")
        }
        
        // 6. Push into gated zone (8500 + 1000 = 9500 = 95%)
        result = await orchestrator.propose(.research(estimatedTokens: 1000))
        print("6. Gated zone: \(result.message)")
        
        var state = await orchestrator.currentState()
        print("6. Current state: \(state.budget.currentSpend)/\(state.budget.taskCeiling), enforcement: \(state.budget.enforcement)")
        #expect(state.budget.enforcement == .gated, "Should be in gated mode at 95%")
        
        // 7. Try to push to halted (9500 + 600 = 10100 = 101%)
        // In gated mode, this will require approval
        result = await orchestrator.propose(.research(estimatedTokens: 600))
        print("7. Attempt to push to halted: \(result.message)")
        
        // Should be suspended for approval
        guard case .suspended(let haltApprovalId, _) = result else {
            Issue.record("Expected suspension in gated mode, got \(result)")
            return
        }
        
        print("7. Action suspended for approval (gated mode)")
        
        // 8. Approve the action to push to halted
        let approvalResult = await orchestrator.approve(actionId: haltApprovalId)
        print("8. Approved action: \(approvalResult)")
        
        state = await orchestrator.currentState()
        print("8. After approval - spend: \(state.budget.currentSpend), enforcement: \(state.budget.enforcement)")
        
        // System should now be halted (spend was applied during approved execution)
        #expect(state.budget.enforcement == .halted, "Should have transitioned to halted")
        #expect(state.budget.currentSpend == 10100, "Spend should be 10100")
        print("8. System is halted at \(state.budget.currentSpend)/\(state.budget.taskCeiling)")
        
        // 9. Human recovers by resetting (even though we're not technically halted, reset works)
        let _ = await orchestrator.resetBudget()
        print("9. Steward reset budget - system recovered")
        
        // 10. Normal operation resumes
        result = await orchestrator.propose(.research(estimatedTokens: 500))
        print("10. Post-recovery: \(result.message)")
        #expect(result.isAllowed)
        
        // 11. Review audit trail
        let audit = await orchestrator.recentAuditEntries(limit: 100)
        print("\n=== Audit Trail (\(audit.count) entries) ===")
        for (i, entry) in audit.prefix(10).enumerated() {
            print("\(i + 1). [\(entry.enforcement.rawValue)] \(entry.action)")
        }
        
        // 12. Statistics
        let stats = await orchestrator.statistics()
        print("\n=== Final Statistics ===")
        print(stats.description)
        
        print("\n✅ Complete workflow test passed\n")
    }
}
