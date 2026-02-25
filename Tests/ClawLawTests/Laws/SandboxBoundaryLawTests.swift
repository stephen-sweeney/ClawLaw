//
//  SandboxBoundaryLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("SandboxBoundaryLaw")
struct SandboxBoundaryLawTests {

    let law = SandboxBoundaryLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Path-bearing actions

    @Test("Write to allowed path is allowed")
    func writeToAllowedPath() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.writeFile(id: actionID, path: "/workspace/test.txt", content: "data")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
        #expect(verdict.lawID == "SandboxBoundaryLaw")
    }

    @Test("Write outside sandbox is denied")
    func writeOutsideSandbox() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.writeFile(id: actionID, path: "/etc/passwd", content: "hack")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .deny)
        #expect(verdict.reason.contains("outside"))
    }

    @Test("Delete to allowed path is allowed")
    func deleteAllowedPath() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/old.txt")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
    }

    @Test("Delete outside sandbox is denied")
    func deleteOutsideSandbox() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.deleteFile(id: actionID, path: "/root/.bashrc")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .deny)
    }

    // MARK: - Non-path actions abstain

    @Test("Research action abstains (no path)")
    func researchAbstains() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    @Test("Shell command abstains (handled by ShellCommandApprovalLaw)")
    func shellAbstains() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "ls")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    @Test("Send email abstains (no path)")
    func emailAbstains() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.sendEmail(id: actionID, to: "a@b.com", subject: "hi", body: "test")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same verdict")
    func determinism() {
        let state = GovernanceState.mock(writablePaths: ["/workspace"])
        let action = GovernanceAction.writeFile(id: actionID, path: "/etc/passwd", content: "hack")

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
