//
//  OutboundCommLawTests.swift
//  ClawLaw
//

import Testing
import Foundation
import SwiftVectorCore
@testable import ClawLawCore

@Suite("OutboundCommLaw")
struct OutboundCommLawTests {

    let law = OutboundCommLaw()
    let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!

    // MARK: - Email → escalate

    @Test("Send email always escalates")
    func emailEscalates() {
        let state = GovernanceState.mock()
        let action = GovernanceAction.sendEmail(
            id: actionID, to: "user@example.com", subject: "Hello", body: "World"
        )
        let verdict = law.evaluate(state: state, action: action)

        #expect(verdict.decision == .escalate)
        #expect(verdict.lawID == "OutboundCommLaw")
        #expect(verdict.reason.contains("Outbound"))
    }

    // MARK: - Non-email → abstain

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
        let action = GovernanceAction.sendEmail(
            id: actionID, to: "a@b.com", subject: "s", body: "b"
        )

        let v1 = law.evaluate(state: state, action: action)
        let v2 = law.evaluate(state: state, action: action)
        #expect(v1 == v2)
    }
}
