//
//  main.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  CLI for the ClawLaw governance layer.
//  Commands: status, demo, verify
//

import Foundation
import ArgumentParser
import ClawLawCore
import SwiftVectorCore

@main
struct ClawLawCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clawlaw",
        abstract: "Governed Autonomy for OpenClaw",
        version: "0.3.0",
        subcommands: [Status.self, Demo.self, Verify.self],
        defaultSubcommand: Status.self
    )
}

// MARK: - Status Command

extension ClawLawCLI {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show ClawLaw governance layer status"
        )

        func run() async throws {
            let state = GovernanceState.mock()
            let policy = ClawLawPolicy.defaultPolicy()
            let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

            // Evaluate a sample action to verify policy works
            let trace = policy.evaluate(
                state: state,
                action: .research(id: actionID, estimatedTokens: 100),
                correlationID: actionID
            )

            print("""

            ClawLaw Governance Layer v0.3.0
            ===============================

            SwiftVector Integration: Complete
              GovernanceState  -> State protocol
              GovernanceAction -> Action protocol
              ClawLawReducer   -> Reducer protocol
              ClawLawPolicy    -> GovernancePolicy (6 Laws, denyWins)
              ClawLawOrchestrator -> BaseOrchestrator wrapper

            Laws:
              EnforcementGateLaw      Budget enforcement gating
              SandboxBoundaryLaw      Filesystem sandbox
              ProtectedPatternLaw     Protected file patterns
              DeletionApprovalLaw     Deletion approval
              ShellCommandApprovalLaw Shell command approval
              OutboundCommLaw         Outbound communication approval

            Policy Verification:
              Composition rule: \(trace.compositionRule.rawValue)
              Jurisdiction: \(trace.jurisdictionID)
              Sample verdict: \(trace.composedDecision.rawValue)
              Verdicts evaluated: \(trace.verdicts.count)

            State:
              Hash: \(state.stateHash().prefix(16))...
              Budget: \(state.budget.currentSpend)/\(state.budget.taskCeiling) tokens
              Enforcement: \(state.budget.enforcement.rawValue)

            """)
        }
    }
}

// MARK: - Demo Command

extension ClawLawCLI {
    struct Demo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run a governance demo showing allow/deny/escalate"
        )

        func run() async throws {
            let clock = WallClock()
            let uuidGen = SystemUUIDGenerator()
            let state = GovernanceState.mock(
                writablePaths: ["/workspace"],
                protectedPatterns: [".ssh", "credentials", ".env"],
                taskCeiling: 10000
            )

            let orchestrator = ClawLawOrchestrator(
                initialState: state,
                clock: clock,
                uuidGenerator: uuidGen
            )

            print("""

            ClawLaw Governance Demo
            =======================

            """)

            let scenarios: [(String, GovernanceAction)] = [
                ("Research (500 tokens)", .research(id: uuidGen.next(), estimatedTokens: 500)),
                ("Write to workspace", .writeFile(id: uuidGen.next(), path: "/workspace/notes.txt", content: "hello")),
                ("Write outside sandbox", .writeFile(id: uuidGen.next(), path: "/etc/passwd", content: "hack")),
                ("Write to .ssh", .writeFile(id: uuidGen.next(), path: "/workspace/.ssh/key", content: "secret")),
                ("Delete file", .deleteFile(id: uuidGen.next(), path: "/workspace/old.txt")),
                ("Shell command", .executeShellCommand(id: uuidGen.next(), command: "ls -la")),
                ("Send email", .sendEmail(id: uuidGen.next(), to: "user@example.com", subject: "Test", body: "Hello")),
            ]

            for (label, action) in scenarios {
                let result = await orchestrator.propose(action, agentID: "demo-agent")
                let icon: String
                switch result.outcome {
                case .applied:  icon = "[ALLOW]"
                case .rejected: icon = "[REJECT]"
                case .denied:   icon = "[DENY]"
                case .escalated: icon = "[ESCALATE]"
                }
                print("  \(icon) \(label)")
                print("         \(result.rationale)")
                print()
            }

            let finalState = await orchestrator.currentState
            print("""
            Final State:
              Budget: \(finalState.budget.currentSpend)/\(finalState.budget.taskCeiling) tokens
              Enforcement: \(finalState.budget.enforcement.rawValue)
              Pending approvals: \((await orchestrator.pendingApprovals()).count)

            """)
        }
    }
}

// MARK: - Verify Command

extension ClawLawCLI {
    struct Verify: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify determinism and governance invariants"
        )

        func run() async throws {
            print("""

            ClawLaw Verification
            ====================

            """)

            var passed = 0
            var failed = 0

            func check(_ name: String, _ condition: Bool) {
                if condition {
                    print("  PASS  \(name)")
                    passed += 1
                } else {
                    print("  FAIL  \(name)")
                    failed += 1
                }
            }

            // 1. State hash determinism (same state hashed twice)
            let s1 = GovernanceState.mock(taskCeiling: 10000)
            check("State hash determinism", s1.stateHash() == s1.stateHash())

            // 2. Reducer determinism
            let reducer = ClawLawReducer()
            let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
            let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
            let r1 = reducer.reduce(state: s1, action: action)
            let r2 = reducer.reduce(state: s1, action: action)
            check("Reducer determinism", r1.newState == r2.newState)

            // 3. Law determinism
            let policy = ClawLawPolicy.defaultPolicy()
            let t1 = policy.evaluate(state: s1, action: action, correlationID: actionID)
            let t2 = policy.evaluate(state: s1, action: action, correlationID: actionID)
            check("Law evaluation determinism", t1 == t2)

            // 4. Budget reconciliation
            let budget = BudgetState(taskCeiling: 10000, currentSpend: 9500, enforcement: .normal)
            check("Budget reconciliation", budget.enforcement == .gated)

            // 5. Sandbox enforcement
            let trace = policy.evaluate(
                state: s1,
                action: .writeFile(id: actionID, path: "/etc/passwd", content: "x"),
                correlationID: actionID
            )
            check("Sandbox enforcement", trace.composedDecision == .deny)

            // 6. Policy has all 6 laws
            let researchTrace = policy.evaluate(
                state: s1,
                action: .research(id: actionID, estimatedTokens: 10),
                correlationID: actionID
            )
            let lawIDs = Set(researchTrace.verdicts.map(\.lawID))
            check("All 6 laws present", lawIDs.count == 6)

            print("""

            Results: \(passed) passed, \(failed) failed
            """)

            if failed > 0 {
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Production Dependencies

/// Wall clock for production use (not in reducers/laws — only orchestrator).
struct WallClock: Clock {
    func now() -> Date { Date() } // deterministic: audit timestamps only, not stored in state
}

/// System UUID generator for production use.
struct SystemUUIDGenerator: UUIDGenerator {
    func next() -> UUID { UUID() } // deterministic: correlation IDs only, not stored in state
}

