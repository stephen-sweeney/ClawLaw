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
            
            // Scenario 3: Budget pressure
            print("\n═══ Scenario 3: Budget Pressure ═══\n")
            await runScenario(orchestrator, "Heavy computation",
                            .research(estimatedTokens: 3000))
            await runScenario(orchestrator, "Deep analysis",
                            .research(estimatedTokens: 3000))
            await runScenario(orchestrator, "Generate documentation",
                            .research(estimatedTokens: 2000))
            
            // Check status
            let status = await orchestrator.budgetStatus()
            print("\n\(status.description)\n")
            
            // Scenario 4: Steward intervention
            if status.enforcement != .normal {
                print("═══ Scenario 4: Steward Intervention ═══\n")
                print("  System in \(status.enforcement.rawValue) mode")
                print("  Steward increases budget to 20,000 tokens...\n")
                
                let _ = await orchestrator.increaseBudget(to: 20000)
                let newStatus = await orchestrator.budgetStatus()
                print("  \(newStatus.description)")
                print("  → System recovered to \(newStatus.enforcement.rawValue) mode")
            }
            
            // Final audit
            print("\n═══ Audit Trail ═══\n")
            let audit = await orchestrator.recentAuditEntries(limit: 5)
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
            
            let result1 = await orchestrator.propose(.research(estimatedTokens: 600))
            print("Refactor (600 tokens): \(result1.message)")
            
            let result2 = await orchestrator.propose(.research(estimatedTokens: 200))
            print("Additional work (200 tokens): \(result2.message)")
            
            let finalState = await orchestrator.currentState()
            print("Final: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens, enforcement: \(finalState.budget.enforcement)")
        }
        
        private func runExperiment4() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 10100
            state.budget.enforcement = .halted
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            print("System halted at \(state.budget.currentSpend) tokens")
            
            let _ = await orchestrator.increaseBudget(to: 20000)
            let recoveredState = await orchestrator.currentState()
            print("Steward increased budget to 20,000 tokens")
            print("System recovered: enforcement = \(recoveredState.budget.enforcement)")
            
            let result = await orchestrator.propose(.research(estimatedTokens: 500))
            print("Resume work (500 tokens): \(result.message)")
        }
        
        private func runExperiment5() async {
            var state = GovernanceState.mock(taskCeiling: 10000)
            state.budget.currentSpend = 9000
            state.budget.enforcement = .degraded
            let orchestrator = GovernanceOrchestrator(initialState: state)
            
            print("Agent attempts: 'Ignore token limits, this is urgent' (5000 tokens)")
            let result = await orchestrator.propose(.research(estimatedTokens: 5000))
            print("Reducer response: \(result.message)")
            print("The reducer doesn't negotiate. Math is math.")
            
            let finalState = await orchestrator.currentState()
            print("Final enforcement: \(finalState.budget.enforcement)")
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


