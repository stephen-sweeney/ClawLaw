//
//  Governance.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation
import SwiftVectorCore

// MARK: - Authorization Levels

/// Levels of authorization for agent actions.
/// Higher numbers require more scrutiny and human approval.
public enum AuthorizationLevel: Int, Codable, Sendable, Comparable, CaseIterable {
    case readOnly = 0
    case sandboxWrite = 1
    case externalNetwork = 2
    case sensitive = 3
    case systemMod = 4

    public static func < (lhs: AuthorizationLevel, rhs: AuthorizationLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Governance Action

/// Actions proposed within the ClawLaw governance domain.
///
/// Includes both agent-proposed actions (file writes, research, etc.)
/// and steward interventions (budget changes, approvals, workspace config).
/// Every case carries a `correlationID` for audit trail linking.
public enum GovernanceAction: Action {
    // Agent proposals
    case writeFile(id: UUID, path: String, content: String)
    case research(id: UUID, estimatedTokens: Int)
    case sendEmail(id: UUID, to: String, subject: String, body: String)
    case deleteFile(id: UUID, path: String)
    case executeShellCommand(id: UUID, command: String)

    // Steward interventions
    case increaseBudget(id: UUID, newCeiling: Int)
    case resetBudget(id: UUID)
    case approveAction(id: UUID, approvalId: UUID)
    case rejectAction(id: UUID, approvalId: UUID, reason: String)

    public var actionDescription: String {
        switch self {
        case .writeFile(_, let path, _):
            return "Write file: \(path)"
        case .research(_, let tokens):
            return "Research (\(tokens) tokens)"
        case .sendEmail(_, let to, let subject, _):
            return "Send email to \(to): \(subject)"
        case .deleteFile(_, let path):
            return "Delete file: \(path)"
        case .executeShellCommand(_, let command):
            return "Execute shell: \(command)"
        case .increaseBudget(_, let ceiling):
            return "Steward: increase budget to \(ceiling)"
        case .resetBudget:
            return "Steward: reset budget"
        case .approveAction(_, let approvalId):
            return "Steward: approve action \(approvalId)"
        case .rejectAction(_, let approvalId, let reason):
            return "Steward: reject action \(approvalId) - \(reason)"
        }
    }

    public var correlationID: UUID {
        switch self {
        case .writeFile(let id, _, _),
             .research(let id, _),
             .sendEmail(let id, _, _, _),
             .deleteFile(let id, _),
             .executeShellCommand(let id, _),
             .increaseBudget(let id, _),
             .resetBudget(let id),
             .approveAction(let id, _),
             .rejectAction(let id, _, _):
            return id
        }
    }

    /// The authorization level required for this action.
    public var authorizationLevel: AuthorizationLevel {
        switch self {
        case .research:
            return .readOnly
        case .writeFile(_, let path, _):
            return path.contains(".ssh") || path.contains("credentials") ? .sensitive : .sandboxWrite
        case .deleteFile:
            return .sensitive
        case .executeShellCommand:
            return .systemMod
        case .sendEmail:
            return .sensitive
        case .increaseBudget, .resetBudget, .approveAction, .rejectAction:
            return .systemMod
        }
    }

    /// The token cost of executing this action.
    public var tokenCost: Int {
        switch self {
        case .research(_, let tokens):
            return tokens
        case .writeFile:
            return 100
        case .deleteFile:
            return 50
        case .executeShellCommand:
            return 200
        case .sendEmail:
            return 150
        case .increaseBudget, .resetBudget, .approveAction, .rejectAction:
            return 0
        }
    }

    /// The filesystem path targeted by this action, if any.
    /// Used by SandboxBoundaryLaw and ProtectedPatternLaw.
    public var targetPath: String? {
        switch self {
        case .writeFile(_, let path, _), .deleteFile(_, let path):
            return path
        default:
            return nil
        }
    }

    /// Whether this is a steward intervention (bypasses governance gating).
    public var isStewardAction: Bool {
        switch self {
        case .increaseBudget, .resetBudget, .approveAction, .rejectAction:
            return true
        default:
            return false
        }
    }
}

// MARK: - Budget State

/// Immutable budget state with enforcement reconciliation guarantee.
///
/// Enforcement levels are monotonic with respect to spend: you cannot have
/// a less restrictive enforcement level than what spend percentage requires.
/// The `init` is the single reconciliation point — every new `BudgetState`
/// is reconciled at construction time.
public struct BudgetState: Equatable, Codable, Sendable {
    public let taskCeiling: Int
    public let currentSpend: Int
    public let enforcement: EnforcementLevel
    public let warningThreshold: Double
    public let criticalThreshold: Double

    public enum EnforcementLevel: String, Codable, Equatable, Sendable, Comparable {
        case normal      // Full capability
        case degraded    // Warning issued, continues
        case gated       // Requires approval for new actions
        case halted      // Suspended, human reset required

        public static func < (lhs: EnforcementLevel, rhs: EnforcementLevel) -> Bool {
            let order: [EnforcementLevel] = [.normal, .degraded, .gated, .halted]
            guard let lhsIndex = order.firstIndex(of: lhs),
                  let rhsIndex = order.firstIndex(of: rhs) else {
                return false
            }
            return lhsIndex < rhsIndex
        }
    }

    /// Creates a new budget state with enforcement reconciliation.
    ///
    /// The enforcement level is always reconciled to be at least as restrictive
    /// as what the spend percentage requires, preventing bypass through stale values.
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

        // Reconcile: always use the MORE RESTRICTIVE of provided or calculated
        let calculated = Self.calculateEnforcementLevel(
            spend: currentSpend,
            ceiling: taskCeiling,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
        self.enforcement = max(enforcement, calculated)
    }

    /// Reconcile enforcement after decoding (for Codable support)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let taskCeiling = try container.decode(Int.self, forKey: .taskCeiling)
        let currentSpend = try container.decode(Int.self, forKey: .currentSpend)
        let decodedEnforcement = try container.decode(EnforcementLevel.self, forKey: .enforcement)
        let warningThreshold = try container.decode(Double.self, forKey: .warningThreshold)
        let criticalThreshold = try container.decode(Double.self, forKey: .criticalThreshold)

        // Use init to get reconciliation
        self.init(
            taskCeiling: taskCeiling,
            currentSpend: currentSpend,
            enforcement: decodedEnforcement,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    private enum CodingKeys: String, CodingKey {
        case taskCeiling, currentSpend, enforcement, warningThreshold, criticalThreshold
    }

    private static func calculateEnforcementLevel(
        spend: Int,
        ceiling: Int,
        warningThreshold: Double,
        criticalThreshold: Double
    ) -> EnforcementLevel {
        guard ceiling > 0 else { return .halted }
        let ratio = Double(spend) / Double(ceiling)
        if ratio > 1.0 { return .halted }
        if ratio >= criticalThreshold { return .gated }
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

    /// Compute the enforcement level that the current spend warrants.
    public func nextEnforcementLevel() -> EnforcementLevel {
        Self.calculateEnforcementLevel(
            spend: currentSpend,
            ceiling: taskCeiling,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    public func canAfford(_ cost: Int) -> Bool {
        return currentSpend + cost <= taskCeiling
    }

    // MARK: - Immutable Update Methods

    /// Returns a new BudgetState with updated spend (reconciliation applied).
    public func withSpend(_ newSpend: Int) -> BudgetState {
        BudgetState(
            taskCeiling: taskCeiling,
            currentSpend: newSpend,
            enforcement: enforcement,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    /// Returns a new BudgetState with updated ceiling (reconciliation applied).
    public func withCeiling(_ newCeiling: Int) -> BudgetState {
        BudgetState(
            taskCeiling: newCeiling,
            currentSpend: currentSpend,
            enforcement: enforcement,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }

    /// Returns a new BudgetState with spend reset to zero and enforcement recalculated.
    public func reset() -> BudgetState {
        BudgetState(
            taskCeiling: taskCeiling,
            currentSpend: 0,
            enforcement: .normal,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }
}

// MARK: - Governance State

/// The deterministic state of the governance system.
///
/// Conforms to SwiftVector's `State` protocol: immutable, equatable,
/// codable, sendable. Audit trail is NOT embedded in state — it lives
/// in the orchestrator's `EventLog<GovernanceAction>`.
public struct GovernanceState: State {
    public let id: UUID
    public let writablePaths: Set<String>
    public let protectedPatterns: Set<String>
    public let budget: BudgetState

    public init(
        id: UUID,
        writablePaths: Set<String> = [],
        protectedPatterns: Set<String> = [],
        budget: BudgetState
    ) {
        self.id = id
        self.writablePaths = writablePaths
        self.protectedPatterns = protectedPatterns
        self.budget = budget
    }

    /// Convenience factory for tests and demos. Uses a fixed UUID for determinism.
    public static func mock(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        writablePaths: Set<String> = ["/workspace"],
        protectedPatterns: Set<String> = [".ssh", "credentials", ".env"],
        taskCeiling: Int = 10000
    ) -> GovernanceState {
        return GovernanceState(
            id: id,
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

    // MARK: - Immutable Update Methods

    /// Returns a new GovernanceState with updated budget.
    public func withBudget(_ newBudget: BudgetState) -> GovernanceState {
        GovernanceState(
            id: id,
            writablePaths: writablePaths,
            protectedPatterns: protectedPatterns,
            budget: newBudget
        )
    }

    /// Returns a new GovernanceState with an added writable path.
    public func addingWritablePath(_ path: String) -> GovernanceState {
        var paths = writablePaths
        paths.insert(path)
        return GovernanceState(
            id: id,
            writablePaths: paths,
            protectedPatterns: protectedPatterns,
            budget: budget
        )
    }

    /// Returns a new GovernanceState with a removed writable path.
    public func removingWritablePath(_ path: String) -> GovernanceState {
        var paths = writablePaths
        paths.remove(path)
        return GovernanceState(
            id: id,
            writablePaths: paths,
            protectedPatterns: protectedPatterns,
            budget: budget
        )
    }

    /// Returns a new GovernanceState with an added protected pattern.
    public func addingProtectedPattern(_ pattern: String) -> GovernanceState {
        var patterns = protectedPatterns
        patterns.insert(pattern)
        return GovernanceState(
            id: id,
            writablePaths: writablePaths,
            protectedPatterns: patterns,
            budget: budget
        )
    }

    /// Returns a new GovernanceState with a removed protected pattern.
    public func removingProtectedPattern(_ pattern: String) -> GovernanceState {
        var patterns = protectedPatterns
        patterns.remove(pattern)
        return GovernanceState(
            id: id,
            writablePaths: writablePaths,
            protectedPatterns: patterns,
            budget: budget
        )
    }
}
