//
//  SyntaxToActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import SwiftUI
import OrderedCollections



func deriveStitchActions(_ viewNode: SyntaxView) -> VPLLayerConceptOrderedSet {
    var actions = VPLLayerConceptOrderedSet()

    // 1. Every ViewNode → one SACreateLayer (with children).
    if let createdLayer = viewNode.deriveCreateLayerAction() {
        actions.append(.layer(createdLayer))
        
        // 2. For each initializer argument in ViewNode.arguments:
        // 3. For each modifier in ViewNode.modifiers:
        actions.append(
            contentsOf: viewNode.deriveSetInputAndIncomingEdgeActions(createdLayer.name)
        )
        
        // 4. Recurse into children (emit their actions in order).
        for child in viewNode.children {
            let childActions = deriveStitchActions(child)
            for act in childActions {
                actions.append(act)
            }
        }
    } else {
        // if we can't create the layer, then we can't (or shouldn't) process its constructor-args, modifiers and children
        log("deriveStitchActions: Could not create layer for view node. Name: \(viewNode.name), viewNode: \(viewNode)")
    }
    
    return actions
}
