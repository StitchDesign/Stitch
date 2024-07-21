//
//  NodeTitleActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NodeTitleEdited: GraphEventWithResponse {
    let id: CanvasItemId
    let edit: String
    let isCommitting: Bool

    func handle(state: GraphState) -> GraphResponse {
        guard let node = state.getNode(id.associatedNodeId) else {
            log("NodeTitleEdited: could not retrieve node \(id)...")
            return .noChange
        }
        node.title = edit
        
        return .init(willPersist: isCommitting)
    }
}


extension CanvasItemId {
    var isNode: Bool {
        switch self {
        case .node:
            return true
        default:
            return false
        }
    }
    
    // Every canvas item belongs to same node.
    var associatedNodeId: NodeId {
        switch self {
        case .node(let x):
            return x
        case .layerInput(let x):
            return x.node
        case .layerOutput(let x):
            return x.node
        }
    }
}
