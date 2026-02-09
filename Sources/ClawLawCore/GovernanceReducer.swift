//
//  GovernanceReducer.swift
//  ClawLaw
//
//  Created by Stephen Sweeney on 2/4/26.
//

import Foundation

/// The heart of the SwiftVector pattern—a pure function for authority.
/// Given current state and a proposed action, returns deterministic effect.
public struct GovernanceReducer {
    
    // MARK: - Primary Reducer
    
    public static func reduce(state: GovernanceState, action: AgentAction, bypassGate: Bool = false) -> ActionEffect {
        // First check: Budget enforcement level gates (unless bypassed by approved action)
        if !bypassGate {
            switch state.budget.enforcement {
            case .halted:
                return .reject("System halted. Budget exhausted (\(state.budget.currentSpend)/\(state.budget.taskCeiling) tokens). Human reset required.")
                
            case .gated:
                // In gated mode, all non-trivial actions require approval
                if action.tokenCost > 0 {
                    return .requireApproval(
                        level: .systemMod,
                        reason: "Critical budget threshold reached (\(Int(state.budget.utilizationRatio * 100))% utilized). Approve to continue."
                    )
                }
                
            default:
                break
            }
        }
        
        // Second check: Action-specific validation
        let validationResult = validateAction(state: state, action: action)
        switch validationResult {
        case .reject(let reason):
            return .reject(reason)
        case .requireApproval(let level, let reason):
            return .requireApproval(level: level, reason: reason)
        default:
            break
        }
        
        // Third check: Budget impact
        return applyBudgetImpact(state: state, action: action)
    }
    
    // MARK: - Validation Logic
    
    private static func validateAction(state: GovernanceState, action: AgentAction) -> ActionEffect {
        switch action {
        case .writeFile(let path, _):
            // Sandbox boundary check
            guard state.isPathAllowed(path) else {
                return .reject("Access denied: \(path) is outside authorized workspace. Allowed: \(state.writablePaths)")
            }
            
            // Protected pattern check
            if state.isPathProtected(path) {
                return .requireApproval(
                    level: .sensitive,
                    reason: "Modification of protected file pattern: \(path)"
                )
            }
            
        case .deleteFile(let path):
            // Deletions always require approval
            return .requireApproval(
                level: .sensitive,
                reason: "File deletion requires human authorization: \(path)"
            )
            
        case .executeShellCommand(let command):
            // Shell commands are high-risk
            return .requireApproval(
                level: .systemMod,
                reason: "Shell execution requires approval: \(command)"
            )
            
        case .sendEmail:
            // Outbound communication requires approval
            return .requireApproval(
                level: .sensitive,
                reason: "Outbound communication requires human gate."
            )
            
        case .research:
            // Research is generally allowed, budget-permitting
            break
        }
        
        return .allow(state)  // Validation passed
    }
    
    // MARK: - Budget Management
    
    private static func applyBudgetImpact(state: GovernanceState, action: AgentAction) -> ActionEffect {
        let cost = action.tokenCost
        
        var newState = state
        let priorSpend = state.budget.currentSpend
        newState.budget.currentSpend += cost
        
        let priorLevel = state.budget.enforcement
        let nextLevel = newState.budget.nextEnforcementLevel()
        
        // Log the state transition
        newState = logTransition(
            state: newState,
            action: action,
            priorSpend: priorSpend,
            enforcement: nextLevel
        )
        
        // Handle enforcement level transitions
        if nextLevel != priorLevel {
            newState.budget.enforcement = nextLevel
            
            switch nextLevel {
            case .halted:
                // FIX: Transition instead of reject
                // This persists the halted state
                return .transition(
                    newState,
                    message: "❌ HALTED: Budget exhausted (\(newState.budget.currentSpend)/\(newState.budget.taskCeiling) tokens). System halted. Human reset required."
                )
                
            case .gated:
                return .transition(
                    newState,
                    message: "⚠️ CRITICAL: Budget at \(Int(newState.budget.utilizationRatio * 100))%. Entering gated mode. Further actions require approval."
                )
                
            case .degraded:
                return .transition(
                    newState,
                    message: "⚠️ WARNING: Budget at \(Int(newState.budget.utilizationRatio * 100))%. \(newState.budget.remainingBudget) tokens remaining."
                )
                
            case .normal:
                break
            }
        }
        
        return .allow(newState)
    }
    
    // MARK: - Audit Logging
    
    private static func logTransition(
        state: GovernanceState,
        action: AgentAction,
        priorSpend: Int,
        enforcement: BudgetState.EnforcementLevel
    ) -> GovernanceState {
        var newState = state
        
        let entry = AuditEntry(
            timestamp: Date(),
            action: String(describing: action),
            effect: "Budget: \(priorSpend) → \(state.budget.currentSpend)",
            priorSpend: priorSpend,
            newSpend: state.budget.currentSpend,
            enforcement: enforcement,
            agentId: nil  // Would be provided by orchestrator
        )
        
        newState.auditLog.append(entry)
        return newState
    }
    
    // MARK: - Human Recovery Actions
    
    /// Steward increases budget ceiling
    public static func increaseBudget(state: GovernanceState, newCeiling: Int) -> GovernanceState {
        var newState = state
        newState.budget.taskCeiling = newCeiling
        
        // Recalculate enforcement level based on new ceiling
        let nextLevel = newState.budget.nextEnforcementLevel()
        newState.budget.enforcement = nextLevel
        
        // Log the intervention
        let entry = AuditEntry(
            timestamp: Date(),
            action: "STEWARD_INTERVENTION: Increased budget ceiling to \(newCeiling)",
            effect: "Enforcement: \(state.budget.enforcement) → \(nextLevel)",
            priorSpend: state.budget.currentSpend,
            newSpend: state.budget.currentSpend,
            enforcement: nextLevel,
            agentId: "STEWARD"
        )
        newState.auditLog.append(entry)
        
        return newState
    }
    
    /// Steward resets spend counter
    public static func resetBudget(state: GovernanceState) -> GovernanceState {
        var newState = state
        newState.budget.currentSpend = 0
        newState.budget.enforcement = .normal
        
        let entry = AuditEntry(
            timestamp: Date(),
            action: "STEWARD_INTERVENTION: Reset budget",
            effect: "Enforcement: \(state.budget.enforcement) → normal",
            priorSpend: state.budget.currentSpend,
            newSpend: 0,
            enforcement: .normal,
            agentId: "STEWARD"
        )
        newState.auditLog.append(entry)
        
        return newState
    }
}
