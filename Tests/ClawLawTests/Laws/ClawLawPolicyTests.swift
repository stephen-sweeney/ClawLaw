//
//  ClawLawPolicyTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("ClawLawPolicy — Composition")
struct ClawLawPolicyTests {

    let policy = ClawLawPolicy.defaultPolicy()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Clean allow path

    @Test("Research in normal state is allowed by all laws")
    func researchAllowed() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .allow)
        #expect(trace.compositionRule == .denyWins)
        #expect(trace.jurisdictionID == "ClawLaw")
    }

    // MARK: - Single deny wins

    @Test("Write outside sandbox is denied even if other laws allow")
    func sandboxDenyWins() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh"],
            taskCeiling: 10000
        )
        let action = GovernanceAction.writeFile(
            id: actionID, path: "/etc/passwd", content: "hack"
        )
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .deny)
    }

    @Test("Halted enforcement denies regardless of action type")
    func haltedDenyWins() {
        let state = GovernanceState.mock().withBudget(
            BudgetState(taskCeiling: 100, currentSpend: 200, enforcement: .halted)
        )
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 10)
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .deny)
    }

    // MARK: - Escalation

    @Test("Delete file escalates through composition")
    func deleteEscalates() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            taskCeiling: 10000
        )
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/old.txt")
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .escalate)
    }

    @Test("Shell command escalates through composition")
    func shellEscalates() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "ls")
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .escalate)
    }

    @Test("Email escalates through composition")
    func emailEscalates() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.sendEmail(
            id: actionID, to: "a@b.com", subject: "hi", body: "test"
        )
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        #expect(trace.composedDecision == .escalate)
    }

    // MARK: - Multi-violation trace

    @Test("Delete of protected file outside sandbox captures multiple violations")
    func multiViolationTrace() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh"],
            taskCeiling: 10000
        )
        let action = GovernanceAction.deleteFile(id: actionID, path: "/etc/.ssh/key")
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        // SandboxBoundaryLaw denies (outside workspace)
        // ProtectedPatternLaw escalates (.ssh pattern)
        // DeletionApprovalLaw escalates (delete always)
        // denyWins → final decision is deny
        #expect(trace.composedDecision == .deny)

        // Verify trace contains verdicts from multiple laws
        let denyVerdicts = trace.verdicts.filter { $0.decision == .deny }
        let escalateVerdicts = trace.verdicts.filter { $0.decision == .escalate }
        #expect(!denyVerdicts.isEmpty, "Should have at least one deny verdict")
        #expect(!escalateVerdicts.isEmpty, "Should have at least one escalate verdict")
    }

    // MARK: - Policy structure

    @Test("Policy contains all 6 laws")
    func policyContainsAllLaws() {
        let state = GovernanceState.mock(taskCeiling: 10000)
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 10)
        let trace = policy.evaluate(state: state, action: action, correlationID: actionID)

        let lawIDs = Set(trace.verdicts.map(\.lawID))
        #expect(lawIDs.contains("EnforcementGateLaw"))
        #expect(lawIDs.contains("SandboxBoundaryLaw"))
        #expect(lawIDs.contains("ProtectedPatternLaw"))
        #expect(lawIDs.contains("DeletionApprovalLaw"))
        #expect(lawIDs.contains("ShellCommandApprovalLaw"))
        #expect(lawIDs.contains("OutboundCommLaw"))
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same trace")
    func determinism() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh"],
            taskCeiling: 10000
        )
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/.ssh/key")

        let t1 = policy.evaluate(state: state, action: action, correlationID: actionID)
        let t2 = policy.evaluate(state: state, action: action, correlationID: actionID)
        #expect(t1 == t2)
    }
}
