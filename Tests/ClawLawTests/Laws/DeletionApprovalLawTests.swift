//
//  DeletionApprovalLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("DeletionApprovalLaw")
struct DeletionApprovalLawTests {

    let law = DeletionApprovalLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Delete → escalate

    @Test("Delete file always escalates")
    func deleteEscalates() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/old.txt")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
        #expect(verdict.lawID == "DeletionApprovalLaw")
        #expect(verdict.reason.contains("deletion"))
    }

    // MARK: - Non-delete → abstain

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

    @Test("Shell command abstains")
    func shellAbstains() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.executeShellCommand(id: actionID, command: "ls")
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .abstain)
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same verdict")
    func determinism() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.deleteFile(id: actionID, path: "/workspace/f.txt")

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
