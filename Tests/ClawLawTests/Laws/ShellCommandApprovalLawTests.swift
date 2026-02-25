//
//  ShellCommandApprovalLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("ShellCommandApprovalLaw")
struct ShellCommandApprovalLawTests {

    let law = ShellCommandApprovalLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Shell command → escalate

    @Test("Shell command always escalates")
    func shellEscalates() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "rm -rf /")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
        #expect(verdict.lawID == "ShellCommandApprovalLaw")
        #expect(verdict.reason.contains("Shell"))
    }

    // MARK: - Non-shell → abstain

    @Test("Write file abstains")
    func writeAbstains() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.writeFile(id: actionID, path: "/workspace/f.txt", content: "x")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    @Test("Research abstains")
    func researchAbstains() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    @Test("Delete file abstains")
    func deleteAbstains() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/f.txt")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same verdict")
    func determinism() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "ls")

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
