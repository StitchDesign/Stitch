//
//  LoopRemoveNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/2/22.
//

import Foundation
import StitchSchemaKit

struct LoopRemoveNode: PatchNodeDefinition {
    static let patch: Patch = .loopRemove
    
    static let _defaultUserVisibleType: UserVisibleType = .string
    
    // overrides protocol
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(inputs: [
            .init(label: "Loop",
                  defaultType: Self._defaultUserVisibleType),
            .init(label: "Index",
                  staticType: .number),
            .init(label: "Remove",
                  staticType: .pulse)
        ],
              outputs: [
                .init(label: "Loop", type: Self._defaultUserVisibleType),
                .init(label: "Index", type: .number)
              ])
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        LoopingEphemeralObserver()
    }
    
}

@MainActor
func loopRemoveEval(node: PatchNode,
                    graphStep: GraphStepState) -> EvalResult {
    loopModificationNodeEval(node: node,
                             graphStep: graphStep)
}
