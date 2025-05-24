//
//  StepTypeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/25.
//

import Foundation
import SwiftUI

// See `StepType` enum
enum StepTypeAction: Equatable, Hashable, Codable {
    
    case addNode(StepActionAddNode)
    case connectNodes(StepActionConnectionAdded)
    case changeValueType(StepActionChangeValueType)
    case setInput(StepActionSetInput)
    case sidebarGroupCreated(StepActionLayerGroupCreated)
    
    var stepType: StepType {
        switch self {
        case .addNode:
            return StepActionAddNode.stepType
        case .connectNodes:
            return StepActionConnectionAdded.stepType
        case .changeValueType:
            return StepActionChangeValueType.stepType
        case .setInput:
            return StepActionSetInput.stepType
        case .sidebarGroupCreated:
            return StepActionLayerGroupCreated.stepType
        }
    }
    
    func toStep() -> Step {
        switch self {
        case .addNode(let x):
            return x.toStep
        case .connectNodes(let x):
            return x.toStep
        case .changeValueType(let x):
            return x.toStep
        case .setInput(let x):
            return x.toStep
        case .sidebarGroupCreated(let x):
            return x.toStep
        }
    }
    
    static func fromStep(_ action: Step) -> Result<Self, StitchAIStepHandlingError> {
        switch action.stepType {
        case .addNode:
            return StepActionAddNode.fromStep(action).map { StepTypeAction.addNode($0) }
        case .connectNodes:
            return StepActionConnectionAdded.fromStep(action).map { .connectNodes($0) }
        case .changeValueType:
            return StepActionChangeValueType.fromStep(action).map { .changeValueType($0) }
        case .setInput:
            return StepActionSetInput.fromStep(action).map { .setInput($0) }
        case .sidebarGroupCreated:
            return StepActionLayerGroupCreated.fromStep(action).map { .sidebarGroupCreated($0) }
        }
    }
}
