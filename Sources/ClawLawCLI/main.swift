//
//  File.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation
import ArgumentParser
import ClawLawCore

@main
struct ClawLawCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clawlaw",
        abstract: "Governed Autonomy for OpenClaw",
        version: "0.1.0-alpha"
    )
    
    func run() throws {
        print("⚖️ ClawLaw Governance Layer Active")
        print("Status: Active Construction")
        print("See https://agentincommand.ai for the architectural thesis")
    }
}
