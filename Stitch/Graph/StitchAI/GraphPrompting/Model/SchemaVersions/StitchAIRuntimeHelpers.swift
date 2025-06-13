//
//  StitchAIRuntimeHelpers.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/25.
//

// MARK: - comment or uncomment code below when runtime versions equate or differ from Stitch AI schema types.
extension CurrentStep.PortValue {
    var getInteractionId: NodeId? {
        switch self {
        case .assignedLayer(let x): return x?.id
        default: return nil
        }
    }
}
