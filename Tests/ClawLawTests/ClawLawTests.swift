//
//  ClawLawTests.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//
//  PHASE 1: Minimal type-level tests to verify SwiftVector integration.
//  Full governance tests will be rewritten in Phase 6 after Laws,
//  Reducer, and Orchestrator are implemented (Phases 2-5).
//
//  The original 17 governance tests are preserved in git history.
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("ClawLaw Phase 1 — Type Integration Tests")
struct ClawLawTypeTests {

    // MARK: - GovernanceState conforms to State

    @Test("GovernanceState conforms to SwiftVector State protocol")
    func governanceStateConformsToState() {
        let state = GovernanceState.mock()

        // State requires stateHash() — provided by default implementation
        let hash = state.stateHash()
        #expect(!hash.isEmpty, "State hash should be non-empty")
        #expect(hash.count == 64, "SHA256 hash should be 64 hex characters")

        // Determinism: same state → same hash
        let hash2 = state.stateHash()
        #expect(hash == hash2, "Same state must produce same hash")
    }

    @Test("GovernanceState Codable round-trip preserves all fields")
    func governanceStateCodable() throws {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace", "/tmp"],
            protectedPatterns: [".ssh", "credentials"],
            taskCeiling: 5000
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GovernanceState.self, from: data)

        #expect(decoded == state, "Codable round-trip should preserve equality")
        #expect(decoded.id == state.id)
        #expect(decoded.writablePaths == state.writablePaths)
        #expect(decoded.protectedPatterns == state.protectedPatterns)
        #expect(decoded.budget == state.budget)
    }

    @Test("GovernanceState is immutable — updates produce new instances")
    func governanceStateImmutability() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let updated = state.withBudget(state.budget.withSpend(5000))

        #expect(state.budget.currentSpend == 0, "Original should be unchanged")
        #expect(updated.budget.currentSpend == 5000, "Updated should have new spend")
        #expect(state.id == updated.id, "ID should be preserved")
    }

    // MARK: - BudgetState enforcement reconciliation

    @Test("BudgetState init reconciles enforcement level")
    func budgetStateReconciliation() {
        // Stale enforcement (normal) with 95% spend → should reconcile to gated
        let budget = BudgetState(
            taskCeiling: 10000,
            currentSpend: 9500,
            enforcement: .normal
        )
        #expect(budget.enforcement == .gated, "Init should reconcile stale enforcement")

        // Over budget → halted
        let overBudget = BudgetState(
            taskCeiling: 10000,
            currentSpend: 10500,
            enforcement: .normal
        )
        #expect(overBudget.enforcement == .halted, "Over budget should be halted")

        // Normal spend → stays normal
        let normalBudget = BudgetState(
            taskCeiling: 10000,
            currentSpend: 5000,
            enforcement: .normal
        )
        #expect(normalBudget.enforcement == .normal, "50% spend should stay normal")
    }

    @Test("BudgetState.withSpend preserves reconciliation guarantee")
    func budgetStateWithSpend() {
        let budget = BudgetState(taskCeiling: 10000)
        let updated = budget.withSpend(9500)

        #expect(updated.enforcement == .gated, "95% spend should trigger gated")
        #expect(updated.currentSpend == 9500)
        #expect(updated.taskCeiling == 10000, "Ceiling unchanged")
    }

    @Test("BudgetState Codable round-trip with reconciliation")
    func budgetStateCodable() throws {
        let budget = BudgetState(
            taskCeiling: 10000,
            currentSpend: 8500,
            enforcement: .degraded,
            warningThreshold: 0.80,
            criticalThreshold: 0.95
        )

        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(BudgetState.self, from: data)

        #expect(decoded == budget, "Codable round-trip should preserve equality")
        #expect(decoded.enforcement == .degraded)
    }

    // MARK: - GovernanceAction conforms to Action

    @Test("GovernanceAction provides correlationID and actionDescription")
    func governanceActionProtocol() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let action = GovernanceAction.research(id: id, estimatedTokens: 500)

        #expect(action.correlationID == id)
        #expect(action.actionDescription.contains("500"))
        #expect(action.tokenCost == 500)
        #expect(action.authorizationLevel == .readOnly)
    }

    @Test("GovernanceAction Codable round-trip")
    func governanceActionCodable() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let actions: [GovernanceAction] = [
            .research(id: id, estimatedTokens: 500),
            .writeFile(id: id, path: "/workspace/test.txt", content: "data"),
            .deleteFile(id: id, path: "/workspace/old.txt"),
            .sendEmail(id: id, to: "user@example.com", subject: "Test", body: "Hello"),
            .executeShellCommand(id: id, command: "ls"),
            .increaseBudget(id: id, newCeiling: 20000),
            .resetBudget(id: id),
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for action in actions {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(GovernanceAction.self, from: data)
            #expect(decoded == action, "Codable round-trip failed for \(action.actionDescription)")
        }
    }

    @Test("GovernanceAction steward actions have zero token cost")
    func stewardActionsCost() {
        let id = UUID()
        #expect(GovernanceAction.increaseBudget(id: id, newCeiling: 20000).tokenCost == 0)
        #expect(GovernanceAction.resetBudget(id: id).tokenCost == 0)
        #expect(GovernanceAction.approveAction(id: id, approvalId: UUID()).tokenCost == 0)
        #expect(GovernanceAction.rejectAction(id: id, approvalId: UUID(), reason: "no").tokenCost == 0)
    }

    @Test("GovernanceAction isStewardAction distinguishes agent vs steward")
    func stewardActionFlag() {
        let id = UUID()
        #expect(!GovernanceAction.research(id: id, estimatedTokens: 500).isStewardAction)
        #expect(!GovernanceAction.writeFile(id: id, path: "/workspace/f", content: "x").isStewardAction)
        #expect(GovernanceAction.increaseBudget(id: id, newCeiling: 20000).isStewardAction)
        #expect(GovernanceAction.resetBudget(id: id).isStewardAction)
        #expect(GovernanceAction.approveAction(id: id, approvalId: UUID()).isStewardAction)
    }

    // MARK: - Path utilities

    @Test("GovernanceState path checks work correctly")
    func pathChecks() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace", "/tmp"],
            protectedPatterns: [".ssh", "credentials"]
        )

        #expect(state.isPathAllowed("/workspace/test.txt"))
        #expect(state.isPathAllowed("/tmp/scratch"))
        #expect(!state.isPathAllowed("/etc/passwd"))
        #expect(!state.isPathAllowed("/home/user/file.txt"))

        #expect(state.isPathProtected("/workspace/.ssh/id_rsa"))
        #expect(state.isPathProtected("/workspace/credentials.json"))
        #expect(!state.isPathProtected("/workspace/readme.md"))
    }
}
