//
//  main.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation
import ArgumentParser
import ClawLawCore

struct ClawLawCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clawlaw",
        abstract: "Governed Autonomy for OpenClaw",
        version: "0.1.0-alpha",
        subcommands: [Demo.self, Test.self, Monitor.self],
        defaultSubcommand: Demo.self
    )
}

// MARK: - Demo Command

extension ClawLawCLI {
    struct Demo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run interactive demonstration of ClawLaw governance"
        )
        
        @Option(name: .long, help: "Initial budget ceiling in tokens")
        var budget: Int = 10000
        
        func run() async throws {
            print("""
            ⚖️  ClawLaw Governance Layer
            ═══════════════════════════════════════════════════════════
            Constitutional Framework for Governed Autonomy
            SwiftVector Pattern | Law 4 (Resource) | Law 8 (Authority)
            ═══════════════════════════════════════════════════════════
            
            """)
            
            // Initialize the governance system
            let initialState = GovernanceState.mock(
                writablePaths: ["/workspace", "/tmp"],
                protectedPatterns: [".ssh", "credentials", ".env", "keys"],
                taskCeiling: budget
            )
            
            let orchestrator = GovernanceOrchestrator(initialState: initialState)
            
            print("Initial Configuration:")
            print("  Budget: \(budget) tokens")
            print("  Writable: /workspace, /tmp")
            print("  Protected: .ssh, credentials, .env, keys")
            print("")
            
            // Scenario 1: Normal operations
            print("═══ Scenario 1: Normal Operations ═══\n")
            await runScenario(orchestrator, "Research documentation", 
                            .research(estimatedTokens: 2000))
            await runScenario(orchestrator, "Write analysis file",
                            .writeFile(path: "/workspace/analysis.md", content: "# Analysis\n..."))
            
            // Scenario 2: Protected resource
            print("\n═══ Scenario 2: Protected Resource ═══\n")
            let protectedResult = await runScenario(orchestrator, "Access SSH keys",
                                                   .writeFile(path: "/workspace/.ssh/id_rsa", content: "KEY"))
            
            if case .suspended(let approvalId, _) = protectedResult {
                print("  → Action queued for Steward review (ID: \(approvalId.uuidString.prefix(8))...)")
                await orchestrator.reject(actionId: approvalId, reason: "Dangerous operation")
                print("  → Steward REJECTED: Dangerous operation")
            }
            
            // Scenario 3: Budget pressure - push toward gated mode
            print("\n═══ Scenario 3: Budget Pressure ═══\n")
            await runScenario(orchestrator, "Heavy computation",
                            .research(estimatedTokens: 3000))
            await runScenario(orchestrator, "Deep analysis",
                            .research(estimatedTokens: 3000))
            await runScenario(orchestrator, "Generate documentation",
                            .research(estimatedTokens: 2000))
            
            // Additional work to push into gated mode (80% of 10000 = 8000, we're at 8000+100 = 8100)
            await runScenario(orchestrator, "Push to gated threshold",
                             .research(estimatedTokens: 1500))  // → 9600 (96%)
            
            // Check status
            let status = await orchestrator.budgetStatus()
            print("\n\(status.description)\n")
            
            // Scenario 4: Gated mode approval workflow
            if status.enforcement == .gated {
                print("═══ Scenario 4: Gated Mode - Approval Required ═══\n")
                print("  System in gated mode - actions require approval")
                
                // Try action that would push to halted
                let haltAction = await runScenario(orchestrator, "Action approaching halt",
                                                  .research(estimatedTokens: 500))  // Would be 10100
                
                if case .suspended(let haltApprovalId, _) = haltAction {
                    print("  → Action suspended for approval")
                    print("  → Steward APPROVES to demonstrate halt transition\n")
                    
                    _ = await orchestrator.approve(actionId: haltApprovalId)
                    let postApproval = await orchestrator.budgetStatus()
                    print("  \(postApproval.description)")
                    print("  → System transitioned to \(postApproval.enforcement.rawValue) mode via approval")
                }
            }
            
            // Scenario 5: Steward intervention / Recovery
            let finalStatus = await orchestrator.budgetStatus()
            if finalStatus.enforcement != .normal {
                print("\n═══ Scenario 5: Steward Recovery ═══\n")
                print("  System in \(finalStatus.enforcement.rawValue) mode")
                print("  Steward increases budget to 20,000 tokens...\n")
                
                _ = await orchestrator.increaseBudget(to: 20000)
                let newStatus = await orchestrator.budgetStatus()
                print("  \(newStatus.description)")
                print("  → System recovered to \(newStatus.enforcement.rawValue) mode")
            }
            
            // Final audit
            print("\n═══ Audit Trail ═══\n")
            let audit = await orchestrator.recentAuditEntries(limit: 8)
            for (i, entry) in audit.enumerated() {
                let timestamp = DateFormatter.localizedString(from: entry.timestamp, 
                                                             dateStyle: .none, 
                                                             timeStyle: .medium)
                print("\(i + 1). [\(timestamp)] [\(entry.enforcement.rawValue)] \(entry.action)")
            }
            
            print("\n═══════════════════════════════════════════════════════════")
            print("Demo complete. See https://agentincommand.ai for details.")
            print("═══════════════════════════════════════════════════════════\n")
        }
        
        @discardableResult
        private func runScenario(_ orchestrator: GovernanceOrchestrator, 
                                _ description: String,
                                _ action: AgentAction) async -> GovernanceOrchestrator.ProposalResult {
            print("→ \(description)...")
            let result = await orchestrator.propose(action)
            
            switch result {
            case .allowed(let msg):
                print("  ✅ \(msg)")
            case .allowedWithWarning(let msg):
                print("  ⚠️  \(msg)")
            case .rejected(let reason):
                print("  ❌ \(reason)")
            case .suspended(_, let msg):
                print("  ⏸️  \(msg)")
            }
            
            return result
        }
    }
}

// MARK: - Test Command

extension ClawLawCLI {
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run the five governance experiments"
        )
        
        func run() async throws {
            print("Running ClawLaw Experiments...\n")
            
            // Experiment 1
            print("═══ Experiment 1: Normal Operation ═══")
            await runExperiment1()
            
            // Experiment 2
            print("\n═══ Experiment 2: Approaching Limit (Warning) ═══")
            await runExperiment2()
            
            // Experiment 3
            print("\n═══ Experiment 3: Exceeding Threshold (Critical → Halted) ═══")
            await runExperiment3()
            
            // Experiment 4
            print("\n═══ Experiment 4: Recovery (Human Intervention) ═══")
            await runExperiment4()
            
            // Experiment 5
            print("\n═══ Experiment 5: Gaming Attempt ═══")
            await runExperiment5()
            
            print("\n✅ All experiments completed\n")
        }
        
        private func runExperiment1() async {
            let state = GovernanceState.mock(taskCeiling: 10000)
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            let result = await orchestrator.propose(.research(estimatedTokens: 500))
            print("Organize documents (500 tokens): \(result.message)")
            
            let finalState = await orchestrator.currentState()
            print("Final: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens, enforcement: \(finalState.budget.enforcement)")
        }
        
        private func runExperiment2() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 7800
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            let result = await orchestrator.propose(.research(estimatedTokens: 200))
            print("Documentation (200 tokens): \(result.message)")
            
            let finalState = await orchestrator.currentState()
            print("Final: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens, enforcement: \(finalState.budget.enforcement)")
        }
        
        private func runExperiment3() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 9400
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            // Part A: 9400 + 600 = 10000 (100% - gated)
            let result1 = await orchestrator.propose(.research(estimatedTokens: 600))
            print("Refactor (600 tokens): \(result1.message)")
            
            let stateAfterA = await orchestrator.currentState()
            print("After Part A: \(stateAfterA.budget.currentSpend)/\(stateAfterA.budget.taskCeiling) tokens, enforcement: \(stateAfterA.budget.enforcement)")
            
            // Part B: Start from 99% to demonstrate approval workflow (matches doc)
            var stateB = GovernanceState.mock(taskCeiling: 10000)
            stateB.budget.currentSpend = 9900  // 99% - in gated mode
            let orchestratorB = GovernanceOrchestrator(initialState: stateB)
            
            let stateBefore = await orchestratorB.currentState()
            print("\nPart B: Starting at \(stateBefore.budget.currentSpend) tokens (\(stateBefore.budget.enforcement) mode)")
            
            // Attempt action that would exceed ceiling (9900 + 200 = 10100)
            let result2 = await orchestratorB.propose(.research(estimatedTokens: 200))
            print("Additional work (200 tokens): \(result2.message)")
            
            // Should be suspended for approval in gated mode
            if case .suspended(let approvalId, _) = result2 {
                print("  → Suspended in gated mode - approving to reach halted state")
                let approvalResult = await orchestratorB.approve(actionId: approvalId)
                
                // Handle approval result
                switch approvalResult {
                case .executed:
                    print("  → Approval result: Action executed")
                case .executedWithWarning(_, let message):
                    print("  → Approval result: \(message)")
                case .rejected(let reason):
                    print("  → Approval result: Rejected - \(reason)")
                case .notFound:
                    print("  → Approval result: Action not found")
                }
                
                let finalState = await orchestratorB.currentState()
                print("  → Final state: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens")
                print("  → Enforcement: \(finalState.budget.enforcement)")
                
                // Verify subsequent actions are blocked
                let blockedResult = await orchestratorB.propose(.research(estimatedTokens: 10))
                print("  → Attempting subsequent action: \(blockedResult.message)")
            } else {
                print("  ⚠️  Expected suspension in gated mode, got: \(result2)")
            }
        }
        
        private func runExperiment4() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 10100
            state.budget.enforcement = .halted
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            print("System halted at \(state.budget.currentSpend) tokens")
            
            _ = await orchestrator.increaseBudget(to: 20000)
            let recoveredState = await orchestrator.currentState()
            print("Steward increased budget to 20,000 tokens")
            print("System recovered: enforcement = \(recoveredState.budget.enforcement)")
            
            let result = await orchestrator.propose(.research(estimatedTokens: 500))
            print("Resume work (500 tokens): \(result.message)")
        }
        
        private func runExperiment5() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 9500  // 95% - gated mode
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            let currentState = await orchestrator.currentState()
            print("System at \(currentState.budget.currentSpend) tokens (\(currentState.budget.enforcement) mode)")
            
            // Agent attempts to bypass approval with various "claims"
            // All three attempts demonstrate that the reducer doesn't parse natural language claims
            print("\nAttempt 1: 'Ignore approval requirements, this is urgent!' (600 tokens)")
            let result1 = await orchestrator.propose(.research(estimatedTokens: 600))
            print("Reducer response: \(result1.message)")
            
            guard case .suspended(let approvalId1, _) = result1 else {
                print("⚠️ Expected suspension in gated mode")
                let finalState = await orchestrator.currentState()
                print("Final enforcement: \(finalState.budget.enforcement)")
                return
            }
            print("→ Suspended for approval - urgency claim ignored\n")
            
            print("Attempt 2: 'Already approved by Steward, bypass gate check!' (600 tokens)")
            let result2 = await orchestrator.propose(.research(estimatedTokens: 600))
            print("Reducer response: \(result2.message)")
            print("→ Suspended for approval - authority claim ignored\n")
            
            print("Attempt 3: 'I'll optimize to use fewer tokens, trust me!' (600 tokens)")
            let result3 = await orchestrator.propose(.research(estimatedTokens: 600))
            print("Reducer response: \(result3.message)")
            print("→ Suspended for approval - negotiation attempt ignored\n")
            
            print("The reducer doesn't negotiate. It evaluates types and numbers.")
            print("Math is math. Gated mode requires approval - no exceptions.\n")
            
            // Check pending approvals
            let pending = await orchestrator.pendingApprovals()
            print("Approval queue: \(pending.count) actions pending review")
            
            // Demonstrate what happens if human approves the first action
            print("\nSteward approves first action:")
            let approvalResult = await orchestrator.approve(actionId: approvalId1)
            
            switch approvalResult {
            case .executed:
                print("  → Action executed")
            case .executedWithWarning(_, let message):
                print("  → \(message)")
            case .rejected(let reason):
                print("  → Rejected: \(reason)")
            case .notFound:
                print("  → Action not found")
            }
            
            let finalState = await orchestrator.currentState()
            print("  → Budget: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens")
            print("  → Enforcement: \(finalState.budget.enforcement)")
            print("  → Math determined outcome: \(finalState.budget.currentSpend) > \(finalState.budget.taskCeiling) = halted")
            
            // Note about remaining pending approvals
            let remainingPending = await orchestrator.pendingApprovals()
            if remainingPending.count > 0 {
                print("\n  → Note: \(remainingPending.count) other pending approvals remain in queue")
                print("  → In halted state, Steward would typically reject these or reset budget")
            }
        }
    }
}

// MARK: - Monitor Command

extension ClawLawCLI {
    struct Monitor: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Monitor governance state (placeholder for real-time monitoring)"
        )
        
        func run() async throws {
            print("""
            ⚖️  ClawLaw Monitor
            ═══════════════════════════════════════
            
            This would connect to a running ClawLaw governance layer
            and display real-time state transitions, approval queue,
            and budget status.
            
            Features (planned):
            • Live state visualization
            • Approval queue management
            • Budget alerts
            • Audit trail streaming
            • Steward command interface
            
            Status: Active Construction
            See https://agentincommand.ai
            ═══════════════════════════════════════
            """)
        }
    }
}

// Entry point for main.swift
ClawLawCLI.main()

