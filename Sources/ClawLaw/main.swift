//
//  main.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  PHASE 1: Minimal CLI that verifies SwiftVector integration.
//  Full demo, test, and monitor commands will be restored in Phase 7
//  after the governance layer is complete.
//

import Foundation
import ArgumentParser
import ClawLawCore
import SwiftVectorCore

@available(macOS 14, *)
struct ClawLawCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clawlaw",
        abstract: "Governed Autonomy for OpenClaw",
        version: "0.2.0-alpha",
        subcommands: [Status.self],
        defaultSubcommand: Status.self
    )
}

// MARK: - Status Command

extension ClawLawCLI {
    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show ClawLaw integration status"
        )

        func run() async throws {
            print("""
            ⚖️  ClawLaw Governance Layer
            ═══════════════════════════════════════════════════════════
            Version: 0.2.0-alpha (SwiftVector integration in progress)
            ═══════════════════════════════════════════════════════════

            SwiftVector Integration: ✅ Linked
            GovernanceState: ✅ Conforms to State protocol
            GovernanceAction: ✅ Conforms to Action protocol
            BudgetState: ✅ Immutable with enforcement reconciliation

            Phase Status:
              Phase 1: Type integration          ✅ Complete
              Phase 2: Law extraction             🚧 Pending
              Phase 3: ClawLawReducer             🚧 Pending
              Phase 4: ApprovalQueue determinism  🚧 Pending
              Phase 5: Orchestrator integration   🚧 Pending
              Phase 6: Test rewrite               🚧 Pending
              Phase 7: CLI restoration            🚧 Pending

            """)

            // Verify types work
            let state = GovernanceState.mock()
            let hash = state.stateHash()
            print("State hash: \(hash.prefix(16))...")
            print("Budget: \(state.budget.currentSpend)/\(state.budget.taskCeiling) tokens")
            print("Enforcement: \(state.budget.enforcement.rawValue)")
            print("")
        }
    }
}

// Entry point for main.swift
ClawLawCLI.main()
