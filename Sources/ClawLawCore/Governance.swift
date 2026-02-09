//
//  Governance.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

// MARK: - Authorization Levels

/// Levels of authorization for agent actions.
/// Higher numbers require more scrutiny and human approval.
public enum AuthorizationLevel: Int, Codable, Comparable {
    case readOnly = 0
    case sandboxWrite = 1
    case externalNetwork = 2
    case sensitive = 3
    case systemMod = 4
    
    public static func < (lhs: AuthorizationLevel, rhs: AuthorizationLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Action Effects

/// The result of a Reducer's evaluation of a proposed action.
public enum ActionEffect: Equatable {
    case allow(GovernanceState)
    case reject(String)
    case transition(GovernanceState, message: String)
    case requireApproval(level: AuthorizationLevel, reason: String)
    
    public static func == (lhs: ActionEffect, rhs: ActionEffect) -> Bool {
        switch (lhs, rhs) {
        case (.allow(let s1), .allow(let s2)):
            return s1.id == s2.id
        case (.reject(let r1), .reject(let r2)):
            return r1 == r2
        case (.transition(let s1, let m1), .transition(let s2, let m2)):
            return s1.id == s2.id && m1 == m2
        case (.requireApproval(let l1, let r1), .requireApproval(let l2, let r2)):
            return l1 == l2 && r1 == r2
        default:
            return false
        }
    }
}

// MARK: - Agent Actions

/// Actions an agent can propose.
public enum AgentAction: Equatable, Codable {
    case writeFile(path: String, content: String)
    case research(estimatedTokens: Int)
    case sendEmail(to: String, subject: String, body: String)
    case deleteFile(path: String)
    case executeShellCommand(command: String)
    
    public var authorizationLevel: AuthorizationLevel {
        switch self {
        case .research:
            return .readOnly
        case .writeFile(let path, _):
            return path.contains(".ssh") || path.contains("credentials") ? .sensitive : .sandboxWrite
        case .deleteFile:
            return .sensitive
        case .executeShellCommand:
            return .systemMod
        case .sendEmail:
            return .sensitive
        }
    }
    
    public var tokenCost: Int {
        switch self {
        case .research(let tokens):
            return tokens
        case .writeFile:
            return 100
        case .deleteFile:
            return 50
        case .executeShellCommand:
            return 200
        case .sendEmail:
            return 150
        }
    }
}

// MARK: - Budget State

public struct BudgetState: Equatable, Codable {
    public var taskCeiling: Int
    public var currentSpend: Int
    public var enforcement: EnforcementLevel
    
    // Thresholds for state transitions (as percentages)
    public var warningThreshold: Double
    public var criticalThreshold: Double
    
    public enum EnforcementLevel: String, Codable, Equatable, Comparable {
        case normal      // Full capability
        case degraded    // Warning issued, continues
        case gated       // Requires approval for new actions
        case halted      // Suspended, human reset required
        
        // Ordering: normal < degraded < gated < halted
        public static func < (lhs: EnforcementLevel, rhs: EnforcementLevel) -> Bool {
            let order: [EnforcementLevel] = [.normal, .degraded, .gated, .halted]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }
    
    public init(
        taskCeiling: Int,
        currentSpend: Int = 0,
        enforcement: EnforcementLevel = .normal,
        warningThreshold: Double = 0.80,
        criticalThreshold: Double = 0.95
    ) {
        self.taskCeiling = taskCeiling
        self.currentSpend = currentSpend
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        
        // Reconcile enforcement level with actual spend on initialization
        // This prevents state/enforcement mismatches when loading from storage
        let calculatedLevel = Self.calculateEnforcementLevel(
            spend: currentSpend,
            ceiling: taskCeiling,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
        
        // Use the more restrictive of provided or calculated enforcement
        // This prevents bypassing gating by providing stale enforcement level
        self.enforcement = max(enforcement, calculatedLevel)
    }
    
    private static func calculateEnforcementLevel(
        spend: Int,
        ceiling: Int,
        warningThreshold: Double,
        criticalThreshold: Double
    ) -> EnforcementLevel {
        guard ceiling > 0 else { return .halted }
        let ratio = Double(spend) / Double(ceiling)
        if ratio > 1.0 { return .halted }  // ONLY over 100% → halted
        if ratio >= criticalThreshold { return .gated }  // 95-100% → gated
        if ratio >= warningThreshold { return .degraded }
        return .normal
    }
    
    public var utilizationRatio: Double {
        guard taskCeiling > 0 else { return 1.0 }
        return Double(currentSpend) / Double(taskCeiling)
    }
    
    public var remainingBudget: Int {
        return max(0, taskCeiling - currentSpend)
    }
    
    public func nextEnforcementLevel() -> EnforcementLevel {
        let ratio = utilizationRatio
        if ratio > 1.0 { return .halted }  // ONLY over 100% → halted
        if ratio >= criticalThreshold { return .gated }  // 95-100% → gated
        if ratio >= warningThreshold { return .degraded }
        return .normal
    }
    
    public func canAfford(_ cost: Int) -> Bool {
        return currentSpend + cost <= taskCeiling
    }
}

// MARK: - Audit Trail

public struct AuditEntry: Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let action: String
    public let effect: String
    public let priorSpend: Int
    public let newSpend: Int
    public let enforcement: BudgetState.EnforcementLevel
    public let agentId: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: String,
        effect: String,
        priorSpend: Int,
        newSpend: Int,
        enforcement: BudgetState.EnforcementLevel,
        agentId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.effect = effect
        self.priorSpend = priorSpend
        self.newSpend = newSpend
        self.enforcement = enforcement
        self.agentId = agentId
    }
}

// MARK: - Governance State

/// The deterministic state of the governance system.
public struct GovernanceState: Equatable {
    public let id: UUID
    public var writablePaths: Set<String>
    public var protectedPatterns: Set<String>
    public var budget: BudgetState
    public var auditLog: [AuditEntry]
    
    public init(
        id: UUID = UUID(),
        writablePaths: Set<String> = [],
        protectedPatterns: Set<String> = [],
        budget: BudgetState,
        auditLog: [AuditEntry] = []
    ) {
        self.id = id
        self.writablePaths = writablePaths
        self.protectedPatterns = protectedPatterns
        self.budget = budget
        self.auditLog = auditLog
    }
    
    public static func mock(
        writablePaths: Set<String> = ["/workspace"],
        protectedPatterns: Set<String> = [".ssh", "credentials", ".env"],
        taskCeiling: Int = 10000
    ) -> GovernanceState {
        return GovernanceState(
            writablePaths: writablePaths,
            protectedPatterns: protectedPatterns,
            budget: BudgetState(taskCeiling: taskCeiling)
        )
    }
    
    public func isPathAllowed(_ path: String) -> Bool {
        return writablePaths.contains { path.hasPrefix($0) }
    }
    
    public func isPathProtected(_ path: String) -> Bool {
        return protectedPatterns.contains { path.contains($0) }
    }
}
