//
//  ProtectedPatternLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("ProtectedPatternLaw")
struct ProtectedPatternLawTests {

    let law = ProtectedPatternLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Protected paths → escalate

    @Test("Write to protected path escalates")
    func writeProtectedPath() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh", "credentials"]
        )
        let action = GovernanceAction.writeFile(
            id: actionID, path: "/workspace/.ssh/id_rsa", content: "key"
        )
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
        #expect(verdict.lawID == "ProtectedPatternLaw")
        #expect(verdict.reason.contains("protected"))
    }

    @Test("Delete of protected path escalates")
    func deleteProtectedPath() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh", "credentials"]
        )
        let action = GovernanceAction.deleteFile(
            id: actionID, path: "/workspace/credentials.json"
        )
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
    }

    // MARK: - Safe paths → allow

    @Test("Write to non-protected path allows")
    func writeSafePath() {
        let state = GovernanceState.mock(
            writablePaths: ["/workspace"],
            protectedPatterns: [".ssh", "credentials"]
        )
        let action = GovernanceAction.writeFile(
            id: actionID, path: "/workspace/readme.md", content: "docs"
        )
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .allow)
    }

    // MARK: - Non-path actions → abstain

    @Test("Research action abstains")
    func researchAbstains() {
        let state = GovernanceState.mock(protectedPatterns: [".ssh"])
        let action = GovernanceAction.research(id: actionID, estimatedTokens: 500)
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    @Test("Shell command abstains")
    func shellAbstains() {
        let state = GovernanceState.mock(protectedPatterns: [".ssh"])
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "ls")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same verdict")
    func determinism() {
        let state = GovernanceState.mock(protectedPatterns: [".ssh"])
        let action = GovernanceAction.writeFile(
            id: actionID, path: "/workspace/.ssh/key", content: "x"
        )

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
